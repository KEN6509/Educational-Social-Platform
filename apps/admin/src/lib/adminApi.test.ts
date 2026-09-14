import { describe, expect, it, vi } from 'vitest';

import { AdminApiError, createAdminApi } from './adminApi';

describe('adminApi', () => {
  it('invokes fetch with the browser global as its receiver', async () => {
    const receiverSensitiveFetch = vi.fn(function (
      this: typeof globalThis,
    ) {
      if (this !== globalThis) {
        throw new TypeError('Illegal invocation');
      }
      return Promise.resolve(
        new Response(JSON.stringify({ activeUsers: 0 }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }) as unknown as typeof fetch;
    const api = createAdminApi({
      baseUrl: 'https://api.cyanzone.test',
      fetcher: receiverSensitiveFetch,
      getAccessToken: async () => 'access-token',
    });

    await expect(api.get('/admin/overview')).resolves.toEqual({
      activeUsers: 0,
    });
  });

  it('attaches the bearer token and encodes query parameters', async () => {
    const fetcher = vi.fn(async () =>
      new Response(JSON.stringify({ items: [], total: 0 }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    const api = createAdminApi({
      baseUrl: 'https://api.cyanzone.test',
      fetcher,
      getAccessToken: async () => 'access-token',
    });

    await api.get('/admin/users', {
      search: 'cyan member',
      page: 2,
      pageSize: 20,
    });

    expect(fetcher).toHaveBeenCalledWith(
      'https://api.cyanzone.test/admin/users?search=cyan+member&page=2&pageSize=20',
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: 'Bearer access-token',
        }),
      }),
    );
  });

  it.each([
    [401, 'unauthenticated'],
    [403, 'forbidden'],
    [400, 'validation'],
    [404, 'not-found'],
    [409, 'conflict'],
    [500, 'server'],
  ] as const)('maps HTTP %s to %s', async (status, code) => {
    const api = createAdminApi({
      baseUrl: 'https://api.cyanzone.test',
      fetcher: async () =>
        new Response(JSON.stringify({ error: 'Safe API message.' }), {
          status,
          headers: { 'Content-Type': 'application/json' },
        }),
      getAccessToken: async () => 'access-token',
    });

    await expect(api.get('/admin/overview')).rejects.toMatchObject({
      code,
      message: 'Safe API message.',
    } satisfies Partial<AdminApiError>);
  });

  it('classifies a missing session before making a request', async () => {
    const fetcher = vi.fn();
    const api = createAdminApi({
      baseUrl: 'https://api.cyanzone.test',
      fetcher,
      getAccessToken: async () => null,
    });

    await expect(api.get('/admin/overview')).rejects.toMatchObject({
      code: 'unauthenticated',
    });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('reuses a recent authenticated GET response', async () => {
    const fetcher = vi.fn(async () =>
      new Response(JSON.stringify({ activeUsers: 4 }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    const api = createAdminApi({
      baseUrl: 'https://api.cyanzone.test',
      fetcher,
      getAccessToken: async () => 'access-token',
    });

    await api.get('/admin/overview');
    await api.get('/admin/overview');

    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('clears cached reads after an administrator write', async () => {
    const fetcher = vi.fn(async (_url: string | URL | Request, init?: RequestInit) =>
      new Response(
        init?.method === 'POST'
          ? undefined
          : JSON.stringify({ activeUsers: 4 }),
        {
          status: init?.method === 'POST' ? 204 : 200,
          headers: { 'Content-Type': 'application/json' },
        },
      ),
    );
    const api = createAdminApi({
      baseUrl: 'https://api.cyanzone.test',
      fetcher,
      getAccessToken: async () => 'access-token',
    });

    await api.get('/admin/overview');
    await api.post('/admin/users/member-1/account-status', {
      status: 'suspended',
      reason: 'Verified policy violation.',
    });
    await api.get('/admin/overview');

    expect(fetcher).toHaveBeenCalledTimes(3);
  });

  it('does not reuse an older in-flight read after an administrator write', async () => {
    let resolveStaleRead!: (response: Response) => void;
    let markReadStarted!: () => void;
    const readStarted = new Promise<void>((resolve) => {
      markReadStarted = resolve;
    });
    let getCount = 0;
    const fetcher = vi.fn(async (_url: string | URL | Request, init?: RequestInit) => {
      if (init?.method === 'POST') {
        return new Response(undefined, { status: 204 });
      }
      getCount += 1;
      if (getCount === 1) {
        markReadStarted();
        return new Promise<Response>((resolve) => {
          resolveStaleRead = resolve;
        });
      }
      return new Response(JSON.stringify({ activeUsers: 5 }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    });
    const api = createAdminApi({
      baseUrl: 'https://api.cyanzone.test',
      fetcher,
      getAccessToken: async () => 'access-token',
    });

    const staleRead = api.get('/admin/overview');
    await readStarted;
    await api.post('/admin/users/member-1/account-status', {
      status: 'suspended',
      reason: 'Verified policy violation.',
    });
    const freshRead = api.get<{ activeUsers: number }>('/admin/overview');
    setTimeout(() => {
      resolveStaleRead(
        new Response(JSON.stringify({ activeUsers: 4 }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }, 0);
    const freshResult = await freshRead;
    await staleRead;

    expect(freshResult.activeUsers).toBe(5);
    expect(fetcher).toHaveBeenCalledTimes(3);
  });
});
