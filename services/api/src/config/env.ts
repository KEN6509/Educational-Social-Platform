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

const envSchema = z
  .object({
    PORT: z.coerce.number().default(4000),
    SUPABASE_URL: z.string().url(),
    SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
    ADMIN_BOOTSTRAP_SECRET: z.string().min(24),
    REPORT_REVIEW_THRESHOLD: z.coerce.number().int().min(1).default(1),
    GEMINI_API_KEY: z.string().min(1).optional(),
    GEMINI_MODEL: z.string().trim().min(1).default('gemini-3.5-flash-lite'),
    GEMINI_FALLBACK_MODEL: z
      .string()
      .trim()
      .min(1)
      .default('gemini-3.8-flash'),
    GEMINI_TIMEOUT_MS: z.coerce
      .number()
      .int()
      .min(1000)
      .max(18000)
      .default(15000),
    PUSH_WEBHOOK_SECRET: z.string().min(32).optional(),
    FIREBASE_PROJECT_ID: z.string().trim().min(1).optional(),
    FIREBASE_CLIENT_EMAIL: z.string().email().optional(),
    FIREBASE_PRIVATE_KEY: z
      .string()
      .min(1)
      .transform((value) => value.replace(/\\n/g, '\n'))
      .optional(),
    CORS_ALLOWED_ORIGINS: corsOriginsSchema,
  })
  .refine((value) => value.GEMINI_MODEL !== value.GEMINI_FALLBACK_MODEL, {
    message: 'GEMINI_MODEL and GEMINI_FALLBACK_MODEL must be different',
    path: ['GEMINI_FALLBACK_MODEL'],
  })
  .refine(
    (value) => {
      const firebaseValues = [
        value.PUSH_WEBHOOK_SECRET,
        value.FIREBASE_PROJECT_ID,
        value.FIREBASE_CLIENT_EMAIL,
        value.FIREBASE_PRIVATE_KEY,
      ];
      return firebaseValues.every((item) => item == null) ||
        firebaseValues.every((item) => item != null);
    },
    {
      message:
        'Firebase push configuration must include the webhook secret and all Firebase credentials together',
      path: ['FIREBASE_PROJECT_ID'],
    },
  );

export function parseEnv(
  input: NodeJS.ProcessEnv | Record<string, string>,
) {
  return envSchema.parse(input);
}

export const env = parseEnv(process.env);
