import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { ReportReasonChart } from './ReportReasonChart';

describe('ReportReasonChart', () => {
  it('shows totals, a labelled pie chart, and exact reason percentages', () => {
    render(
      <ReportReasonChart
        reasonCounts={[
          { reason: 'Bullying or harassment', count: 4 },
          { reason: 'Spam', count: 3 },
        ]}
        totalReports={7}
        uniqueReporters={7}
      />,
    );

    expect(screen.getByText('7 total reports')).toBeVisible();
    expect(screen.getByText('7 unique reporters')).toBeVisible();
    expect(screen.getByText('Bullying or harassment')).toBeVisible();
    expect(screen.getByText('4 · 57%')).toBeVisible();
    expect(screen.getByText('Spam')).toBeVisible();
    expect(screen.getByText('3 · 43%')).toBeVisible();
    expect(screen.getByRole('img', { name: 'Report reasons' })).toBeVisible();
  });

  it('renders a safe empty evidence state', () => {
    render(
      <ReportReasonChart
        reasonCounts={[]}
        totalReports={0}
        uniqueReporters={0}
      />,
    );

    expect(screen.getByText('No report reasons available.')).toBeVisible();
    expect(document.body).not.toHaveTextContent(/NaN|Infinity/);
  });
});
