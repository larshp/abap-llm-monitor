import { app, BrowserWindow } from "electron";
import { server, serverReady, serverUrl } from "../server.mjs";

let mainWindow;
let isQuitting = false;

async function createWindow() {
  await serverReady;

  mainWindow = new BrowserWindow({
    alwaysOnTop: true,
    height: 720,
    minHeight: 720,
    minWidth: 2560,
    title: "LLM Monitor",
    width: 2560,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  mainWindow.setAlwaysOnTop(true, "floating");
  await mainWindow.loadURL(serverUrl);
}

app.whenReady().then(createWindow);

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

app.on("window-all-closed", () => {
  app.quit();
});

app.on("before-quit", (event) => {
  if (isQuitting || !server?.listening) {
    return;
  }

  event.preventDefault();
  server.close(() => {
    isQuitting = true;
    app.quit();
  });
});