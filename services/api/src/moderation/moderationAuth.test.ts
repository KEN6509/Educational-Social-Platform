import assert from 'node:assert/strict';
import test from 'node:test';
import {
  createVerifyMember,
  MemberAuthorizationError,
} from './moderationAuth.js';

test('active member authentication exposes only the verified identity', async () => {
  const verifyMember = createVerifyMember({
    getUser: async () => ({ id: 'member-1', email: 'member@cyanzone.test' }),
    getProfile: async () => ({
      id: 'member-1',
      email: 'member@cyanzone.test',
      accountStatus: 'active',
      isAdmin: false,
    }),
  });

  assert.deepEqual(await verifyMember('valid-token'), {
    id: 'member-1',
    email: 'member@cyanzone.test',
  });
});

test('missing or invalid sessions are rejected with 401', async () => {
  const verifyMember = createVerifyMember({
    getUser: async () => null,
    getProfile: async () => null,
  });

  await assert.rejects(
    verifyMember('invalid-token'),
    (error: unknown) =>
      error instanceof MemberAuthorizationError && error.status === 401,
  );
});

test('suspended members and administrators cannot request moderation', async () => {
  for (const profile of [
    {
      id: 'member-1',
      email: 'member@cyanzone.test',
      accountStatus: 'suspended',
      isAdmin: false,
    },
    {
      id: 'admin-1',
      email: 'admin@cyanzone.test',
      accountStatus: 'active',
      isAdmin: true,
    },
  ]) {
    const verifyMember = createVerifyMember({
      getUser: async () => ({ id: profile.id, email: profile.email }),
      getProfile: async () => profile,
    });

    await assert.rejects(
      verifyMember('valid-token'),
      (error: unknown) =>
        error instanceof MemberAuthorizationError && error.status === 403,
    );
  }
});

test('missing profiles are rejected with 403', async () => {
  const verifyMember = createVerifyMember({
    getUser: async () => ({ id: 'member-1', email: 'member@cyanzone.test' }),
    getProfile: async () => null,
  });

  await assert.rejects(
    verifyMember('valid-token'),
    (error: unknown) =>
      error instanceof MemberAuthorizationError && error.status === 403,
  );
});
