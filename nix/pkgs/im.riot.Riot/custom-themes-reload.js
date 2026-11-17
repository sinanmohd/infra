// NOTE: element only reads config.json at startup. Watch it and push
// `setting_defaults.custom_themes` into the running renderer, then flip the
// active theme between `custom-<name>` and `custom-<name>-alt` (two identical
// themes) so element re-applies the colors, same trick as the gtk theme.
// The pushed themes are saved at device level, which wins over config.json on
// the next start, so they are pushed again on every page load.
import { app } from "electron";
import fs from "node:fs";
import path from "node:path";

const CANVAS = "--cpd-color-bg-canvas-default";

// runs in the renderer, must be self contained
async function apply(themes) {
  // NOTE: [AGENT]: on startup the page is loaded before the settings store
  // exists, element assigns it to the window from a lazy loaded chunk. Catch
  // that assignment with a setter, then turn it back into a plain property
  if (!window.mxSettingsStore) {
    await new Promise((resolve) => {
      Object.defineProperty(window, "mxSettingsStore", {
        configurable: true,
        set(value) {
          Object.defineProperty(window, "mxSettingsStore", {
            value,
            writable: true,
            enumerable: true,
            configurable: true,
          });
          resolve();
        },
      });
    });
  }

  const settings = window.mxSettingsStore;
  const stored = settings.getValue("custom_themes");
  if (JSON.stringify(stored) === JSON.stringify(themes)) {
    return;
  }

  await settings.setValue("custom_themes", null, "device", themes);

  const current = settings.getValue("theme");
  if (typeof current !== "string" || !current.startsWith("custom-")) return;

  const names = new Set(themes.map((t) => t.name));
  const name = current.slice("custom-".length);
  const next = name.endsWith("-alt") ? name.slice(0, -"-alt".length) : `${name}-alt`;
  if (!names.has(name) || !names.has(next)) return;

  await settings.setValue("theme", null, "device", `custom-${next}`);
}

// NOTE: [AGENT]: runs in the renderer, must be self contained. Until element
// applies the theme the page is drawn with the colors of the previous one, a
// flash before the loading screen. Pin the canvas color of the active custom
// theme on <html>, and drop the pin once element has set the theme class on
// <body>
function prepaint(themes, token) {
  let active;
  try {
    active = JSON.parse(localStorage.getItem("mx_local_settings") ?? "{}").theme;
  } catch {
    return;
  }

  const color = themes.find((t) => `custom-${t.name}` === active)?.compound?.[token];
  if (typeof color !== "string") {
    return;
  }

  const pin = () => {
    const root = document.documentElement;
    root.style.setProperty(token, color);

    new MutationObserver((_, observer) => {
      if (!document.body?.className.includes("cpd-theme-")) {
        return;
      }

      root.style.removeProperty(token);
      observer.disconnect();
    }).observe(document, { subtree: true, attributes: true, attributeFilter: ["class"] });
  };

  if (document.documentElement) {
    pin();
    return;
  }

  // NOTE: [AGENT]: this can run before the parser has created <html>
  new MutationObserver((_, observer) => {
    if (!document.documentElement) {
      return;
    }

    observer.disconnect();
    pin();
  }).observe(document, { childList: true });
}

void app.whenReady().then(() => {
  const dir = app.getPath("userData");
  const file = path.join(dir, "config.json");
  let timer;

  const read = () => {
    try {
      const themes = JSON.parse(fs.readFileSync(file, "utf8"))?.setting_defaults?.custom_themes;
      return Array.isArray(themes) ? themes : null;
    } catch {
      return null; // partially written or missing, wait for the next event
    }
  };

  // NOTE: [AGENT]: webContents.executeJavaScript waits until the page has
  // stopped loading, by then the loading screen is drawn with the old colors.
  // The frame runs it right away
  const run = (fn, ...args) => {
    global.mainWindow?.webContents.mainFrame
      .executeJavaScript(`(${fn})(${args.map((arg) => JSON.stringify(arg)).join(", ")})`)
      .catch((e) => console.warn(`custom themes ${fn.name} failed`, e));
  };

  const reload = () => {
    const themes = read();
    if (themes) {
      run(apply, themes);
    }
  };

  app.on("browser-window-created", (_, win) => {
    // NOTE: [AGENT]: the window background shows until the first frame of
    // the page is drawn, so give it the color of the current theme
    const color = read()?.[0]?.compound?.[CANVAS];
    if (typeof color === "string") {
      win.setBackgroundColor(color);
    }

    // NOTE: [AGENT]: the page starts loading, element has drawn nothing yet
    win.webContents.on("did-navigate", () => {
      const themes = read();
      if (win !== global.mainWindow || !themes) {
        return;
      }

      run(prepaint, themes, CANVAS);
      run(apply, themes);
    });
  });

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
