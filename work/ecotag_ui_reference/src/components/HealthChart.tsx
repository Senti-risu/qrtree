import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from "recharts";

interface HealthChartProps {
  healthy: number;
  dying: number;
  dead: number;
  loading?: boolean;
}

const COLORS = ["#2E7D32", "#F57C00", "#D32F2F"];

const TooltipContent = ({ active, payload }: any) =>
  active && payload?.length ? (
    <div className="bg-white border border-green-100 rounded-xl px-3 py-2 shadow text-sm">
      <span className="font-semibold">{payload[0].name}:</span> {payload[0].value}
    </div>
  ) : null;

export default function HealthChart({ healthy, dying, dead, loading }: HealthChartProps) {
  const total = healthy + dying + dead;
  const data = [
    { name: "Healthy", value: healthy },
    { name: "Dying", value: dying },
    { name: "Dead", value: dead },
  ];
  const display = total === 0 ? [{ name: "No data", value: 1 }] : data;
  const displayColors = total === 0 ? ["#e5e7eb"] : COLORS;

  return (
    <div
      className="bg-white rounded-2xl p-6"
      style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.03)" }}
    >
      <div className="text-lg font-bold text-gray-900 mb-0.5">Plant Health Overview</div>
      <div className="text-sm text-gray-400 mb-6">Distribution of plant health status</div>

      {loading ? (
        <div className="skeleton h-48 w-48 rounded-full mx-auto" />
      ) : (
        <>
          <div className="relative" style={{ height: 200 }}>
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={display}
                  cx="50%"
                  cy="50%"
                  innerRadius={70}
                  outerRadius={95}
                  paddingAngle={total === 0 ? 0 : 2}
                  dataKey="value"
                  startAngle={90}
                  endAngle={-270}
                >
                  {display.map((_, i) => (
                    <Cell key={i} fill={displayColors[i % displayColors.length]} stroke="none" />
                  ))}
                </Pie>
                <Tooltip content={<TooltipContent />} />
              </PieChart>
            </ResponsiveContainer>
            {/* Center label */}
            <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
              <span
                className="text-2xl font-bold text-gray-900 leading-none"
                style={{ fontFamily: "'Nunito', sans-serif" }}
              >
                {total}
              </span>
              <span className="text-sm text-gray-500 mt-1">Total Plants</span>
            </div>
          </div>

          {/* Legend */}
          <div className="flex items-center justify-center gap-4 mt-4 flex-wrap">
            {[
              { color: "#2E7D32", label: `Healthy: ${healthy}` },
              { color: "#F57C00", label: `Dying: ${dying}` },
              { color: "#D32F2F", label: `Dead: ${dead}` },
            ].map(({ color, label }) => (
              <div key={label} className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full" style={{ background: color }} />
                <span className="text-xs text-gray-700">{label}</span>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
