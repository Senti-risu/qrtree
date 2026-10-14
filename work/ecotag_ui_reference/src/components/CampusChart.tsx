import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from "recharts";
import type { CampusCount } from "../hooks/useDashboardData";

interface Props {
  data: CampusCount[];
  loading?: boolean;
}

const BAR_COLORS = ["#2E7D32", "#43A047", "#66BB6A", "#A5D6A7", "#C8E6C9"];

const CustomTooltip = ({ active, payload, label }: any) =>
  active && payload?.length ? (
    <div className="bg-white border border-green-100 rounded-xl px-3 py-2 shadow text-sm">
      <div className="font-semibold text-gray-900 mb-0.5">{label}</div>
      <div style={{ color: "#2E7D32" }}>{payload[0].value} plants</div>
    </div>
  ) : null;

export default function CampusChart({ data, loading }: Props) {
  return (
    <div className="bg-white rounded-2xl p-6" style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.03)", border: "1px solid #D8EAD8" }}>
      <div className="text-base font-bold text-gray-900 mb-0.5" style={{ fontFamily: "'Nunito',sans-serif" }}>Plants by Campus</div>
      <div className="text-xs mb-5" style={{ color: "#5A7A5C" }}>Distribution across university campuses</div>

      {loading ? (
        <div className="skeleton rounded-xl" style={{ height: 200 }} />
      ) : (
        <div style={{ height: 220 }}>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={data} margin={{ top: 4, right: 8, left: -20, bottom: 4 }} barSize={32}>
              <CartesianGrid strokeDasharray="3 3" stroke="#E8F5E8" vertical={false} />
              <XAxis
                dataKey="campus"
                tick={{ fontSize: 11, fill: "#5A7A5C", fontFamily: "Inter,sans-serif" }}
                axisLine={false}
                tickLine={false}
                tickFormatter={(v: string) => v.replace("CSU ", "").replace("Other Campus", "Other")}
              />
              <YAxis
                tick={{ fontSize: 11, fill: "#5A7A5C", fontFamily: "Inter,sans-serif" }}
                axisLine={false}
                tickLine={false}
              />
              <Tooltip content={<CustomTooltip />} cursor={{ fill: "#F0F9F0", radius: 6 }} />
              <Bar dataKey="count" radius={[8, 8, 0, 0]}>
                {data.map((_, i) => (
                  <Cell key={i} fill={BAR_COLORS[i % BAR_COLORS.length]} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Legend */}
      {!loading && (
        <div className="flex flex-wrap gap-x-4 gap-y-1 mt-3">
          {data.map((d, i) => (
            <div key={d.campus} className="flex items-center gap-1.5 text-xs text-gray-500">
              <span className="w-2.5 h-2.5 rounded-sm flex-shrink-0" style={{ background: BAR_COLORS[i % BAR_COLORS.length] }} />
              {d.campus}: <span className="font-semibold text-gray-700">{d.count}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
