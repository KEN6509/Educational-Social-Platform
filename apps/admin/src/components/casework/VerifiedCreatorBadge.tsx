import { BadgeCheck, Check } from 'lucide-react';

type Props = {
  className?: string;
  size?: number;
};

export function VerifiedCreatorBadge({
  className = '',
  size = 16,
}: Props) {
  return (
    <span
      aria-label="Verified content creator"
      className={`relative inline-grid shrink-0 place-items-center ${className}`}
      data-badge-shape="rosette"
      role="img"
      style={{ height: size, width: size }}
    >
      <BadgeCheck
        aria-hidden="true"
        className="absolute inset-0 text-[#4490AD]"
        fill="currentColor"
        size={size}
        strokeWidth={1.5}
      />
      <Check
        aria-hidden="true"
        className="relative text-white"
        size={size * 0.56}
        strokeWidth={4}
      />
    </span>
  );
}
