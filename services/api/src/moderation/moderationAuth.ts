import type { NextFunction, Request, RequestHandler, Response } from 'express';

export type MemberIdentity = {
  id: string;
  email: string | null;
};

export type VerifyMember = (token: string) => Promise<MemberIdentity>;

export type MemberAuthSource = {
  getUser: (
    token: string,
  ) => Promise<{ id: string; email: string | null } | null>;
  getProfile: (userId: string) => Promise<{
    id: string;
    email?: string | null;
    isAdmin: boolean;
    accountStatus: string;
  } | null>;
};

export class MemberAuthorizationError extends Error {
  constructor(
    public readonly status: 401 | 403,
    message: string,
  ) {
    super(message);
    this.name = 'MemberAuthorizationError';
  }
}

export function createVerifyMember(source: MemberAuthSource): VerifyMember {
  return async (token) => {
    const user = await source.getUser(token);
    if (!user) {
      throw new MemberAuthorizationError(401, 'Member session required.');
    }

    const profile = await source.getProfile(user.id);
    if (
      !profile ||
      profile.id !== user.id ||
      profile.isAdmin ||
      profile.accountStatus !== 'active'
    ) {
      throw new MemberAuthorizationError(403, 'Active member access required.');
    }

    return {
      id: profile.id,
      email: profile.email ?? user.email ?? null,
    };
  };
}

export function requireMember(verifyMember: VerifyMember): RequestHandler {
  return async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    const header = req.header('authorization');
    if (!header?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Member session required.' });
      return;
    }

    const token = header.slice('Bearer '.length).trim();
    if (!token) {
      res.status(401).json({ error: 'Member session required.' });
      return;
    }

    try {
      res.locals.member = await verifyMember(token);
      res.locals.memberAccessToken = token;
      next();
    } catch (error) {
      if (error instanceof MemberAuthorizationError) {
        res.status(error.status).json({ error: error.message });
        return;
      }

      next(error);
    }
  };
}
