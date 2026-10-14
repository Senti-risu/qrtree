import { useState, useEffect, useCallback } from "react";
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell, PieChart, Pie } from "recharts";
import { Download, FileText, RefreshCw } from "lucide-react";
import { supabase, isSupabaseConfigured } from "../lib/supabase";
import type { HealthValue } from "../hooks/useDashboardData";

interface ReportData {
  totalPlants: number;
  healthyPlants: number;
  dyingPlants: number;
  deadPlants: number;
  campusBreakdown: { campus: string; count: number; healthy: number; dying: number; dead: number }[];
  growthBreakdown: { stage: string; count: number }[];
}

const MOCK_REPORT: ReportData = {
  totalPlants: 400,
  healthyPlants: 340,
  dyingPlants: 10,
  deadPlants: 50,
  campusBreakdown: [
    { campus: "CSU Lasam",   count: 180, healthy: 160, dying: 5,  dead: 15 },
    { campus: "CSU Carig",   count: 120, healthy: 100, dying: 3,  dead: 17 },
    { campus: "CSU Andrews", count: 60,  healthy: 50,  dying: 2,  dead: 8  },
    { campus: "Other",       count: 40,  healthy: 30,  dying: 0,  dead: 10 },
  ],
  growthBreakdown: [
    { stage: "Seedling", count: 40  },
    { stage: "Sapling",  count: 80  },
    { stage: "Growing",  count: 120 },
    { stage: "Mature",   count: 160 },
  ],
};

const PIE_COLORS  = ["#2E7D32", "#F57C00", "#D32F2F"];
const BAR_COLORS  = ["#2E7D32", "#43A047", "#66BB6A", "#A5D6A7"];
const GROWTH_COLORS = ["#1565C0", "#0288D1", "#00796B", "#6A1B9A"];

function SummaryTile({ label, value, sub, color }: { label: string; value: number | string; sub?: string; color: string }) {
  return (
    <div className="bg-white rounded-2xl p-5" style={{ border: "1px solid #D8EAD8", boxShadow: "0 4px 10px rgba(0,0,0,0.04)" }}>
      <div className="text-3xl font-extrabold mb-1" style={{ color, fontFamily: "'Nunito',sans-serif" }}>{value}</div>
      <div className="text-sm font-semibold text-gray-700">{label}</div>
      {sub && <div className="text-xs text-gray-400 mt-0.5">{sub}</div>}
    </div>
  );
}

const CustomTooltip = ({ active, payload, label }: any) =>
  active && payload?.length ? (
    <div className="bg-white border border-green-100 rounded-xl px-3 py-2 shadow text-xs">
      <div className="font-semibold text-gray-900 mb-1">{label}</div>
      {payload.map((p: any) => (
        <div key={p.name} className="flex items-center gap-1.5">
          <span className="w-2 h-2 rounded-full" style={{ background: p.fill ?? p.color }} />
          <span className="text-gray-500">{p.name}:</span>
          <span className="font-semibold text-gray-800">{p.value}</span>
        </div>
      ))}
    </div>
  ) : null;

export default function Reports() {
  const [data, setData]       = useState<ReportData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo]   = useState("");

  const fetchReport = useCallback(async () => {
    setLoading(true);
    setError(null);

    if (!isSupabaseConfigured || !supabase) {
      await new Promise((r) => setTimeout(r, 700));
      setData(MOCK_REPORT);
      setLoading(false);
      return;
    }

    try {
      let query = supabase.from("plant").select(`
        plant_id,
        health_status(status_name),
        growth_status(growth_stage),
        campus(campus_name),
        date_planted
      `);
      if (dateFrom) query = query.gte("date_planted", dateFrom);
      if (dateTo)   query = query.lte("date_planted", dateTo);

      const { data: rows, error: err } = await query;
      if (err) throw err;

      let healthy = 0, dying = 0, dead = 0;
      const campusMap: Record<string, { count: number; healthy: number; dying: number; dead: number }> = {};
      const growthMap: Record<string, number> = {};

      for (const row of (rows ?? [])) {
        const status  = (row as any).health_status?.status_name as string | undefined;
        const stage   = (row as any).growth_status?.growth_stage as string | undefined ?? "Unknown";
        const campus  = (row as any).campus?.campus_name as string | undefined ?? "Unknown";

        if (status === "alive")  healthy++;
        else if (status === "dying") dying++;
        else if (status === "dead")  dead++;

        if (!campusMap[campus]) campusMap[campus] = { count: 0, healthy: 0, dying: 0, dead: 0 };
        campusMap[campus].count++;
        if (status === "alive")  campusMap[campus].healthy++;
        else if (status === "dying") campusMap[campus].dying++;
        else if (status === "dead")  campusMap[campus].dead++;

        growthMap[stage] = (growthMap[stage] ?? 0) + 1;
      }

      setData({
        totalPlants: (rows ?? []).length,
        healthyPlants: healthy,
        dyingPlants: dying,
        deadPlants: dead,
        campusBreakdown: Object.entries(campusMap).map(([campus, v]) => ({ campus, ...v })).sort((a, b) => b.count - a.count),
        growthBreakdown: Object.entries(growthMap).map(([stage, count]) => ({ stage, count })),
      });
    } catch (e: any) {
      setError(e?.message ?? "Failed to generate report.");
    } finally {
      setLoading(false);
    }
  }, [dateFrom, dateTo]);

  useEffect(() => { fetchReport(); }, [fetchReport]);

  const pieData = data ? [
    { name: "Healthy", value: data.healthyPlants },
    { name: "Dying",   value: data.dyingPlants   },
    { name: "Dead",    value: data.deadPlants     },
  ] : [];

  const inputCls = "px-3 py-2 text-sm rounded-xl border border-gray-200 outline-none transition-all focus:border-green-500 focus:ring-2 focus:ring-green-100";

  return (
    <div className="h-full overflow-y-auto" style={{ background: "#F0F7F0" }}>
      <div style={{ padding: "28px 24px 56px" }}>

        {/* Header */}
        <div className="flex items-start justify-between gap-4 flex-wrap mb-7">
          <div>
            <h1 className="text-3xl font-bold text-gray-900" style={{ fontFamily: "'Nunito',sans-serif" }}>Reports</h1>
            <p className="text-sm mt-1" style={{ color: "#2E7D32" }}>Plant monitoring reports and analytics</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={fetchReport}
              className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold border transition-colors"
              style={{ borderColor: "#D8EAD8", color: "#2E7D32", background: "#fff" }}
            >
              <RefreshCw size={14} />Refresh
            </button>
            <button
              className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold text-white transition-opacity"
              style={{ background: "#2E7D32" }}
              onClick={() => alert("Export feature coming soon.")}
            >
              <Download size={14} />Export PDF
            </button>
          </div>
        </div>

        {/* Date filter */}
        <div className="bg-white rounded-2xl p-4 mb-6 flex flex-wrap gap-3 items-center" style={{ border: "1px solid #D8EAD8" }}>
          <FileText size={16} className="text-gray-400" />
          <span className="text-sm font-medium text-gray-600">Filter by date planted:</span>
          <input type="date" className={inputCls} value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} />
          <span className="text-sm text-gray-400">to</span>
          <input type="date" className={inputCls} value={dateTo} onChange={(e) => setDateTo(e.target.value)} />
          {(dateFrom || dateTo) && (
            <button
              onClick={() => { setDateFrom(""); setDateTo(""); }}
              className="text-xs font-semibold px-3 py-1.5 rounded-lg"
              style={{ background: "#F0F0F0", color: "#666" }}
            >
              Clear
            </button>
          )}
        </div>

        {/* Error */}
        {error && (
          <div className="mb-6 p-4 rounded-2xl text-sm" style={{ background: "#FFEBEE", border: "1px solid #FFCDD2", color: "#C62828" }}>
            {error}
            <button onClick={fetchReport} className="ml-3 font-semibold underline">Retry</button>
          </div>
        )}

        {/* Summary tiles */}
        <div className="grid gap-4 mb-6" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))" }}>
          {loading ? (
            [...Array(4)].map((_, i) => <div key={i} className="skeleton h-28 rounded-2xl" />)
          ) : (
            <>
              <SummaryTile label="Total Plants"   value={data?.totalPlants ?? 0}   color="#1B5E20" />
              <SummaryTile label="Healthy Plants" value={data?.healthyPlants ?? 0} sub={`${data ? Math.round(data.healthyPlants / data.totalPlants * 100) : 0}% of total`} color="#2E7D32" />
              <SummaryTile label="At Risk"        value={data?.dyingPlants ?? 0}   color="#E65100" />
              <SummaryTile label="Dead Plants"    value={data?.deadPlants ?? 0}    sub={`${data && data.totalPlants > 0 ? (data.deadPlants / data.totalPlants * 100).toFixed(1) : 0}% of total`} color="#C62828" />
            </>
          )}
        </div>

        {/* Charts row 1: health donut + campus bar */}
        <div className="grid gap-5 mb-5" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))" }}>
          {/* Health distribution */}
          <div className="bg-white rounded-2xl p-6" style={{ border: "1px solid #D8EAD8", boxShadow: "0 4px 10px rgba(0,0,0,0.04)" }}>
            <div className="text-base font-bold text-gray-900 mb-0.5" style={{ fontFamily: "'Nunito',sans-serif" }}>Health Distribution</div>
            <div className="text-xs text-gray-400 mb-5">Overall plant health across all campuses</div>
            {loading ? (
              <div className="skeleton h-48 rounded-xl" />
            ) : (
              <>
                <div className="relative" style={{ height: 180 }}>
                  <ResponsiveContainer width="100%" height={180}>
                    <PieChart>
                      <Pie data={pieData} cx="50%" cy="50%" innerRadius={55} outerRadius={78} paddingAngle={3} dataKey="value" startAngle={90} endAngle={-270}>
                        {pieData.map((_, i) => <Cell key={i} fill={PIE_COLORS[i]} stroke="none" />)}
                      </Pie>
                      <Tooltip content={<CustomTooltip />} />
                    </PieChart>
                  </ResponsiveContainer>
                  <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                    <span className="text-2xl font-extrabold" style={{ color: "#2E7D32", fontFamily: "'Nunito',sans-serif" }}>{data?.totalPlants}</span>
                    <span className="text-xs text-gray-400">Total</span>
                  </div>
                </div>
                <div className="flex justify-center gap-4 mt-3 flex-wrap">
                  {pieData.map((d, i) => (
                    <div key={d.name} className="flex items-center gap-1.5 text-xs text-gray-500">
                      <span className="w-2.5 h-2.5 rounded-full" style={{ background: PIE_COLORS[i] }} />
                      {d.name}: <span className="font-semibold text-gray-800">{d.value}</span>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>

          {/* Growth stage breakdown */}
          <div className="bg-white rounded-2xl p-6" style={{ border: "1px solid #D8EAD8", boxShadow: "0 4px 10px rgba(0,0,0,0.04)" }}>
            <div className="text-base font-bold text-gray-900 mb-0.5" style={{ fontFamily: "'Nunito',sans-serif" }}>Growth Stage Breakdown</div>
            <div className="text-xs text-gray-400 mb-5">Plant count by growth stage</div>
            {loading ? (
              <div className="skeleton h-48 rounded-xl" />
            ) : (
              <div style={{ height: 200 }}>
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart data={data?.growthBreakdown ?? []} margin={{ top: 4, right: 8, left: -20, bottom: 4 }} barSize={32}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E8F5E8" vertical={false} />
                    <XAxis dataKey="stage" tick={{ fontSize: 11, fill: "#5A7A5C" }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fontSize: 11, fill: "#5A7A5C" }} axisLine={false} tickLine={false} />
                    <Tooltip content={<CustomTooltip />} cursor={{ fill: "#F0F9F0", radius: 6 }} />
                    <Bar dataKey="count" name="Plants" radius={[8, 8, 0, 0]}>
                      {(data?.growthBreakdown ?? []).map((_, i) => <Cell key={i} fill={GROWTH_COLORS[i % GROWTH_COLORS.length]} />)}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}
          </div>
        </div>

        {/* Campus breakdown table */}
        <div className="bg-white rounded-2xl overflow-hidden" style={{ border: "1px solid #D8EAD8", boxShadow: "0 4px 10px rgba(0,0,0,0.04)" }}>
          <div className="px-6 py-5 border-b border-green-50">
            <div className="text-base font-bold text-gray-900" style={{ fontFamily: "'Nunito',sans-serif" }}>Campus Breakdown</div>
            <div className="text-xs text-gray-400 mt-0.5">Plant health summary per campus</div>
          </div>
          {loading ? (
            <div className="p-5 flex flex-col gap-3">
              {[...Array(4)].map((_, i) => <div key={i} className="skeleton h-10 rounded" />)}
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full" style={{ minWidth: 540 }}>
                <thead>
                  <tr style={{ background: "#F8FBF8", borderBottom: "1px solid #E8F0E8" }}>
                    {["Campus", "Total", "Healthy", "At Risk", "Dead", "Health Rate"].map((col) => (
                      <th key={col} className="text-left px-5 py-3 text-xs font-bold text-green-600 uppercase tracking-wide whitespace-nowrap">{col}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {(data?.campusBreakdown ?? []).map((row, i) => {
                    const rate = row.count > 0 ? Math.round(row.healthy / row.count * 100) : 0;
                    return (
                      <tr
                        key={row.campus}
                        className="border-t transition-colors"
                        style={{ borderColor: "#F0F7F0" }}
                        onMouseEnter={(e) => (e.currentTarget.style.background = "#F8FBF8")}
                        onMouseLeave={(e) => (e.currentTarget.style.background = "")}
                      >
                        <td className="px-5 py-3.5">
                          <div className="flex items-center gap-2">
                            <span className="w-3 h-3 rounded-sm" style={{ background: BAR_COLORS[i % BAR_COLORS.length] }} />
                            <span className="text-sm font-semibold text-gray-900">{row.campus}</span>
                          </div>
                        </td>
                        <td className="px-5 py-3.5 text-sm font-semibold text-gray-700">{row.count}</td>
                        <td className="px-5 py-3.5 text-sm font-semibold" style={{ color: "#2E7D32" }}>{row.healthy}</td>
                        <td className="px-5 py-3.5 text-sm font-semibold" style={{ color: "#F57C00" }}>{row.dying}</td>
                        <td className="px-5 py-3.5 text-sm font-semibold" style={{ color: "#D32F2F" }}>{row.dead}</td>
                        <td className="px-5 py-3.5">
                          <div className="flex items-center gap-2">
                            <div className="flex-1 h-1.5 rounded-full bg-gray-100 overflow-hidden" style={{ minWidth: 64 }}>
                              <div className="h-full rounded-full" style={{ width: `${rate}%`, background: rate >= 80 ? "#2E7D32" : rate >= 50 ? "#F57C00" : "#D32F2F" }} />
                            </div>
                            <span className="text-xs font-semibold text-gray-600">{rate}%</span>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
