import { z } from 'zod';

export const pageSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

export const reasonSchema = z.string().trim().min(10).max(500);
const optionalDecisionReasonSchema = z
  .string()
  .trim()
  .max(500)
  .refine(
    (value) => value.length === 0 || value.length >= 10,
    'Reason must be empty or contain at least 10 characters.',
  )
  .optional()
  .default('');

export const accountStatusSchema = z.enum(['active', 'suspended']);
export const creatorRequestStatusSchema = z.enum([
  'pending',
  'approved',
  'rejected',
]);
export const reportStatusSchema = z.enum([
  'pending_review',
  'resolved',
  'dismissed',
]);
export const appealStatusSchema = z.enum([
  'pending',
  'approved',
  'rejected',
]);
export const reportTargetTypeSchema = z.enum(['post', 'comment']);
export const aiModerationStatusSchema = z.enum(['pending', 'approved', 'rejected']);

export const creatorRequestDecisionSchema = z.object({
  decision: z.enum(['approved', 'rejected']),
  reason: reasonSchema,
});

export const reportDecisionSchema = z.discriminatedUnion('decision', [
  z.object({
    decision: z.literal('retain'),
    reason: optionalDecisionReasonSchema,
  }),
  z.object({
    decision: z.literal('remove'),
    reason: reasonSchema,
  }),
]);

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

export const userCreatorStatusSchema = z.discriminatedUnion('isCreator', [
  z.object({
    isCreator: z.literal(true),
    reason: optionalDecisionReasonSchema,
  }),
  z.object({
    isCreator: z.literal(false),
    reason: reasonSchema,
  }),
]);

export const creatorRequestListQuerySchema = pageSchema.extend({
  search: z.string().trim().max(100).default(''),
  status: creatorRequestStatusSchema.default('pending'),
});

export const reportCaseListQuerySchema = pageSchema.extend({
  search: z.string().trim().max(100).default(''),
  status: reportStatusSchema.default('pending_review'),
  targetType: reportTargetTypeSchema.optional(),
});

export const appealListQuerySchema = pageSchema.extend({
  search: z.string().trim().max(100).default(''),
  status: appealStatusSchema.default('pending'),
});

export const aiModerationListQuerySchema = pageSchema.extend({
  search: z.string().trim().max(100).default(''),
  status: aiModerationStatusSchema.default('pending'),
  targetType: reportTargetTypeSchema.optional(),
});

export const aiModerationDecisionSchema = z.discriminatedUnion('decision', [
  z.object({
    decision: z.literal('approved'),
    reason: optionalDecisionReasonSchema,
  }),
  z.object({
    decision: z.literal('rejected'),
    reason: reasonSchema,
  }),
]);
