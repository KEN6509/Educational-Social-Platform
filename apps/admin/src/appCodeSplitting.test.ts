import { describe, expect, it } from 'vitest';

import appSource from './App.tsx?raw';

describe('Admin route loading', () => {
  it('loads each casework page through a route-level dynamic import', () => {
    for (const page of [
      'overview/OverviewPage',
      'users/UsersPage',
      'creatorRequests/CreatorRequestsPage',
      'reports/ReportsPage',
      'appeals/AppealsPage',
      'aiFlagged/AiFlaggedContentPage',
    ]) {
      expect(appSource).toContain(`import('./features/${page}')`);
    }
  });
});
