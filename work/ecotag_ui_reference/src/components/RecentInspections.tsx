import type { RecentInspection, HealthValue } from "../hooks/useDashboardData";
import { ClipboardCheck, UserCircle } from "lucide-react";

interface Props {
  inspections: RecentInspection[];
  loading?: boolean;
}

const HEALTH_BADGE: Record<HealthValue, { bg: string; dot: string; text: string; label: string }> = {
  healthy: { bg: "#E8F5E9", dot: "#2E7D32", text: "#2E7D32", label: "Healthy" },
  dying:   { bg: "#FFF3E0", dot: "#F57C00", text: "#F57C00", label: "Dying"   },
  dead:    { bg: "#FFEBEE", dot: "#D32F2F", text: "#D32F2F", label: "Dead"    },
};

const STATUS_STYLE: Record<string, { bg: string; text: string }> = {
  Completed: { bg: "#E3F2FD", text: "#1565C0" },
  Pending:   { bg: "#FFF3E0", text: "#E65100" },
};

export default function RecentInspections({ inspections, loading }: Props) {
  return (
    <div className="bg-white rounded-2xl overflow-hidden" style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.03)", border: "1px solid #D8EAD8" }}>
      {/* Header */}
      <div className="flex items-start justify-between px-6 py-5 border-b border-green-50">
        <div>
          <div className="text-base font-bold text-gray-900" style={{ fontFamily: "'Nunito',sans-serif" }}>Recent Inspections</div>
          <div className="text-xs mt-0.5" style={{ color: "#5A7A5C" }}>Latest plant health inspections</div>
        </div>
        <button
          className="text-xs font-semibold px-3 py-1.5 rounded-lg border transition-colors"
          style={{ borderColor: "#D8EAD8", color: "#2E7D32" }}
          onMouseEnter={(e) => (e.currentTarget.style.borderColor = "#2E7D32")}
          onMouseLeave={(e) => (e.currentTarget.style.borderColor = "#D8EAD8")}
        >
          View All
        </button>
      </div>

      {/* Rows */}
      {loading ? (
        <div className="p-4 flex flex-col gap-3">
          {[...Array(4)].map((_, i) => <div key={i} className="skeleton h-16 rounded-xl" />)}
        </div>
      ) : inspections.length === 0 ? (
        <div className="py-10 text-center text-sm text-gray-400">No inspections recorded yet.</div>
      ) : (
        <div className="divide-y divide-green-50">
          {inspections.map((insp) => {
            const hb = HEALTH_BADGE[insp.health];
            const ss = STATUS_STYLE[insp.status] ?? { bg: "#F3F4F6", text: "#374151" };
            return (
              <div
                key={insp.id}
                className="flex items-start gap-4 px-6 py-4 transition-colors"
                style={{ cursor: "default" }}
                onMouseEnter={(e) => (e.currentTarget.style.background = "#F8FBF8")}
                onMouseLeave={(e) => (e.currentTarget.style.background = "")}
              >
                <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 mt-0.5" style={{ background: "#E3F2FD" }}>
                  <ClipboardCheck size={18} color="#1565C0" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2 flex-wrap">
                    <span className="text-sm font-semibold text-gray-900">{insp.plantName}</span>
                    <span className="text-xs font-semibold px-2.5 py-1 rounded-full" style={{ background: ss.bg, color: ss.text }}>
                      {insp.status}
                    </span>
                  </div>
                  <div className="flex items-center gap-1.5 mt-1 text-xs text-gray-400">
                    <UserCircle size={12} />
                    <span>{insp.inspector}</span>
                  </div>
                  <div className="flex items-center gap-2 mt-2 flex-wrap">
                    {/* Health badge */}
                    <span className="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1 rounded-full" style={{ background: hb.bg, color: hb.text }}>
                      <span className="w-1.5 h-1.5 rounded-full" style={{ background: hb.dot }} />
                      {hb.label}
                    </span>
                    <span className="text-xs text-gray-400">{insp.growthStage}</span>
                    <span className="text-gray-200">·</span>
                    <span className="text-xs text-gray-400">{insp.date}</span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
