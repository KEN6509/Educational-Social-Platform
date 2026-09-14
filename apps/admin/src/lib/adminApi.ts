import { supabase } from './supabase';

export type AdminApiErrorCode =
  | 'unauthenticated'
  | 'forbidden'
  | 'validation'
  | 'not-found'
  | 'conflict'
  | 'server';

export class AdminApiError extends Error {
  constructor(
    public readonly code: AdminApiErrorCode,
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = 'AdminApiError';
  }
}

type QueryValue = string | number | boolean | null | undefined;

export type AdminApi = {
  get: <T>(
    path: string,
    query?: Record<string, QueryValue>,
  ) => Promise<T>;
  post: <T>(
    path: string,
    body: unknown,
  ) => Promise<T>;
};

type AdminApiDependencies = {
  baseUrl: string;
  fetcher: typeof fetch;
  getAccessToken: () => Promise<string | null>;
  requestTimeoutMs?: number;
  retryDelayMs?: number;
  sleep?: (milliseconds: number) => Promise<void>;
};

const ADMIN_READ_CACHE_TTL_MS = 10_000;
const RETRYABLE_GET_STATUSES = new Set([500, 502, 503, 504]);

function isAbortError(error: unknown): boolean {
  return typeof DOMException !== 'undefined'
    && error instanceof DOMException
    && error.name === 'AbortError';
}

function statusToCode(status: number): AdminApiErrorCode {
  if (status === 401) return 'unauthenticated';
  if (status === 403) return 'forbidden';
  if (status === 400) return 'validation';
  if (status === 404) return 'not-found';
  if (status === 409) return 'conflict';
  return 'server';
}

export function createAdminApi(
  dependencies: AdminApiDependencies,
): AdminApi {
  const readCache = new Map<
    string,
    { expiresAt: number; value: unknown }
  >();
  const readsInFlight = new Map<string, Promise<unknown>>();
  let cacheToken: string | null = null;
  let cacheGeneration = 0;

  const request = async <T>(
    path: string,
    init: RequestInit,
    query?: Record<string, QueryValue>,
  ): Promise<T> => {
    const token = await dependencies.getAccessToken();
    if (!token) {
      throw new AdminApiError(
        'unauthenticated',
        'Administrator session required.',
      );
    }

    if (cacheToken !== token) {
      readCache.clear();
      readsInFlight.clear();
      cacheToken = token;
      cacheGeneration += 1;
    }

    const url = new URL(
      `${dependencies.baseUrl.replace(/\/$/, '')}${path}`,
    );
    for (const [key, value] of Object.entries(query ?? {})) {
      if (value !== undefined && value !== null && value !== '') {
        url.searchParams.set(key, String(value));
      }
    }

    const executeOnce = async (): Promise<T> => {
      const controller = new AbortController();
      const timeout = setTimeout(
        () => controller.abort(),
        dependencies.requestTimeoutMs ?? 15_000,
      );
      try {
        const response = await dependencies.fetcher.call(
          globalThis,
          url.toString(),
          {
            ...init,
            signal: controller.signal,
            headers: {
              Accept: 'application/json',
              Authorization: `Bearer ${token}`,
              ...(init.body ? { 'Content-Type': 'application/json' } : {}),
              ...init.headers,
            },
          },
        );

        if (!response.ok) {
          let message = 'Unable to complete the administrator request.';
          try {
            const payload = (await response.json()) as { error?: string };
            if (payload.error) {
              message = payload.error;
            }
          } catch {
            // Keep the safe fallback message.
          }
          throw new AdminApiError(statusToCode(response.status), message, response.status);
        }

        if (response.status === 204) {
          return undefined as T;
        }
        return (await response.json()) as T;
      } finally {
        clearTimeout(timeout);
      }
    };

    const execute = async (): Promise<T> => {
      const isGet = init.method === 'GET';
      const maxAttempts = isGet ? 2 : 1;
      const sleep = dependencies.sleep ?? ((milliseconds: number) => new Promise<void>((resolve) => setTimeout(resolve, milliseconds)));
      for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
        try {
          return await executeOnce();
        } catch (error) {
          const retryable = isGet && (
            error instanceof AdminApiError
              ? RETRYABLE_GET_STATUSES.has(error.status ?? 0)
              : error instanceof TypeError || isAbortError(error)
          );
          if (attempt < maxAttempts && retryable) {
            await sleep(dependencies.retryDelayMs ?? 150);
            continue;
          }
          throw error instanceof TypeError || isAbortError(error)
            ? new AdminApiError('server', 'Unable to complete the administrator request.')
            : error;
        }
      }
      throw new AdminApiError('server', 'Unable to complete the administrator request.');
    };

    if (init.method !== 'GET') {
      readCache.clear();
      readsInFlight.clear();
      cacheGeneration += 1;
      return execute();
    }

    const cacheKey = url.toString();
    const cached = readCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.value as T;
    }
    readCache.delete(cacheKey);

    const currentRead = readsInFlight.get(cacheKey);
    if (currentRead) {
      return currentRead as Promise<T>;
    }

    const generation = cacheGeneration;
    const read = execute()
      .then((value) => {
        if (generation === cacheGeneration) {
          readCache.set(cacheKey, {
            expiresAt: Date.now() + ADMIN_READ_CACHE_TTL_MS,
            value,
          });
        }
        return value;
      })
      .finally(() => {
        if (readsInFlight.get(cacheKey) === read) {
          readsInFlight.delete(cacheKey);
        }
      });
    readsInFlight.set(cacheKey, read);
    return read;
  };

  return {
    get: (path, query) => request(path, { method: 'GET' }, query),
    post: (path, body) =>
      request(path, {
        method: 'POST',
        body: JSON.stringify(body),
      }),
  };
}

export const adminApi = createAdminApi({
  baseUrl: (import.meta.env.VITE_API_BASE_URL ??
    import.meta.env.VITE_API_URL) as string,
  fetcher: fetch,
  getAccessToken: async () => {
    const { data } = await supabase.auth.getSession();
    return data.session?.access_token ?? null;
  },
});
