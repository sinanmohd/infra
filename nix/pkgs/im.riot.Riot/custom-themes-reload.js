// NOTE: [AGENT]: element only reads config.json at startup. Watch it and push
// `setting_defaults.custom_themes` into the running renderer, then flip the
// active theme between `custom-<name>` and `custom-<name>-alt` (two identical
// themes) so element re-applies the colors, same trick as the gtk theme.
import { app } from "electron";
import fs from "node:fs";
import path from "node:path";

// runs in the renderer, must be self contained
async function apply(themes) {
  const settings = window.mxSettingsStore;
  if (!settings) return;

  await settings.setValue("custom_themes", null, "device", themes);

  const current = settings.getValue("theme");
  if (typeof current !== "string" || !current.startsWith("custom-")) return;

  const names = new Set(themes.map((t) => t.name));
  const name = current.slice("custom-".length);
  const next = name.endsWith("-alt") ? name.slice(0, -"-alt".length) : `${name}-alt`;
  if (!names.has(name) || !names.has(next)) return;

  await settings.setValue("theme", null, "device", `custom-${next}`);
}

void app.whenReady().then(() => {
  const dir = app.getPath("userData");
  const file = path.join(dir, "config.json");
  let timer;

  const reload = () => {
    let themes;
    try {
      themes = JSON.parse(fs.readFileSync(file, "utf8"))?.setting_defaults?.custom_themes;
    } catch {
      return; // partially written or missing, wait for the next event
    }
    if (!Array.isArray(themes)) return;

    global.mainWindow?.webContents
      .executeJavaScript(`(${apply})(${JSON.stringify(themes)})`)
      .catch((e) => console.warn("custom themes reload failed", e));
  };

  try {
    // watch the dir, the file may be replaced instead of written in place
    fs.watch(dir, (_, name) => {
      if (name !== "config.json") return;
      clearTimeout(timer);
      timer = setTimeout(reload, 200);
    });
  } catch (e) {
    console.warn("custom themes watch failed", e);
  }
});
