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

  test('chat SQL supports comment reply and comment like activity notifications',
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
}
