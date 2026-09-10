import { invoke, isTauri } from "@tauri-apps/api/core";
import { AppState, defaultState, normalizeState } from "./model";

const browserKey = "workday-widget-v4-state";

export async function loadState(): Promise<AppState> {
  try {
    if (isTauri()) {
      return normalizeState(await invoke<unknown | null>("load_app_state"));
    }
    const raw = localStorage.getItem(browserKey);
    return raw ? normalizeState(JSON.parse(raw)) : defaultState();
  } catch (error) {
    console.error("Unable to load state", error);
    return defaultState();
  }
}

export async function saveState(state: AppState): Promise<void> {
  if (isTauri()) {
    await invoke("save_app_state", { state });
  } else {
    localStorage.setItem(browserKey, JSON.stringify(state));
  }
}
