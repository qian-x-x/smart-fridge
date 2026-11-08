// SkyWalking UI 截图：首页服务视图 + 链路列表。
// SkyWalking 10.x UI 是 React SPA，没有 canvas，等网络空闲后直接截图即可。

import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { setTimeout as sleep } from 'node:timers/promises';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const PORT = 9336;
const APP = process.env.SW_UI || 'http://127.0.0.1:8088';
const OUT = process.env.OUT_DIR || 'docs/reviews/evidence/2026-11-08-n4';
const PROFILE = 'C:\\Users\\Lenovo\\AppData\\Local\\Temp\\sf-e2e\\edge-skywalking';

async function waitForEndpoint(url, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return response.json();
    } catch {
      // 还没起来
    }
    await sleep(400);
  }
  throw new Error('CDP endpoint not ready: ' + url);
}

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id && this.pending.has(message.id)) {
        const { resolve, reject } = this.pending.get(message.id);
        this.pending.delete(message.id);
        message.error ? reject(new Error(JSON.stringify(message.error))) : resolve(message.result);
      }
    });
  }

  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      setTimeout(() => reject(new Error(method + ' timeout')), 30000);
    });
  }

  async evaluate(expression) {
    const result = await this.send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
    return result.result?.value;
  }

  async shot(name) {
    const result = await this.send('Page.captureScreenshot', { format: 'png' });
    mkdirSync(OUT, { recursive: true });
    writeFileSync(`${OUT}/${name}.png`, Buffer.from(result.data, 'base64'));
    console.log('shot', name);
  }
}

const child = spawn(
  EDGE,
  [
    '--headless=new',
    `--remote-debugging-port=${PORT}`,
    '--window-size=1440,900',
    `--user-data-dir=${PROFILE}`,
    '--no-first-run',
    '--disable-gpu',
    APP,
  ],
  { stdio: 'ignore', detached: false },
);

try {
  await waitForEndpoint(`http://127.0.0.1:${PORT}/json/version`);
  const targets = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
  const page = targets.find((target) => target.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve) => ws.addEventListener('open', resolve));

  const cdp = new Cdp(ws);
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width: 1440,
    height: 900,
    deviceScaleFactor: 1,
    mobile: false,
  });

  await sleep(6000);
  await cdp.shot('01-skywalking-dashboard');

  // 直接改 URL 会 404（SkyWalking UI 的 SPA 路由不接受外部 pushState）。
  // 页签是 Ant Design 的 Tab，DOM 里拿不到稳定文本，按 1440x900 视口下的固定坐标点击。
  const clickAt = async (x, y) => {
    for (const type of ['mousePressed', 'mouseReleased']) {
      await cdp.send('Input.dispatchMouseEvent', {
        type,
        x,
        y,
        button: 'left',
        clickCount: 1,
        buttons: type === 'mousePressed' ? 1 : 0,
      });
      await sleep(90);
    }
  };

  // Topology / Trace 页签（视口 1440x900）
  await clickAt(173, 155);
  await sleep(8000);
  await cdp.shot('02-skywalking-topology');

  await clickAt(258, 155);
  await sleep(6000);
  await cdp.shot('03-skywalking-service-trace');

  // 点开列表里那条跨服务的 Feign 调用，右侧会显示多段链路
  await clickAt(193, 697);
  await sleep(5000);
  await cdp.shot('04-skywalking-trace-detail');

  console.log('done');
} finally {
  child.kill();
}
