const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');

const ARTIFACT_DIR = 'C:\\Users\\HP\\.gemini\\antigravity\\brain\\b14da891-817c-4330-b53c-1889dc3cf52e';
const SCREENSHOT_DIR = path.join(ARTIFACT_DIR, 'stock_verification_screenshots');

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

http.get('http://127.0.0.1:9222/json', async (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', async () => {
    const pages = JSON.parse(data);
    const target = pages.find(p => p.type === 'page');
    if (!target) {
      console.error('No page target found');
      process.exit(1);
    }

    const ws = new WebSocket(target.webSocketDebuggerUrl);
    let id = 1;

    function send(method, params = {}) {
      return new Promise((resolve) => {
        const reqId = id++;
        const handler = (msg) => {
          const res = JSON.parse(msg);
          if (res.id === reqId) {
            ws.removeListener('message', handler);
            if (res.error) console.error(`[CDP Error ${method}]`, res.error);
            resolve(res.result || null);
          }
        };
        ws.on('message', handler);
        ws.send(JSON.stringify({ id: reqId, method, params }));
      });
    }

    async function screenshot(name) {
      const filename = `${name}.png`;
      const filepath = path.join(SCREENSHOT_DIR, filename);
      const shot = await send('Page.captureScreenshot', { format: 'png' });
      if (shot && shot.data) {
        fs.writeFileSync(filepath, Buffer.from(shot.data, 'base64'));
        console.log(`[SCREENSHOT SUCCESS] ${filename}`);
      } else {
        console.log(`[SCREENSHOT FAILED] ${filename}`);
      }
      return filepath;
    }

    async function click(x, y, label = '') {
      console.log(`[CLICK] ${label} at (${x}, ${y})`);
      await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
      await new Promise(r => setTimeout(r, 100));
      await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
      await new Promise(r => setTimeout(r, 1000));
    }

    ws.on('open', async () => {
      console.log('Connected to CDP target');
      await send('Page.enable');
      await send('Runtime.enable');

      await send('Emulation.setDeviceMetricsOverride', {
        width: 1920,
        height: 1080,
        deviceScaleFactor: 1,
        mobile: false
      });

      await new Promise(r => setTimeout(r, 500));
      await screenshot('00_viewport_1920x1080');

      console.log('Clicking Stock tile at (1030, 300)...');
      await click(1030, 300, 'Stock Tile');

      await screenshot('01_after_stock_click');

      const textCheck = await send('Runtime.evaluate', {
        expression: 'document.body ? document.body.innerText : ""',
        returnByValue: true
      });
      console.log('Page Text After Click:', (textCheck && textCheck.value) ? textCheck.value.substring(0, 500) : '');

      ws.close();
      process.exit(0);
    });
  });
});
