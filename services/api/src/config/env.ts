import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const corsOriginsSchema = z
  .string()
  .default('http://localhost:5173,http://127.0.0.1:5173')
  .transform((value) => [
    ...new Set(
      value
        .split(',')
        .map((origin) => origin.trim())
        .filter((origin) => origin.length > 0),
    ),
  ])
  .pipe(z.array(z.string().url()));

const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  ADMIN_BOOTSTRAP_SECRET: z.string().min(24),
  REPORT_REVIEW_THRESHOLD: z.coerce.number().int().min(1).default(1),
  GEMINI_API_KEY: z.string().min(1).optional(),
  GEMINI_MODEL: z.string().trim().min(1).default('gemini-3.8-flash'),
  GEMINI_TIMEOUT_MS: z.coerce.number().int().min(1000).max(9500).default(8500),
  CORS_ALLOWED_ORIGINS: corsOriginsSchema,
});

export function parseEnv(
  input: NodeJS.ProcessEnv | Record<string, string>,
) {
  return envSchema.parse(input);
}

export const env = parseEnv(process.env);
