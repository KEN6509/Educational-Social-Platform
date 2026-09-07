import {
  createVerifyAdmin,
  type AdminAuthSource,
} from './admin/adminAuth.js';
import { createAdminRepository } from './admin/adminRepository.js';
import { createProtectedAdminRouter } from './admin/adminRouter.js';
import { createAdminService } from './admin/adminService.js';
import { createApp } from './app.js';
import { env } from './config/env.js';
import {
  createSupabaseAdminRequestClient,
  supabaseAdmin,
} from './lib/supabase.js';
import {
  createVerifyMember,
  type MemberAuthSource,
} from './moderation/moderationAuth.js';
import {
  createModerationRepository,
  type ModerationSupabaseClient,
} from './moderation/moderationRepository.js';
import { GeminiModerationGateway } from './moderation/geminiModerationGateway.js';
import { createModerationService } from './moderation/moderationService.js';
import { createModerationRouter } from './moderation/moderationRouter.js';
import { ModerationProviderError } from './moderation/moderationTypes.js';
import { AdminBootstrapError } from './routes/admin.js';

const adminAuthSource: AdminAuthSource = {
  getUser: async (token) => {
    const { data, error } = await supabaseAdmin.auth.getUser(token);
    if (error || !data.user) return null;
    return { id: data.user.id, email: data.user.email ?? null };
  },
  getProfile: async (userId) => {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .select('id, email, is_admin, account_status')
      .eq('id', userId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return null;
    return {
      id: data.id,
      email: data.email,
      isAdmin: data.is_admin,
      accountStatus: data.account_status,
    };
  },
};

const protectedAdminRouter = createProtectedAdminRouter({
  createService: (context) =>
    createAdminService(
      createAdminRepository(
        createSupabaseAdminRequestClient(context.accessToken),
      ),
      env.REPORT_REVIEW_THRESHOLD,
      context.admin,
    ),
});

const memberAuthSource: MemberAuthSource = {
  getUser: async (token) => {
    const { data, error } = await supabaseAdmin.auth.getUser(token);
    if (error || !data.user) return null;
    return { id: data.user.id, email: data.user.email ?? null };
  },
  getProfile: async (userId) => {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .select('id, email, is_admin, account_status')
      .eq('id', userId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return null;
    return {
      id: data.id,
      email: data.email,
      isAdmin: data.is_admin,
      accountStatus: data.account_status,
    };
  },
};

const moderationProvider = env.GEMINI_API_KEY
  ? new GeminiModerationGateway({
      apiKey: env.GEMINI_API_KEY,
      model: env.GEMINI_MODEL,
      timeoutMs: env.GEMINI_TIMEOUT_MS,
    })
  : {
      moderate: async () => {
        throw new ModerationProviderError('provider_unconfigured', {
          retryable: true,
        });
      },
    };

const moderationRouter = createModerationRouter({
  verifyMember: createVerifyMember(memberAuthSource),
  service: createModerationService(
    createModerationRepository(
      supabaseAdmin as unknown as ModerationSupabaseClient,
    ),
    moderationProvider,
  ),
});

const app = createApp({
  allowedOrigins: env.CORS_ALLOWED_ORIGINS,
  bootstrapSecret: env.ADMIN_BOOTSTRAP_SECRET,
  countAdministrators: async () => {
    const { count, error } = await supabaseAdmin
      .from('profiles')
      .select('id', { count: 'exact', head: true })
      .eq('is_admin', true);
    if (error) throw new AdminBootstrapError(500, error.message);
    return count ?? 0;
  },
  createAdministrator: async (input) => {
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email: input.email,
      password: input.password,
      email_confirm: true,
      user_metadata: { name: input.name },
    });
    if (error || !data.user) {
      throw new AdminBootstrapError(
        400,
        error?.message ?? 'Unable to create admin user.',
      );
    }
    return { id: data.user.id };
  },
  upsertAdministratorProfile: async (input) => {
    const { error } = await supabaseAdmin.from('profiles').upsert({
      id: input.id,
      email: input.email,
      name: input.name,
      is_admin: true,
      is_content_creator: false,
      account_status: 'active',
    });
    if (error) throw new AdminBootstrapError(500, error.message);
  },
  protectedAdminRouter,
  moderationRouter,
  verifyAdmin: createVerifyAdmin(adminAuthSource),
});

export default app;
