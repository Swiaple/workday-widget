export type BackgroundMode = "glass" | "image" | "blur";
export type ProgressIconMode = "off" | "builtin" | "custom";

export interface WorkRecord {
  start: number;
  plannedDuration: number;
  plannedEnd: number;
  completed: boolean;
  actualEnd?: number;
  updatedAt: number;
  completionSource?: "widget" | "manual" | "edited";
}

export interface WidgetSettings {
  durationMinutes: number;
  backgroundMode: BackgroundMode;
  backgroundDataUrl?: string;
  backgroundZoom: number;
  backgroundOffsetX: number;
  backgroundOffsetY: number;
  progressIconMode: ProgressIconMode;
  progressIconDataUrl?: string;
}

export interface AppState {
  schemaVersion: 1;
  records: Record<string, WorkRecord>;
  settings: WidgetSettings;
}

export const defaultSettings = (): WidgetSettings => ({
  durationMinutes: 8 * 60 + 30,
  backgroundMode: "glass",
  backgroundZoom: 1,
  backgroundOffsetX: 0,
  backgroundOffsetY: 0,
  progressIconMode: "off"
});

export const defaultState = (): AppState => ({
  schemaVersion: 1,
  records: {},
  settings: defaultSettings()
});

export function localDateKey(date = new Date()): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function dateFromKey(key: string): Date {
  const [year = 1970, month = 1, day = 1] = key.split("-").map(Number);
  return new Date(year, month - 1, day);
}

export function minutesAt(date = new Date()): number {
  return date.getHours() * 60 + date.getMinutes();
}

export function formatClock(minutes: number): string {
  const normalized = ((minutes % 1440) + 1440) % 1440;
  return `${String(Math.floor(normalized / 60)).padStart(2, "0")}:${String(normalized % 60).padStart(2, "0")}`;
}

export function formatDuration(minutes: number): string {
  const safe = Math.max(0, Math.round(minutes));
  const hours = Math.floor(safe / 60);
  const rest = safe % 60;
  if (hours === 0) return `${rest}分钟`;
  if (rest === 0) return `${hours}小时`;
  return `${hours}小时${rest}分`;
}

export function normalizeState(raw: unknown): AppState {
  if (!raw || typeof raw !== "object") return defaultState();
  const candidate = raw as Partial<AppState> & { version?: number };
  const settings = candidate.schemaVersion === 1 && candidate.settings
    ? { ...defaultSettings(), ...candidate.settings }
    : defaultSettings();
  const records: Record<string, WorkRecord> = {};
  if (candidate.records && typeof candidate.records === "object") {
    for (const [key, value] of Object.entries(candidate.records)) {
      if (!value || typeof value !== "object") continue;
      const record = value as Partial<WorkRecord>;
      if (!Number.isFinite(record.start)) continue;
      const plannedDuration = Number.isFinite(record.plannedDuration)
        ? Math.min(1440, Math.max(1, Number(record.plannedDuration)))
        : settings.durationMinutes;
      const start = Number(record.start);
      records[key] = {
        start,
        plannedDuration,
        plannedEnd: Number.isFinite(record.plannedEnd) ? Number(record.plannedEnd) : start + plannedDuration,
        completed: Boolean(record.completed),
        ...(Number.isFinite(record.actualEnd) ? { actualEnd: Number(record.actualEnd) } : {}),
        updatedAt: Number.isFinite(record.updatedAt) ? Number(record.updatedAt) : 0,
        ...(record.completionSource === "widget" || record.completionSource === "manual" || record.completionSource === "edited"
          ? { completionSource: record.completionSource }
          : {})
      };
    }
  }
  return { schemaVersion: 1, records, settings };
}

export function relevantDateKey(state: AppState, now = new Date()): string {
  const today = localDateKey(now);
  const todayRecord = state.records[today];
  if (todayRecord) return today;

  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  const yesterdayKey = localDateKey(yesterday);
  const previous = state.records[yesterdayKey];
  if (previous && !previous.completed) {
    const elapsed = elapsedMinutes(yesterdayKey, previous, now);
    if (elapsed > 0 && elapsed <= 24 * 60) return yesterdayKey;
  }
  return today;
}

export function elapsedMinutes(key: string, record: WorkRecord, now = new Date()): number {
  if (record.completed && record.actualEnd != null) return Math.max(0, record.actualEnd - record.start);
  const startDate = dateFromKey(key);
  startDate.setHours(Math.floor(record.start / 60), record.start % 60, 0, 0);
  return Math.max(0, Math.floor((now.getTime() - startDate.getTime()) / 60_000));
}

export function saveStart(state: AppState, key: string, start: number): AppState {
  const duration = Math.min(1440, Math.max(1, state.settings.durationMinutes));
  return {
    ...state,
    records: {
      ...state.records,
      [key]: {
        start,
        plannedDuration: duration,
        plannedEnd: start + duration,
        completed: false,
        updatedAt: Date.now() / 1000
      }
    }
  };
}

export function completeAt(state: AppState, key: string, end: number, source: "widget" | "manual" = "widget"): AppState {
  const record = state.records[key];
  if (!record) return state;
  return {
    ...state,
    records: {
      ...state.records,
      [key]: {
        ...record,
        completed: true,
        actualEnd: end,
        completionSource: source,
        updatedAt: Date.now() / 1000
      }
    }
  };
}

export function clockOutMinutes(key: string, now = new Date()): number {
  const base = dateFromKey(key);
  base.setHours(0, 0, 0, 0);
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  const dayOffset = Math.round((today.getTime() - base.getTime()) / 86_400_000);
  return dayOffset * 1440 + minutesAt(now);
}

export function updateSchedule(state: AppState, durationMinutes: number): AppState {
  const duration = Math.min(1440, Math.max(1, durationMinutes));
  const key = relevantDateKey(state);
  const active = state.records[key];
  const records = active && !active.completed
    ? { ...state.records, [key]: { ...active, plannedDuration: duration, plannedEnd: active.start + duration } }
    : state.records;
  return { ...state, records, settings: { ...state.settings, durationMinutes: duration } };
}

export function deleteRecord(state: AppState, key: string): AppState {
  const records = { ...state.records };
  delete records[key];
  return { ...state, records };
}

export interface DayVisual {
  worked: number;
  overtime: number;
  greenStrength: number;
  redStrength: number;
}

export function dayVisual(record?: WorkRecord): DayVisual | null {
  if (!record?.completed || record.actualEnd == null) return null;
  const worked = Math.max(0, record.actualEnd - record.start);
  const planned = record.plannedDuration || 510;
  const overtime = Math.max(0, worked - planned);
  return {
    worked,
    overtime,
    greenStrength: Math.min(1, worked / Math.max(1, planned)),
    redStrength: Math.min(1, overtime / 180)
  };
}
