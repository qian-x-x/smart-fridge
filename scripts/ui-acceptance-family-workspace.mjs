// Drives the release Flutter app through native CDP pointer/keyboard events.
import { spawn } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

const APP = process.env.APP_URL || 'http://127.0.0.1:18000';
const OUT = process.env.OUT_DIR || 'docs/reviews/evidence/2026-11-09-real-business';
const context = JSON.parse(readFileSync('output/real-business/ui-context.json', 'utf8'));
const checks = [];
const events = [];
let cdp;
function check(name, pass, detail = '') {
  checks.push({ name, pass, detail });
  console.log(`${pass ? 'PASS' : 'FAIL'} ${name} ${detail}`);
  if (!pass) throw new Error(name);
}
async function until(fn, timeout = 25000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const value = await fn();
    if (value) return value;
    await sleep(250);
  }
  throw new Error('UI wait timed out');
}
class Cdp {
  constructor(ws) {
    this.ws = ws; this.id = 0; this.pending = new Map();
    ws.addEventListener('message', e => {
      const m = JSON.parse(e.data);
      if (m.method) events.push(m);
      if (m.id) {
        const pair = this.pending.get(m.id);
        if (pair) { this.pending.delete(m.id); m.error ? pair.reject(new Error(JSON.stringify(m.error))) : pair.resolve(m.result); }
      }
    });
  }
  send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++this.id;
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error('CDP timeout: ' + method)); }, 15000);
      this.pending.set(id, { resolve: value => { clearTimeout(timer); resolve(value); }, reject: error => { clearTimeout(timer); reject(error); } });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression) {
    const r = await this.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.text);
    return r.result?.value;
  }
  async shot(name) {
    const { data } = await this.send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(`${OUT}/${name}.png`, Buffer.from(data, 'base64'));
  }
  async click(x, y) {
    await this.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y, buttons: 0 });
    await sleep(120);
    for (const type of ['mousePressed', 'mouseReleased']) {
      await this.send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1, buttons: type === 'mousePressed' ? 1 : 0 });
      await sleep(80);
    }
    await sleep(300);
  }
  async label(text, scroll = false) {
    const r = await until(async () => {
      const rect = await this.evaluate(`(() => {
      const items = [...document.querySelectorAll('[aria-label],flt-semantics')].filter(n => {
        const label = (n.getAttribute('aria-label') || n.textContent || '').trim(); const r = n.getBoundingClientRect();
        return (label === ${JSON.stringify(text)} || label.startsWith(${JSON.stringify(text + '\n')})) && r.width > 0 && r.height > 0 && r.top >= 0 && r.bottom <= innerHeight;
      }).sort((a,b) => a.getBoundingClientRect().width*a.getBoundingClientRect().height-b.getBoundingClientRect().width*b.getBoundingClientRect().height);
      const r = items[0]?.getBoundingClientRect(); return r ? {x:r.x+r.width/2,y:r.y+r.height/2} : null;
    })()`);
      if (!rect && scroll) {
        await this.send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 500, y: 500, deltaX: 0, deltaY: 500 });
        await sleep(300);
      }
      return rect;
    });
    await this.click(r.x, r.y);
  }
}
const responses = path => events.filter(e => e.method === 'Network.responseReceived' && e.params.response.url.includes(path));
async function body(event) {
  await until(() => events.some(e => e.method === 'Network.loadingFinished' && e.params.requestId === event.params.requestId));
  return JSON.parse((await cdp.send('Network.getResponseBody', { requestId: event.params.requestId })).body);
}
async function semantics() {
  // Flutter's hidden accessibility activator ignores pointer hit testing.
  // Enable its provided semantics switch; business controls still use native input.
  await cdp.evaluate("document.querySelector('flt-semantics-placeholder')?.click(); true");
  await until(() => cdp.evaluate("document.querySelectorAll('flt-semantics').length > 2"));
}
async function sceneReady() {
  return until(() => cdp.evaluate(`(() => {
    const roots=[document], frames=[];
    for(let i=0;i<roots.length;i++) {
      frames.push(...roots[i].querySelectorAll('iframe'));
      for(const node of roots[i].querySelectorAll('*')) if(node.shadowRoot) roots.push(node.shadowRoot);
    }
    return frames.some(frame => {
    const r=frame.getBoundingClientRect(); const doc=frame.contentDocument;
    const scene=doc?.querySelector('#scene'); const loading=doc?.querySelector('#loading');
    return r.width>100 && r.height>100 && scene?.dataset.ready==='true' &&
      scene.dataset.settled==='true' && loading?.classList.contains('is-hidden');
  }); })()`), 30000);
}
async function main() {
  mkdirSync(OUT, { recursive: true });
  // A fresh account keeps onboarding deterministic even after repeated API
  // acceptance runs have created many other families in the isolated schema.
  context.username = 'family_ui_' + Date.now();
  const fixture = await fetch(context.base + '/api/v1/auth/register', { method: 'POST',
    headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({
      username: context.username, password: context.password, displayName: '界面验收用户' }) });
  if (fixture.status !== 201) throw new Error('UI fixture registration failed: ' + fixture.status);
  const edge = spawn('C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe', [
    '--headless=new', '--remote-debugging-port=9336', '--window-size=1400,1000',
    '--force-device-scale-factor=1', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    '--no-first-run', '--no-default-browser-check', `--user-data-dir=${join(tmpdir(), 'sf-family-ui-' + Date.now())}`, 'about:blank',
  ], { stdio: 'ignore' });
  let error;
  try {
    await until(async () => { try { return (await fetch('http://127.0.0.1:9336/json/version')).ok; } catch { return false; } });
    const tab = await fetch('http://127.0.0.1:9336/json/new?about:blank', { method: 'PUT' }).then(r => r.json());
    const ws = new WebSocket(tab.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { ws.addEventListener('open', resolve, { once: true }); ws.addEventListener('error', reject, { once: true }); });
    cdp = new Cdp(ws);
    for (const feature of ['Page.enable', 'Runtime.enable', 'Network.enable']) await cdp.send(feature);
    await cdp.send('Emulation.setDeviceMetricsOverride', { width: 1400, height: 900, deviceScaleFactor: 1, mobile: false });
    await cdp.send('Page.navigate', { url: APP });
    await sleep(7000); await semantics(); await cdp.shot('ui-01-login');
    await cdp.label('用户名或手机号'); await cdp.send('Input.insertText', { text: context.username });
    await cdp.label('密码'); await cdp.send('Input.insertText', { text: context.password });
    await cdp.label('进入我的冰箱');
    await until(() => responses('/auth/login').some(e => e.params.response.status === 200));
    check('real-login', true);
    await sleep(3000); await cdp.shot('ui-02-home-before-create');
    // Rail positions are verified in the 1400x900 screenshots. Some Flutter
    // semantic text nodes have tiny hit boxes, so use the visible icon centers.
    await cdp.click(48, 300);
    await until(() => cdp.evaluate("location.href.includes('/profile')"));
    console.log('NAV profile');
    await cdp.label('创建家庭', true); await cdp.shot('ui-03-create-dialog');
    await cdp.label('家庭名称'); await cdp.send('Input.insertText', { text: context.familyName });
    await cdp.label('创建');
    const created = await until(() => responses('/families/workspaces').find(e => e.params.response.status === 201));
    const result = (await body(created)).data;
    check('flutter-creates-workspace', result.family.name === context.familyName && result.fridgeId > 0, `family=${result.family.id}, fridge=${result.fridgeId}`);
    const manual = events.filter(e => e.method === 'Network.requestWillBeSent' && e.params.request.method === 'POST' && /\/api\/v1\/fridges$/.test(e.params.request.url));
    check('no-second-manual-fridge-post', manual.length === 0);
    await sleep(2000); await cdp.shot('ui-04-family-created');
    await cdp.click(48, 130);
    await until(() => cdp.evaluate("location.href.includes('/home')"));
    console.log('NAV home');
    const loaded = await until(() => responses('/fridges?familyId=' + result.family.id).find(e => e.params.response.status === 200));
    const fridge = (await body(loaded)).data;
    check('new-fridge-loaded-from-ui', fridge.id === result.fridgeId && fridge.zones.map((zone) => zone.code).join(',') === 'FRESH,VARIABLE,FREEZER');
    check('desktop-scene-ready', await sceneReady());
    await cdp.shot('ui-05-new-fridge-desktop');
    const beforeReload = events.length;
    await cdp.send('Page.reload'); await sleep(4500);
    const reloaded = await until(() => events.slice(beforeReload).find(e =>
      e.method === 'Network.responseReceived' && e.params.response.status === 200 &&
      e.params.response.url.includes('/fridges?familyId=' + result.family.id)));
    check('created-family-survives-reload', (await body(reloaded)).data.id === result.fridgeId);
    await cdp.send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
    // A screenshot requests a compositor frame after CDP changes the viewport.
    // Headless Chromium may otherwise defer the new platform-view iframe paint.
    await cdp.send('Page.captureScreenshot', { format: 'png' });
    await sleep(500);
    check('mobile-scene-ready', await sceneReady());
    await sleep(500); await cdp.shot('ui-06-new-fridge-mobile');
    check('mobile-viewport', (await cdp.evaluate('innerWidth')) === 390);
    const errors = events.filter(e => e.method === 'Runtime.exceptionThrown');
    check('no-browser-exceptions', errors.length === 0, 'exceptions=' + errors.length);
    const apiErrors = events.filter(e => e.method === 'Network.responseReceived' && e.params.response.url.includes('/api/') && e.params.response.status >= 400);
    check('no-failed-api-calls', apiErrors.length === 0, 'failed=' + apiErrors.length);
  } catch (e) {
    error = e.message;
    if (cdp) {
      await cdp.shot('ui-failure');
      const labels = await cdp.evaluate(`[...document.querySelectorAll('[aria-label],flt-semantics')].map(n=>(n.getAttribute('aria-label')||n.textContent||'').trim()).filter(Boolean)`);
      writeFileSync(`${OUT}/ui-failure-labels.json`, JSON.stringify(labels, null, 2));
      writeFileSync(`${OUT}/ui-failure-network.json`, JSON.stringify(events.filter(e => e.method === 'Network.responseReceived').map(e => ({url:e.params.response.url,status:e.params.response.status})), null, 2));
      const scenes = await cdp.evaluate(`(() => {const roots=[document],frames=[];for(let i=0;i<roots.length;i++){frames.push(...roots[i].querySelectorAll('iframe'));for(const n of roots[i].querySelectorAll('*'))if(n.shadowRoot)roots.push(n.shadowRoot);}return frames.map(f=>({src:f.src,rect:f.getBoundingClientRect().toJSON(),ready:f.contentDocument?.querySelector('#scene')?.dataset.ready,settled:f.contentDocument?.querySelector('#scene')?.dataset.settled,loading:f.contentDocument?.querySelector('#loading')?.className}));})()`);
      writeFileSync(`${OUT}/ui-failure-scenes.json`, JSON.stringify(scenes, null, 2));
      writeFileSync(`${OUT}/ui-failure-location.json`, JSON.stringify(await cdp.evaluate('({url:location.href,w:innerWidth,h:innerHeight,dpr:devicePixelRatio})'), null, 2));
    }
    throw e;
  } finally {
    writeFileSync(`${OUT}/ui-acceptance.json`, JSON.stringify({ runAt: new Date().toISOString(), app: APP,
      passed: checks.filter(c=>c.pass).length, total: checks.length, checks, error }, null, 2));
    if (cdp) { try { await cdp.send('Browser.close'); } catch {} cdp.ws.close(); }
    edge.kill();
  }
}
main().catch(e => { console.error('FATAL', e.message); process.exitCode = 1; });
