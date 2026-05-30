import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  PERSPECTIVE_API_KEY: z.string().optional(),
  ADMIN_BOOTSTRAP_SECRET: z.string().min(24),
});

export const env = envSchema.parse(process.env);
