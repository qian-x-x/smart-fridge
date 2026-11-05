// Desktop-width UI acceptance for the S3 timeline and cooking sheets.
// Drives the real Flutter Web build over CDP with native mouse events, because
// Flutter renders to canvas and the semantics layer does not forward clicks.
// Coordinates are CSS pixels in a 1080x600 viewport (1440x900 window).

import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { setTimeout as sleep } from 'node:timers/promises';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const PORT = 9333;
const APP = process.env.APP_URL || 'http://127.0.0.1:3000';
const OUT = process.env.OUT_DIR || 'docs/reviews/evidence/2026-11-06-s3';
const USER = process.env.E2E_USER || '';
const PASS = process.env.E2E_PASS || '';
const USER_DATA = 'C:\\Users\\Lenovo\\AppData\\Local\\Temp\\sf-e2e\\edge-profile';
const PLAN = JSON.parse(process.env.UI_PLAN || '{}');

const steps = [];
const record = (name, pass, detail) => {
  steps.push({ name, pass, detail });
  console.log(`${pass ? 'PASS' : 'FAIL'}  ${name} :: ${detail ?? ''}`);
};

async function waitForEndpoint(url, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return await response.json();
    } catch {
      /* retry */
    }
    await sleep(300);
  }
  throw new Error(`timeout waiting for ${url}`);
}

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.events = [];
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.method) this.events.push(message);
      if (message.id && this.pending.has(message.id)) {
        const { resolve, reject } = this.pending.get(message.id);
        this.pending.delete(message.id);
        if (message.error) reject(new Error(JSON.stringify(message.error)));
        else resolve(message.result);
      }
    });
  }

  send(method, params = {}) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const result = await this.send('Runtime.evaluate', {
      expression,
      awaitPromise: true,
      returnByValue: true,
    });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text || 'evaluate failed');
    return result.result?.value;
  }

  async shot(name) {
    const { data } = await this.send('Page.captureScreenshot', { format: 'png' });
    mkdirSync(OUT, { recursive: true });
    writeFileSync(`${OUT}/${name}.png`, Buffer.from(data, 'base64'));
  }

  async click(x, y) {
    for (const type of ['mousePressed', 'mouseReleased']) {
      await this.send('Input.dispatchMouseEvent', {
        type,
        x,
        y,
        button: 'left',
        clickCount: 1,
        buttons: type === 'mousePressed' ? 1 : 0,
      });
      await sleep(80);
    }
    await sleep(250);
  }

  async type(text) {
    await this.send('Input.insertText', { text });
    await sleep(200);
  }

  responses(filter) {
    return this.events
      .filter((event) => event.method === 'Network.responseReceived')
      .filter((event) => String(event.params?.response?.url || '').includes(filter))
      .map((event) => ({ url: event.params.response.url, status: event.params.response.status }));
  }

  requests(filter) {
    return this.events
      .filter((event) => event.method === 'Network.requestWillBeSent')
      .filter((event) => String(event.params?.request?.url || '').includes(filter))
      .map((event) => ({ url: event.params.request.url, method: event.params.request.method }));
  }

  async labels() {
    return this.evaluate(`[...document.querySelectorAll('flt-semantics')]
      .map((node) => (node.getAttribute('aria-label') || '').trim())
      .filter((text) => text.length > 0)
      .slice(0, 200)`);
  }
}

async function main() {
  mkdirSync(USER_DATA, { recursive: true });
  const edge = spawn(
    EDGE,
    [
      '--headless=new',
      `--remote-debugging-port=${PORT}`,
      '--window-size=1440,900',
      '--force-device-scale-factor=1',
      '--use-angle=swiftshader',
      '--enable-unsafe-swiftshader',
      '--no-first-run',
      '--no-default-browser-check',
      `--user-data-dir=${USER_DATA}`,
      'about:blank',
    ],
    { stdio: 'ignore' },
  );

  try {
    await waitForEndpoint(`http://127.0.0.1:${PORT}/json/version`);
    const tab = await fetch(`http://127.0.0.1:${PORT}/json/new?about:blank`, { method: 'PUT' }).then((r) => r.json());
    const ws = new WebSocket(tab.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      ws.addEventListener('open', resolve, { once: true });
      ws.addEventListener('error', reject, { once: true });
    });
    const cdp = new Cdp(ws);
    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Network.enable');

    await cdp.send('Page.navigate', { url: APP });
    await sleep(6000);
    await cdp.evaluate('window.localStorage.clear(); true');
    await cdp.send('Page.reload');
    await sleep(6000);
    await cdp.shot('01-login-desktop');

    const viewport = await cdp.evaluate('({ w: innerWidth, h: innerHeight })');
    record('viewport', viewport.w > 900, JSON.stringify(viewport));

    const login = PLAN.login || { user: [258, 298], pass: [258, 343], submit: [258, 393] };
    await cdp.click(...login.user);
    await cdp.type(USER);
    await cdp.click(...login.pass);
    await cdp.type(PASS);
    await cdp.shot('02-login-filled');

    await cdp.click(...login.submit);
    await sleep(6000);
    await cdp.shot('03-home-desktop');

    const loginRequests = cdp.events.filter(
      (event) =>
        event.method === 'Network.requestWillBeSent' &&
        String(event.params?.request?.url || '').includes('/api/v1/auth/login'),
    );
    record('login-request-sent', loginRequests.length > 0, `count=${loginRequests.length}`);
    const failed = cdp.events.filter((event) => event.method === 'Network.loadingFailed');
    record('no-network-failures', failed.length === 0, `failures=${failed.length}`);

    let labels = [];
    if (PLAN.record) {
      await cdp.click(...PLAN.record);
      await sleep(2500);
      await cdp.shot('04-timeline-desktop');
      const timelineCalls = cdp.responses('/operations');
      record(
        'timeline-loaded-from-api',
        timelineCalls.some((call) => call.status === 200),
        JSON.stringify(timelineCalls.slice(-2)),
      );

      if (PLAN.undo) {
        await cdp.click(...PLAN.undo);
        await sleep(2500);
        await cdp.shot('05-timeline-after-undo');
        const undoCalls = cdp.responses('/undo');
        record(
          'undo-succeeded-in-ui',
          undoCalls.some((call) => call.status === 200),
          JSON.stringify(undoCalls.slice(-2)),
        );
      }
      if (PLAN.restore) {
        await cdp.click(...PLAN.restore);
        await sleep(2500);
        await cdp.shot('06-timeline-after-restore');
        const restoreCalls = cdp.responses('/restore');
        record(
          'restore-succeeded-in-ui',
          restoreCalls.some((call) => call.status === 200),
          JSON.stringify(restoreCalls.slice(-2)),
        );
      }
    }

    const summary = {
      runAt: new Date().toISOString(),
      app: APP,
      plan: PLAN,
      total: steps.length,
      passed: steps.filter((step) => step.pass).length,
      steps,
      labels,
    };
    writeFileSync(`${OUT}/ui-acceptance.json`, JSON.stringify(summary, null, 2));
    console.log(`\n== ${summary.passed}/${summary.total} UI checks passed ==`);
    ws.close();
  } finally {
    edge.kill();
  }
}

main().catch((error) => {
  console.error('FATAL', error);
  process.exitCode = 1;
});
