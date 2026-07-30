import type { AiFlaggedCase } from './aiFlaggedTypes';

export const aiFlaggedMockData: AiFlaggedCase[] = [
  {
    id: 'preview-post-1',
    targetType: 'post',
    authorName: 'Demo Educator One',
    authorEmail: 'demo.educator1@example.test',
    submittedAt: '2026-07-31T08:20:00.000Z',
    title: 'Managing Competitive Stress',
    content:
      'A classroom discussion about recognizing pressure and asking a trusted adult for support.',
    imageUrls: [],
    riskScore: 0.56,
    evidence: [
      'Mentions emotional distress in an educational context.',
      'Requires human review because the surrounding context changes the meaning.',
    ],
    status: 'pending',
  },
  {
    id: 'preview-comment-1',
    targetType: 'comment',
    authorName: 'Demo Member Two',
    authorEmail: 'demo.member2@example.test',
    submittedAt: '2026-07-31T07:45:00.000Z',
    title: null,
    content:
      'That experiment looked dangerous until I read the safety steps.',
    imageUrls: [],
    riskScore: 0.44,
    evidence: [
      'Contains a safety-related term.',
      'The sentence appears cautionary, not encouraging harm.',
    ],
    status: 'pending',
  },
  {
    id: 'preview-post-2',
    targetType: 'post',
    authorName: 'Demo Educator Three',
    authorEmail: 'demo.educator3@example.test',
    submittedAt: '2026-07-30T15:10:00.000Z',
    title: 'Debating Historical Propaganda',
    content:
      'Students compare persuasive language in historical posters and discuss why it can cause harm.',
    imageUrls: [],
    riskScore: 0.49,
    evidence: [
      'Includes potentially harmful language as a subject of analysis.',
      'Educational framing should be checked by a reviewer.',
    ],
    status: 'pending',
  },
  {
    id: 'preview-comment-2',
    targetType: 'comment',
    authorName: 'Demo Member Four',
    authorEmail: 'demo.member4@example.test',
    submittedAt: '2026-07-30T11:30:00.000Z',
    title: null,
    content:
      'This explanation helped me understand why the claim is misleading.',
    imageUrls: [],
    riskScore: 0.41,
    evidence: ['References misinformation while disagreeing with it.'],
    status: 'approved',
  },
  {
    id: 'preview-post-3',
    targetType: 'post',
    authorName: 'Demo Educator Five',
    authorEmail: 'demo.educator5@example.test',
    submittedAt: '2026-07-29T09:15:00.000Z',
    title: 'Unsafe Shortcut Challenge',
    content:
      'A challenge that encourages students to ignore laboratory safety instructions.',
    imageUrls: [],
    riskScore: 0.6,
    evidence: [
      'Encourages bypassing safety instructions.',
      'The stated challenge may create a direct physical risk.',
    ],
    status: 'rejected',
  },
  {
    id: 'preview-comment-3',
    targetType: 'comment',
    authorName: 'Demo Member Six',
    authorEmail: 'demo.member6@example.test',
    submittedAt: '2026-07-28T17:05:00.000Z',
    title: null,
    content:
      'People who disagree should be removed from the discussion entirely.',
    imageUrls: [],
    riskScore: 0.52,
    evidence: [
      'Potentially exclusionary language.',
      'Human review is needed to distinguish moderation feedback from harassment.',
    ],
    status: 'approved',
  },
];
