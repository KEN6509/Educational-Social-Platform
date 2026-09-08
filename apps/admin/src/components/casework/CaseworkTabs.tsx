type TabItem = {
  id: string;
  label: string;
  count?: number;
};

type Props = {
  items: TabItem[];
  activeId: string;
  onChange: (id: string) => void;
};

export function CaseworkTabs({ items, activeId, onChange }: Props) {
  return (
    <div
      aria-label="Case status"
      className="flex gap-1 overflow-x-auto border-b border-slate-200 px-4 pt-2"
      role="tablist"
    >
      {items.map((item) => {
        const active = item.id === activeId;
        return (
          <button
            aria-selected={active}
            className={`relative flex min-h-12 shrink-0 items-center gap-2 px-3 text-sm font-bold transition ${
              active
                ? 'text-cyan-700'
                : 'text-slate-500 hover:text-slate-800'
            }`}
            key={item.id}
            onClick={() => onChange(item.id)}
            role="tab"
            type="button"
          >
            {item.label}
            {item.count !== undefined ? (
              <span
                className={`rounded-full px-2 py-0.5 text-xs ${
                  active ? 'bg-cyan-100 text-cyan-800' : 'bg-slate-100'
                }`}
              >
                {item.count}
              </span>
            ) : null}
            {active ? (
              <span className="absolute inset-x-2 bottom-0 h-0.5 rounded-full bg-cyanZone-cyan" />
            ) : null}
          </button>
        );
      })}
    </div>
  );
}
