import type { RecentPlant } from "../hooks/useDashboardData";
import { TreeDeciduous } from "lucide-react";

interface RecentPlantsProps {
  plants: RecentPlant[];
  loading?: boolean;
}

const HEALTH_LABEL: Record<string, string> = {
  healthy: "Healthy",
  dying: "At Risk",
  dead: "Dead",
};

const HEALTH_STYLE: Record<string, { bg: string; color: string }> = {
  healthy: { bg: "#2E7D32", color: "#fff" },
  dying: { bg: "#F57C00", color: "#fff" },
  dead: { bg: "#D32F2F", color: "#fff" },
};

const GROWTH_STYLE = { bg: "#F3E5F5", color: "#7B1FA2" };

export default function RecentPlants({ plants, loading }: RecentPlantsProps) {
  return (
    <div
      className="bg-white rounded-2xl p-6"
      style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.03)" }}
    >
      <div className="flex items-start justify-between mb-5">
        <div>
          <div className="text-lg font-bold text-gray-900">Recent Plants</div>
          <div className="text-sm text-gray-400">Recently registered or updated plants</div>
        </div>
        <button
          className="text-sm font-medium px-4 py-1.5 rounded-full border transition-colors"
          style={{ borderColor: "#2E7D32", color: "#2E7D32" }}
          onMouseEnter={(e) => { (e.currentTarget.style.background = "#E8F5E9"); }}
          onMouseLeave={(e) => { (e.currentTarget.style.background = ""); }}
        >
          View All
        </button>
      </div>

      {loading ? (
        <div className="flex flex-col gap-3">
          {[...Array(4)].map((_, i) => <div key={i} className="skeleton h-12 rounded-lg" />)}
        </div>
      ) : plants.length === 0 ? (
        <div className="py-12 text-center">
          <div className="text-4xl mb-3">🌱</div>
          <div className="text-sm font-semibold text-gray-600 mb-1">No plants registered yet.</div>
          <div className="text-xs text-gray-400 mb-4">
            Start building your campus plant database by registering your first plant.
          </div>
          <button
            className="px-4 py-2 rounded-xl text-sm font-semibold text-white transition-opacity hover:opacity-90"
            style={{ background: "#2E7D32" }}
          >
            Register Plant
          </button>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full" style={{ minWidth: 640, borderCollapse: "separate", borderSpacing: 0 }}>
            <thead>
              <tr style={{ background: "#F9FAFB" }}>
                {["PLANT", "TYPE", "VARIETY", "CAMPUS", "GROWTH STAGE", "HEALTH", "DATE PLANTED"].map((col) => (
                  <th
                    key={col}
                    className="text-left px-4 py-3 text-xs font-semibold text-gray-400"
                    style={{ letterSpacing: "0.04em" }}
                  >
                    {col}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {plants.map((p) => {
                const hs = HEALTH_STYLE[p.health] ?? HEALTH_STYLE.healthy;
                return (
                  <tr
                    key={p.id}
                    className="table-row border-t border-gray-50"
                  >
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <TreeDeciduous size={16} className="text-green-300 flex-shrink-0" />
                        <span className="text-sm font-semibold text-gray-900">{p.name}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-600">{p.type}</td>
                    <td className="px-4 py-3 text-sm text-gray-600">{p.variety}</td>
                    <td className="px-4 py-3 text-sm text-gray-600">{p.campus}</td>
                    <td className="px-4 py-3">
                      <span
                        className="text-xs font-medium px-2 py-1 rounded"
                        style={{ background: GROWTH_STYLE.bg, color: GROWTH_STYLE.color }}
                      >
                        {p.growthStage}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className="text-xs font-medium px-2 py-1 rounded flex items-center gap-1.5 w-fit"
                        style={{ background: hs.bg, color: hs.color }}
                      >
                        <span className="w-2 h-2 rounded-full bg-white opacity-90" />
                        {HEALTH_LABEL[p.health]}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-400">{p.datePlanted}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
