import { describe, expect, it } from "vitest";
import {
  clockOutMinutes,
  completeAt,
  dayVisual,
  defaultState,
  elapsedMinutes,
  formatClock,
  normalizeState,
  relevantDateKey,
  saveStart,
  updateSchedule
} from "./model";

describe("workday model", () => {
  it("creates and completes a normal workday", () => {
    let state = saveStart(defaultState(), "2026-09-10", 9 * 60 + 25);
    state = completeAt(state, "2026-09-10", 18 * 60, "widget");
    expect(state.records["2026-09-10"]?.actualEnd).toBe(1080);
    expect(dayVisual(state.records["2026-09-10"])?.overtime).toBe(5);
  });

  it("carries an unfinished overnight shift into the next date", () => {
    const state = saveStart(defaultState(), "2026-09-10", 23 * 60);
    const now = new Date(2026, 8, 11, 1, 0);
    expect(relevantDateKey(state, now)).toBe("2026-09-10");
    expect(elapsedMinutes("2026-09-10", state.records["2026-09-10"]!, now)).toBe(120);
    expect(clockOutMinutes("2026-09-10", now)).toBe(1500);
    expect(formatClock(1500)).toBe("01:00");
  });

  it("updates the active plan and imports legacy records", () => {
    let state = saveStart(defaultState(), new Date().toLocaleDateString("en-CA"), 540);
    state = updateSchedule(state, 480);
    expect(state.settings.durationMinutes).toBe(480);
    expect(Object.values(state.records)[0]?.plannedDuration).toBe(480);
    expect(normalizeState({ version: 2, records: state.records }).settings.progressIconMode).toBe("off");
  });

  it("repairs old records that do not contain a planned duration", () => {
    const normalized = normalizeState({
      schemaVersion: 1,
      settings: { durationMinutes: 480 },
      records: { "2026-09-10": { start: 540, completed: true, actualEnd: 1020 } }
    });
    expect(normalized.records["2026-09-10"]?.plannedDuration).toBe(480);
    expect(normalized.records["2026-09-10"]?.plannedEnd).toBe(1020);
  });
});
