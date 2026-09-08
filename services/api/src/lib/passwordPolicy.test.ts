import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PASSWORD_POLICY_MESSAGE,
  isStrongPassword,
} from './passwordPolicy.js';
import { bootstrapSchema } from '../routes/adminSchema.js';

test('accepts passwords containing a period or underscore as symbols', () => {
  assert.equal(isStrongPassword('StrongPass12.'), true);
  assert.equal(isStrongPassword('StrongPass12_'), true);
});

test('rejects passwords shorter than 12 characters', () => {
  assert.equal(isStrongPassword('Short1.Aa'), false);
});

test('rejects passwords missing an uppercase letter', () => {
  assert.equal(isStrongPassword('strongpass12.'), false);
});

test('rejects passwords missing a lowercase letter', () => {
  assert.equal(isStrongPassword('STRONGPASS12.'), false);
});

test('rejects passwords missing a number', () => {
  assert.equal(isStrongPassword('StrongPassword.'), false);
});

test('rejects passwords missing a non-whitespace symbol', () => {
  assert.equal(isStrongPassword('StrongPassword12'), false);
  assert.equal(isStrongPassword('StrongPass12 '), false);
});

test('bootstrap schema applies the shared strong-password guidance', () => {
  const result = bootstrapSchema.safeParse({
    email: 'admin@example.com',
    password: 'weakpass',
    name: 'Administrator',
  });

  assert.equal(result.success, false);
  if (!result.success) {
    assert.deepEqual(
      result.error.flatten().fieldErrors.password,
      [PASSWORD_POLICY_MESSAGE],
    );
  }
});
