// Standalone file:// browser acceptance. Uses the installed Edge and Node built-ins.
// No app server, production account, API, database or third-party dependency is used.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {spawn} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {setTimeout as sleep} from 'node:timers/promises';

const root=process.cwd();
const file=path.join(root,'apps/frontend-demo/index.html');
const out=process.env.DEMO_REVIEW_DIR || path.join(root,'docs/reviews/evidence/2026-11-10-frontend-demo');
const profile=fs.mkdtempSync(path.join(os.tmpdir(),'xiaoyi-html-review-'));
const downloads=path.join(profile,'downloads');
const checks=[],events=[],pending=new Map();
let browser,ws,seq=0;
fs.mkdirSync(out,{recursive:true});fs.mkdirSync(downloads,{recursive:true});
const literal=JSON.stringify;
function check(name,passed,detail){checks.push({name,passed:Boolean(passed),...(detail===undefined?{}:{detail})});console.log((passed?'PASS ':'FAIL ')+name);if(!passed)throw Error(name);}
async function until(fn,timeout=12000){const end=Date.now()+timeout;while(Date.now()<end){const result=await fn();if(result)return result;await sleep(70);}throw Error('Condition timed out');}
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;const timer=setTimeout(()=>{pending.delete(id);reject(Error(method+' timed out'));},15000);pending.set(id,{resolve,reject,timer});ws.send(JSON.stringify({id,method,params}));});}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description||r.exceptionDetails.text);return r.result?.value;}
async function click(selector){
  const point=await evaluate(`(()=>{const el=[...document.querySelectorAll(${literal(selector)})].find(e=>e.getBoundingClientRect().width>0&&e.getBoundingClientRect().height>0);if(!el)throw Error('Missing visible element: '+${literal(selector)});if(el.disabled)throw Error('Disabled element: '+${literal(selector)});el.scrollIntoView({block:'center',inline:'nearest'});const r=el.getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2};})()`);
  for(const type of ['mousePressed','mouseReleased'])await send('Input.dispatchMouseEvent',{type,...point,button:'left',clickCount:1});
  await sleep(70);
}
async function fill(selector,value){await evaluate(`(()=>{const e=document.querySelector(${literal(selector)});e.value=${literal(value)};e.dispatchEvent(new Event('input',{bubbles:true}));return true;})()`);}
async function select(selector,value){await evaluate(`(()=>{const e=document.querySelector(${literal(selector)});e.value=${literal(value)};e.dispatchEvent(new Event('change',{bubbles:true}));return true;})()`);}
async function textOf(selector){return evaluate(`document.querySelector(${literal(selector)})?.textContent||''`);}
async function storage(){return evaluate(`JSON.parse(localStorage.getItem('xiaoyi-standalone-demo-v1'))`);}
async function foods(){return evaluate(`(()=>{const s=JSON.parse(localStorage.getItem('xiaoyi-standalone-demo-v1'));return s?s.families.find(f=>f.id===s.activeFamilyId).foods:null;})()`);}
async function foodByName(name){return(await foods()).find(f=>f.name===name);}
async function screenshot(name){await sleep(200);const{data}=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(data,'base64'));}
async function viewport(width,height){await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<600});await sleep(130);}
async function navigate(page){await click(`[data-page="${page}"]`);}
async function openSettings(){await click('.topbar [data-action="settings"]');}
async function closeModal(){if(await evaluate(`document.querySelector('#modal').open`))await click('#modal [data-action="close-modal"]');}
async function addFood(values={}){
  await click('#main [data-action="add-food"]');
  const data={name:'演示苹果',category:'水果',quantity:'3',unit:'个',zone:'冷藏',purchased:'2026-11-10',expiry:'2026-11-15',...values};
  for(const[key,value]of Object.entries(data))await fill(`#food-form [name="${key}"]`,value);
  await click('#food-form button[type="submit"]');
}
async function chooseFamily(id){await click('.topbar [data-action="switch-family"]');await click(`#modal [data-action="choose-family"][data-id="${id}"]`);}
async function modalBounds(){return evaluate(`(()=>{const d=document.querySelector('#modal'),r=d.getBoundingClientRect();return{left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:innerWidth,height:innerHeight,overflow:d.scrollWidth>d.clientWidth+1};})()`);}
async function reload(){await send('Page.reload');await until(()=>evaluate(`document.readyState==='complete'&&Boolean(document.querySelector('.page-head'))`));}

try{
  const html=fs.readFileSync(file,'utf8');
  new vm.Script(html.match(/<script>([\s\S]*?)<\/script>/)[1]);
  check('inline-script-parses',true);
  check('six-embedded-photos-and-no-external-assets',(html.match(/data:image\/jpeg;base64,/g)||[]).length===6&&!/<(?:script|link|img)\b[^>]*(?:src|href)=["']https?:/i.test(html));
  const edge=process.env.EDGE_PATH||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
  browser=spawn(edge,['--headless=new','--remote-debugging-port=0','--no-first-run','--no-default-browser-check','--disable-extensions','--window-size=1440,1000','--user-data-dir='+profile,'about:blank'],{stdio:'ignore',windowsHide:true});
  await until(()=>fs.existsSync(path.join(profile,'DevToolsActivePort')),15000);
  const port=fs.readFileSync(path.join(profile,'DevToolsActivePort'),'utf8').split('\n')[0];
  const target=await fetch(`http://127.0.0.1:${port}/json/new?about:blank`,{method:'PUT'}).then(r=>r.json());
  ws=new WebSocket(target.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
  ws.addEventListener('message',event=>{const r=JSON.parse(event.data);if(r.method)events.push(r);if(r.id){const p=pending.get(r.id);if(p){pending.delete(r.id);clearTimeout(p.timer);r.error?p.reject(Error(r.error.message)):p.resolve(r.result);}}});
  for(const method of ['Page.enable','Runtime.enable','Network.enable'])await send(method);
  await send('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:downloads});
  await viewport(1440,1000);await send('Page.navigate',{url:pathToFileURL(file).href});
  await until(()=>evaluate(`Boolean(document.querySelector('.stat'))`));
  check('file-protocol-renders-twelve-foods',await evaluate(`location.protocol==='file:'&&document.querySelector('.stat-value').textContent.trim().startsWith('12')`));
  const outlineVisible = `(key) => {
    const scene = document.querySelector('.scene');
    const drawer = scene.querySelector('.drawer-overhead.' + key);
    const stage = scene.getBoundingClientRect();
    const outline = drawer.getBoundingClientRect();
    const overview = scene.querySelector('.scene-overview').getBoundingClientRect();
    return getComputedStyle(drawer).opacity === '1' && outline.top > overview.bottom &&
      outline.left >= stage.left + 10 && outline.right <= stage.right - 10 &&
      outline.bottom <= stage.bottom - 10 && outline.width >= stage.width * 0.6;
  }`;
  check('three-storage-zones-and-400ms-transition',await evaluate(`(() => {
    const controls = [...document.querySelectorAll('[data-action="focus-zone"]')];
    controls[0].click();
    const scene = document.querySelector('.scene');
    return controls.map(button => button.dataset.zone).join(',') === '冷藏,变温,冷冻' &&
      scene.dataset.focus === '冷藏' && getComputedStyle(scene.querySelector('.scene-view')).transitionDuration.split(', ').every(value => value === '0.4s');
  })()`));
  check('variable-control-reaches-the-full-outline-after-an-intermediate-pose',await evaluate(`(() => {
    const scene = document.querySelector('.scene');
    const tray = scene.querySelector('.drawer-overhead.variable');
    const start = getComputedStyle(tray).transform;
    document.querySelector('[data-action="focus-zone"][data-zone="变温"]').click();
    getComputedStyle(tray).transform;
    const transition = tray.getAnimations().find(animation => animation.transitionProperty === 'transform');
    if (!transition) return false;
    transition.pause();
    transition.currentTime = 200;
    const middle = getComputedStyle(tray).transform;
    tray.getAnimations().forEach(animation => animation.finish());
    const end = getComputedStyle(tray).transform;
    return scene.dataset.focus === '变温' && scene.querySelector('.scene-view').inert &&
      scene.querySelectorAll('.fridge [data-door].open').length === 1 &&
      scene.querySelector('.fridge-drawer.variable.open') !== null &&
      (${outlineVisible})('variable') &&
      start !== middle && middle !== end && start !== end;
  })()`));
  await screenshot('home-desktop');
  for(const[width,height,label]of[[1440,1000,'desktop'],[390,844,'mobile'],[320,740,'narrow']]){
    await viewport(width,height);
    await click('[data-action="close-doors"]');
    const doorSteps = [
      ['left', ['left'], '冷藏'],
      ['right', ['left','right'], '冷藏'],
      ['freezer', ['freezer'], '冷冻'],
      ['variable', ['variable'], '变温'],
      ['freezer', ['freezer'], '冷冻'],
      ['freezer', [], 'overview'],
    ];
    for(const [index,[key,open,focus]] of doorSteps.entries()){
      await click(`.door-control[data-door="${key}"]`);
      check(`${label}-drawer-control-step-${index+1}`,await evaluate(`(() => {
        const scene = document.querySelector('.scene');
        const active = ${literal(open)};
        const focusedTray = ['变温','冷冻'].includes(scene.dataset.focus);
        return scene.dataset.focus === ${literal(focus)} &&
          scene.querySelector('.scene-view').inert === focusedTray &&
          [...document.querySelectorAll('[data-door]')].every(el =>
            (el.getAttribute('aria-pressed') === 'true') === active.includes(el.dataset.door)) &&
          [...scene.querySelectorAll('[data-door]')].every(el =>
            el.classList.contains('open') === active.includes(el.dataset.door));
      })()`));
    }
    for (const key of ['variable','freezer']) {
      await click(`.door-control[data-door="${key}"]`);
      await until(()=>evaluate(`getComputedStyle(document.querySelector('.drawer-overhead.${key}')).opacity === '1'`));
      check(`${label}-${key}-all-four-edges-visible`,await evaluate(`(${outlineVisible})(${literal(key)})`));
    }
    await screenshot('home-'+label+'-open');await click('[data-action="close-doors"]');
  }
  await viewport(1440,1000);await navigate('foods');
  await fill('#food-search','牛奶');
  check('live-name-search',await evaluate(`document.querySelectorAll('[data-food-row]').length===1&&document.querySelector('#food-results').textContent.includes('鲜牛奶')`));
  await select('#expiry-filter','expired');check('combined-filter-empty-state',(await textOf('#food-results')).includes('没有找到'));
  await click('[data-action="reset-filters"]');await click('[data-filter-zone="冷冻"]');
  check('zone-filter-one-frozen-food',await evaluate(`document.querySelectorAll('[data-food-row]').length===1&&document.querySelector('#food-results').textContent.includes('鸡翅')`));
  await click('[data-filter-zone="变温"]');
  check('zone-filter-one-variable-food',await evaluate(`document.querySelectorAll('[data-food-row]').length===1&&document.querySelector('#food-results').textContent.includes('三文鱼')`));
  await click('[data-action="reset-filters"]');await select('#category-filter','奶制品');check('category-filter',await evaluate(`document.querySelectorAll('[data-food-row]').length===1`));
  await click('[data-action="reset-filters"]');await select('#food-sort','quantity');check('quantity-sort',(await textOf('[data-food-row]')).includes('鸡蛋'));
  await click('#main [data-action="add-food"]');
  check('required-name-validation',await evaluate(`!document.querySelector('#food-form').checkValidity()`));
  await fill('#food-form [name="name"]','演示苹果');await fill('#food-form [name="quantity"]','-1');
  check('negative-quantity-native-validation',await evaluate(`!document.querySelector('#food-form').checkValidity()`));
  await fill('#food-form [name="quantity"]','3');await fill('#food-form [name="expiry"]','2026-11-09');await click('#food-form button[type="submit"]');
  check('invalid-chronology-retains-form',(await textOf('[data-form-error]')).includes('到期日期不能早于'));
  await click('#modal [data-action="close-modal"]');check('draft-discard-confirmation',await evaluate(`document.querySelector('#confirmation').open`));
  await click('#confirm-cancel');check('draft-cancel-retains-value',await evaluate(`document.querySelector('#food-form [name="name"]').value==='演示苹果'`));
  await click('#modal [data-action="close-modal"]');await click('#confirm-accept');
  await openSettings();await click('#failure-setting');await closeModal();
  await addFood();check('failed-save-preserves-draft-and-no-write',await evaluate(`document.querySelector('#modal').open&&document.querySelector('[data-form-error]').textContent.includes('模拟保存失败')&&document.querySelector('#food-form [name="name"]').value==='演示苹果'&&document.querySelectorAll('[data-food-row]').length===12`));
  await click('#food-form button[type="submit"]');check('retry-add-succeeds-once',(await foods()).length===13&&(await foods()).filter(f=>f.name==='演示苹果').length===1);
  await reload();check('file-reload-preserves-data',(await foods()).length===13);
  const apple=(await foodByName('演示苹果')).id;
  await click(`[data-action="edit-food"][data-id="${apple}"]`);await fill('#food-form [name="name"]','苹果 <img src=x onerror=alert(1)>');await fill('#food-form [name="quantity"]','4');await click('#food-form button[type="submit"]');
  check('user-content-escaped',await evaluate(`!document.querySelector('img[src="x"]')&&document.querySelector('#food-results').textContent.includes('<img src=x')`));
  await click(`[data-action="edit-food"][data-id="${apple}"]`);await fill('#food-form [name="name"]','演示苹果');await click('#food-form button[type="submit"]');
  await click(`[data-action="food-detail"][data-id="${apple}"]`);await fill('#use-form [name="quantity"]','1');await click('#use-form button[type="submit"]');
  check('use-food-decrements-exactly',(await foodByName('演示苹果')).quantity===3);
  await click(`[data-action="food-detail"][data-id="${apple}"]`);await click('#modal [data-action="move-food"]');await select('#move-form [name="zone"]','冷冻');await click('#move-form button[type="submit"]');
  check('move-preserves-quantity',(await foodByName('演示苹果')).zone==='冷冻'&&(await foodByName('演示苹果')).quantity===3);
  await click(`[data-action="food-detail"][data-id="${apple}"]`);await click('#modal [data-action="discard-food"]');await click('#confirm-cancel');check('discard-cancel-no-write',Boolean(await foodByName('演示苹果')));
  await click('#modal [data-action="discard-food"]');await click('#confirm-accept');check('discard-removes-food',!await foodByName('演示苹果'));
  await navigate('records');await click('#main [data-action="revert"]');check('undo-restores-discard',(await foodByName('演示苹果')).quantity===3);await click('#main [data-action="revert"]');check('redo-reapplies-discard',!await foodByName('演示苹果'));
  await navigate('recipes');await until(()=>evaluate(`[...document.querySelectorAll('.recipe-photo img')].every(i=>i.complete&&i.naturalWidth>0)`));
  check('six-offline-photos-load',await evaluate(`document.querySelectorAll('.recipe-card').length===6`));
  await click('[data-action="favorite"][data-id="tomato-eggs"]');await click('[data-recipe-filter="favorite"]');check('favorite-filter',await evaluate(`document.querySelectorAll('.recipe-card').length===1`));
  await click('[data-recipe-filter="all"]');
  await openSettings();await click('#failure-setting');await closeModal();
  await click('[data-action="recipe-detail"][data-id="tomato-eggs"]');await click('#modal [data-action="servings-up"]');
  check('servings-updates-ingredients',(await textOf('.ingredient-list')).includes('4.5 个'));
  await click('#modal [data-action="servings-down"]');await click('#modal [data-action="cook"]');await click('#confirm-accept');
  check('failed-cook-atomic-and-retryable',(await foodByName('番茄')).quantity===4&&(await foodByName('鸡蛋')).quantity===10&&(await textOf('[data-form-error]')).includes('模拟保存失败'));
  await click('#modal [data-action="cook"]');await click('#confirm-accept');
  check('cook-atomic-multi-food-deduction',(await foodByName('番茄')).quantity===2&&(await foodByName('鸡蛋')).quantity===7&&!await evaluate(`document.querySelector('#modal').open`));
  await click('[data-action="recipe-detail"][data-id="pan-seared-salmon"]');check('expired-stock-not-cookable',await evaluate(`document.querySelector('#modal [data-action="cook"]').disabled`));
  await click('#modal [data-action="add-missing"]');await click('#food-form button[type="submit"]');
  check('missing-food-form-prefill',(await foods()).filter(f=>f.name==='三文鱼').length===2);
  await click('[data-action="recipe-detail"][data-id="pan-seared-salmon"]');await click('#modal [data-action="cook"]');await click('#confirm-accept');
  check('cooking-excludes-expired-batch',(await foods()).filter(f=>f.name==='三文鱼').length===1&&(await foodByName('三文鱼')).quantity===2);
  await navigate('foods');await addFood({name:'番茄',category:'蔬菜',quantity:'1',zone:'冷藏',expiry:'2026-11-10'});
  const firstBatch=(await foods()).find(f=>f.name==='番茄'&&f.expiry==='2026-11-10').id;
  await navigate('recipes');await click('[data-action="recipe-detail"][data-id="tomato-eggs"]');await click('#modal [data-action="cook"]');await click('#confirm-accept');
  check('duplicate-batch-first-expiry-first-out',!(await foods()).some(f=>f.id===firstBatch)&&(await foodByName('番茄')).quantity===1);
  await click('[data-action="recipe-detail"][data-id="vegetable-egg-pancake"]');
  check('missing-recipe-shows-disabled-action',await evaluate(`document.querySelector('#modal [data-action="cook"]').disabled&&document.querySelector('.ingredient-list').textContent.includes('缺 100')`));await closeModal();
  await navigate('foods');await click('[data-action="clear-expired"]');await click('#confirm-accept');
  check('expiry-cleanup-preserves-today',!await foodByName('三文鱼')&&Boolean(await foodByName('嫩豆腐')));
  await navigate('records');await click('#main [data-action="revert"]');check('cleanup-undo-restores-expired',Boolean(await foodByName('三文鱼')));
  check('stale-undo-actions-disabled',await evaluate(`[...document.querySelectorAll('#main [data-action="revert"]')].some(b=>b.disabled)`));
  await navigate('family');await click('#main [data-action="add-member"]');await fill('#member-form [name="name"]','演示小雨');await click('#member-form button[type="submit"]');
  let s=await storage();const member=s.families.find(f=>f.id==='forest').members.find(m=>m.name==='演示小雨');check('add-local-member',Boolean(member));
  await click('#main [data-action="invite"]');await click('#modal [data-action="copy-code"]');await until(async()=>/已复制|已选中/.test(await textOf('#toast')));check('invitation-copy-or-manual-fallback',true);await closeModal();
  await select(`[data-member-role="${member.id}"]`,'VIEWER');s=await storage();check('change-member-role',s.families.find(f=>f.id==='forest').members.find(m=>m.id===member.id).role==='VIEWER');
  await click(`[data-action="remove-member"][data-id="${member.id}"]`);await click('#confirm-accept');s=await storage();check('remove-local-member',!s.families.find(f=>f.id==='forest').members.some(m=>m.id===member.id));
  const forestBefore=JSON.stringify(await foods());await chooseFamily('weekend');check('family-isolation-empty-workspace',(await foods()).length===0);await navigate('foods');check('empty-workspace-add-action',(await textOf('#food-results')).includes('等着第一份'));
  await chooseFamily('forest');check('family-switch-restores-original-data',JSON.stringify(await foods())===forestBefore);
  await navigate('family');await click('#main [data-action="join-family"]');await fill('#join-form [name="code"]','WRONG123');await click('#join-form button[type="submit"]');check('invalid-invite-feedback',(await textOf('[data-form-error]')).includes('没有找到'));
  await fill('#join-form [name="code"]','SUNN2026');await click('#join-form button[type="submit"]');check('join-demo-readonly-family',(await foods()).length===2&&(await storage()).activeFamilyId==='sunny');
  await navigate('foods');check('viewer-disabled-write-controls',await evaluate(`[...document.querySelectorAll('#main [data-action="add-food"],#main [data-action="edit-food"]')].every(b=>b.disabled)`));
  await evaluate(`document.querySelector('#main [data-action="add-food"]').disabled=false;document.querySelector('#main [data-action="add-food"]').click();true`);
  check('write-handler-rechecks-role',!await evaluate(`document.querySelector('#modal').open`));
  await chooseFamily('forest');await openSettings();await click('#readonly-setting');await closeModal();
  check('readonly-preview-disables-writes',await evaluate(`document.querySelector('#main [data-action="add-food"]').disabled`));
  await openSettings();await click('#readonly-setting');await closeModal();
  await openSettings();await click('#motion-setting');check('reduce-motion-setting',await evaluate(`document.body.classList.contains('reduce-motion')`));await click('#motion-setting');await closeModal();
  await navigate('family');await click('#main [data-action="create-family"]');await fill('#family-form [name="name"]','演示新厨房');await click('#family-form button[type="submit"]');check('create-isolated-family',(await foods()).length===0&&(await storage()).families.length===4);await chooseFamily('forest');
  await navigate('foods');await click('#main [data-action="export"]');await until(()=>fs.readdirSync(downloads).some(n=>n.endsWith('.json')));
  const exported=JSON.parse(fs.readFileSync(path.join(downloads,fs.readdirSync(downloads).find(n=>n.endsWith('.json'))),'utf8'));check('export-contains-current-family-only',exported.family.id==='forest'&&!Object.hasOwn(exported,'families'));
  // Reset ensures review screenshots show the intended initial sample, not test debris.
  await openSettings();await click('#modal [data-action="reset"]');await click('#confirm-cancel');check('reset-cancel-preserves-data',(await storage()).families.length===4);
  await click('#modal [data-action="reset"]');await click('#confirm-accept');check('reset-restores-initial-sample',(await foods()).length===12&&(await storage()).families.length===2);
  for(const[width,height,label]of[[1440,1000,'desktop'],[390,844,'mobile'],[320,740,'narrow']]){
    await viewport(width,height);
    for(const page of ['home','foods','recipes','family','records']){
      await navigate(page);check(`${label}-${page}-no-horizontal-overflow`,await evaluate(`document.documentElement.scrollWidth<=innerWidth+1`));
      if(label!=='narrow')await screenshot(page+'-'+label);
    }
    await navigate('home');
    for(const action of ['add-food','notifications','settings','help','switch-family','create-family']){
      if(action==='help'){await openSettings();await click('#modal [data-action="help"]');}
      else if(action==='create-family'){await navigate('family');await click('#main [data-action="create-family"]');}
      else await click(action==='add-food'?'#main [data-action="add-food"]':`.topbar [data-action="${action}"]`);
      const b=await modalBounds();check(`${label}-${action}-dialog-fits`,b.left>=0&&b.right<=b.width+1&&b.top>=0&&b.bottom<=b.height+1&&!b.overflow,b);await closeModal();
      if(action==='create-family')await navigate('home');
    }
    await navigate('recipes');await click('[data-action="recipe-detail"]');const b=await modalBounds();check(`${label}-recipe-dialog-fits`,b.left>=0&&b.right<=b.width+1&&!b.overflow,b);if(label==='mobile')await screenshot('recipe-dialog-mobile');await closeModal();
  }
  await viewport(1440,1000);await navigate('home');
  await send('Input.dispatchKeyEvent',{type:'keyDown',key:'/',code:'Slash',text:'/'});await send('Input.dispatchKeyEvent',{type:'keyUp',key:'/',code:'Slash'});
  check('keyboard-shortcut-focuses-search',await evaluate(`document.activeElement.id==='food-search'`));
  await click('#main [data-action="add-food"]');await fill('#food-form [name="name"]','键盘草稿');
  await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27,nativeVirtualKeyCode:27});await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Escape',code:'Escape',windowsVirtualKeyCode:27,nativeVirtualKeyCode:27});
  check('escape-guards-draft',await evaluate(`document.querySelector('#confirmation').open`));await click('#confirm-accept');
  const fresh=await evaluate(`(()=>{const s=JSON.parse(localStorage.getItem('xiaoyi-standalone-demo-v1'));s.families[0].foods[0].quantity=8;const raw=JSON.stringify(s);localStorage.setItem('xiaoyi-standalone-demo-v1',raw);dispatchEvent(new StorageEvent('storage',{key:'xiaoyi-standalone-demo-v1',newValue:raw}));return raw;})()`);
  check('cross-tab-update-blocks-stale-writes',await evaluate(`document.querySelector('#main [data-action="add-food"]').disabled&&Boolean(document.querySelector('[data-action="reload-demo"]'))`));
  await openSettings();await click('#readonly-setting');check('cross-tab-preferences-cannot-overwrite-new-data',await evaluate(`localStorage.getItem('xiaoyi-standalone-demo-v1')===${literal(fresh)}`));await closeModal();await click('[data-action="reload-demo"]');await until(async()=>Boolean(await evaluate(`document.querySelector('[data-food-row="tomato"]')`)));
  check('cross-tab-reload-loads-latest',(await foodByName('番茄')).quantity===8);
  await evaluate(`(() => {
    const saved = JSON.parse(localStorage.getItem('xiaoyi-standalone-demo-v1'));
    const household = saved.families[0];
    const food = household.foods.find(value => value.id === 'seaweed');
    food.zone = '常温';
    const after = structuredClone(household.foods);
    const before = structuredClone(after);
    before.find(value => value.id === 'seaweed').quantity = 0.5;
    household.activities.unshift({
      id: 'old-move', title: '旧库存操作', detail: '', kind: 'move', time: '',
      before, after, undone: false,
    });
    localStorage.setItem('xiaoyi-standalone-demo-v1', JSON.stringify(saved));
    return true;
  })()`);
  await reload();
  await navigate('records');
  await click('[data-action="revert"][data-id="old-move"]');
  const migrated = await storage();
  const legacyFood = migrated.families[0].foods.find(value => value.id === 'seaweed');
  check('legacy-zone-loads-with-food-and-undo-snapshots',
    legacyFood.zone === '冷藏' && legacyFood.quantity === 0.5 &&
    migrated.families[0].foods.find(value => value.id === 'salmon').zone === '变温' &&
    migrated.families[0].foods.length === 12 && migrated.families[0].activities[0].undone);
  await navigate('foods');
  await evaluate(`localStorage.setItem('xiaoyi-standalone-demo-v1','{"version":1,"families":"broken"}');true`);await reload();
  check('corrupt-storage-recovers-to-seed',await evaluate(`document.querySelectorAll('[data-food-row]').length===12&&document.querySelector('#toast').textContent.includes('数据损坏')`));
  await send('Page.addScriptToEvaluateOnNewDocument',{source:`Storage.prototype.setItem=function(){throw new DOMException('blocked','SecurityError')}`});await reload();await addFood();
  check('storage-failure-keeps-interaction-and-explains-limit',await evaluate(`document.querySelectorAll('[data-food-row]').length===13&&document.querySelector('#toast').textContent.includes('仅保留在当前页面')`));
  check('no-runtime-exceptions',!events.some(e=>e.method==='Runtime.exceptionThrown'),events.filter(e=>e.method==='Runtime.exceptionThrown').map(e=>e.params.exceptionDetails.text));
  const network=events.filter(e=>e.method==='Network.requestWillBeSent').map(e=>e.params.request.url);
  check('offline-page-never-calls-http-or-backend',network.every(url=>!/^https?:/.test(url)));
}catch(error){console.error(error.stack);checks.push({name:'completed',passed:false,detail:String(error)});process.exitCode=1;if(ws?.readyState===1)try{await screenshot('failure');}catch{}}
finally{
  const result={date:new Date().toLocaleDateString('sv-SE',{timeZone:'Asia/Shanghai'}),scope:'Standalone HTML file://, Edge headless, desktop/mobile viewport emulation; no production API or physical-device acceptance.',checks,passed:checks.filter(c=>c.passed).length,failed:checks.filter(c=>!c.passed).length};
  fs.writeFileSync(path.join(out,'browser-review.json'),JSON.stringify(result,null,2)+'\n');
  if(ws?.readyState===1){try{await send('Browser.close');}catch{}ws.close();}browser?.kill();
  console.log(JSON.stringify({passed:result.passed,failed:result.failed}));
}
