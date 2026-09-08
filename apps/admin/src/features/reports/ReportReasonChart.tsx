import { Flag } from 'lucide-react';
import { Cell, Pie, PieChart, Tooltip } from 'recharts';

type Props = {
  totalReports: number;
  uniqueReporters: number;
  reasonCounts: Array<{ reason: string; count: number }>;
};

const colors = [
  '#ef4444',
  '#f97316',
  '#eab308',
  '#14b8a6',
  '#3b82f6',
  '#8b5cf6',
  '#ec4899',
];

export function ReportReasonChart({
  totalReports,
  uniqueReporters,
  reasonCounts,
}: Props) {
  return (
    <section className="mt-6 grid gap-5 rounded-xl border border-slate-200 bg-white p-5 lg:grid-cols-[14rem_16rem_minmax(0,1fr)] lg:items-center">
      <div className="flex items-center gap-3">
        <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-red-50 text-red-600">
          <Flag className="h-5 w-5" aria-hidden="true" />
        </span>
        <div>
          <h3 className="font-black">{totalReports} total reports</h3>
          <p className="mt-1 text-sm text-slate-500">
            {uniqueReporters} unique reporters
          </p>
        </div>
      </div>

      {reasonCounts.length ? (
        <div
          aria-label="Report reasons"
          className="mx-auto h-44 w-56"
          role="img"
        >
          <PieChart height={176} width={224}>
            <Pie
              cx="50%"
              cy="50%"
              data={reasonCounts}
              dataKey="count"
              innerRadius={42}
              nameKey="reason"
              outerRadius={76}
              stroke="#ffffff"
              strokeWidth={3}
            >
              {reasonCounts.map((item, index) => (
                <Cell
                  fill={colors[index % colors.length]}
                  key={item.reason}
                />
              ))}
            </Pie>
            <Tooltip />
          </PieChart>
        </div>
      ) : (
        <div
          aria-label="Report reasons"
          className="grid min-h-32 place-items-center rounded-lg bg-slate-50 px-4 text-center text-sm font-semibold text-slate-500"
          role="img"
        >
          No report reasons available.
        </div>
      )}

      <ul className="grid gap-x-6 gap-y-3 sm:grid-cols-2">
        {reasonCounts.map((item, index) => {
          const percentage =
            totalReports === 0
              ? 0
              : Math.round((item.count / totalReports) * 100);
          return (
            <li className="flex min-w-0 items-center gap-3" key={item.reason}>
              <span
                aria-hidden="true"
                className="h-3 w-3 shrink-0 rounded-full"
                style={{ backgroundColor: colors[index % colors.length] }}
              />
              <span className="min-w-0 flex-1 text-sm font-semibold text-slate-700">
                {item.reason}
              </span>
              <span className="shrink-0 text-xs font-black text-slate-600">
                {item.count} · {percentage}%
              </span>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
