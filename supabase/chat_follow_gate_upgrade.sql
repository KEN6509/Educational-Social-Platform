-- CyanZone direct-chat follow-gate upgrade for existing Supabase projects.
--
-- Use this focused upgrade only when the project previously ran an older
-- supabase/chat.sql. Fresh projects should run the complete chat.sql instead.
-- Run after schema.sql, follow.sql, comment_mentions.sql, and the original
-- chat.sql. Existing conversations and message history are preserved.

begin;

-- Remove the obsolete overload so PostgREST always resolves the current
-- three-argument function used by the mobile client.
drop function if exists public.send_chat_message(uuid, text);

create or replace function public.can_send_chat_message(
  p_conversation_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_conversations c
    join public.chat_conversation_members cm
      on cm.conversation_id = c.id
     and cm.user_id = auth.uid()
     and cm.status = 'active'
    where c.id = p_conversation_id
      and (
        c.type = 'group'
        or exists (
          select 1
          from public.chat_conversation_members other_cm
          where other_cm.conversation_id = c.id
            and other_cm.user_id <> auth.uid()
            and other_cm.status = 'active'
            and public.chat_users_have_follow_relationship(
              auth.uid(),
              other_cm.user_id
            )
        )
      )
  );
$$;

create or replace function public.send_chat_message(
  p_conversation_id uuid,
  p_body text,
  p_mentions jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_conversation public.chat_conversations%rowtype;
  v_message_id uuid;
  v_pending_message_count int;
  v_mention jsonb;
  v_mentioned_user uuid;
  v_display_text text;
  v_start_offset int;
  v_end_offset int;
  v_is_all boolean;
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  if char_length(v_body) < 1 or char_length(v_body) > 10000 then
    raise exception 'Message body must be 1 to 10000 characters';
  end if;

  if p_conversation_id is null then
    raise exception 'Conversation id is required';
  end if;

  if jsonb_typeof(coalesce(p_mentions, '[]'::jsonb)) <> 'array'
    or jsonb_array_length(coalesce(p_mentions, '[]'::jsonb)) > 100
  then
    raise exception 'Message mentions must be an array of at most 100 entries';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_conversation_id::text, 0));

  select c.* into v_conversation
  from public.chat_conversations c
  where c.id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found';
  end if;

  if not exists (
    select 1
    from public.chat_conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = v_current_user
      and cm.status = 'active'
  ) then
    raise exception 'Active conversation membership required';
  end if;

  if v_conversation.type = 'direct'
    and not public.can_send_chat_message(p_conversation_id)
  then
    raise exception 'Follow relationship required';
  end if;

  if v_conversation.type = 'direct'
    and v_conversation.request_status = 'pending'
    and v_conversation.requested_by = v_current_user
    and not public.chat_users_have_relationship(
      v_conversation.requested_by,
      v_conversation.requested_to
    )
  then
    select count(*) into v_pending_message_count
    from public.chat_messages m
    where m.conversation_id = p_conversation_id
      and m.sender_id = v_current_user
      and m.deleted_at is null;

    if v_pending_message_count >= 3 then
      raise exception 'Pending message requests are limited to 3 messages';
    end if;
  end if;

  insert into public.chat_messages (conversation_id, sender_id, body)
  values (p_conversation_id, v_current_user, v_body)
  returning id into v_message_id;

  for v_mention in
    select value from jsonb_array_elements(coalesce(p_mentions, '[]'::jsonb))
  loop
    if v_conversation.type <> 'group' then
      raise exception 'Mentions are only supported in group chats';
    end if;

    v_display_text := v_mention->>'display_text';
    v_start_offset := (v_mention->>'start_offset')::int;
    v_end_offset := (v_mention->>'end_offset')::int;
    v_is_all := coalesce((v_mention->>'is_all')::boolean, false);

    if v_display_text is null
      or v_start_offset < 0
      or v_end_offset <= v_start_offset
      or v_end_offset > char_length(v_body)
      or substring(
        v_body from v_start_offset + 1
        for v_end_offset - v_start_offset
      ) <> v_display_text
    then
      raise exception 'Invalid mention span';
    end if;

    if v_is_all then
      if v_display_text <> '@all' or not exists (
        select 1
        from public.chat_conversation_members cm
        where cm.conversation_id = p_conversation_id
          and cm.user_id = v_current_user
          and cm.status = 'active'
          and cm.role = 'owner'
      ) then
        raise exception 'Only group admins can mention all members';
      end if;

      insert into public.chat_message_mentions (
        message_id,
        mentioned_user_id,
        display_text,
        start_offset,
        end_offset,
        is_all_source
      )
      select
        v_message_id,
        cm.user_id,
        v_display_text,
        v_start_offset,
        v_end_offset,
        true
      from public.chat_conversation_members cm
      where cm.conversation_id = p_conversation_id
        and cm.status = 'active'
        and cm.user_id <> v_current_user
      on conflict (message_id, mentioned_user_id, start_offset) do nothing;
    else
      v_mentioned_user := nullif(v_mention->>'user_id', '')::uuid;
      if v_mentioned_user is null
        or v_mentioned_user = v_current_user
        or not exists (
          select 1
          from public.chat_conversation_members cm
          join public.profiles p on p.id = cm.user_id
          where cm.conversation_id = p_conversation_id
            and cm.user_id = v_mentioned_user
            and cm.status = 'active'
            and v_display_text = '@' || p.name
        )
      then
        raise exception 'Mentioned user is not an active group member';
      end if;

      insert into public.chat_message_mentions (
        message_id,
        mentioned_user_id,
        display_text,
        start_offset,
        end_offset,
        is_all_source
      ) values (
        v_message_id,
        v_mentioned_user,
        v_display_text,
        v_start_offset,
        v_end_offset,
        false
      )
      on conflict (message_id, mentioned_user_id, start_offset) do nothing;
    end if;
  end loop;

  update public.chat_conversations c
  set last_message_at = now()
  where c.id = p_conversation_id;

  update public.chat_conversation_members cm
  set last_read_at = now()
  where cm.conversation_id = p_conversation_id
    and cm.user_id = v_current_user;

  begin
    insert into public.notifications (
      user_id,
      type,
      actor_id,
      conversation_id,
      message_id,
      title,
      body,
      action_type,
      action_payload
    )
    select
      cm.user_id,
      'chat_message',
      v_current_user,
      p_conversation_id,
      v_message_id,
      'New message',
      left(v_body, 160),
      'open_conversation',
      jsonb_build_object(
        'conversation_id', p_conversation_id,
        'message_id', v_message_id
      )
    from public.chat_conversation_members cm
    left join public.notification_preferences np
      on np.user_id = cm.user_id
    where cm.conversation_id = p_conversation_id
      and cm.user_id <> v_current_user
      and cm.status in ('active', 'pending')
      and (coalesce(np.in_app_enabled, true) or coalesce(np.push_enabled, false))
      and coalesce(np.chat_enabled, true);
  exception
    when undefined_column or check_violation or foreign_key_violation then
      raise notice 'Chat message saved but notification insert skipped: %', sqlerrm;
  end;

  return v_message_id;
end;
$$;

revoke execute on function public.can_send_chat_message(uuid) from public, anon;
revoke execute on function public.send_chat_message(uuid, text, jsonb) from public, anon;

grant execute on function public.can_send_chat_message(uuid) to authenticated;
grant execute on function public.send_chat_message(uuid, text, jsonb) to authenticated;

commit;

-- Expected result: both columns contain a function signature, not NULL.
select
  to_regprocedure('public.can_send_chat_message(uuid)')
    as permission_function,
  to_regprocedure('public.send_chat_message(uuid,text,jsonb)')
    as send_function;

-- Expected result: true. This verifies that the deployed send function calls
-- the current follow-permission function before inserting a direct message.
select position(
  'can_send_chat_message' in pg_get_functiondef(
    'public.send_chat_message(uuid,text,jsonb)'::regprocedure
  )
) > 0 as send_uses_follow_gate;
