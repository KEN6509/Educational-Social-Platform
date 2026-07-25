import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('storage SQL creates the shared images bucket', () {
    final sql = File('../../supabase/storage.sql').readAsStringSync();

    expect(sql, contains("('images', 'images'"));
    expect(sql, contains("bucket_id = 'images'"));
    expect(sql, contains("update storage.objects"));
    expect(sql, isNot(contains("with check (bucket_id = 'post-images')")));
    expect(sql, isNot(contains("using (bucket_id = 'post-images')")));
  });

  test('chat SQL migrates existing notification tables in place', () {
    final sql = File('../../supabase/chat.sql').readAsStringSync();

    expect(
      sql,
      contains(
        'alter table public.notification_preferences add column if not exists chat_enabled',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.notification_preferences add column if not exists activity_enabled',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.notification_preferences add column if not exists followers_enabled',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.notifications add column if not exists conversation_id',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.notifications add column if not exists message_id',
      ),
    );
    expect(sql, contains('notifications_type_check'));
    expect(sql, contains("'chat_message'"));
    expect(sql, contains("'new_follower'"));
  });

  test('chat SQL marks notification sections read through RPC', () {
    final sql = File('../../supabase/chat.sql').readAsStringSync();

    expect(sql, contains('mark_notification_section_read'));
    expect(sql, contains('p_section text'));
    expect(sql, contains("p_section = 'activity'"));
    expect(sql, contains("p_section = 'followers'"));
    expect(sql, contains("p_section = 'system'"));
    expect(
      sql,
      contains(
        'grant execute on function public.mark_notification_section_read(text) to authenticated',
      ),
    );
  });

  test('chat SQL supports per-message deletion and group member removal', () {
    final sql = File('../../supabase/chat.sql').readAsStringSync();

    expect(
      sql,
      contains(
        'alter table public.chat_messages add column if not exists deleted_for',
      ),
    );
    expect(sql, contains('delete_chat_message_for_me'));
    expect(sql, contains('restore_chat_message_for_me'));
    expect(sql, contains('unsend_chat_message'));
    expect(sql, contains('remove_group_member'));
    expect(sql, contains('now() - interval \'10 minutes\''));
    expect(sql, isNot(contains("set body = 'This message was deleted'")));
    expect(sql, contains('delete from public.chat_messages m'));
    expect(sql, contains('chat_image_storage_paths_from_body'));
    expect(sql, contains('delete from storage.objects'));
    expect(sql, contains("bucket_id = 'images'"));
    expect(sql, contains('/storage/v1/object/public/images/'));
    expect(sql, contains('/storage/v1/object/public/post-images/'));
  });

  test('chat SQL keeps unsend working when storage cleanup fails', () {
    final sql = File('../../supabase/chat.sql').readAsStringSync();

    final helperStart = sql.indexOf(
        'create or replace function public.chat_delete_message_storage_objects');
    final pruneStart = sql.indexOf(
        'create or replace function public.chat_prune_message_if_fully_deleted');
    expect(helperStart, greaterThanOrEqualTo(0));
    expect(pruneStart, greaterThan(helperStart));

    final helperSql = sql.substring(helperStart, pruneStart);
    expect(helperSql, contains('delete from storage.objects'));
    expect(helperSql, contains('exception when others then'));
    expect(helperSql, contains('raise notice'));
  });

  test('chat SQL deletes attached images when the last group member exits', () {
    final sql = File('../../supabase/chat.sql').readAsStringSync();
    final start = sql.indexOf(
      'create or replace function public.chat_delete_group_messages_if_empty',
    );
    final end = sql.indexOf(
      'create or replace function public.remove_group_member',
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final groupCleanupSql = sql.substring(start, end);
    expect(groupCleanupSql, contains('chat_delete_message_storage_objects'));
    expect(groupCleanupSql, contains('delete from public.chat_messages'));
  });

  test(
      'chat SQL supports comment reply and comment like activity notifications',
      () {
    final sql = File('../../supabase/chat.sql').readAsStringSync();

    expect(sql, contains("'comment_reply'"));
    expect(sql, contains("'comment_like'"));
    expect(sql, contains('notify_comment_like'));
    expect(sql, contains('notify_comment_like_on_insert'));
    expect(sql, contains('new.parent_comment_id'));
    expect(sql, contains('parent.author_id'));
    expect(sql, contains('comment_likes'));
    expect(sql, contains('liked your comment'));
    expect(sql, contains('replied to your comment'));
  });

  test('chat SQL keeps only latest follower notification per actor', () {
    final sql = File('../../supabase/chat.sql').readAsStringSync();
    final start =
        sql.indexOf('create or replace function public.notify_new_follower()');
    final end =
        sql.indexOf('create or replace function public.notify_post_like()');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final followerSql = sql.substring(start, end);
    expect(followerSql, contains('delete from public.notifications'));
    expect(followerSql, contains("type = 'new_follower'"));
    expect(followerSql, contains('actor_id = new.follower_id'));
    expect(followerSql, contains('user_id = new.following_id'));
  });

  test('Supabase README documents applying chat SQL for activity triggers', () {
    final readme = File('../../supabase/README.md').readAsStringSync();

    expect(readme, contains('comment_reply'));
    expect(readme, contains('comment_like'));
    expect(readme, contains('supabase/chat.sql'));
  });

  test('chat SQL defines normalized group mention lifecycle', () {
    final sql = File('../../supabase/chat.sql').readAsStringSync();

    expect(sql,
        contains('create table if not exists public.chat_message_mentions'));
    expect(
        sql, contains('unique (message_id, mentioned_user_id, start_offset)'));
    expect(sql, contains("p_mentions jsonb default '[]'::jsonb"));
    expect(sql, contains('fetch_unvisited_chat_mentions'));
    expect(sql, contains('mark_chat_mention_visited'));
    expect(sql, contains("v_conversation.type <> 'group'"));
    expect(sql, contains("v_mention->>'is_all'"));
    expect(sql, contains("cm.role = 'owner'"));
    expect(sql, contains("'@' || p.name"));
    expect(sql, contains("cm.status = 'active'"));
    expect(sql, contains('on delete cascade'));
  });

  test('chat SQL defines MVP system notifications and post appeals', () {
    final sql = File('../../supabase/chat.sql').readAsStringSync();

    expect(
      sql,
      contains('create table if not exists public.post_appeals'),
    );
    expect(
      sql,
      contains('char_length(btrim(reason)) between 20 and 500'),
    );
    expect(sql, contains('unique (post_id, user_id)'));
    expect(sql, contains('submit_post_appeal'));
    expect(sql, contains("new.moderation_status = 'rejected'"));
    expect(
      sql,
      contains('old.is_content_creator is distinct from true'),
    );
    expect(sql, contains('system_enabled'));
    expect(sql, contains('Users delete own notifications'));
    expect(sql, contains("'creator_badge_awarded'"));
    expect(sql, contains("'post_rejected'"));
    expect(sql, contains("'scheduled_deletion_at'"));
  });
}
