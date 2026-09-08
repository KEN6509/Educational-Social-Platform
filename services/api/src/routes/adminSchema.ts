import { z } from 'zod';

import {
  PASSWORD_POLICY_MESSAGE,
  isStrongPassword,
} from '../lib/passwordPolicy.js';

export const bootstrapSchema = z.object({
  email: z.string().email(),
  password: z.string().refine(isStrongPassword, {
    message: PASSWORD_POLICY_MESSAGE,
  }),
  name: z.string().min(2).max(80),
});
