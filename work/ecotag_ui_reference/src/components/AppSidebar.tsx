import {
  LayoutDashboard,
  PlusCircle,
  Trees,
  ClipboardCheck,
  BarChart3,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";

interface NavItem {
  id: string;
  label: string;
  icon: React.ComponentType<{ size?: number; className?: string }>;
}

const NAV_ITEMS: NavItem[] = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "register", label: "Register Plant", icon: PlusCircle },
  { id: "plants", label: "Plant List", icon: Trees },
  { id: "inspections", label: "Inspections", icon: ClipboardCheck },
  { id: "reports", label: "Reports", icon: BarChart3 },
];

interface AppSidebarProps {
  activePage: string;
  onNavigate: (page: string) => void;
  collapsed: boolean;
  onToggle: () => void;
}

export default function AppSidebar({ activePage, onNavigate, collapsed, onToggle }: AppSidebarProps) {
  return (
    <aside
      className="h-full flex flex-col sidebar-transition"
      style={{
        width: collapsed ? 64 : 248,
        background: "#fff",
        borderRight: "1px solid #D8EAD8",
        boxShadow: "2px 0 12px rgba(46,125,50,0.04)",
        flexShrink: 0,
      }}
    >
      <div className="flex-1 overflow-y-auto overflow-x-hidden py-4">
        {!collapsed && (
          <div className="px-4 mb-2">
            <span className="text-xs font-bold tracking-widest uppercase text-green-500">
              Management
            </span>
          </div>
        )}

        <nav className="px-2 flex flex-col gap-1">
          {NAV_ITEMS.map(({ id, label, icon: Icon }) => {
            const isActive = activePage === id;
            return (
              <button
                key={id}
                onClick={() => onNavigate(id)}
                title={collapsed ? label : undefined}
                className={`nav-item w-full flex items-center rounded-xl text-sm font-semibold outline-none
                  ${collapsed ? "justify-center px-0 py-3" : "gap-3 px-3 py-2.5"}
                  ${isActive
                    ? "bg-green-50 text-green-800"
                    : "text-green-700 hover:bg-green-50 hover:text-green-900"
                  }
                `}
              >
                <div
                  className={`flex items-center justify-center rounded-lg
                    ${collapsed ? "w-9 h-9" : "w-8 h-8"}
                    ${isActive ? "bg-green-100" : ""}
                  `}
                >
                  <Icon
                    size={collapsed ? 20 : 18}
                    className={isActive ? "text-green-700" : "text-green-500"}
                  />
                </div>
                {!collapsed && (
                  <span className={isActive ? "text-green-800" : ""}>{label}</span>
                )}
                {!collapsed && isActive && (
                  <span className="ml-auto w-1.5 h-6 rounded-full bg-green-600" />
                )}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Collapse toggle */}
      <div className="p-2 border-t border-green-50">
        <button
          onClick={onToggle}
          className={`w-full flex items-center rounded-xl py-2.5 text-green-600 hover:bg-green-50 transition-colors
            ${collapsed ? "justify-center" : "gap-3 px-3"}
          `}
        >
          {collapsed ? (
            <ChevronRight size={18} />
          ) : (
            <>
              <ChevronLeft size={18} />
              <span className="text-sm font-medium">Collapse</span>
            </>
          )}
        </button>
      </div>
    </aside>
  );
}
