import { z } from 'zod';

export const pageSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

export const reasonSchema = z.string().trim().min(10).max(500);

export const accountStatusSchema = z.enum(['active', 'suspended']);
export const creatorRequestStatusSchema = z.enum([
  'pending',
  'approved',
  'rejected',
]);
export const reportStatusSchema = z.enum([
  'open',
  'reviewing',
  'resolved',
  'dismissed',
]);
export const appealStatusSchema = z.enum([
  'pending',
  'approved',
  'rejected',
]);
export const reportTargetTypeSchema = z.enum(['post', 'comment']);

export const creatorRequestDecisionSchema = z.object({
  decision: z.enum(['approved', 'rejected']),
  reason: reasonSchema,
});

export const reportDecisionSchema = z.object({
  decision: z.enum(['retain', 'remove']),
  reason: reasonSchema,
});

export const appealDecisionSchema = z.object({
  decision: z.enum(['approved', 'rejected']),
  reason: reasonSchema,
});

export const userListQuerySchema = pageSchema.extend({
  search: z.string().trim().max(100).default(''),
  accountStatus: accountStatusSchema.optional(),
  creator: z.enum(['all', 'creator', 'member']).default('all'),
});

export const userAccountStatusSchema = z.object({
  status: accountStatusSchema,
  reason: reasonSchema,
});

export const userCreatorStatusSchema = z.object({
  isCreator: z.boolean(),
  reason: reasonSchema,
});

export const creatorRequestListQuerySchema = pageSchema.extend({
  search: z.string().trim().max(100).default(''),
  status: creatorRequestStatusSchema.default('pending'),
});
