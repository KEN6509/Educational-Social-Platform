import { z } from 'zod';
import {
  normalizeModerationScore,
  type ModerationProviderResult,
} from './moderationTypes.js';

const score = z.number()
  .finite()
  .min(0)
  .max(100)
  .transform(normalizeModerationScore);

export const moderationResultSchema = z.object({
  overallRiskScore: score,
  evidence: z.array(z.string().trim().min(1)).max(8),
  userReason: z.string().trim().min(1).max(280),
}).strict();

export const GEMINI_MODERATION_RESPONSE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['overallRiskScore', 'evidence', 'userReason'],
  properties: {
    overallRiskScore: { type: 'number', minimum: 0, maximum: 100 },
    evidence: { type: 'array', items: { type: 'string' }, maxItems: 8 },
    userReason: { type: 'string', minLength: 1, maxLength: 280 },
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
