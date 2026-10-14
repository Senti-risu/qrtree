import type { ReactNode } from "react";

interface StatCardProps {
  icon: ReactNode;
  title: string;
  value: string | number;
  subtext?: string;
  iconBg: string;
  iconColor: string;
  percentage?: string;
  progress?: number; // 0–1
  loading?: boolean;
}

export default function StatCard({
  icon, title, value, subtext, iconBg, iconColor, percentage, progress, loading,
}: StatCardProps) {
  if (loading) {
    return (
      <div className="bg-white rounded-2xl p-5 shadow-sm" style={{ minWidth: 200, flex: "1 1 200px" }}>
        <div className="skeleton h-11 w-11 rounded-xl mb-4" />
        <div className="skeleton h-7 w-16 mb-2 rounded" />
        <div className="skeleton h-4 w-28 mb-2 rounded" />
        <div className="skeleton h-3 w-36 rounded" />
      </div>
    );
  }

  return (
    <div
      className="stat-card bg-white rounded-2xl p-5"
      style={{
        boxShadow: "0 4px 10px rgba(0,0,0,0.05)",
        minWidth: 200,
        flex: "1 1 200px",
      }}
    >
      <div className="flex items-start justify-between mb-4">
        <div
          className="w-11 h-11 rounded-xl flex items-center justify-center"
          style={{ background: iconBg }}
        >
          <span style={{ color: iconColor }}>{icon}</span>
        </div>
        {percentage && (
          <span className="text-sm font-bold" style={{ color: iconColor }}>
            {percentage}
          </span>
        )}
      </div>

      <div className="text-3xl font-bold text-gray-900 mb-1" style={{ fontFamily: "'Nunito', sans-serif" }}>
        {typeof value === "number" ? value.toLocaleString() : value}
      </div>
      <div className="text-sm font-medium text-gray-500 mb-1">{title}</div>
      {subtext && <div className="text-xs text-gray-400">{subtext}</div>}

      {progress !== undefined && (
        <div className="mt-3 h-1 rounded-full bg-gray-200 overflow-hidden">
          <div
            className="h-full rounded-full transition-all"
            style={{ width: `${Math.min(progress * 100, 100)}%`, background: iconColor }}
          />
        </div>
      )}
    </div>
  );
}
