import { PlusCircle, Trees, BarChart3, type LucideIcon } from "lucide-react";

interface Action {
  icon: LucideIcon;
  title: string;
  subtitle: string;
}

const ACTIONS: Action[] = [
  { icon: PlusCircle, title: "Register New Plant", subtitle: "Add a new plant to EcoTag" },
  { icon: Trees, title: "View Plant List", subtitle: "Browse registered plants" },
  { icon: BarChart3, title: "Create Report", subtitle: "Generate plant monitoring reports" },
];

export default function QuickActions() {
  return (
    <div
      className="bg-white rounded-2xl p-6"
      style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.03)" }}
    >
      <div className="text-lg font-bold text-gray-900 mb-0.5">Quick Actions</div>
      <div className="text-sm text-gray-400 mb-5">Common plant management tasks</div>

      <div className="flex flex-col gap-3">
        {ACTIONS.map(({ icon: Icon, title, subtitle }) => (
          <button
            key={title}
            className="flex items-center gap-4 p-4 rounded-xl text-left transition-all"
            style={{ background: "#E8F5E9" }}
            onMouseEnter={(e) => (e.currentTarget.style.filter = "brightness(0.97)")}
            onMouseLeave={(e) => (e.currentTarget.style.filter = "")}
          >
            <Icon size={24} color="#2E7D32" />
            <div>
              <div className="text-sm font-semibold text-gray-900">{title}</div>
              <div className="text-xs text-gray-500 mt-0.5">{subtitle}</div>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
