import { isTauri } from "@tauri-apps/api/core";
import { relaunch } from "@tauri-apps/plugin-process";
import { check } from "@tauri-apps/plugin-updater";

export interface UpdateResult {
  status: "unavailable" | "current" | "available" | "installed" | "error";
  message: string;
}

export async function checkUpdateAvailability(): Promise<UpdateResult> {
  if (!isTauri()) return { status: "unavailable", message: "" };
  try {
    const update = await check();
    return update
      ? { status: "available", message: `发现新版本 ${update.version}，可一键更新。` }
      : { status: "current", message: "当前已经是最新版本。" };
  } catch {
    // 启动时静默失败，避免网络波动打扰用户；手动检查仍会显示完整错误。
    return { status: "error", message: "" };
  }
}

export async function checkAndInstallUpdate(onProgress?: (message: string) => void): Promise<UpdateResult> {
  if (!isTauri()) return { status: "unavailable", message: "浏览器预览模式不支持应用更新。" };
  try {
    onProgress?.("正在检查新版本…");
    const update = await check();
    if (!update) return { status: "current", message: "当前已经是最新版本。" };

    let downloaded = 0;
    let total = 0;
    await update.downloadAndInstall((event) => {
      if (event.event === "Started") total = event.data.contentLength ?? 0;
      if (event.event === "Progress") downloaded += event.data.chunkLength;
      const percent = total > 0 ? Math.min(100, Math.round(downloaded / total * 100)) : 0;
      onProgress?.(percent ? `正在下载更新 ${percent}%` : "正在下载更新…");
    });
    onProgress?.("更新完成，正在重新启动…");
    await relaunch();
    return { status: "installed", message: "更新已安装。" };
  } catch (error) {
    return { status: "error", message: `检查更新失败：${String(error)}` };
  }
}
