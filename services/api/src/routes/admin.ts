import { Router } from 'express';

import { env } from '../config/env.js';
import { supabaseAdmin } from '../lib/supabase.js';
import { bootstrapSchema } from './adminSchema.js';

export const adminRouter = Router();

adminRouter.post('/bootstrap', async (req, res) => {
  const providedSecret = req.header('x-bootstrap-secret');

  if (providedSecret !== env.ADMIN_BOOTSTRAP_SECRET) {
    return res.status(401).json({ error: 'Invalid bootstrap secret.' });
  }

  const parsed = bootstrapSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({
      error: 'Invalid request body.',
      details: parsed.error.flatten().fieldErrors,
    });
  }

  const { count, error: countError } = await supabaseAdmin
    .from('profiles')
    .select('id', { count: 'exact', head: true })
    .eq('is_admin', true);

  if (countError) {
    return res.status(500).json({ error: countError.message });
  }

  if ((count ?? 0) > 0) {
    return res.status(409).json({
      error: 'An admin user already exists. Bootstrap is disabled.',
    });
  }

  const { data: createdUser, error: createError } =
    await supabaseAdmin.auth.admin.createUser({
      email: parsed.data.email,
      password: parsed.data.password,
      email_confirm: true,
      user_metadata: {
        name: parsed.data.name,
      },
    });

  if (createError || !createdUser.user) {
    return res.status(400).json({
      error: createError?.message ?? 'Unable to create admin user.',
    });
  }

  const { error: profileError } = await supabaseAdmin.from('profiles').upsert({
    id: createdUser.user.id,
    email: parsed.data.email,
    name: parsed.data.name,
    is_admin: true,
    is_content_creator: false,
    account_status: 'active',
  });

  if (profileError) {
    return res.status(500).json({ error: profileError.message });
  }

  return res.status(201).json({
    userId: createdUser.user.id,
    email: parsed.data.email,
    isAdmin: true,
  });
});
