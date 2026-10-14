import { useState, useEffect, useCallback } from "react";
import { Search, TreeDeciduous, ChevronLeft, ChevronRight, Filter, X } from "lucide-react";
import { supabase, isSupabaseConfigured } from "../lib/supabase";
import type { HealthValue } from "../hooks/useDashboardData";

interface Plant {
  id: string;
  name: string;
  type: string;
  variety: string;
  campus: string;
  growthStage: string;
  health: HealthValue;
  datePlanted: string;
}

const MOCK_PLANTS: Plant[] = [
  { id: "1",  name: "Mango",       type: "Tree", variety: "Indian Mango", campus: "CSU Lasam",   growthStage: "Mature",   health: "healthy", datePlanted: "March 16, 2025"   },
  { id: "2",  name: "Coconut",     type: "Tree", variety: "Coconut",      campus: "CSU Lasam",   growthStage: "Mature",   health: "healthy", datePlanted: "March 16, 2025"   },
  { id: "3",  name: "Cacao",       type: "Tree", variety: "Cacao",        campus: "CSU Lasam",   growthStage: "Mature",   health: "healthy", datePlanted: "March 16, 2025"   },
  { id: "4",  name: "Banana",      type: "Herb", variety: "Cavendish",    campus: "CSU Carig",   growthStage: "Growing",  health: "healthy", datePlanted: "April 2, 2025"    },
  { id: "5",  name: "Jackfruit",   type: "Tree", variety: "Langka",       campus: "CSU Andrews", growthStage: "Sapling",  health: "dying",   datePlanted: "May 10, 2025"     },
  { id: "6",  name: "Papaya",      type: "Herb", variety: "Solo",         campus: "CSU Carig",   growthStage: "Growing",  health: "healthy", datePlanted: "June 5, 2025"     },
  { id: "7",  name: "Guava",       type: "Tree", variety: "Thai",         campus: "CSU Lasam",   growthStage: "Mature",   health: "healthy", datePlanted: "Jan 20, 2025"     },
  { id: "8",  name: "Avocado",     type: "Tree", variety: "Hass",         campus: "CSU Andrews", growthStage: "Sapling",  health: "healthy", datePlanted: "Feb 14, 2025"     },
  { id: "9",  name: "Narra",       type: "Tree", variety: "Narra",        campus: "CSU Lasam",   growthStage: "Mature",   health: "dead",    datePlanted: "Dec 1, 2024"      },
  { id: "10", name: "Mahogany",    type: "Tree", variety: "African",      campus: "CSU Carig",   growthStage: "Mature",   health: "healthy", datePlanted: "Nov 12, 2024"     },
  { id: "11", name: "Bamboo",      type: "Grass",variety: "Giant",        campus: "CSU Andrews", growthStage: "Mature",   health: "healthy", datePlanted: "Oct 8, 2024"      },
  { id: "12", name: "Talisay",     type: "Tree", variety: "Talisay",      campus: "CSU Lasam",   growthStage: "Growing",  health: "dying",   datePlanted: "Sept 22, 2025"    },
];

const HEALTH_BADGE: Record<HealthValue, { bg: string; dot: string; text: string; label: string }> = {
  healthy: { bg: "#E8F5E9", dot: "#2E7D32", text: "#2E7D32", label: "Healthy" },
  dying:   { bg: "#FFF3E0", dot: "#F57C00", text: "#F57C00", label: "At Risk" },
  dead:    { bg: "#FFEBEE", dot: "#D32F2F", text: "#D32F2F", label: "Dead"    },
};

const GROWTH_COLORS: Record<string, { bg: string; text: string }> = {
  Seedling: { bg: "#E8F5E9", text: "#2E7D32"  },
  Sapling:  { bg: "#E0F2F1", text: "#00695C"  },
  Growing:  { bg: "#E3F2FD", text: "#1565C0"  },
  Mature:   { bg: "#F3E5F5", text: "#6A1B9A"  },
};

const PAGE_SIZE = 8;

export default function PlantList() {
  const [plants, setPlants]     = useState<Plant[]>([]);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState<string | null>(null);
  const [search, setSearch]     = useState("");
  const [filterHealth, setFilterHealth] = useState<HealthValue | "all">("all");
  const [page, setPage]         = useState(1);
  const [showFilters, setShowFilters] = useState(false);

  const fetchPlants = useCallback(async () => {
    setLoading(true);
    setError(null);
    if (!isSupabaseConfigured || !supabase) {
      await new Promise((r) => setTimeout(r, 600));
      setPlants(MOCK_PLANTS);
      setLoading(false);
      return;
    }
    try {
      const { data, error: err } = await supabase
        .from("plant")
        .select(`plant_id, variety, date_planted,
          plant_classification(common_name, plant_type),
          campus(campus_name),
          growth_status(growth_stage),
          health_status(status_name)`)
        .order("created_at", { ascending: false });
      if (err) throw err;
      setPlants((data ?? []).map((p: any) => ({
        id: String(p.plant_id),
        name: p.plant_classification?.common_name ?? "-",
        type: p.plant_classification?.plant_type ?? "-",
        variety: p.variety ?? "-",
        campus: p.campus?.campus_name ?? "-",
        growthStage: p.growth_status?.growth_stage ?? "-",
        health: (p.health_status?.status_name === "alive" ? "healthy" : p.health_status?.status_name ?? "healthy") as HealthValue,
        datePlanted: p.date_planted ?? "-",
      })));
    } catch (e: any) {
      setError(e?.message ?? "Failed to load plants.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchPlants(); }, [fetchPlants]);

  // Filter + search
  const filtered = plants.filter((p) => {
    const matchSearch = !search || [p.name, p.type, p.variety, p.campus].some((v) =>
      v.toLowerCase().includes(search.toLowerCase())
    );
    const matchHealth = filterHealth === "all" || p.health === filterHealth;
    return matchSearch && matchHealth;
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const paginated = filtered.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE);

  return (
    <div className="h-full overflow-y-auto" style={{ background: "#F0F7F0" }}>
      <div style={{ padding: "28px 24px 56px" }}>

        {/* Header */}
        <div className="flex items-start justify-between gap-4 flex-wrap mb-7">
          <div>
            <h1 className="text-3xl font-bold text-gray-900" style={{ fontFamily: "'Nunito',sans-serif" }}>Plant List</h1>
            <p className="text-sm mt-1" style={{ color: "#2E7D32" }}>All registered plants in the EcoTag system</p>
          </div>
          <div className="flex items-center gap-2 text-sm font-medium px-4 py-2 rounded-xl text-white" style={{ background: "#2E7D32" }}>
            <span>{filtered.length} plants</span>
          </div>
        </div>

        {/* Search + filters */}
        <div className="bg-white rounded-2xl p-4 mb-5 flex flex-wrap gap-3 items-center" style={{ border: "1px solid #D8EAD8" }}>
          <div className="flex items-center gap-2 flex-1 min-w-0 px-3 py-2 rounded-xl" style={{ background: "#F8FBF8", border: "1px solid #D8EAD8" }}>
            <Search size={16} className="text-gray-400 flex-shrink-0" />
            <input
              className="flex-1 text-sm bg-transparent outline-none placeholder:text-gray-300"
              placeholder="Search by name, type, campus…"
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            />
            {search && (
              <button onClick={() => { setSearch(""); setPage(1); }}>
                <X size={14} className="text-gray-400 hover:text-gray-600" />
              </button>
            )}
          </div>

          <button
            onClick={() => setShowFilters((v) => !v)}
            className="flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-medium transition-colors"
            style={{ background: showFilters ? "#E8F5E9" : "#F8FBF8", color: showFilters ? "#2E7D32" : "#5A7A5C", border: "1px solid #D8EAD8" }}
          >
            <Filter size={15} />Filters
          </button>

          {showFilters && (
            <div className="flex gap-2 flex-wrap w-full">
              {(["all", "healthy", "dying", "dead"] as const).map((h) => (
                <button
                  key={h}
                  onClick={() => { setFilterHealth(h); setPage(1); }}
                  className="px-3 py-1.5 rounded-full text-xs font-semibold transition-all"
                  style={{
                    background: filterHealth === h ? "#2E7D32" : "#F0F7F0",
                    color: filterHealth === h ? "#fff" : "#5A7A5C",
                    border: `1px solid ${filterHealth === h ? "#2E7D32" : "#D8EAD8"}`,
                  }}
                >
                  {h === "all" ? "All" : h === "healthy" ? "Healthy" : h === "dying" ? "At Risk" : "Dead"}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Table card */}
        <div className="bg-white rounded-2xl overflow-hidden mb-5" style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.04)", border: "1px solid #D8EAD8" }}>
          {loading ? (
            <div className="p-6 flex flex-col gap-3">
              {[...Array(6)].map((_, i) => <div key={i} className="skeleton h-12 rounded-lg" />)}
            </div>
          ) : error ? (
            <div className="p-8 text-center">
              <p className="text-sm text-red-500 mb-3">{error}</p>
              <button onClick={fetchPlants} className="text-sm font-semibold px-4 py-2 rounded-xl" style={{ background: "#FFEBEE", color: "#C62828" }}>Retry</button>
            </div>
          ) : filtered.length === 0 ? (
            <div className="py-16 text-center">
              <div className="text-4xl mb-3">🌱</div>
              <div className="text-sm font-semibold text-gray-600 mb-1">No plants found</div>
              <div className="text-xs text-gray-400">Try adjusting your search or filters.</div>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full" style={{ minWidth: 680 }}>
                <thead>
                  <tr style={{ background: "#F8FBF8", borderBottom: "1px solid #E8F0E8" }}>
                    {["Plant", "Type", "Variety", "Campus", "Growth Stage", "Health", "Date Planted"].map((col) => (
                      <th key={col} className="text-left px-5 py-3 text-xs font-bold text-green-600 uppercase tracking-wide whitespace-nowrap">
                        {col}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {paginated.map((p) => {
                    const hb = HEALTH_BADGE[p.health];
                    const gc = GROWTH_COLORS[p.growthStage] ?? { bg: "#F3F4F6", text: "#374151" };
                    return (
                      <tr
                        key={p.id}
                        className="border-t transition-colors"
                        style={{ borderColor: "#F0F7F0" }}
                        onMouseEnter={(e) => (e.currentTarget.style.background = "#F8FBF8")}
                        onMouseLeave={(e) => (e.currentTarget.style.background = "")}
                      >
                        <td className="px-5 py-3.5">
                          <div className="flex items-center gap-2.5">
                            <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: "#E8F5E9" }}>
                              <TreeDeciduous size={15} color="#2E7D32" />
                            </div>
                            <span className="text-sm font-semibold text-gray-900 whitespace-nowrap">{p.name}</span>
                          </div>
                        </td>
                        <td className="px-5 py-3.5 text-sm text-gray-600 whitespace-nowrap">{p.type}</td>
                        <td className="px-5 py-3.5 text-sm text-gray-600 whitespace-nowrap">{p.variety}</td>
                        <td className="px-5 py-3.5 text-sm text-gray-600 whitespace-nowrap">{p.campus}</td>
                        <td className="px-5 py-3.5">
                          <span className="text-xs font-semibold px-2.5 py-1 rounded-full whitespace-nowrap" style={{ background: gc.bg, color: gc.text }}>
                            {p.growthStage}
                          </span>
                        </td>
                        <td className="px-5 py-3.5">
                          <span className="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1 rounded-full whitespace-nowrap" style={{ background: hb.bg, color: hb.text }}>
                            <span className="w-1.5 h-1.5 rounded-full" style={{ background: hb.dot }} />
                            {hb.label}
                          </span>
                        </td>
                        <td className="px-5 py-3.5 text-sm text-gray-400 whitespace-nowrap">{p.datePlanted}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Pagination */}
        {!loading && !error && filtered.length > PAGE_SIZE && (
          <div className="flex items-center justify-between flex-wrap gap-3">
            <span className="text-sm text-gray-400">
              Showing {(currentPage - 1) * PAGE_SIZE + 1}–{Math.min(currentPage * PAGE_SIZE, filtered.length)} of {filtered.length}
            </span>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="p-2 rounded-xl border transition-colors disabled:opacity-40"
                style={{ borderColor: "#D8EAD8" }}
              >
                <ChevronLeft size={16} className="text-gray-600" />
              </button>
              {Array.from({ length: totalPages }, (_, i) => i + 1).map((n) => (
                <button
                  key={n}
                  onClick={() => setPage(n)}
                  className="w-9 h-9 rounded-xl text-sm font-semibold transition-colors border"
                  style={{
                    background: n === currentPage ? "#2E7D32" : "#fff",
                    color: n === currentPage ? "#fff" : "#5A7A5C",
                    borderColor: n === currentPage ? "#2E7D32" : "#D8EAD8",
                  }}
                >
                  {n}
                </button>
              ))}
              <button
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                className="p-2 rounded-xl border transition-colors disabled:opacity-40"
                style={{ borderColor: "#D8EAD8" }}
              >
                <ChevronRight size={16} className="text-gray-600" />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
