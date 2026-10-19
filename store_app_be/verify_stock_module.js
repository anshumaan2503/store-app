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

async function main() {
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
        return new Promise((resolve, reject) => {
          const reqId = id++;
          const handler = (msg) => {
            const res = JSON.parse(msg);
            if (res.id === reqId) {
              ws.removeListener('message', handler);
              if (res.error) {
                console.error(`CDP Error on [${method}]:`, res.error);
                resolve(null); // resolve null instead of rejecting
              } else {
                resolve(res.result);
              }
            }
          };
          ws.on('message', handler);
          ws.send(JSON.stringify({ id: reqId, method, params }));
        });
      }

      async function takeScreenshot(name) {
        stepCount++;
        const filename = `${String(stepCount).padStart(2, '0')}_${name}.png`;
        const filepath = path.join(SCREENSHOT_DIR, filename);
        const shot = await send('Page.captureScreenshot', { format: 'png' });
        if (shot && shot.data) {
          fs.writeFileSync(filepath, Buffer.from(shot.data, 'base64'));
          console.log(`[SCREENSHOT] Saved: ${filename}`);
        } else {
          console.warn(`[SCREENSHOT WARNING] Failed to capture screenshot for ${name}`);
        }
        return filepath;
      }

      async function clickPoint(x, y, label = '') {
        console.log(`[CLICK] ${label} at (${x}, ${y})`);
        await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
        await new Promise(r => setTimeout(r, 100));
        await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
        await new Promise(r => setTimeout(r, 500));
      }

      async function typeText(text) {
        for (const char of text) {
          await send('Input.dispatchKeyEvent', { type: 'keyDown', text: char, key: char });
          await send('Input.dispatchKeyEvent', { type: 'keyUp', text: char, key: char });
          await new Promise(r => setTimeout(r, 50));
        }
      }

      ws.on('open', async () => {
        console.log('Connected to CDP target');
        await send('Page.enable');
        await send('Runtime.enable');

        ws.on('message', (msg) => {
          const parsed = JSON.parse(msg);
          if (parsed.method === 'Console.messageAdded') {
            consoleLogs.push(parsed.params.message);
          } else if (parsed.method === 'Runtime.exceptionThrown') {
            runtimeExceptions.push(parsed.params.exceptionDetails);
            console.error('[RUNTIME EXCEPTION]', JSON.stringify(parsed.params.exceptionDetails));
          }
        });

        // 1. Navigate to http://localhost:3000
        console.log('--- Step 1: Navigating to app ---');
        await send('Page.navigate', { url: 'http://localhost:3000' });
        await new Promise(r => setTimeout(r, 3000));
        await takeScreenshot('01_initial_load');

        // Check if we are on login screen or dashboard
        const evalRes = await send('Runtime.evaluate', {
          expression: `
            (() => {
              const bodyText = document.body ? document.body.innerText : '';
              const inputs = Array.from(document.querySelectorAll('input'));
              return {
                text: bodyText ? bodyText.substring(0, 300) : '',
                inputCount: inputs.length,
                inputs: inputs.map(i => {
                  const r = i.getBoundingClientRect();
                  return { type: i.type, placeholder: i.placeholder, value: i.value, bounds: { left: r.left, top: r.top, width: r.width, height: r.height } };
                })
              };
            })()
          `,
          returnByValue: true
        });

        console.log('Page Evaluation:', JSON.stringify(evalRes ? evalRes.result.value : null, null, 2));

        const pageData = evalRes ? evalRes.result.value : { text: '', inputCount: 0, inputs: [] };

        // If on login page (input fields present or "Log In" text visible)
        if (pageData.text.includes('Sign In') || pageData.text.includes('Welcome back') || pageData.inputCount > 0) {
          console.log('--- Step 2: Logging in ---');
          const inputs = pageData.inputs;
          if (inputs.length >= 2) {
            // Click Email field
            const emailField = inputs[0];
            const emailX = Math.round(emailField.bounds.left + emailField.bounds.width / 2);
            const emailY = Math.round(emailField.bounds.top + emailField.bounds.height / 2);
            await clickPoint(emailX, emailY, 'Email Input Field');
            
            // Select all & type email
            await send('Input.dispatchKeyEvent', { type: 'keyDown', modifiers: 2, key: 'a', code: 'KeyA' }); // Ctrl+A
            await typeText('test@local.dev');

            // Click Password field
            const passField = inputs[1];
            const passX = Math.round(passField.bounds.left + passField.bounds.width / 2);
            const passY = Math.round(passField.bounds.top + passField.bounds.height / 2);
            await clickPoint(passX, passY, 'Password Input Field');

            // Select all & type password
            await send('Input.dispatchKeyEvent', { type: 'keyDown', modifiers: 2, key: 'a', code: 'KeyA' }); // Ctrl+A
            await typeText('pass123');

            await takeScreenshot('02_credentials_filled');

            // Click Login Button
            const btnEval = await send('Runtime.evaluate', {
              expression: `
                (() => {
                  const elements = Array.from(document.querySelectorAll('*'));
                  for (const el of elements) {
                    const text = (el.innerText || '').trim();
                    if (text === 'Log In' || text === 'Sign In' || text === 'LOGIN') {
                      const rect = el.getBoundingClientRect();
                      if (rect.width > 0 && rect.height > 0) {
                        return { left: rect.left, top: rect.top, width: rect.width, height: rect.height, text };
                      }
                    }
                  }
                  return null;
                })()
              `,
              returnByValue: true
            });

            console.log('Login Button Search:', btnEval ? btnEval.result.value : null);

            if (btnEval && btnEval.result.value) {
              const btn = btnEval.result.value;
              await clickPoint(Math.round(btn.left + btn.width / 2), Math.round(btn.top + btn.height / 2), 'Login Button');
            } else {
              // Fallback click on login button area (approx 500, 720)
              await clickPoint(500, 720, 'Fallback Login Button');
            }

            await new Promise(r => setTimeout(r, 4000));
            await takeScreenshot('03_after_login');
          }
        }

        // Verify Dashboard & Click Stock Tile
        console.log('--- Step 3: Verifying Dashboard & Clicking Stock Tile ---');
        const dashEval = await send('Runtime.evaluate', {
          expression: `
            (() => {
              const text = document.body ? document.body.innerText : '';
              return {
                isDashboard: text.includes('Dashboard') || text.includes('Stock'),
                bodyText: text.substring(0, 500)
              };
            })()
          `,
          returnByValue: true
        });

        console.log('Dashboard Check:', dashEval ? dashEval.result.value : null);

        // Click Stock tile at (570, 410)
        await clickPoint(570, 410, 'Stock Tile');
        await new Promise(r => setTimeout(r, 3000));
        await takeScreenshot('04_stock_module_opened');

        // Check current page content and tabs
        const stockPageEval = await send('Runtime.evaluate', {
          expression: `
            (() => {
              const text = document.body ? document.body.innerText : '';
              return {
                bodyText: text.substring(0, 1000),
                hasMachine: text.includes('Machine'),
                hasBags: text.includes('Bags'),
                hasItems: text.includes('Items'),
                hasSorting: text.includes('Sorting')
              };
            })()
          `,
          returnByValue: true
        });

        console.log('Stock Page Inspection:', stockPageEval ? stockPageEval.result.value : null);

        // Helper to find tab coordinates
        async function getTabCoords(tabName) {
          const tabEval = await send('Runtime.evaluate', {
            expression: `
              (() => {
                const all = Array.from(document.querySelectorAll('*'));
                for (const el of all) {
                  if ((el.innerText || '').trim() === '${tabName}') {
                    const rect = el.getBoundingClientRect();
                    if (rect.width > 0 && rect.height > 0) {
                      return { left: rect.left, top: rect.top, width: rect.width, height: rect.height, text: el.innerText };
                    }
                  }
                }
                return null;
              })()
            `,
            returnByValue: true
          });
          return tabEval && tabEval.result ? tabEval.result.value : null;
        }

        // --- Step 4: MACHINE TAB Verification ---
        console.log('--- Step 4: Verifying Machine Tab ---');
        await takeScreenshot('05_machine_tab');
        const machineContent = await send('Runtime.evaluate', {
          expression: 'document.body ? document.body.innerText : ""',
          returnByValue: true
        });
        console.log('Machine Tab Content Snippet:', machineContent && machineContent.result ? (machineContent.result.value || '').substring(0, 400) : '');

        // --- Step 5: BAGS TAB Verification ---
        console.log('--- Step 5: Verifying Bags Tab ---');
        const bagsTab = await getTabCoords('Bags');
        console.log('Bags Tab Coords:', bagsTab);
        if (bagsTab) {
          await clickPoint(Math.round(bagsTab.left + bagsTab.width / 2), Math.round(bagsTab.top + bagsTab.height / 2), 'Bags Tab');
        } else {
          await clickPoint(250, 110, 'Fallback Bags Tab');
        }
        await new Promise(r => setTimeout(r, 2000));
        await takeScreenshot('06_bags_tab');

        const bagsContent = await send('Runtime.evaluate', {
          expression: 'document.body ? document.body.innerText : ""',
          returnByValue: true
        });
        console.log('Bags Tab Content Snippet:', bagsContent && bagsContent.result ? (bagsContent.result.value || '').substring(0, 400) : '');

        // --- Step 6: ITEMS TAB Verification ---
        console.log('--- Step 6: Verifying Items Tab ---');
        const itemsTab = await getTabCoords('Items');
        console.log('Items Tab Coords:', itemsTab);
        if (itemsTab) {
          await clickPoint(Math.round(itemsTab.left + itemsTab.width / 2), Math.round(itemsTab.top + itemsTab.height / 2), 'Items Tab');
        } else {
          await clickPoint(400, 110, 'Fallback Items Tab');
        }
        await new Promise(r => setTimeout(r, 2000));
        await takeScreenshot('07_items_tab');

        const itemsContent = await send('Runtime.evaluate', {
          expression: 'document.body ? document.body.innerText : ""',
          returnByValue: true
        });
        console.log('Items Tab Content Snippet:', itemsContent && itemsContent.result ? (itemsContent.result.value || '').substring(0, 400) : '');

        // --- Step 7: SORTING TAB Verification ---
        console.log('--- Step 7: Verifying Sorting Tab ---');
        const sortingTab = await getTabCoords('Sorting');
        console.log('Sorting Tab Coords:', sortingTab);
        if (sortingTab) {
          await clickPoint(Math.round(sortingTab.left + sortingTab.width / 2), Math.round(sortingTab.top + sortingTab.height / 2), 'Sorting Tab');
        } else {
          await clickPoint(550, 110, 'Fallback Sorting Tab');
        }
        await new Promise(r => setTimeout(r, 2000));
        await takeScreenshot('08_sorting_tab');

        const sortingContent = await send('Runtime.evaluate', {
          expression: 'document.body ? document.body.innerText : ""',
          returnByValue: true
        });
        console.log('Sorting Tab Content Snippet:', sortingContent && sortingContent.result ? (sortingContent.result.value || '').substring(0, 400) : '');

        // --- Step 8: REFRESH & TAB STABILITY TEST ---
        console.log('--- Step 8: Tab Stability & Refresh Test ---');
        console.log('Reloading page via Page.reload...');
        await send('Page.reload');
        await new Promise(r => setTimeout(r, 4000));
        await takeScreenshot('09_after_page_reload');

        const postReloadContent = await send('Runtime.evaluate', {
          expression: 'document.body ? document.body.innerText : ""',
          returnByValue: true
        });
        console.log('Post Reload Content Snippet:', postReloadContent && postReloadContent.result ? (postReloadContent.result.value || '').substring(0, 400) : '');

        console.log('=== VERIFICATION RUN COMPLETE ===');
        console.log('Console Exception Count:', runtimeExceptions.length);

        ws.close();
        process.exit(0);
      });
    });
  });
}

main().catch(err => {
  console.error('Fatal Script Error:', err);
  process.exit(1);
});
