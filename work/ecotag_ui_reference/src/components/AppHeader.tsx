import { useState, useRef, useEffect } from "react";
import { Leaf, ChevronDown, User, Settings, LogOut, Bell } from "lucide-react";

interface AppHeaderProps {
  sidebarCollapsed: boolean;
  onToggleSidebar: () => void;
}

export default function AppHeader({ sidebarCollapsed, onToggleSidebar }: AppHeaderProps) {
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  return (
    <header
      className="fixed top-0 left-0 right-0 z-40 flex items-center justify-between px-6"
      style={{
        height: 68,
        background: "#fff",
        borderBottom: "1px solid #D8EAD8",
        boxShadow: "0 1px 8px rgba(46,125,50,0.06)",
      }}
    >
      {/* Left: hamburger + logo */}
      <div className="flex items-center gap-4">
        <button
          onClick={onToggleSidebar}
          className="p-2 rounded-lg hover:bg-green-50 transition-colors"
          aria-label="Toggle sidebar"
        >
          <div className="flex flex-col gap-1.5">
            <span className="block w-5 h-0.5 bg-green-800 rounded" />
            <span className="block w-5 h-0.5 bg-green-800 rounded" />
            <span className="block w-5 h-0.5 bg-green-800 rounded" />
          </div>
        </button>

        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl flex items-center justify-center" style={{ background: "linear-gradient(135deg, #2E7D32 0%, #43A047 100%)" }}>
            <Leaf size={18} className="text-white" />
          </div>
          <div>
            <div className="text-lg font-extrabold leading-none text-green-900" style={{ fontFamily: "'Nunito', sans-serif" }}>
              EcoTag
            </div>
            <div className="text-xs text-green-600 font-medium leading-none mt-0.5">
              Campus Plant Profiling System
            </div>
          </div>
        </div>
      </div>

      {/* Right: notification + user */}
      <div className="flex items-center gap-3">
        <button className="relative p-2 rounded-lg hover:bg-green-50 transition-colors">
          <Bell size={20} className="text-green-700" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-green-500" />
        </button>

        {/* Profile dropdown */}
        <div className="relative" ref={dropdownRef}>
          <button
            className="flex items-center gap-3 px-3 py-2 rounded-xl hover:bg-green-50 transition-colors"
            onClick={() => setDropdownOpen(!dropdownOpen)}
          >
            <div
              className="w-9 h-9 rounded-full flex items-center justify-center font-bold text-sm text-white shadow-sm"
              style={{ background: "linear-gradient(135deg, #2E7D32, #66BB6A)" }}
            >
              JD
            </div>
            <div className="text-left hidden sm:block">
              <div className="text-sm font-semibold text-green-900 leading-none">Delacruz, Jumi</div>
              <div className="text-xs text-green-600 mt-0.5">College Admin</div>
            </div>
            <ChevronDown
              size={14}
              className={`text-green-600 transition-transform ${dropdownOpen ? "rotate-180" : ""}`}
            />
          </button>

          {dropdownOpen && (
            <div
              className="dropdown-menu absolute right-0 mt-2 w-52 rounded-2xl bg-white shadow-xl border border-green-100 overflow-hidden"
              style={{ top: "100%" }}
            >
              <div className="px-4 py-3 border-b border-green-50">
                <div className="text-sm font-semibold text-green-900">Delacruz, Jumi</div>
                <div className="text-xs text-green-600">jumi.delacruz@csu.edu.ph</div>
              </div>
              {[
                { icon: User, label: "My Profile" },
                { icon: Settings, label: "Account Settings" },
              ].map(({ icon: Icon, label }) => (
                <button
                  key={label}
                  className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-green-800 hover:bg-green-50 transition-colors"
                >
                  <Icon size={16} className="text-green-600" />
                  {label}
                </button>
              ))}
              <div className="border-t border-green-50">
                <button className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors">
                  <LogOut size={16} />
                  Logout
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
