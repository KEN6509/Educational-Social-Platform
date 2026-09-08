import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { PortalTestMarker } from './PortalTestMarker';

describe('Administration Portal test setup', () => {
  it('renders React components in jsdom', () => {
    render(<PortalTestMarker />);
    expect(screen.getByText('Portal tests ready')).toBeInTheDocument();
  });
});
