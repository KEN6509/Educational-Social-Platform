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
