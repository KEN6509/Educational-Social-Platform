import { ChevronRight } from 'lucide-react';
import type { ReactNode } from 'react';

export type CaseworkListItem = {
  id: string;
  title: string;
  subtitle: string;
  meta?: string;
  leading?: ReactNode;
  trailing?: ReactNode;
};

type Props = {
  items: CaseworkListItem[];
  selectedId: string | null;
  onSelect: (id: string) => void;
};

export function CaseworkList({ items, selectedId, onSelect }: Props) {
  return (
    <div aria-label="Casework queue" className="divide-y divide-slate-200">
      {items.map((item) => {
        const selected = item.id === selectedId;
        return (
          <button
            aria-pressed={selected}
            className={`group relative flex w-full items-center gap-3 px-4 py-4 text-left transition focus:z-10 focus:outline-none focus:ring-4 focus:ring-inset focus:ring-cyan-100 ${
              selected
                ? 'bg-cyan-50/80'
                : 'bg-white hover:bg-slate-50'
            }`}
            key={item.id}
            onClick={() => onSelect(item.id)}
            type="button"
          >
            {selected ? (
              <span className="absolute inset-y-0 left-0 w-1 bg-cyanZone-cyan" />
            ) : null}
            {item.leading}
            <span className="min-w-0 flex-1">
              <span className="flex items-baseline justify-between gap-3">
                <span className="truncate text-sm font-extrabold text-cyanZone-ink">
                  {item.title}
                </span>
                {item.meta ? (
                  <span className="shrink-0 text-xs text-slate-500">
                    {item.meta}
                  </span>
                ) : null}
              </span>
              <span className="mt-1 line-clamp-2 block text-xs leading-5 text-slate-600">
                {item.subtitle}
              </span>
            </span>
            {item.trailing ?? (
              <ChevronRight
                aria-hidden="true"
                className="h-4 w-4 shrink-0 text-slate-300 group-hover:text-cyan-600"
              />
            )}
          </button>
        );
      })}
    </div>
  );
}
