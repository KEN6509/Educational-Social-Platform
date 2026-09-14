import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { ModerationImageGallery } from './ModerationImageGallery';

describe('ModerationImageGallery', () => {
  it('shows an unavailable state when no retained image exists', () => {
    render(<ModerationImageGallery imageUrls={[]} />);
    expect(screen.getByText('Image no longer available.')).toBeVisible();
  });

  it('opens a contained image preview and handles load failures', () => {
    render(<ModerationImageGallery imageUrls={['https://cdn.test/a.jpg']} />);
    const image = screen.getByAltText('Moderated post attachment');
    expect(image.className).toContain('object-contain');
    fireEvent.click(screen.getByRole('button', { name: 'Enlarge moderated image 1' }));
    expect(screen.getByRole('dialog', { name: 'Moderated image preview' })).toBeVisible();
    fireEvent.error(screen.getAllByRole('img').slice(-1)[0]);
    expect(screen.queryByRole('dialog', { name: 'Moderated image preview' })).not.toBeInTheDocument();
    expect(screen.getByLabelText('Moderated image 1 unavailable')).toBeVisible();
  });
});
