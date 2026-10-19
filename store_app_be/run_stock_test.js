const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');

const ARTIFACT_DIR = 'C:\\Users\\HP\\.gemini\\antigravity\\brain\\b14da891-817c-4330-b53c-1889dc3cf52e';
const SCREENSHOT_DIR = path.join(ARTIFACT_DIR, 'stock_verification_screenshots');

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

let stepCount = 0;
const consoleLogs = [];
const runtimeExceptions = [];

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
      stepCount++;
      const filename = `${String(stepCount).padStart(2, '0')}_${name}.png`;
      const filepath = path.join(SCREENSHOT_DIR, filename);
      const shot = await send('Page.captureScreenshot', { format: 'png' });
      if (shot && shot.data) {
        fs.writeFileSync(filepath, Buffer.from(shot.data, 'base64'));
        console.log(`[SCREENSHOT SUCCESS] ${filename}`);
      }
      return filepath;
    }

    async function click(x, y, label = '') {
      console.log(`[CLICK] ${label} at (${x}, ${y})`);
      await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
      await new Promise(r => setTimeout(r, 100));
      await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
      await new Promise(r => setTimeout(r, 800));
    }

    ws.on('open', async () => {
      console.log('Connected to CDP');
      await send('Page.enable');
      await send('Runtime.enable');

      ws.on('message', (msg) => {
        const parsed = JSON.parse(msg);
        if (parsed.method === 'Runtime.exceptionThrown') {
          runtimeExceptions.push(parsed.params.exceptionDetails);
          console.error('[RUNTIME EXCEPTION]', JSON.stringify(parsed.params.exceptionDetails));
        }
      });

      // Step 1: Capture initial active page
      console.log('=== STEP 1: Current Page State ===');
      await screenshot('01_current_page');

      // Check window size & page text
      const info = await send('Runtime.evaluate', {
        expression: `
          (() => {
            return {
              url: window.location.href,
              innerWidth: window.innerWidth,
              innerHeight: window.innerHeight,
              text: (document.body ? document.body.innerText : '').substring(0, 500)
            };
          })()
        `,
        returnByValue: true
      });
      console.log('Page Info:', JSON.stringify(info ? info.value : null, null, 2));

      const pageText = info && info.value ? info.value.text : '';

      // If we are on login screen, perform login
      if (pageText.includes('Sign In') || pageText.includes('Welcome back') && pageText.includes('Email')) {
        console.log('=== STEP 2: Logging in ===');
        // Click Email (centered approx 500, 555 in viewport)
        await click(500, 555, 'Email Input');
        await send('Input.insertText', { text: 'test@local.dev' });
        await new Promise(r => setTimeout(r, 300));

        // Click Password (centered approx 500, 637)
        await click(500, 637, 'Password Input');
        await send('Input.insertText', { text: 'pass123' });
        await new Promise(r => setTimeout(r, 300));

        await screenshot('02_credentials_entered');

        // Click Login Button (approx 500, 720)
        await click(500, 720, 'Login Button');
        await new Promise(r => setTimeout(r, 3000));

        await screenshot('03_dashboard_after_login');
      }

      // We are on Dashboard! Let's click "Stock" tile card.
      // Based on 1920x1080 resolution in screenshot:
      // Store card is around x=796, y=300
      // Scrap card is around x=960, y=300
      // Stock card is around x=1100, y=300
      // Or in standard viewport:
      // Stock tile is the 3rd tile. Let's try clicking at x=1100, y=300 and x=570, y=300 / x=570, y=410.
      console.log('=== STEP 3: Clicking Stock Tile ===');
      
      // Let's inspect DOM elements for "Stock" text or semantics node
      const stockFind = await send('Runtime.evaluate', {
        expression: `
          (() => {
            const nodes = Array.from(document.querySelectorAll('*'));
            const matches = [];
            for (const n of nodes) {
              if ((n.innerText || '').trim() === 'Stock') {
                const r = n.getBoundingClientRect();
                if (r.width > 0 && r.height > 0) {
                  matches.push({ left: r.left, top: r.top, width: r.width, height: r.height, tag: n.tagName });
                }
              }
            }
            return matches;
          })()
        `,
        returnByValue: true
      });
      console.log('Stock Element Finder:', JSON.stringify(stockFind ? stockFind.value : null));

      if (stockFind && stockFind.value && stockFind.value.length > 0) {
        const targetEl = stockFind.value[0];
        await click(Math.round(targetEl.left + targetEl.width / 2), Math.round(targetEl.top - 40), 'Stock Tile Icon');
      } else {
        // Fallback: try clicking at multiple candidate coordinates for Stock tile
        console.log('Using candidate coordinate clicks for Stock tile');
        const candidateCoords = [
          { x: 1100, y: 300 },
          { x: 570, y: 410 },
          { x: 570, y: 300 },
          { x: 1100, y: 410 }
        ];
        for (const c of candidateCoords) {
          await click(c.x, c.y, `Candidate (${c.x}, ${c.y})`);
          await new Promise(r => setTimeout(r, 1000));
          const checkText = await send('Runtime.evaluate', {
            expression: 'document.body ? document.body.innerText : ""',
            returnByValue: true
          });
          const textVal = checkText ? checkText.value : '';
          if (textVal.includes('Machine') || textVal.includes('Bags') || textVal.includes('Sorting')) {
            console.log('Navigated to Stock module!');
            break;
          }
        }
      }

      await new Promise(r => setTimeout(r, 2000));
      await screenshot('04_stock_module_view');

      const stockCheck = await send('Runtime.evaluate', {
        expression: `
          (() => {
            const text = document.body ? document.body.innerText : '';
            return {
              text: text.substring(0, 1000),
              hasMachine: text.includes('Machine'),
              hasBags: text.includes('Bags'),
              hasItems: text.includes('Items'),
              hasSorting: text.includes('Sorting')
            };
          })()
        `,
        returnByValue: true
      });
      console.log('Stock View State:', JSON.stringify(stockCheck ? stockCheck.value : null, null, 2));

      // STEP 4: Machine Tab
      console.log('=== STEP 4: Machine Tab Inspection ===');
      await screenshot('05_machine_tab_details');

      // STEP 5: Bags Tab
      console.log('=== STEP 5: Bags Tab Inspection ===');
      // Look for "Bags" tab element
      const bagsTabFind = await send('Runtime.evaluate', {
        expression: `
          (() => {
            const nodes = Array.from(document.querySelectorAll('*'));
            for (const n of nodes) {
              if ((n.innerText || '').trim() === 'Bags') {
                const r = n.getBoundingClientRect();
                if (r.width > 0 && r.height > 0) {
                  return { left: r.left, top: r.top, width: r.width, height: r.height };
                }
              }
            }
            return null;
          })()
        `,
        returnByValue: true
      });
      console.log('Bags Tab Finder:', JSON.stringify(bagsTabFind ? bagsTabFind.value : null));
      if (bagsTabFind && bagsTabFind.value) {
        const b = bagsTabFind.value;
        await click(Math.round(b.left + b.width / 2), Math.round(b.top + b.height / 2), 'Bags Tab');
      } else {
        await click(250, 100, 'Fallback Bags Tab');
      }
      await new Promise(r => setTimeout(r, 2000));
      await screenshot('06_bags_tab_view');

      // STEP 6: Items Tab
      console.log('=== STEP 6: Items Tab Inspection ===');
      const itemsTabFind = await send('Runtime.evaluate', {
        expression: `
          (() => {
            const nodes = Array.from(document.querySelectorAll('*'));
            for (const n of nodes) {
              if ((n.innerText || '').trim() === 'Items') {
                const r = n.getBoundingClientRect();
                if (r.width > 0 && r.height > 0) {
                  return { left: r.left, top: r.top, width: r.width, height: r.height };
                }
              }
            }
            return null;
          })()
        `,
        returnByValue: true
      });
      console.log('Items Tab Finder:', JSON.stringify(itemsTabFind ? itemsTabFind.value : null));
      if (itemsTabFind && itemsTabFind.value) {
        const it = itemsTabFind.value;
        await click(Math.round(it.left + it.width / 2), Math.round(it.top + it.height / 2), 'Items Tab');
      } else {
        await click(400, 100, 'Fallback Items Tab');
      }
      await new Promise(r => setTimeout(r, 2000));
      await screenshot('07_items_tab_view');

      // STEP 7: Sorting Tab
      console.log('=== STEP 7: Sorting Tab Inspection ===');
      const sortingTabFind = await send('Runtime.evaluate', {
        expression: `
          (() => {
            const nodes = Array.from(document.querySelectorAll('*'));
            for (const n of nodes) {
              if ((n.innerText || '').trim() === 'Sorting') {
                const r = n.getBoundingClientRect();
                if (r.width > 0 && r.height > 0) {
                  return { left: r.left, top: r.top, width: r.width, height: r.height };
                }
              }
            }
            return null;
          })()
        `,
        returnByValue: true
      });
      console.log('Sorting Tab Finder:', JSON.stringify(sortingTabFind ? sortingTabFind.value : null));
      if (sortingTabFind && sortingTabFind.value) {
        const st = sortingTabFind.value;
        await click(Math.round(st.left + st.width / 2), Math.round(st.top + st.height / 2), 'Sorting Tab');
      } else {
        await click(550, 100, 'Fallback Sorting Tab');
      }
      await new Promise(r => setTimeout(r, 2000));
      await screenshot('08_sorting_tab_view');

      console.log('=== MANUAL VERIFICATION EXECUTION COMPLETE ===');
      console.log(`Total Runtime Exceptions: ${runtimeExceptions.length}`);

      ws.close();
      process.exit(0);
    });
  });
});
