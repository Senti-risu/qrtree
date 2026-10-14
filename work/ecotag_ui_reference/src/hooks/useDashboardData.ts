import { useState, useEffect, useCallback } from "react";
import { supabase, isSupabaseConfigured } from "../lib/supabase";

export interface DashboardStats {
  totalPlants: number;
  healthyPlants: number;
  dyingPlants: number;
  deadPlants: number;
}

export type HealthValue = "healthy" | "dying" | "dead";

export interface RecentPlant {
  id: string;
  name: string;
  type: string;
  variety: string;
  campus: string;
  growthStage: string;
  health: HealthValue;
  datePlanted: string;
}

export interface RecentInspection {
  id: string;
  plantName: string;
  inspector: string;
  health: HealthValue;
  growthStage: string;
  date: string;
  status: string;
}

export interface CampusCount {
  campus: string;
  count: number;
}

export interface DashboardData {
  stats: DashboardStats;
  recentPlants: RecentPlant[];
  recentInspections: RecentInspection[];
  campusDistribution: CampusCount[];
}

// ── Mock data (used when Supabase is not configured) ─────────────────────────
const MOCK: DashboardData = {
  stats: { totalPlants: 400, healthyPlants: 340, dyingPlants: 10, deadPlants: 50 },
  recentPlants: [
    { id: "1", name: "Mango",    type: "Tree", variety: "Indian Mango", campus: "CSU Lasam",   growthStage: "Mature",  health: "healthy", datePlanted: "March 16, 2025" },
    { id: "2", name: "Coconut",  type: "Tree", variety: "Coconut",      campus: "CSU Lasam",   growthStage: "Mature",  health: "healthy", datePlanted: "March 16, 2025" },
    { id: "3", name: "Cacao",    type: "Tree", variety: "Cacao",        campus: "CSU Lasam",   growthStage: "Mature",  health: "healthy", datePlanted: "March 16, 2025" },
    { id: "4", name: "Banana",   type: "Herb", variety: "Cavendish",    campus: "CSU Carig",   growthStage: "Growing", health: "healthy", datePlanted: "April 2, 2025"  },
    { id: "5", name: "Jackfruit",type: "Tree", variety: "Langka",       campus: "CSU Andrews", growthStage: "Sapling", health: "dying",   datePlanted: "May 10, 2025"   },
  ],
  recentInspections: [
    { id: "1", plantName: "Mango",    inspector: "Juan Dela Cruz", health: "healthy", growthStage: "Mature",  date: "August 18, 2026", status: "Completed" },
    { id: "2", plantName: "Coconut",  inspector: "Maria Santos",   health: "healthy", growthStage: "Mature",  date: "August 17, 2026", status: "Completed" },
    { id: "3", plantName: "Jackfruit",inspector: "Pedro Reyes",    health: "dying",   growthStage: "Sapling", date: "August 16, 2026", status: "Pending"   },
    { id: "4", plantName: "Banana",   inspector: "Ana Cruz",       health: "healthy", growthStage: "Growing", date: "August 15, 2026", status: "Completed" },
  ],
  campusDistribution: [
    { campus: "CSU Lasam",   count: 180 },
    { campus: "CSU Carig",   count: 120 },
    { campus: "CSU Andrews", count: 60  },
    { campus: "Other",       count: 40  },
  ],
};

function parseHealth(v?: string): HealthValue {
  if (v === "alive") return "healthy";
  if (v === "dying") return "dying";
  if (v === "dead")  return "dead";
  return "healthy";
}

export function useDashboardData() {
  const [data, setData]       = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);

    if (!isSupabaseConfigured || !supabase) {
      await new Promise((r) => setTimeout(r, 700));
      setData(MOCK);
      setLoading(false);
      return;
    }

    try {
      // 1. Health counts
      const { data: healthRows, error: e1 } = await supabase
        .from("plant")
        .select("plant_id, health_status(status_name)");
      if (e1) throw e1;

      let healthy = 0, dying = 0, dead = 0;
      for (const row of (healthRows ?? [])) {
        const s = (row as any).health_status?.status_name as string | undefined;
        if (s === "alive") healthy++;
        else if (s === "dying") dying++;
        else if (s === "dead") dead++;
      }

      // 2. Recent plants
      const { data: plantRows, error: e2 } = await supabase
        .from("plant")
        .select(`plant_id, variety, date_planted,
          plant_classification(common_name, plant_type),
          campus(campus_name),
          growth_status(growth_stage),
          health_status(status_name)`)
        .order("created_at", { ascending: false })
        .limit(5);
      if (e2) throw e2;

      // 3. Recent inspections
      const { data: inspRows, error: e3 } = await supabase
        .from("inspection")
        .select(`inspection_id, inspector_name, inspection_date, status,
          plant(plant_classification(common_name)),
          health_status(status_name),
          growth_status(growth_stage)`)
        .order("inspection_date", { ascending: false })
        .limit(4);
      if (e3) throw e3;

      // 4. Campus distribution (derive from plant rows)
      const campusMap: Record<string, number> = {};
      for (const row of (healthRows ?? [])) {
        const name = (row as any).campus?.campus_name as string | undefined ?? "Unknown";
        campusMap[name] = (campusMap[name] ?? 0) + 1;
      }
      // Alternatively fetch per-campus if the data above doesn't have campus:
      // fall back to a separate query
      let campusDist: CampusCount[] = Object.entries(campusMap)
        .map(([campus, count]) => ({ campus, count }))
        .sort((a, b) => b.count - a.count);

      if (campusDist.length === 0) {
        // Separate query
        const { data: campusRows } = await supabase
          .from("plant")
          .select("campus(campus_name)");
        const m2: Record<string, number> = {};
        for (const r of (campusRows ?? [])) {
          const n = (r as any).campus?.campus_name as string | undefined ?? "Unknown";
          m2[n] = (m2[n] ?? 0) + 1;
        }
        campusDist = Object.entries(m2).map(([campus, count]) => ({ campus, count })).sort((a, b) => b.count - a.count);
      }

      setData({
        stats: {
          totalPlants: (healthRows ?? []).length,
          healthyPlants: healthy,
          dyingPlants: dying,
          deadPlants: dead,
        },
        recentPlants: (plantRows ?? []).map((p: any) => ({
          id: String(p.plant_id),
          name: p.plant_classification?.common_name ?? "-",
          type: p.plant_classification?.plant_type ?? "-",
          variety: p.variety ?? "-",
          campus: p.campus?.campus_name ?? "-",
          growthStage: p.growth_status?.growth_stage ?? "-",
          health: parseHealth(p.health_status?.status_name),
          datePlanted: p.date_planted ?? "-",
        })),
        recentInspections: (inspRows ?? []).map((i: any) => ({
          id: String(i.inspection_id),
          plantName: i.plant?.plant_classification?.common_name ?? "-",
          inspector: i.inspector_name ?? "-",
          health: parseHealth(i.health_status?.status_name),
          growthStage: i.growth_status?.growth_stage ?? "-",
          date: i.inspection_date ?? "-",
          status: i.status ?? "Completed",
        })),
        campusDistribution: campusDist,
      });
    } catch (err: any) {
      const isNetwork = /Failed to fetch|ClientException/i.test(String(err));
      setError(
        isNetwork
          ? "Could not reach Supabase. Check that your project is not paused and this device has internet access."
          : `Could not load dashboard data: ${err?.message ?? err}`
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);
  return { data, loading, error, refetch: fetchData };
}
