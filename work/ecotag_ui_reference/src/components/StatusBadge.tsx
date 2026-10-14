interface StatusBadgeProps {
  status: "healthy" | "dying" | "dead" | string;
}

const CONFIG = {
  healthy: { label: "Healthy", bg: "bg-emerald-50", text: "text-emerald-700", dot: "bg-emerald-500" },
  dying: { label: "Dying", bg: "bg-amber-50", text: "text-amber-700", dot: "bg-amber-500" },
  dead: { label: "Dead", bg: "bg-red-50", text: "text-red-700", dot: "bg-red-400" },
  completed: { label: "Completed", bg: "bg-blue-50", text: "text-blue-700", dot: "bg-blue-500" },
  pending: { label: "Pending", bg: "bg-orange-50", text: "text-orange-700", dot: "bg-orange-500" },
};

export default function StatusBadge({ status }: StatusBadgeProps) {
  const key = status.toLowerCase() as keyof typeof CONFIG;
  const cfg = CONFIG[key] ?? { label: status, bg: "bg-gray-50", text: "text-gray-700", dot: "bg-gray-400" };

  return (
    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${cfg.bg} ${cfg.text}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${cfg.dot}`} />
      {cfg.label}
    </span>
  );
}
