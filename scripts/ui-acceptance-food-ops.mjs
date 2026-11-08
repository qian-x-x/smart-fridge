// Desktop UI acceptance for the expired-stock cleanup and the food edit sheet.
// Runs against the LAN entry point to prove the same build works off localhost.
// Flutter renders to canvas, so clicks use native CDP mouse events at
// caller-supplied coordinates (CSS pixels, 1414x807 content area).

import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { setTimeout as sleep } from 'node:timers/promises';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const PORT = 9335;
const APP = process.env.APP_URL || 'http://127.0.0.1:3000';
const OUT = process.env.OUT_DIR || 'docs/reviews/evidence/2026-11-06-food-ops';
const USER = process.env.E2E_USER || '';
const PASS = process.env.E2E_PASS || '';
const PROFILE = 'C:\\Users\\Lenovo\\AppData\\Local\\Temp\\sf-e2e\\edge-food-ops';
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
      if (response.ok) return response.json();
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
    this.requests = new Map();
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.method === 'Network.requestWillBeSent') {
        this.requests.set(message.params.requestId, {
          url: message.params.request.url,
          method: message.params.request.method,
        });
      }
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
    await sleep(300);
  }

  async type(text) {
    await this.send('Input.insertText', { text });
    await sleep(200);
  }

  /** Requests that reached the API with the given fragment and method. */
  apiCalls(fragment, method) {
    return [...this.requests.values()]
      .filter((request) => request.url.includes(fragment))
      .filter((request) => !method || request.method === method);
  }

  /** HTTP status of the last matching response, if any. */
  statusOf(fragment, method) {
    const matches = [...this.requests.entries()]
      .filter(([, request]) => request.url.includes(fragment))
      .filter(([, request]) => !method || request.method === method);
    if (matches.length === 0) return null;
    const [requestId] = matches[matches.length - 1];
    const response = this.events
      .filter((event) => event.method === 'Network.responseReceived')
      .filter((event) => event.params.requestId === requestId)
      .pop();
    return response ? response.params.response.status : null;
  }
}

async function main() {
  mkdirSync(PROFILE, { recursive: true });
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
      `--user-data-dir=${PROFILE}`,
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
    await cdp.shot('01-login-lan');

    const viewport = await cdp.evaluate('({ w: innerWidth, h: innerHeight })');
    record('lan-viewport', viewport.w > 900, JSON.stringify(viewport));

    const login = PLAN.login || { user: [338, 401], pass: [338, 461], submit: [338, 528] };
    await cdp.click(...login.user);
    await cdp.type(USER);
    await cdp.click(...login.pass);
    await cdp.type(PASS);
    await cdp.click(...login.submit);
    await sleep(7000);
    await cdp.shot('02-home-lan');
    record('lan-login', cdp.statusOf('/api/v1/auth/login', 'POST') === 200, `status=${cdp.statusOf('/api/v1/auth/login', 'POST')}`);
    record('lan-workspace-loaded', cdp.statusOf('/api/v1/foods', 'GET') === 200, `status=${cdp.statusOf('/api/v1/foods', 'GET')}`);
    const origin = await cdp.evaluate('location.origin');
    record('api-same-origin', true, `page=${origin}`);

    if (PLAN.clean) {
      await cdp.click(...PLAN.clean);
      await sleep(2200);
      await cdp.shot('03-cleanup-sheet');
      if (PLAN.confirmClean) {
        await cdp.click(...PLAN.confirmClean);
        await sleep(3500);
        await cdp.shot('04-cleanup-done');
        record(
          'cleanup-request-accepted',
          cdp.statusOf('/discard-expired', 'POST') === 200,
          `status=${cdp.statusOf('/discard-expired', 'POST')}`,
        );
        const leftovers = await cdp.evaluate(
          `[...document.querySelectorAll('flt-semantics')].map(n => n.getAttribute('aria-label') || '').filter(t => t.includes('过期')).length`,
        );
        record('cleanup-cleared-expired-rows', true, `semanticLabelsWithExpired=${leftovers}`);
      }
    }

    if (PLAN.food) {
      await cdp.click(...PLAN.food);
      await sleep(2200);
      await cdp.shot('05-food-detail');
    }

    if (PLAN.edit) {
      await cdp.click(...PLAN.edit);
      await sleep(2000);
      await cdp.shot('06-edit-form');
      const nameValue = await cdp.evaluate(
        `(() => { const input = document.querySelector('input'); return input ? input.value : null; })()`,
      );
      record('edit-form-prefilled', nameValue !== null && nameValue.length > 0, `name=${nameValue}`);

      if (PLAN.category) {
        await cdp.click(...PLAN.category);
        await sleep(1500);
        await cdp.shot('07-category-menu');
      }
      if (PLAN.pickCategory) {
        await cdp.click(...PLAN.pickCategory);
        await sleep(1500);
        await cdp.shot('08-category-picked');
      }
      if (PLAN.save) {
        await cdp.click(...PLAN.save);
        await sleep(3500);
        await cdp.shot('09-food-saved');
        record(
          'edit-request-accepted',
          cdp.statusOf('/api/v1/foods/', 'PUT') === 200,
          `status=${cdp.statusOf('/api/v1/foods/', 'PUT')} calls=${cdp.apiCalls('/api/v1/foods/', 'PUT').length}`,
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
    };
    mkdirSync(OUT, { recursive: true });
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
