import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  ADMIN_BOOTSTRAP_SECRET: z.string().min(24),
  REPORT_REVIEW_THRESHOLD: z.coerce.number().int().min(1).default(1),
  GEMINI_API_KEY: z.string().min(1).optional(),
});

export function parseEnv(
  input: NodeJS.ProcessEnv | Record<string, string>,
) {
  return envSchema.parse(input);
}

export const env = parseEnv(process.env);
