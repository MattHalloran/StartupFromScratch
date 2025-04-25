import { app, BrowserWindow } from 'electron';
import path from 'node:path';
import { fork, ChildProcess } from 'node:child_process';
import process from 'node:process';

let serverProcess: ChildProcess | null = null;

// Function to create the main application window
function createWindow() {
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      // Important: Ensure contextIsolation and nodeIntegration settings
      // are appropriate for your security needs. Default values are generally recommended.
      // contextIsolation: true, // default
      // nodeIntegration: false, // default
    },
  });

  // Construct the path to the UI's index.html
  // This assumes the UI is built into 'packages/ui/dist' relative to the project root,
  // and Electron runs from a 'dist/electron' directory after building.
  // Adjust if your build output structure differs.
  const uiPath = path.join(__dirname, '../../packages/ui/dist/index.html');
  console.log(`[Electron Main] Loading UI from: ${uiPath}`);
  mainWindow.loadFile(uiPath)
    .then(() => {
      console.log('[Electron Main] UI loaded successfully.');
    })
    .catch(err => {
      console.error('[Electron Main] Failed to load UI:', err);
      // Optionally load a fallback error page
      // mainWindow.loadURL('data:text/html;charset=utf-8,<h1>Error loading UI</h1>');
    });


  // Open the DevTools (optional - useful for debugging)
  // mainWindow.webContents.openDevTools();

  mainWindow.on('closed', () => {
    console.log('[Electron Main] Main window closed.');
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    // We might want to kill the server process here if it's tied to this single window.
    // However, the 'quit' event handler is probably more robust for server cleanup.
  });
}

// Function to start the backend server
function startServer() {
  // Path to the compiled server entry point
  // Assumes server builds to 'packages/server/dist/main.js' relative to project root
  const serverPath = path.resolve(__dirname, '../../packages/server/dist/main.js');
  console.log(`[Electron Main] Starting server from: ${serverPath}`);

  serverProcess = fork(serverPath, [], {
    // Pass necessary environment variables, inherit stdio, etc.
    stdio: 'inherit', // Show server logs in Electron's console
  });

  serverProcess.on('error', (err) => {
    console.error('[Electron Main] Failed to start server process:', err);
    // Handle error appropriately (e.g., show error message in UI, exit app)
    app.quit();
  });

  serverProcess.on('exit', (code, signal) => {
    console.log(`[Electron Main] Server process exited with code: ${code}, signal: ${signal}`);
    serverProcess = null;
    // Optionally attempt to restart or handle unexpected exit
  });

  console.log('[Electron Main] Server process requested to start.');
}

// Electron App Lifecycle Events

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.whenReady().then(() => {
  console.log('[Electron Main] App is ready.');
  startServer(); // Start the backend server
  createWindow(); // Create the main application window

  app.on('activate', () => {
    // On macOS it's common to re-create a window in the app when the
    // dock icon is clicked and there are no other windows open.
    if (BrowserWindow.getAllWindows().length === 0) {
      console.log('[Electron Main] Activate event: No windows open, creating one.');
      // Consider if the server needs restarting or if it's still running
      if (!serverProcess) {
        startServer();
      }
      createWindow();
    } else {
       console.log('[Electron Main] Activate event: Window(s) already open.');
    }
  });
});

// Quit when all windows are closed, except on macOS.
app.on('window-all-closed', () => {
  console.log('[Electron Main] All windows closed.');
  // On macOS it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (process.platform !== 'darwin') {
    console.log('[Electron Main] Quitting app (non-macOS).');
    app.quit();
  } else {
    console.log('[Electron Main] Keeping app active (macOS).');
  }
});

// Ensure the server process is killed when the app quits.
app.on('quit', () => {
  console.log('[Electron Main] App quit event triggered.');
  if (serverProcess) {
    console.log('[Electron Main] Killing server process...');
    serverProcess.kill();
    serverProcess = null;
  }
});

// You can include the rest of your app's specific main process
// code here. You can also put them in separate files and import them. 