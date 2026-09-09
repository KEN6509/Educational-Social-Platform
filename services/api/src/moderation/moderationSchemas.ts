import { z } from 'zod';
import {
  MODERATION_CATEGORIES,
  type ModerationProviderResult,
} from './moderationTypes.js';

const score = z.number().finite().min(0).max(100);

export const moderationResultSchema = z.object({
  recommendedDecision: z.enum(['approved', 'admin_review', 'rejected']),
  overallRiskScore: score,
  categoryScores: z.object(
    Object.fromEntries(MODERATION_CATEGORIES.map((category) => [category, score])) as Record<
      (typeof MODERATION_CATEGORIES)[number],
      typeof score
    >,
  ),
  evidence: z.array(z.string().trim().min(1)).max(8),
  userReason: z.string().trim().min(1).max(280),
  evidenceSource: z.enum(['text', 'image', 'both']),
});

export const GEMINI_MODERATION_RESPONSE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: [
    'recommendedDecision',
    'overallRiskScore',
    'categoryScores',
    'evidence',
    'userReason',
    'evidenceSource',
  ],
  properties: {
    recommendedDecision: {
      type: 'string',
      enum: ['approved', 'admin_review', 'rejected'],
    },
    overallRiskScore: { type: 'number', minimum: 0, maximum: 100 },
    categoryScores: {
      type: 'object',
      additionalProperties: false,
      required: [...MODERATION_CATEGORIES],
      properties: Object.fromEntries(
        MODERATION_CATEGORIES.map((category) => [category, { type: 'number', minimum: 0, maximum: 100 }]),
      ),
    },
    evidence: { type: 'array', items: { type: 'string' }, maxItems: 8 },
    userReason: { type: 'string', minLength: 1, maxLength: 280 },
    evidenceSource: { type: 'string', enum: ['text', 'image', 'both'] },
  },
} as const;

export function parseModerationResult(
  raw: unknown,
  model: string,
  promptVersion: string,
): ModerationProviderResult {
  const parsed = moderationResultSchema.parse(raw);
  return {
    ...parsed,
    model,
    promptVersion,
  };
}
