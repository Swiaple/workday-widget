import "./styles.css";
import { isTauri } from "@tauri-apps/api/core";
import { currentMonitor, getCurrentWindow, LogicalSize, PhysicalPosition } from "@tauri-apps/api/window";
import { exit } from "@tauri-apps/plugin-process";
import {
  AppState,
  WidgetSettings,
  clockOutMinutes,
  completeAt,
  dateFromKey,
  dayVisual,
  defaultSettings,
  deleteRecord,
  elapsedMinutes,
  formatClock,
  formatDuration,
  localDateKey,
  minutesAt,
  relevantDateKey,
  saveStart,
  updateSchedule
} from "./model";
import { loadState, saveState } from "./storage";
import { checkAndInstallUpdate, checkUpdateAvailability } from "./updater";

type ViewMode = "widget" | "menu" | "start" | "schedule" | "settings" | "history" | "edit";

const app = document.querySelector<HTMLElement>("#app")!;
let state: AppState = await loadState();
let mode: ViewMode = "widget";
let monthCursor = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
let selectedRecordKey: string | null = null;
let deleteArmed = false;
let draftSettings: WidgetSettings = { ...state.settings };
let updateMessage = "";
let updateAvailable = false;
let widgetPosition: { x: number; y: number } | null = null;

const viewSizes: Record<ViewMode, [number, number]> = {
  widget: [224, 88],
  menu: [310, 372],
  start: [350, 250],
  schedule: [360, 270],
  settings: [480, 620],
  history: [400, 520],
  edit: [360, 390]
};

function escapeHtml(value: string): string {
  return value.replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
  })[character]!);
}

async function persist(nextState = state): Promise<void> {
  state = nextState;
  await saveState(state);
  render();
}

async function setView(nextMode: ViewMode): Promise<void> {
  if (nextMode === "settings") draftSettings = { ...state.settings };
  if (nextMode !== "edit") deleteArmed = false;

  document.body.classList.remove("ready");
  if (isTauri()) {
    const window = getCurrentWindow();
    if (mode === "widget" && nextMode !== "widget") {
      const position = await window.outerPosition();
      widgetPosition = { x: position.x, y: position.y };
    }

    const [width, height] = viewSizes[nextMode];
    await window.setSize(new LogicalSize(width, height));
    if (nextMode === "widget" && widgetPosition) {
      await window.setPosition(new PhysicalPosition(widgetPosition.x, widgetPosition.y));
    } else if (nextMode !== "widget") {
      const monitor = await currentMonitor();
      const scale = await window.scaleFactor();
      if (monitor && widgetPosition) {
        const area = monitor.workArea;
        const widthPixels = width * scale;
        const heightPixels = height * scale;
        const x = Math.min(area.position.x + area.size.width - widthPixels,
                           Math.max(area.position.x, widgetPosition.x));
        const y = Math.min(area.position.y + area.size.height - heightPixels,
                           Math.max(area.position.y, widgetPosition.y));
        await window.setPosition(new PhysicalPosition(Math.round(x), Math.round(y)));
      }
      await window.setFocus();
    }
  }
  mode = nextMode;
  render();
  requestAnimationFrame(() => document.body.classList.add("ready"));
}

function activeRecord(now = new Date()) {
  const key = relevantDateKey(state, now);
  return { key, record: state.records[key] };
}

function backgroundMarkup(settings: WidgetSettings): string {
  if (settings.backgroundMode === "glass" || !settings.backgroundDataUrl) return "";
  const blur = settings.backgroundMode === "blur" ? " background-image-blur" : "";
  const x = 50 + settings.backgroundOffsetX * 50;
  const y = 50 + settings.backgroundOffsetY * 50;
  return `<img class="background-image${blur}" alt="" src="${settings.backgroundDataUrl}"
    style="transform:scale(${settings.backgroundZoom});object-position:${x}% ${y}%">`;
}

function widgetMarkup(): string {
  const now = new Date();
  const { key, record } = activeRecord(now);
  let hint = "今日工时";
  let range = "点击设置上班时间";
  let elapsed = 0;
  let overtime = 0;
  let completed = false;

  if (record) {
    completed = record.completed;
    elapsed = elapsedMinutes(key, record, now);
    overtime = Math.max(0, elapsed - record.plannedDuration);
    if (record.completed) {
      hint = `今日工时 · ${formatDuration(elapsed)}`;
      range = `${formatClock(record.start)}–${formatClock(record.actualEnd ?? record.plannedEnd)}`;
    } else if (overtime > 0) {
      hint = `加班中 · +${formatDuration(overtime)}`;
      range = `${formatClock(record.plannedEnd)}–`;
    } else {
      hint = `今日工时 · 已进行 ${formatDuration(elapsed)}`;
      range = `${formatClock(record.start)}–${formatClock(record.plannedEnd)}`;
    }
  }

  const regularProgress = record ? Math.min(1, elapsed / Math.max(1, record.plannedDuration)) : 0;
  const overtimeProgress = Math.min(1, overtime / 180);
  const greenWidth = regularProgress * 82;
  const redWidth = overtimeProgress * 18;
  const iconPosition = overtime > 0 ? 82 + redWidth : greenWidth;
  const redStrength = 0.52 + overtimeProgress * 0.48;
  const active = Boolean(record && !completed);
  const runnerSvg = `<svg viewBox="0 0 16 16" aria-hidden="true"><circle cx="10.8" cy="2.6" r="1.6" fill="currentColor" stroke="none"/><path d="M8.7 5.2 6.2 7.4 3.7 6.5M8.5 5.4l2.1 3 2.9.4M8.2 6.2l-1 4-3.4 3M7.4 10.2l3 1.4 1.2 2.5"/></svg>`;
  const icon = state.settings.progressIconMode === "builtin"
    ? `<span class="progress-avatar builtin ${overtime > 0 ? "overtime" : ""}" style="left:${iconPosition}%" aria-hidden="true">${runnerSvg}</span>`
    : state.settings.progressIconMode === "custom" && state.settings.progressIconDataUrl
      ? `<img class="progress-avatar custom" style="left:${iconPosition}%" src="${state.settings.progressIconDataUrl}" alt="工时进度图标">`
      : "";

  return `<section class="widget-shell drag-surface" aria-label="打卡时间桌面小组件">
    ${backgroundMarkup(state.settings)}
    <div class="glass-tint"></div>
    <span class="status-dot ${overtime > 0 ? "overtime" : ""}" style="--red-strength:${redStrength}"></span>
    <div class="widget-copy">
      <div class="hint">${escapeHtml(hint)}</div>
      <div class="range ${record ? "active" : ""}">${escapeHtml(range)}</div>
    </div>
    ${updateAvailable ? `<button class="update-pill" data-view="settings" title="打开更新">更新</button>` : ""}
    <button class="icon-button calendar-button" data-action="history" aria-label="工作记录" title="工作记录">▦</button>
    <div class="progress-wrap">
      <div class="progress-track">
        <span class="progress-green" style="width:${greenWidth}%"></span>
        <span class="planned-marker"></span>
        <span class="progress-red" style="width:${redWidth}%;--red-strength:${redStrength}"></span>
        ${active ? icon : ""}
      </div>
    </div>
    <button class="clock-out-button ${overtime > 0 ? "overtime" : ""}" data-action="clock-out"
      style="--red-strength:${redStrength}" ${active ? "" : "disabled"} title="${active ? "按当前时间一键下班" : "设置上班时间后可用"}">下班</button>
  </section>`;
}

function panelHeader(title: string, back: ViewMode = "widget"): string {
  return `<header class="panel-header"><button class="plain-button" data-view="${back}" aria-label="返回">‹</button>
    <h1>${escapeHtml(title)}</h1><button class="plain-button close-button" data-view="widget" aria-label="关闭">×</button></header>`;
}

function menuMarkup(): string {
  const { record } = activeRecord();
  const canClockOut = Boolean(record && !record.completed);
  return `<section class="panel-shell">${panelHeader("打卡时间")}
    <div class="menu-list">
      <button data-view="start"><span>◷</span><b>设置上班时间</b><small>修改今天的开始时间</small></button>
      <button data-action="clock-out" ${canClockOut ? "" : "disabled"}><span>✓</span><b>一键下班</b><small>按当前时间完成记录</small></button>
      <button data-view="history"><span>▦</span><b>工作记录</b><small>月度热力图与历史详情</small></button>
      <button data-view="schedule"><span>◴</span><b>工作时间计划</b><small>当前 ${formatDuration(state.settings.durationMinutes)}</small></button>
      <button data-view="settings"><span>⚙</span><b>更多小组件设置${updateAvailable ? " · 有新版本" : ""}</b><small>${updateAvailable ? "点击后可一键安装更新" : "背景、动态图标与更新"}</small></button>
      <button data-action="quit"><span>⏻</span><b>退出小组件</b><small>记录与设置不会删除</small></button>
    </div>
  </section>`;
}

function startMarkup(): string {
  const today = localDateKey();
  const relevant = relevantDateKey(state);
  const record = state.records[relevant];
  if (record && relevant !== today && !record.completed) {
    return `<section class="panel-shell compact-panel">${panelHeader("上一班次未结束")}
      <div class="notice-card"><p>${relevant} 的班次跨到了今天。</p><p>请先一键下班，或在记录中补录正确时间。</p></div>
      <div class="button-row"><button class="primary" data-action="clock-out">现在下班</button><button data-view="history">打开记录</button></div>
    </section>`;
  }
  const current = state.records[today];
  const initial = current ? formatClock(current.start) : formatClock(minutesAt());
  return `<section class="panel-shell compact-panel">${panelHeader("设置今天的上班时间")}
    <form id="start-form" class="form-stack">
      <label>上班时间<input name="start" type="time" value="${initial}" required></label>
      <p class="form-hint">预计下班时间按照 ${formatDuration(state.settings.durationMinutes)} 后计算。</p>
      <div class="button-row"><button class="primary" type="submit">保存</button><button type="button" data-view="widget">取消</button></div>
    </form>
  </section>`;
}

function scheduleMarkup(): string {
  const hours = Math.floor(state.settings.durationMinutes / 60);
  const minutes = state.settings.durationMinutes % 60;
  return `<section class="panel-shell compact-panel">${panelHeader("工作时间计划", "menu")}
    <form id="schedule-form" class="form-stack">
      <div class="duration-fields"><label>小时<input name="hours" type="number" min="0" max="24" value="${hours}"></label>
      <label>分钟<input name="minutes" type="number" min="0" max="59" value="${minutes}"></label></div>
      <p class="form-hint">保存一次后永久执行。正在进行的班次也会同步更新计划。</p>
      <div class="button-row"><button class="primary" type="submit">保存计划</button><button type="button" data-view="menu">取消</button></div>
    </form>
  </section>`;
}

function settingsMarkup(): string {
  const background = draftSettings.backgroundDataUrl
    ? `<img src="${draftSettings.backgroundDataUrl}" alt="背景预览" style="transform:scale(${draftSettings.backgroundZoom});object-position:${50 + draftSettings.backgroundOffsetX * 50}% ${50 + draftSettings.backgroundOffsetY * 50}%">`
    : `<span>选择图片后可在这里预览</span>`;
  const icon = draftSettings.progressIconMode === "builtin"
    ? `<span class="large-runner"><svg viewBox="0 0 16 16" aria-hidden="true"><circle cx="10.8" cy="2.6" r="1.6" fill="currentColor"/><path d="M8.7 5.2 6.2 7.4 3.7 6.5M8.5 5.4l2.1 3 2.9.4M8.2 6.2l-1 4-3.4 3M7.4 10.2l3 1.4 1.2 2.5"/></svg></span>`
    : draftSettings.progressIconMode === "custom" && draftSettings.progressIconDataUrl
      ? `<img src="${draftSettings.progressIconDataUrl}" alt="动态图标预览">`
      : `<span class="muted">关闭</span>`;
  return `<section class="panel-shell settings-panel">${panelHeader("更多小组件设置", "menu")}
    <div class="settings-scroll">
      <section class="setting-section"><h2>背景</h2>
        <div class="background-preview ${draftSettings.backgroundMode === "blur" ? "preview-blur" : ""}">${background}</div>
        <div class="field-row"><label class="file-button">选择背景图片<input id="background-file" type="file" accept="image/png,image/jpeg,image/heic,image/tiff"></label>
          <button data-action="remove-background" ${draftSettings.backgroundDataUrl ? "" : "disabled"}>移除</button></div>
        <label>显示方式<select id="background-mode"><option value="glass" ${draftSettings.backgroundMode === "glass" ? "selected" : ""}>系统毛玻璃</option><option value="image" ${draftSettings.backgroundMode === "image" ? "selected" : ""}>使用原图</option><option value="blur" ${draftSettings.backgroundMode === "blur" ? "selected" : ""}>模糊毛玻璃</option></select></label>
        <label>缩放<input id="background-zoom" type="range" min="1" max="3" step="0.05" value="${draftSettings.backgroundZoom}"></label>
        <div class="field-row"><label>水平<input id="background-x" type="range" min="-1" max="1" step="0.02" value="${draftSettings.backgroundOffsetX}"></label><label>垂直<input id="background-y" type="range" min="-1" max="1" step="0.02" value="${draftSettings.backgroundOffsetY}"></label></div>
      </section>
      <section class="setting-section"><h2>进度图标</h2>
        <div class="icon-setting-row"><div class="icon-preview">${icon}</div><label>图标<select id="icon-mode"><option value="off" ${draftSettings.progressIconMode === "off" ? "selected" : ""}>关闭（默认）</option><option value="builtin" ${draftSettings.progressIconMode === "builtin" ? "selected" : ""}>绿色小人</option><option value="custom" ${draftSettings.progressIconMode === "custom" ? "selected" : ""}>自定义</option></select></label></div>
        <label class="file-button">选择图片或 GIF 动图<input id="icon-file" type="file" accept="image/gif,image/apng,image/webp,image/png,image/jpeg"></label>
        <p class="form-hint">GIF 动画会原样保存并播放。文件最大 20 MB。</p>
      </section>
      <section class="setting-section"><h2>软件更新</h2>
        <button data-action="check-update">${updateAvailable ? "下载并安装新版本" : "检查并安装更新"}</button><p id="update-message" class="form-hint">${escapeHtml(updateMessage)}</p>
      </section>
    </div>
    <footer class="sticky-footer"><button class="primary" data-action="save-settings">保存设置</button><button data-view="menu">取消</button></footer>
  </section>`;
}

function monthLabel(date: Date): string {
  return `${date.getFullYear()}年 ${date.getMonth() + 1}月`;
}

function historyMarkup(): string {
  const first = new Date(monthCursor.getFullYear(), monthCursor.getMonth(), 1);
  const mondayOffset = (first.getDay() + 6) % 7;
  const gridStart = new Date(first);
  gridStart.setDate(first.getDate() - mondayOffset);
  const today = localDateKey();
  const cells = Array.from({ length: 42 }, (_, index) => {
    const date = new Date(gridStart);
    date.setDate(gridStart.getDate() + index);
    const key = localDateKey(date);
    const record = state.records[key];
    const visual = dayVisual(record);
    const outside = date.getMonth() !== monthCursor.getMonth();
    const selected = key === selectedRecordKey;
    const style = visual
      ? `--green:${0.15 + visual.greenStrength * 0.68};--red:${0.25 + visual.redStrength * 0.75}`
      : "";
    return `<button class="day-cell ${outside ? "outside" : ""} ${key === today ? "today" : ""} ${visual ? "worked" : ""} ${visual?.overtime ? "overtime" : ""} ${selected ? "selected" : ""}"
      data-day="${key}" style="${style}"><span>${date.getDate()}</span></button>`;
  }).join("");

  const selectedRecord = selectedRecordKey ? state.records[selectedRecordKey] : undefined;
  const visual = dayVisual(selectedRecord);
  const detail = selectedRecord
    ? `<div class="day-detail"><div><b>${selectedRecordKey}</b><span>${selectedRecord.completed ? "已记录" : "进行中"}</span></div>
       <p>${formatClock(selectedRecord.start)}–${selectedRecord.completed ? formatClock(selectedRecord.actualEnd ?? selectedRecord.plannedEnd) : formatClock(selectedRecord.plannedEnd)}</p>
       <p>总工时 ${formatDuration(selectedRecord.completed ? (selectedRecord.actualEnd ?? selectedRecord.start) - selectedRecord.start : elapsedMinutes(selectedRecordKey!, selectedRecord))}${visual?.overtime ? ` · 加班 ${formatDuration(visual.overtime)}` : ""}</p>
       <button data-view="edit">查看与修改</button></div>`
    : `<div class="day-detail empty">点击有颜色的日期查看具体工时</div>`;

  return `<section class="panel-shell history-panel">${panelHeader("工作记录")}
    <div class="month-toolbar"><button data-action="previous-month">‹</button><b>${monthLabel(monthCursor)}</b><button data-action="next-month">›</button></div>
    <div class="weekday-row">${["一", "二", "三", "四", "五", "六", "日"].map(day => `<span>${day}</span>`).join("")}</div>
    <div class="calendar-grid">${cells}</div>
    ${detail}
    <div class="legend"><span class="green-key"></span>正常工时深浅 <span class="red-key"></span>红色表示加班</div>
  </section>`;
}

function editMarkup(): string {
  const key = selectedRecordKey;
  const record = key ? state.records[key] : undefined;
  if (!key || !record) return `<section class="panel-shell">${panelHeader("记录不存在", "history")}</section>`;
  const end = record.actualEnd ?? record.plannedEnd;
  return `<section class="panel-shell compact-panel">${panelHeader("修改工作记录", "history")}
    <form id="edit-form" class="form-stack">
      <p class="record-date">${key}</p>
      <label>上班时间<input name="start" type="time" value="${formatClock(record.start)}" required></label>
      <label>下班时间<input name="end" type="time" value="${formatClock(end)}" required></label>
      <p class="form-hint">下班时间早于上班时间时，按跨午夜班次计算。</p>
      <div class="button-row"><button class="primary" type="submit">保存记录</button><button type="button" class="danger" data-action="delete-record">${deleteArmed ? "再次点击确认删除" : "删除"}</button></div>
    </form>
  </section>`;
}

function render(): void {
  document.body.dataset.mode = mode;
  app.innerHTML = mode === "widget" ? widgetMarkup()
    : mode === "menu" ? menuMarkup()
    : mode === "start" ? startMarkup()
    : mode === "schedule" ? scheduleMarkup()
    : mode === "settings" ? settingsMarkup()
    : mode === "history" ? historyMarkup()
    : editMarkup();
  bindViewEvents();
}

async function oneClickClockOut(): Promise<void> {
  const now = new Date();
  const { key, record } = activeRecord(now);
  if (!record || record.completed) return;
  const end = clockOutMinutes(key, now);
  const duration = end - record.start;
  if (duration <= 0 || duration > 1440) {
    selectedRecordKey = key;
    await setView("edit");
    return;
  }
  await persist(completeAt(state, key, end, "widget"));
  await setView("widget");
}

function readTime(value: FormDataEntryValue | null): number | null {
  if (typeof value !== "string" || !/^\d{2}:\d{2}$/.test(value)) return null;
  const [hours, minutes] = value.split(":").map(Number);
  if (hours == null || minutes == null || hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

async function fileAsDataUrl(file: File, maximumBytes: number): Promise<string> {
  if (file.size > maximumBytes) throw new Error(`文件不能超过 ${Math.round(maximumBytes / 1024 / 1024)} MB`);
  return await new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error("读取文件失败"));
    reader.readAsDataURL(file);
  });
}

function updateSettingsPreview(): void {
  const preview = document.querySelector<HTMLElement>(".background-preview");
  const image = preview?.querySelector<HTMLImageElement>("img");
  if (preview) preview.classList.toggle("preview-blur", draftSettings.backgroundMode === "blur");
  if (image) {
    image.style.transform = `scale(${draftSettings.backgroundZoom})`;
    image.style.objectPosition = `${50 + draftSettings.backgroundOffsetX * 50}% ${50 + draftSettings.backgroundOffsetY * 50}%`;
  }
}

function bindDragSurface(): void {
  const surface = document.querySelector<HTMLElement>(".drag-surface");
  if (!surface) return;
  let origin: { x: number; y: number } | null = null;
  let dragged = false;
  surface.addEventListener("pointerdown", (event) => {
    if (event.button !== 0 || (event.target as HTMLElement).closest("button,input,select")) return;
    origin = { x: event.screenX, y: event.screenY };
    dragged = false;
  });
  surface.addEventListener("pointermove", async (event) => {
    if (!origin || dragged) return;
    if (Math.hypot(event.screenX - origin.x, event.screenY - origin.y) < 5) return;
    dragged = true;
    if (isTauri()) await getCurrentWindow().startDragging();
  });
  surface.addEventListener("pointerup", async (event) => {
    if (!origin) return;
    const wasDragged = dragged;
    origin = null;
    dragged = false;
    if (!wasDragged && !(event.target as HTMLElement).closest("button,input,select")) await setView("start");
  });
  surface.addEventListener("contextmenu", async (event) => {
    event.preventDefault();
    await setView("menu");
  });
}

function bindViewEvents(): void {
  bindDragSurface();
  document.querySelectorAll<HTMLElement>("[data-view]").forEach((element) => {
    element.addEventListener("click", () => void setView(element.dataset.view as ViewMode));
  });
  document.querySelectorAll<HTMLElement>("[data-action='clock-out']").forEach((element) => {
    element.addEventListener("click", () => void oneClickClockOut());
  });
  document.querySelector("[data-action='quit']")?.addEventListener("click", () => {
    if (isTauri()) void exit(0);
  });
  document.querySelector("[data-action='previous-month']")?.addEventListener("click", () => {
    monthCursor = new Date(monthCursor.getFullYear(), monthCursor.getMonth() - 1, 1); render();
  });
  document.querySelector("[data-action='next-month']")?.addEventListener("click", () => {
    monthCursor = new Date(monthCursor.getFullYear(), monthCursor.getMonth() + 1, 1); render();
  });
  document.querySelectorAll<HTMLElement>("[data-day]").forEach((element) => {
    element.addEventListener("click", () => { selectedRecordKey = element.dataset.day ?? null; render(); });
  });

  document.querySelector<HTMLFormElement>("#start-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const value = readTime(new FormData(event.currentTarget as HTMLFormElement).get("start"));
    if (value == null) return;
    await persist(saveStart(state, localDateKey(), value));
    await setView("widget");
  });

  document.querySelector<HTMLFormElement>("#schedule-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const data = new FormData(event.currentTarget as HTMLFormElement);
    const hours = Number(data.get("hours"));
    const minutes = Number(data.get("minutes"));
    const duration = hours * 60 + minutes;
    if (!Number.isFinite(duration) || hours < 0 || hours > 24 || minutes < 0 || minutes > 59 || duration < 1 || duration > 1440) return;
    await persist(updateSchedule(state, duration));
    await setView("menu");
  });

  document.querySelector<HTMLFormElement>("#edit-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!selectedRecordKey) return;
    const record = state.records[selectedRecordKey];
    if (!record) return;
    const data = new FormData(event.currentTarget as HTMLFormElement);
    const start = readTime(data.get("start"));
    let end = readTime(data.get("end"));
    if (start == null || end == null) return;
    if (end <= start) end += 1440;
    const next = saveStart(state, selectedRecordKey, start);
    await persist(completeAt(next, selectedRecordKey, end, "manual"));
    await setView("history");
  });

  document.querySelector("[data-action='delete-record']")?.addEventListener("click", async () => {
    if (!deleteArmed) { deleteArmed = true; render(); return; }
    if (selectedRecordKey) await persist(deleteRecord(state, selectedRecordKey));
    selectedRecordKey = null;
    await setView("history");
  });

  document.querySelector<HTMLSelectElement>("#background-mode")?.addEventListener("change", (event) => {
    draftSettings.backgroundMode = (event.currentTarget as HTMLSelectElement).value as WidgetSettings["backgroundMode"];
    updateSettingsPreview();
  });
  document.querySelector<HTMLInputElement>("#background-zoom")?.addEventListener("input", (event) => {
    draftSettings.backgroundZoom = Number((event.currentTarget as HTMLInputElement).value); updateSettingsPreview();
  });
  document.querySelector<HTMLInputElement>("#background-x")?.addEventListener("input", (event) => {
    draftSettings.backgroundOffsetX = Number((event.currentTarget as HTMLInputElement).value); updateSettingsPreview();
  });
  document.querySelector<HTMLInputElement>("#background-y")?.addEventListener("input", (event) => {
    draftSettings.backgroundOffsetY = Number((event.currentTarget as HTMLInputElement).value); updateSettingsPreview();
  });
  document.querySelector<HTMLInputElement>("#background-file")?.addEventListener("change", async (event) => {
    const file = (event.currentTarget as HTMLInputElement).files?.[0];
    if (!file) return;
    try {
      draftSettings.backgroundDataUrl = await fileAsDataUrl(file, 20 * 1024 * 1024);
      if (draftSettings.backgroundMode === "glass") draftSettings.backgroundMode = "image";
      render();
    } catch (error) { updateMessage = String(error); render(); }
  });
  document.querySelector("[data-action='remove-background']")?.addEventListener("click", () => {
    draftSettings.backgroundDataUrl = undefined;
    draftSettings.backgroundMode = "glass";
    draftSettings.backgroundZoom = 1;
    draftSettings.backgroundOffsetX = 0;
    draftSettings.backgroundOffsetY = 0;
    render();
  });
  document.querySelector<HTMLSelectElement>("#icon-mode")?.addEventListener("change", (event) => {
    draftSettings.progressIconMode = (event.currentTarget as HTMLSelectElement).value as WidgetSettings["progressIconMode"];
    render();
  });
  document.querySelector<HTMLInputElement>("#icon-file")?.addEventListener("change", async (event) => {
    const file = (event.currentTarget as HTMLInputElement).files?.[0];
    if (!file) return;
    try {
      draftSettings.progressIconDataUrl = await fileAsDataUrl(file, 20 * 1024 * 1024);
      draftSettings.progressIconMode = "custom";
      render();
    } catch (error) { updateMessage = String(error); render(); }
  });
  document.querySelector("[data-action='save-settings']")?.addEventListener("click", async () => {
    if (draftSettings.progressIconMode === "custom" && !draftSettings.progressIconDataUrl) {
      updateMessage = "请先选择自定义图片或 GIF 动图。"; render(); return;
    }
    await persist({ ...state, settings: { ...draftSettings } });
    await setView("widget");
  });
  document.querySelector("[data-action='check-update']")?.addEventListener("click", async () => {
    const result = await checkAndInstallUpdate((message) => {
      updateMessage = message;
      const label = document.querySelector("#update-message");
      if (label) label.textContent = message;
    });
    updateMessage = result.message;
    updateAvailable = result.status === "available";
    const label = document.querySelector("#update-message");
    if (label) label.textContent = result.message;
  });
}

render();
requestAnimationFrame(() => document.body.classList.add("ready"));
setInterval(() => { if (mode === "widget") render(); }, 30_000);

// 启动后稍等片刻再静默检查，不拖慢小组件出现，也不因断网弹错。
setTimeout(async () => {
  const result = await checkUpdateAvailability();
  if (result.status !== "available") return;
  updateAvailable = true;
  updateMessage = result.message;
  render();
}, 4_000);
