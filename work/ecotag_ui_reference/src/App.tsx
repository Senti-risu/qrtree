import { useState, useEffect, useRef } from "react";
import {
  Bell, RefreshCw, ChevronDown, User, Settings, LogOut,
  Leaf, TreeDeciduous, AlertTriangle, Flower2,
} from "lucide-react";
import { useDashboardData } from "./hooks/useDashboardData";
import AppSidebar from "./components/AppSidebar";
import StatCard from "./components/StatCard";
import HealthChart from "./components/HealthChart";
import QuickActions from "./components/QuickActions";
import RecentPlants from "./components/RecentPlants";
import RecentInspections from "./components/RecentInspections";
import CampusChart from "./components/CampusChart";
import RegisterPlant from "./pages/RegisterPlant";
import PlantList from "./pages/PlantList";
import Reports from "./pages/Reports";

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const USER_NAME = "Delacruz, Jumi";
const USER_ROLE = "College Admin";

function initials(name: string) {
  return name.split(/[ ,]+/).filter(Boolean).slice(0, 2).map((s) => s[0]).join("").toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile dropdown
// ─────────────────────────────────────────────────────────────────────────────
function ProfileDropdown({ small }: { small?: boolean }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, []);

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((v) => !v)}
        className="flex items-center gap-2.5 px-2 py-1.5 rounded-xl hover:bg-green-50 transition-colors"
      >
        <div
          className="w-9 h-9 rounded-full flex items-center justify-center font-bold text-sm text-white flex-shrink-0"
          style={{ background: "linear-gradient(135deg,#2E7D32,#66BB6A)" }}
        >
          {initials(USER_NAME)}
        </div>
        {!small && (
          <>
            <div className="text-left hidden sm:block">
              <div className="text-sm font-semibold text-gray-900 leading-tight">{USER_NAME}</div>
              <div className="text-xs leading-tight mt-0.5" style={{ color: "#2E7D32" }}>{USER_ROLE}</div>
            </div>
            <ChevronDown size={14} className={`text-gray-400 transition-transform ${open ? "rotate-180" : ""}`} />
          </>
        )}
      </button>

      {open && (
        <div
          className="dropdown-menu absolute right-0 mt-2 w-52 bg-white rounded-2xl shadow-xl overflow-hidden z-50"
          style={{ top: "100%", border: "1px solid #D8EAD8" }}
        >
          <div className="px-4 py-3 border-b border-green-50">
            <div className="text-sm font-semibold text-gray-900">{USER_NAME}</div>
            <div className="text-xs text-gray-400">{USER_ROLE}</div>
          </div>
          {[{ icon: User, label: "Profile" }, { icon: Settings, label: "Account Settings" }].map(
            ({ icon: Icon, label }) => (
              <button key={label} className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-green-50 transition-colors">
                <Icon size={15} className="text-gray-400" />{label}
              </button>
            )
          )}
          <div className="border-t border-green-50">
            <button className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-red-500 hover:bg-red-50 transition-colors">
              <LogOut size={15} />Logout
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixed top header
// ─────────────────────────────────────────────────────────────────────────────
function AppHeader({ onMenuTap }: { onMenuTap: () => void }) {
  return (
    <header
      className="fixed top-0 left-0 right-0 z-40 flex items-center justify-between px-5"
      style={{
        height: 68,
        background: "#fff",
        borderBottom: "1px solid #D8EAD8",
        boxShadow: "0 1px 8px rgba(46,125,50,0.06)",
      }}
    >
      {/* Left */}
      <div className="flex items-center gap-3">
        <button
          onClick={onMenuTap}
          className="p-2 rounded-lg hover:bg-green-50 transition-colors"
          aria-label="Toggle sidebar"
        >
          <div className="flex flex-col gap-1.5">
            <span className="block w-5 h-0.5 rounded" style={{ background: "#2E7D32" }} />
            <span className="block w-5 h-0.5 rounded" style={{ background: "#2E7D32" }} />
            <span className="block w-5 h-0.5 rounded" style={{ background: "#2E7D32" }} />
          </div>
        </button>
        <div className="flex items-center gap-2.5">
          <div
            className="w-9 h-9 rounded-xl flex items-center justify-center"
            style={{ background: "linear-gradient(135deg,#2E7D32,#43A047)" }}
          >
            <Leaf size={18} className="text-white" />
          </div>
          <div>
            <div className="text-lg font-extrabold leading-none" style={{ fontFamily: "'Nunito',sans-serif", color: "#1B5E20" }}>
              EcoTag
            </div>
            <div className="text-xs font-medium leading-none mt-0.5" style={{ color: "#43A047" }}>
              Campus Plant Profiling System
            </div>
          </div>
        </div>
      </div>

      {/* Right */}
      <div className="flex items-center gap-1">
        <button className="relative p-2 rounded-lg hover:bg-green-50 transition-colors">
          <Bell size={20} className="text-gray-400" />
          <span className="absolute top-2 right-2 w-1.5 h-1.5 rounded-full" style={{ background: "#43A047" }} />
        </button>
        <ProfileDropdown />
      </div>
    </header>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile bottom nav + FAB
// ─────────────────────────────────────────────────────────────────────────────
type MobileTab = "home" | "plants" | "history" | "profile";

const MOBILE_TABS: { id: MobileTab; icon: string; label: string }[] = [
  { id: "home",    icon: "🏠", label: "Home"    },
  { id: "plants",  icon: "🌿", label: "Plants"  },
  { id: "history", icon: "📋", label: "History" },
  { id: "profile", icon: "👤", label: "Profile" },
];

function MobileNav({ active, onChange }: { active: MobileTab; onChange: (t: MobileTab) => void }) {
  return (
    <div
      className="fixed bottom-0 left-0 right-0 z-40 bg-white flex items-center"
      style={{ height: 64, borderTop: "1px solid #F0F0F0", boxShadow: "0 -2px 12px rgba(0,0,0,0.07)" }}
    >
      {MOBILE_TABS.map((tab, i) => {
        const isActive = active === tab.id;
        // Insert FAB placeholder in the middle
        const insertFab = i === 2;
        return (
          <>
            {insertFab && (
              <div key="fab-space" className="flex-1 flex justify-center">
                <div style={{ width: 40 }} />
              </div>
            )}
            <button
              key={tab.id}
              className="flex flex-col items-center gap-0.5 flex-1 py-2"
              onClick={() => onChange(tab.id)}
            >
              <span className="text-2xl leading-none">{tab.icon}</span>
              <span className="text-[10px]" style={{ color: isActive ? "#2E7D32" : "#9CA3AF" }}>{tab.label}</span>
            </button>
          </>
        );
      })}

      {/* Floating QR / scan FAB */}
      <div
        className="absolute left-1/2 -translate-x-1/2 -top-6 w-14 h-14 rounded-full flex items-center justify-center text-white cursor-pointer"
        style={{ background: "#2E7D32", boxShadow: "0 4px 14px rgba(46,125,50,0.45)" }}
      >
        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" />
          <rect x="3" y="14" width="7" height="7" rx="1" />
          <rect x="14" y="14" width="3" height="3" rx="0.5" /><rect x="18" y="14" width="3" height="3" rx="0.5" />
          <rect x="14" y="18" width="3" height="3" rx="0.5" /><rect x="18" y="18" width="3" height="3" rx="0.5" />
        </svg>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard page content
// ─────────────────────────────────────────────────────────────────────────────
function DashboardPage({ isDesktop }: { isDesktop: boolean }) {
  const { data, loading, error, refetch } = useDashboardData();
  const s     = data?.stats;
  const total = s?.totalPlants ?? 0;
  const healthyPct = total > 0 ? (s?.healthyPlants ?? 0) / total : 0;

  return (
    <div className="h-full overflow-y-auto" style={{ background: "#F0F7F0" }}>
      <div style={{ padding: isDesktop ? "28px 24px 48px" : "16px 16px 88px" }}>

        {/* ── Page header ── */}
        <div className="flex items-start justify-between gap-4 flex-wrap mb-7">
          <div>
            <h1
              className="font-bold text-gray-900 leading-tight"
              style={{ fontSize: isDesktop ? 28 : 24, fontFamily: "'Nunito',sans-serif" }}
            >
              {isDesktop ? "Dashboard" : "Home"}
            </h1>
            {isDesktop && (
              <p className="text-sm mt-1" style={{ color: "#2E7D32" }}>
                Overview of campus plants and environmental monitoring
              </p>
            )}
          </div>
          <div className="flex items-center gap-2 flex-shrink-0">
            <span className="text-xs hidden sm:block" style={{ color: "#9CA3AF" }}>
              Last updated: Today, 9:30 AM
            </span>
            <button
              onClick={refetch}
              className="p-1.5 rounded-lg transition-colors"
              style={{ background: "#E8F5E9" }}
              aria-label="Refresh"
            >
              <RefreshCw size={15} color="#2E7D32" />
            </button>
          </div>
        </div>

        {/* ── Error banner ── */}
        {error && (
          <div className="mb-6 flex items-start gap-3 p-4 rounded-2xl" style={{ background: "#FFEBEE", border: "1px solid #FFCDD2" }}>
            <span className="flex-shrink-0 mt-0.5">⚠️</span>
            <div className="flex-1 min-w-0">
              <div className="text-sm font-semibold" style={{ color: "#C62828" }}>Could not load dashboard data</div>
              <div className="text-xs mt-0.5 break-words" style={{ color: "#E53935" }}>{error}</div>
            </div>
            <button
              onClick={refetch}
              className="text-xs font-semibold px-3 py-1.5 rounded-lg flex-shrink-0"
              style={{ background: "#FFCDD2", color: "#C62828" }}
            >
              Retry
            </button>
          </div>
        )}

        {/* ── Stat cards ── */}
        <div
          className="grid gap-4 mb-6"
          style={{ gridTemplateColumns: isDesktop ? "repeat(4,1fr)" : "repeat(2,1fr)" }}
        >
          <StatCard
            icon={<TreeDeciduous size={22} />}
            title="Total Plants"
            value={loading ? "—" : total}
            subtext="+12 this month"
            iconBg="#E8F5E9" iconColor="#2E7D32"
            loading={loading}
          />
          <StatCard
            icon={<Leaf size={20} />}
            title="Healthy Plants"
            value={loading ? "—" : (s?.healthyPlants ?? 0)}
            subtext={`${(healthyPct * 100).toFixed(0)}% of total plants`}
            iconBg="#E8F5E9" iconColor="#2E7D32"
            percentage={`${(healthyPct * 100).toFixed(0)}%`}
            progress={healthyPct}
            loading={loading}
          />
          <StatCard
            icon={<AlertTriangle size={20} />}
            title="At Risk"
            value={loading ? "—" : (s?.dyingPlants ?? 0)}
            subtext="Requires inspection"
            iconBg="#FFF3E0" iconColor="#F57C00"
            loading={loading}
          />
          <StatCard
            icon={<Flower2 size={20} />}
            title="Dead Plants"
            value={loading ? "—" : (s?.deadPlants ?? 0)}
            subtext={total > 0 ? `${((s?.deadPlants ?? 0) / total * 100).toFixed(1)}% of total plants` : "12.5% of total plants"}
            iconBg="#FFEBEE" iconColor="#D32F2F"
            loading={loading}
          />
        </div>

        {/* ── Health chart + Quick actions ── */}
        <div
          className={`gap-4 mb-6 ${isDesktop ? "grid" : "flex flex-col"}`}
          style={isDesktop ? { gridTemplateColumns: "3fr 2fr" } : undefined}
        >
          <HealthChart
            healthy={s?.healthyPlants ?? 340}
            dying={s?.dyingPlants ?? 10}
            dead={s?.deadPlants ?? 50}
            loading={loading}
          />
          <QuickActions />
        </div>

        {/* ── Recent Plants ── */}
        <div className="mb-6">
          <RecentPlants plants={data?.recentPlants ?? []} loading={loading} />
        </div>

        {/* ── Recent Inspections + Campus chart ── */}
        <div
          className={`gap-4 ${isDesktop ? "grid" : "flex flex-col"}`}
          style={isDesktop ? { gridTemplateColumns: "1fr 1fr" } : undefined}
        >
          <RecentInspections inspections={data?.recentInspections ?? []} loading={loading} />
          <CampusChart data={data?.campusDistribution ?? []} loading={loading} />
        </div>

      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Root
// ─────────────────────────────────────────────────────────────────────────────
function PlaceholderPage({ label }: { label: string }) {
  return (
    <div className="h-full flex flex-col items-center justify-center gap-3" style={{ background: "#F0F7F0" }}>
      <span style={{ fontSize: 48 }}>🌿</span>
      <div className="text-xl font-bold text-gray-800" style={{ fontFamily: "'Nunito',sans-serif" }}>{label}</div>
      <div className="text-sm text-gray-400">This section is under development.</div>
    </div>
  );
}

const PAGE_LABELS: Record<string, string> = {
  inspections: "Inspections",
};

export default function App() {
  const [activePage, setActivePage]           = useState("dashboard");
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [mobileTab, setMobileTab]             = useState<MobileTab>("home");
  const [isDesktop, setIsDesktop]             = useState(() => window.innerWidth >= 900);

  useEffect(() => {
    const h = () => setIsDesktop(window.innerWidth >= 900);
    window.addEventListener("resize", h);
    return () => window.removeEventListener("resize", h);
  }, []);

  const sidebarW = sidebarCollapsed ? 64 : 248;

  return (
    <div className="h-full flex flex-col">
      {/* Fixed header */}
      <AppHeader onMenuTap={() => setSidebarCollapsed((v) => !v)} />

      {/* Body below header */}
      <div className="flex flex-1 overflow-hidden" style={{ marginTop: 68 }}>
        {/* Sidebar (desktop only) */}
        {isDesktop && (
          <div
            className="flex-shrink-0 h-full sidebar-transition overflow-hidden"
            style={{ width: sidebarW }}
          >
            <AppSidebar
              activePage={activePage}
              onNavigate={setActivePage}
              collapsed={sidebarCollapsed}
              onToggle={() => setSidebarCollapsed((v) => !v)}
            />
          </div>
        )}

        {/* Main content */}
        <div className="flex-1 min-w-0 h-full">
          {activePage === "dashboard"    && <DashboardPage isDesktop={isDesktop} />}
          {activePage === "register"     && <RegisterPlant />}
          {activePage === "plants"       && <PlantList />}
          {activePage === "inspections"  && <PlaceholderPage label="Inspections" />}
          {activePage === "reports"      && <Reports />}
        </div>
      </div>

      {/* Mobile bottom nav */}
      {!isDesktop && <MobileNav active={mobileTab} onChange={setMobileTab} />}
    </div>
  );
}
