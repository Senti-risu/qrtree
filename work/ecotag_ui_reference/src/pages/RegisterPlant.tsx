import { useState } from "react";
import { CheckCircle, Loader2 } from "lucide-react";
import { supabase, isSupabaseConfigured } from "../lib/supabase";

interface FormState {
  commonName: string;
  plantType: string;
  variety: string;
  campus: string;
  college: string;
  healthStatus: string;
  growthStage: string;
  datePlanted: string;
  notes: string;
}

const EMPTY: FormState = {
  commonName: "", plantType: "", variety: "", campus: "",
  college: "", healthStatus: "alive", growthStage: "Seedling",
  datePlanted: "", notes: "",
};

const PLANT_TYPES   = ["Tree", "Shrub", "Herb", "Vine", "Grass", "Palm", "Fern", "Other"];
const HEALTH_STATUS = [{ value: "alive", label: "Healthy (Alive)" }, { value: "dying", label: "At Risk (Dying)" }, { value: "dead", label: "Dead" }];
const GROWTH_STAGES = ["Seedling", "Sapling", "Growing", "Mature"];
const CAMPUSES      = ["CSU Lasam", "CSU Carig", "CSU Andrews", "CSU Aparri", "CSU Gonzaga", "CSU Lal-lo", "CSU Piat", "Other"];

function Field({ label, required, children }: { label: string; required?: boolean; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-sm font-semibold text-gray-700 mb-1.5">
        {label}{required && <span className="text-red-400 ml-0.5">*</span>}
      </label>
      {children}
    </div>
  );
}

const inputCls = "w-full px-3.5 py-2.5 text-sm rounded-xl border border-gray-200 bg-white outline-none transition-all focus:border-green-500 focus:ring-2 focus:ring-green-100 placeholder:text-gray-300";
const selectCls = inputCls + " cursor-pointer";

export default function RegisterPlant() {
  const [form, setForm]       = useState<FormState>(EMPTY);
  const [saving, setSaving]   = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError]     = useState<string | null>(null);

  const set = (k: keyof FormState) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }));

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.commonName || !form.plantType || !form.campus || !form.datePlanted) {
      setError("Please fill in all required fields.");
      return;
    }

    setSaving(true);
    setError(null);

    if (!isSupabaseConfigured || !supabase) {
      await new Promise((r) => setTimeout(r, 900));
      setSuccess(true);
      setForm(EMPTY);
      setSaving(false);
      setTimeout(() => setSuccess(false), 4000);
      return;
    }

    try {
      // 1. Upsert classification
      const { data: cls, error: e1 } = await supabase
        .from("plant_classification")
        .upsert({ common_name: form.commonName, plant_type: form.plantType, variety: form.variety || null }, { onConflict: "common_name" })
        .select("classification_id")
        .single();
      if (e1) throw e1;

      // 2. Look up FK ids
      const [{ data: campus }, { data: health }, { data: growth }] = await Promise.all([
        supabase.from("campus").select("campus_id").eq("campus_name", form.campus).maybeSingle(),
        supabase.from("health_status").select("health_id").eq("status_name", form.healthStatus).maybeSingle(),
        supabase.from("growth_status").select("growth_id").eq("growth_stage", form.growthStage).maybeSingle(),
      ]);

      // 3. Insert plant
      const { error: e2 } = await supabase.from("plant").insert({
        classification_id: cls?.classification_id,
        campus_id: campus?.campus_id ?? null,
        health_id: health?.health_id ?? null,
        growth_id: growth?.growth_id ?? null,
        variety: form.variety || null,
        date_planted: form.datePlanted,
        notes: form.notes || null,
      });
      if (e2) throw e2;

      setSuccess(true);
      setForm(EMPTY);
      setTimeout(() => setSuccess(false), 4000);
    } catch (err: any) {
      setError(err?.message ?? "Failed to register plant.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="h-full overflow-y-auto" style={{ background: "#F0F7F0" }}>
      <div style={{ maxWidth: 760, margin: "0 auto", padding: "28px 24px 56px" }}>
        {/* Page title */}
        <div className="mb-7">
          <h1 className="text-3xl font-bold text-gray-900" style={{ fontFamily: "'Nunito',sans-serif" }}>Register Plant</h1>
          <p className="text-sm mt-1" style={{ color: "#2E7D32" }}>Add a new plant to the EcoTag database</p>
        </div>

        {/* Success */}
        {success && (
          <div className="flex items-center gap-3 px-5 py-4 mb-6 rounded-2xl" style={{ background: "#E8F5E9", border: "1px solid #A5D6A7" }}>
            <CheckCircle size={20} color="#2E7D32" />
            <div>
              <div className="text-sm font-semibold" style={{ color: "#1B5E20" }}>Plant registered successfully!</div>
              <div className="text-xs" style={{ color: "#388E3C" }}>The plant has been added to the database.</div>
            </div>
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="px-5 py-4 mb-6 rounded-2xl text-sm" style={{ background: "#FFEBEE", border: "1px solid #FFCDD2", color: "#C62828" }}>
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          {/* Card: Plant Information */}
          <div className="bg-white rounded-2xl p-6 mb-5" style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.04)", border: "1px solid #D8EAD8" }}>
            <div className="text-base font-bold text-gray-900 mb-5" style={{ fontFamily: "'Nunito',sans-serif" }}>
              Plant Information
            </div>
            <div className="grid gap-4" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
              <Field label="Common Name" required>
                <input className={inputCls} placeholder="e.g. Mango" value={form.commonName} onChange={set("commonName")} />
              </Field>
              <Field label="Plant Type" required>
                <select className={selectCls} value={form.plantType} onChange={set("plantType")}>
                  <option value="">Select type…</option>
                  {PLANT_TYPES.map((t) => <option key={t}>{t}</option>)}
                </select>
              </Field>
              <Field label="Variety">
                <input className={inputCls} placeholder="e.g. Indian Mango" value={form.variety} onChange={set("variety")} />
              </Field>
            </div>
          </div>

          {/* Card: Location */}
          <div className="bg-white rounded-2xl p-6 mb-5" style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.04)", border: "1px solid #D8EAD8" }}>
            <div className="text-base font-bold text-gray-900 mb-5" style={{ fontFamily: "'Nunito',sans-serif" }}>
              Location
            </div>
            <div className="grid gap-4" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
              <Field label="Campus" required>
                <select className={selectCls} value={form.campus} onChange={set("campus")}>
                  <option value="">Select campus…</option>
                  {CAMPUSES.map((c) => <option key={c}>{c}</option>)}
                </select>
              </Field>
              <Field label="College">
                <input className={inputCls} placeholder="e.g. College of Agriculture" value={form.college} onChange={set("college")} />
              </Field>
            </div>
          </div>

          {/* Card: Status */}
          <div className="bg-white rounded-2xl p-6 mb-5" style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.04)", border: "1px solid #D8EAD8" }}>
            <div className="text-base font-bold text-gray-900 mb-5" style={{ fontFamily: "'Nunito',sans-serif" }}>
              Status & Growth
            </div>
            <div className="grid gap-4" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
              <Field label="Health Status">
                <select className={selectCls} value={form.healthStatus} onChange={set("healthStatus")}>
                  {HEALTH_STATUS.map((h) => <option key={h.value} value={h.value}>{h.label}</option>)}
                </select>
              </Field>
              <Field label="Growth Stage">
                <select className={selectCls} value={form.growthStage} onChange={set("growthStage")}>
                  {GROWTH_STAGES.map((g) => <option key={g}>{g}</option>)}
                </select>
              </Field>
              <Field label="Date Planted" required>
                <input type="date" className={inputCls} value={form.datePlanted} onChange={set("datePlanted")} />
              </Field>
            </div>
          </div>

          {/* Card: Notes */}
          <div className="bg-white rounded-2xl p-6 mb-7" style={{ boxShadow: "0 4px 10px rgba(0,0,0,0.04)", border: "1px solid #D8EAD8" }}>
            <div className="text-base font-bold text-gray-900 mb-5" style={{ fontFamily: "'Nunito',sans-serif" }}>Additional Notes</div>
            <textarea
              className={inputCls}
              rows={4}
              placeholder="Optional notes about this plant…"
              value={form.notes}
              onChange={set("notes")}
              style={{ resize: "vertical" }}
            />
          </div>

          {/* Actions */}
          <div className="flex gap-3 justify-end">
            <button
              type="button"
              onClick={() => setForm(EMPTY)}
              className="px-5 py-2.5 rounded-xl text-sm font-semibold border transition-colors"
              style={{ borderColor: "#D8EAD8", color: "#5A7A5C" }}
            >
              Clear
            </button>
            <button
              type="submit"
              disabled={saving}
              className="flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-semibold text-white transition-opacity disabled:opacity-60"
              style={{ background: "#2E7D32" }}
            >
              {saving && <Loader2 size={15} className="animate-spin" />}
              {saving ? "Registering…" : "Register Plant"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
