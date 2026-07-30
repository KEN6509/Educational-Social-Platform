import { describe, expect, it, vi } from 'vitest';

import { AdminApiError, createAdminApi } from './adminApi';

describe('adminApi', () => {
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
});
