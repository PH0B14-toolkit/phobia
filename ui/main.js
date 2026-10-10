const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const os = require('os');
const pty = require('node-pty');
let win, shell;

function createWindow() {
  win = new BrowserWindow({
    width: 1400, height: 900, minWidth: 900, minHeight: 600,
    frame: false, backgroundColor: '#0a0e1a',
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false }
  });
  win.loadFile(path.join(__dirname, 'index.html'));
  shell = pty.spawn('/bin/bash', [], {
    name: 'xterm-color', cols: 200, rows: 50, cwd: '/home/kali/phobia',
    env: { ...process.env, TERM: 'xterm-256color', LC_ALL: 'en_US.UTF-8', LANG: 'en_US.UTF-8', PHOBIA_UI_LAUNCHED: '1' }
  });
  shell.onData(d => { if (win && win.webContents) win.webContents.send('terminal:data', d); });
  shell.onExit(() => { if (win && win.webContents) win.webContents.send('terminal:exit'); });
  setTimeout(() => {
    if (!shell) return;
    try { shell.write('cd /home/kali/phobia\r'); } catch (e) {}
    setTimeout(() => { try { shell.write('./phobia.sh\r'); } catch (e) {} }, 400);
  }, 1200);
}

ipcMain.on('terminal:input', (e, d) => { if (shell) shell.write(d); });
ipcMain.on('terminal:resize', (e, { cols, rows }) => { if (shell) { try { shell.resize(cols, rows); } catch (e) {} } });
ipcMain.on('terminal:run', (e, c) => { if (shell) shell.write(c + '\r'); });
ipcMain.handle('sys:info', async () => {
  const si = require('systeminformation');
  const [c, m, n, o] = await Promise.all([si.currentLoad(), si.mem(), si.networkStats(), si.osInfo()]);
  return { cpu: c.currentLoad.toFixed(1), mem: ((m.used / m.total) * 100).toFixed(1),
    rx: n[0] ? (n[0].rx_sec / 1024).toFixed(1) : '0.0', tx: n[0] ? (n[0].tx_sec / 1024).toFixed(1) : '0.0',
    os: o.distro + ' ' + o.release, host: os.hostname(), uptime: (os.uptime() / 3600).toFixed(1) };
});
ipcMain.on('window:minimize', () => win && win.minimize());
ipcMain.on('window:maximize', () => { if (!win) return; win.isMaximized() ? win.unmaximize() : win.maximize(); });
ipcMain.on('window:close', () => win && win.close());
app.whenReady().then(createWindow);
app.on('window-all-closed', () => { if (shell) { try { shell.kill(); } catch (e) {} } app.quit(); });
app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
