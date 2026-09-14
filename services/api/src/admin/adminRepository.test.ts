import assert from 'node:assert/strict';
import test from 'node:test';

import type { SupabaseClient } from '@supabase/supabase-js';

import { createAdminRepository } from './adminRepository.js';

test('user repository excludes administrator profiles from rows and totals', async () => {
  const eqCalls: Array<[string, unknown]> = [];
  const profiles = [
    {
      id: 'admin-1',
      name: 'Administrator',
      email: 'admin@cyanzone.test',
      avatar_url: null,
      bio: null,
      is_content_creator: false,
      is_admin: true,
      account_status: 'active',
      created_at: '2026-07-31T00:00:00.000Z',
    },
    {
      id: 'member-1',
      name: 'Member',
      email: 'member@cyanzone.test',
      avatar_url: null,
      bio: null,
      is_content_creator: false,
      is_admin: false,
      account_status: 'active',
      created_at: '2026-07-30T00:00:00.000Z',
    },
  ];
  let filteredProfiles = profiles;

  const query = {
    select() {
      return this;
    },
    eq(column: string, value: unknown) {
      eqCalls.push([column, value]);
      if (column === 'is_admin') {
        filteredProfiles = profiles.filter(
          (profile) => profile.is_admin === value,
        );
      }
      return this;
    },
    order() {
      return this;
    },
    range() {
      return this;
    },
    or() {
      return this;
    },
    then(
      resolve: (value: {
        data: typeof profiles;
        error: null;
        count: number;
      }) => unknown,
    ) {
      return Promise.resolve({
        data: filteredProfiles,
        error: null,
        count: filteredProfiles.length,
      }).then(resolve);
    },
  };
  const client = {
    from(table: string) {
      assert.equal(table, 'profiles');
      return query;
    },
  } as unknown as SupabaseClient;

  const result = await createAdminRepository(client).listUsers({
    page: 1,
    pageSize: 20,
    search: '',
    creator: 'all',
  });

  assert.deepEqual(eqCalls, [['is_admin', false]]);
  assert.deepEqual(result.items.map((item) => item.id), ['member-1']);
  assert.equal(result.total, 1);
});

test('moderation repository paginates the default queue in Supabase', async () => {
  const ranges: Array<[number, number]> = [];
  const query = {
    select() {
      return this;
    },
    eq() {
      return this;
    },
    order() {
      return this;
    },
    range(from: number, to: number) {
      ranges.push([from, to]);
      return this;
    },
    then(
      resolve: (value: { data: never[]; error: null; count: number }) => unknown,
    ) {
      return Promise.resolve({ data: [], error: null, count: 45 }).then(
        resolve,
      );
    },
  };
  const client = {
    from(table: string) {
      assert.equal(table, 'content_moderation_cases');
      return query;
    },
  } as unknown as SupabaseClient;

  const result = await createAdminRepository(client).listModerationCases({
    page: 2,
    pageSize: 20,
    search: '',
    status: 'pending',
  });

  assert.deepEqual(ranges, [[20, 39]]);
  assert.equal(result.total, 45);
});

test('moderation repository filters target type before database pagination', async () => {
  const equalityFilters: Array<[string, unknown]> = [];
  const query = {
    select() {
      return this;
    },
    eq(column: string, value: unknown) {
      equalityFilters.push([column, value]);
      return this;
    },
    order() {
      return this;
    },
    range() {
      return this;
    },
    then(
      resolve: (value: { data: never[]; error: null; count: number }) => unknown,
    ) {
      return Promise.resolve({ data: [], error: null, count: 0 }).then(
        resolve,
      );
    },
  };
  const client = {
    from(table: string) {
      assert.equal(table, 'content_moderation_cases');
      return query;
    },
  } as unknown as SupabaseClient;

  await createAdminRepository(client).listModerationCases({
    page: 1,
    pageSize: 20,
    search: '',
    status: 'rejected',
    targetType: 'post',
  });

  assert.deepEqual(equalityFilters, [
    ['state', 'rejected'],
    ['decision_source', 'admin'],
    ['target_type', 'post'],
  ]);
});

test('moderation repository keeps pending queue independent of administrator decisions', async () => {
  const equalityFilters: Array<[string, unknown]> = [];
  const query = {
    select() { return this; },
    eq(column: string, value: unknown) { equalityFilters.push([column, value]); return this; },
    order() { return this; },
    range() { return this; },
    then(resolve: (value: { data: never[]; error: null; count: number }) => unknown) {
      return Promise.resolve({ data: [], error: null, count: 0 }).then(resolve);
    },
  };
  const client = { from() { return query; } } as unknown as SupabaseClient;
  await createAdminRepository(client).listModerationCases({
    page: 1, pageSize: 20, search: '', status: 'pending',
  });
  assert.deepEqual(equalityFilters, [['state', 'admin_review']]);
});

test('report repository starts independent target reads together', async () => {
  type QueryResult = {
    data: Array<Record<string, unknown>>;
    error: null;
  };
  const started: string[] = [];
  let resolvePosts!: (result: QueryResult) => void;
  let resolveComments!: (result: QueryResult) => void;

  function chain(result: Promise<QueryResult> | QueryResult) {
    return {
      select() {
        return this;
      },
      eq() {
        return this;
      },
      in() {
        return this;
      },
      order() {
        return this;
      },
      limit() {
        return this;
      },
      then(
        resolve: (value: QueryResult) => unknown,
        reject: (reason: unknown) => unknown,
      ) {
        return Promise.resolve(result).then(resolve, reject);
      },
    };
  }

  const reports: QueryResult = {
    data: [
      {
        id: 'report-post',
        reporter_id: 'reporter-1',
        target_type: 'post',
        target_id: 'post-1',
        reason: 'Spam content',
        status: 'pending_review',
        reviewed_by: null,
        reviewed_at: null,
        resolution_note: null,
        created_at: '2026-09-01T00:00:00.000Z',
      },
      {
        id: 'report-comment',
        reporter_id: 'reporter-2',
        target_type: 'comment',
        target_id: 'comment-1',
        reason: 'Harassment',
        status: 'pending_review',
        reviewed_by: null,
        reviewed_at: null,
        resolution_note: null,
        created_at: '2026-09-02T00:00:00.000Z',
      },
    ],
    error: null,
  };
  const postPromise = new Promise<QueryResult>((resolve) => {
    resolvePosts = resolve;
  });
  const commentPromise = new Promise<QueryResult>((resolve) => {
    resolveComments = resolve;
  });
  const client = {
    from(table: string) {
      started.push(table);
      if (table === 'reports') return chain(reports);
      if (table === 'posts') return chain(postPromise);
      if (table === 'comments') return chain(commentPromise);
      if (table === 'profiles') {
        return chain({ data: [], error: null });
      }
      throw new Error(`Unexpected table: ${table}`);
    },
  } as unknown as SupabaseClient;

  const operation = createAdminRepository(client).getReportCaseRows({
    page: 1,
    pageSize: 20,
    search: '',
    status: 'pending_review',
  });
  await new Promise<void>((resolve) => setImmediate(resolve));
  const targetReadsStarted = started.filter(
    (table) => table === 'posts' || table === 'comments',
  );

  resolvePosts({
    data: [
      { id: 'post-1', author_id: 'owner-1', title: 'Post', content: 'Body' },
    ],
    error: null,
  });
  resolveComments({
    data: [
      { id: 'comment-1', author_id: 'owner-2', content: 'Comment' },
    ],
    error: null,
  });
  await operation;

  assert.deepEqual(targetReadsStarted, ['posts', 'comments']);
});
