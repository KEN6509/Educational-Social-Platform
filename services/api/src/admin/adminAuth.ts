import type { NextFunction, Request, RequestHandler, Response } from 'express';

export type AdminIdentity = {
  id: string;
  email: string;
};

export type VerifyAdmin = (token: string) => Promise<AdminIdentity>;

export type AdminAuthSource = {
  getUser: (
    token: string,
  ) => Promise<{ id: string; email: string | null } | null>;
  getProfile: (userId: string) => Promise<{
    id: string;
    email: string;
    isAdmin: boolean;
    accountStatus: string;
  } | null>;
};

export class AdminAuthorizationError extends Error {
  constructor(
    public readonly status: 401 | 403,
    message: string,
  ) {
    super(message);
    this.name = 'AdminAuthorizationError';
  }
}

export function createVerifyAdmin(source: AdminAuthSource): VerifyAdmin {
  return async (token) => {
    const user = await source.getUser(token);

    if (!user) {
      throw new AdminAuthorizationError(
        401,
        'Administrator session required.',
      );
    }

    const profile = await source.getProfile(user.id);

    if (
      !profile ||
      !profile.isAdmin ||
      profile.accountStatus !== 'active'
    ) {
      throw new AdminAuthorizationError(
        403,
        'Active administrator access required.',
      );
    }

    return {
      id: profile.id,
      email: profile.email || user.email || '',
    };
  };
}

export function requireAdministrator(
  verifyAdmin: VerifyAdmin,
): RequestHandler {
  return async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    const header = req.header('authorization');

    if (!header?.startsWith('Bearer ')) {
      res.status(401).json({
        error: 'Administrator session required.',
      });
      return;
    }

    const token = header.slice('Bearer '.length).trim();
    if (!token) {
      res.status(401).json({
        error: 'Administrator session required.',
      });
      return;
    }

    try {
      res.locals.admin = await verifyAdmin(token);
      next();
    } catch (error) {
      if (error instanceof AdminAuthorizationError) {
        res.status(error.status).json({ error: error.message });
        return;
      }

      next(error);
    }
  };
}
