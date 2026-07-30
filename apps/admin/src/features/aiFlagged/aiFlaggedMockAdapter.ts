import { aiFlaggedMockData } from './aiFlaggedMockData';
import type { AiFlaggedCase, AiFlaggedStatus } from './aiFlaggedTypes';

export function loadAiFlaggedPreview(): AiFlaggedCase[] {
  return aiFlaggedMockData.map((item) => ({
    ...item,
    evidence: [...item.evidence],
    imageUrls: [...item.imageUrls],
  }));
}

export function decideAiFlaggedPreview(
  rows: AiFlaggedCase[],
  id: string,
  status: Exclude<AiFlaggedStatus, 'pending'>,
): AiFlaggedCase[] {
  return rows.map((item) => (item.id === id ? { ...item, status } : item));
}
