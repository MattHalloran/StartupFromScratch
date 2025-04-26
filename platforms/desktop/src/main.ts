import { app, BrowserWindow } from 'electron';
import path from 'node:path';
import { fork, ChildProcess } from 'node:child_process';
import process from 'node:process';

let serverProcess: ChildProcess | null = null;
let mainWindow: BrowserWindow | null = null; // Keep a reference to the main window

const SERVER_PORT = 3000; // Define server port
const SERVER_URL = `http://localhost:${SERVER_PORT}`;
const LOAD_URL_DELAY_MS = 3000; // Wait 3 seconds for the server to start

// --- Single Instance Lock ---
const gotTheLock = app.requestSingleInstanceLock();

if (!gotTheLock) {
  console.log('[Electron Main] Another instance is already running. Quitting.');
  app.quit();
} else {
  app.on('second-instance', (event, commandLine, workingDirectory) => {
    // Someone tried to run a second instance, we should focus our window.
    console.log('[Electron Main] Second instance detected. Focusing existing window.');
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });

  // Create mainWindow, load the rest of the app, etc...
  // The rest of the app lifecycle setup goes inside this 'else' block.

  // Function to create the main application window
  function createWindow() {
    console.log('[Electron Main] Creating main window...');
    // Create the browser window.
    mainWindow = new BrowserWindow({ // Assign to the global mainWindow
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

    // Give the server some time to start before trying to load the URL
    console.log(`[Electron Main] Waiting ${LOAD_URL_DELAY_MS}ms for server to start before loading URL...`);
    setTimeout(() => {
      if (!mainWindow) {
          console.log('[Electron Main] Window was closed before URL could be loaded.');
          return;
      }
      console.log(`[Electron Main] Attempting to load URL: ${SERVER_URL}`);
      mainWindow.loadURL(SERVER_URL)
        .then(() => {
          console.log('[Electron Main] URL loaded successfully.');
        })
        .catch(err => {
          console.error(`[Electron Main] Failed to load URL ${SERVER_URL}:`, err);
          console.error('[Electron Main] Ensure the server is running and accessible on the specified port.');
          // Optionally load a fallback error page
          if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.loadURL(`data:text/html;charset=utf-8,<h1>Error loading application</h1><p>Could not connect to the backend server at ${SERVER_URL}. Please ensure the server is running. Error: ${err.message}</p>`);
          }
        });
    }, LOAD_URL_DELAY_MS);


    // Open the DevTools (optional - useful for debugging)
    // mainWindow.webContents.openDevTools();

    mainWindow.on('closed', () => {
      console.log('[Electron Main] Main window closed.');
      // Dereference the window object
      mainWindow = null;
      // Note: We DO NOT kill the server process here automatically.
      // It keeps running until the app quits.
    });
  }

  // Function to start the backend server
  function startServer() {
    if (serverProcess) {
      console.log('[Electron Main] Server process already requested to start.');
      return; // Avoid starting multiple server processes
    }
    // Path to the compiled server entry point
    // Assumes server builds to 'packages/server/dist/main.js' relative to project root
    const serverPath = path.resolve(__dirname, '../../packages/server/dist/main.js');
    console.log(`[Electron Main] Attempting to start server from: ${serverPath}`);

    try {
      serverProcess = fork(serverPath, [], {
        // Pass necessary environment variables, inherit stdio, etc.
        stdio: 'inherit', // Show server logs in Electron's console
        // detached: true // Consider if detaching is needed, usually not for this pattern
      });

      serverProcess.on('error', (err) => {
        console.error('[Electron Main] Server process error:', err);
        // Handle error appropriately (e.g., show error message in UI, exit app)
        // Consider showing an error in the mainWindow if it exists
        if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.loadURL(`data:text/html;charset=utf-8,<h1>Server Error</h1><p>The backend server process encountered an error: ${err.message}. The application might not function correctly.</p>`);
        }
        // Optionally quit if the server is critical and cannot start
        // app.quit();
        serverProcess = null; // Clear the reference on error
      });

      serverProcess.on('exit', (code, signal) => {
        console.log(`[Electron Main] Server process exited with code: ${code}, signal: ${signal}`);
        serverProcess = null; // Clear the reference on exit
        // Optionally attempt to restart or handle unexpected exit,
        // but be careful not to create loops. Maybe show an error in the UI.
        if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.loadURL(`data:text/html;charset=utf-8,<h1>Server Stopped</h1><p>The backend server process stopped unexpectedly (code: ${code}, signal: ${signal}). The application might not function correctly.</p>`);
        }
        // Decide if the app should quit if the server dies
        // if (code !== 0 && signal !== 'SIGTERM') { // Example: Quit if not a clean exit
        //   app.quit();
        // }
      });

      console.log('[Electron Main] Server process requested to start successfully.');

    } catch (error) {
      console.error('[Electron Main] Critical error forking server process:', error);
      // Show error and quit if server cannot be forked at all
       if (mainWindow && !mainWindow.isDestroyed()) {
          mainWindow.loadURL(`data:text/html;charset=utf-8,<h1>Fatal Error</h1><p>Could not start the backend server process. Error: ${(error as Error).message}</p>`);
      } else {
          // If window isn't even created yet, just quit.
          app.quit();
      }
       serverProcess = null;
    }
  }

  // Electron App Lifecycle Events

  // This method will be called when Electron has finished
  // initialization and is ready to create browser windows.
  // Some APIs can only be used after this event occurs.
  app.whenReady().then(() => {
    console.log('[Electron Main] App is ready.');
    startServer(); // Start the backend server FIRST
    createWindow(); // Create the main application window AFTER requesting server start

    app.on('activate', () => {
      console.log('[Electron Main] Activate event triggered.');
      // On macOS it's common to re-create a window in the app when the
      // dock icon is clicked and there are no other windows open.
      if (BrowserWindow.getAllWindows().length === 0) {
         // Check if mainWindow is null or destroyed before creating
        if (!mainWindow || mainWindow.isDestroyed()) {
            console.log('[Electron Main] Activate event: No windows open, creating one.');
            // DO NOT restart the server here. Assume it's running or handle its failure elsewhere.
            createWindow();
        } else {
             console.log('[Electron Main] Activate event: Main window exists but might be hidden.');
             mainWindow.show(); // Or restore/focus as needed
        }
      } else {
         console.log('[Electron Main] Activate event: Window(s) already open. Focusing main window.');
         // Focus the existing window if it exists
         if (mainWindow && !mainWindow.isDestroyed()) {
             if (mainWindow.isMinimized()) mainWindow.restore();
             mainWindow.focus();
         } else if(BrowserWindow.getAllWindows().length > 0) {
             // Fallback if mainWindow reference is lost somehow
             BrowserWindow.getAllWindows()[0].focus();
         }
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
      app.quit(); // Triggers the 'quit' event
    } else {
      console.log('[Electron Main] Keeping app active (macOS).');
      // On macOS, explicitly killing the server might be desired here,
      // or rely on the 'quit' event if the user quits via Cmd+Q.
      // If we kill it here, the 'activate' event won't have a server.
      // Decision: Rely on the 'quit' event for cleanup.
    }
  });

  // Ensure the server process is killed when the app quits.
  app.on('quit', () => {
    console.log('[Electron Main] App quit event triggered.');
    if (serverProcess && !serverProcess.killed) {
      console.log('[Electron Main] Attempting to kill server process...');
      const killed = serverProcess.kill(); // Standard kill signal (SIGTERM)
      console.log(`[Electron Main] Server process kill attempt returned: ${killed}`);
      serverProcess = null;
    } else {
        console.log('[Electron Main] Server process already null or killed.');
    }
    console.log('[Electron Main] Exiting application.');
  });

  // You can include the rest of your app's specific main process
  // code here. You can also put them in separate files and import them.
} // End of the 'else' block for single instance lock 