// Reproducible screenshot and browser checks for the isolated design proposal.
// Uses Edge headless + CDP, Node built-ins only. Does not contact any business API.
import http from 'node:http';
import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {setTimeout as sleep} from 'node:timers/promises';

const designDir=path.dirname(fileURLToPath(import.meta.url));
const rootDir=path.resolve(designDir,'../../..');
const relDir='docs/design/ui-redesign-2026-11-10';
const evidenceDir=path.join(rootDir,'docs/reviews/evidence/2026-11-10-ui-proposal');
const mime={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.png':'image/png','.jpg':'image/jpeg','.ttf':'font/ttf','.md':'text/plain; charset=utf-8'};
const resourceFailures=[];
const server=http.createServer((req,res)=>{
  let file;
  try{const rel=decodeURIComponent(new URL(req.url,'http://local').pathname).replace(/^\/+/, '');file=path.resolve(rootDir,rel);const safeRel=path.relative(rootDir,file).replaceAll('\\','/');
    if(!(safeRel.startsWith(relDir+'/')||safeRel.startsWith('apps/fridge-app/assets/'))||!file.startsWith(rootDir+path.sep))throw Error('outside review scope');
    if(fs.statSync(file).isDirectory())file=path.join(file,'index.html');
    res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
  }catch{if(req.url!=='/favicon.ico')resourceFailures.push(req.url);res.writeHead(404);res.end('Not found');}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const base=`http://127.0.0.1:${server.address().port}/${relDir}`;
if(process.argv.includes('--serve')){console.log(`Review: ${base}/index.html`);process.on('SIGINT',()=>{server.close();process.exit(0);});await new Promise(()=>{});}

const results=[];let browser;let cdp;const profile=path.join(os.tmpdir(),'xiaoyi-ui-review-'+randomUUID());
const errors=[];
async function freePort(){const probe=net.createServer();await new Promise(r=>probe.listen(0,'127.0.0.1',r));const port=probe.address().port;await new Promise(r=>probe.close(r));return port;}
async function until(fn,timeout=15000){const deadline=Date.now()+timeout;while(Date.now()<deadline){try{const value=await fn();if(value)return value;}catch{}await sleep(80);}throw Error('Timed out waiting for browser state');}
class Cdp{
  constructor(socket){this.socket=socket;this.id=0;this.pending=new Map();socket.addEventListener('message',event=>{const m=JSON.parse(event.data);if(m.id&&this.pending.has(m.id)){const p=this.pending.get(m.id);clearTimeout(p.timeout);this.pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}else if(m.method==='Runtime.exceptionThrown'){errors.push(m.params.exceptionDetails.exception?.description||m.params.exceptionDetails.text);}});}
  send(method,params={}){const id=++this.id;return new Promise((resolve,reject)=>{const timeout=setTimeout(()=>{this.pending.delete(id);reject(Error(method+' timeout'));},20000);this.pending.set(id,{resolve,reject,timeout});this.socket.send(JSON.stringify({id,method,params}));});}
  async eval(expression){const r=await this.send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description||r.exceptionDetails.text);return r.result?.value;}
}
async function viewport(width,height){await cdp.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<761});}
async function open(url){await cdp.send('Page.navigate',{url});await until(()=>cdp.eval(`location.href===${JSON.stringify(url)}&&document.readyState==='complete'`));await cdp.eval(`Promise.all([document.fonts.ready,...Array.from(document.images).map(i=>i.decode().catch(()=>{}))]).then(()=>true)`);await sleep(65);}
async function proto(scheme,page='home',width=1440,height=960){await viewport(width,height);await open(`${base}/prototype.html?scheme=${scheme}&page=${page}`);await until(()=>cdp.eval('Boolean(window.reviewState)'));}
async function shot(file,full=false){let clip;if(full){const {cssContentSize}=await cdp.send('Page.getLayoutMetrics');clip={x:0,y:0,width:cssContentSize.width,height:cssContentSize.height,scale:1};}const r=await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:full,...(clip?{clip}:{} )});fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,Buffer.from(r.data,'base64'));}
async function click(selector){const point=await cdp.eval(`(()=>{const e=Array.from(document.querySelectorAll(${JSON.stringify(selector)})).find(e=>{const r=e.getBoundingClientRect();return r.width&&r.height&&getComputedStyle(e).visibility!=='hidden';});if(!e)throw Error('Missing visible control: '+${JSON.stringify(selector)});e.scrollIntoView({block:'center'});const r=e.getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2};})()`);await cdp.send('Input.dispatchMouseEvent',{type:'mousePressed',x:point.x,y:point.y,button:'left',clickCount:1});await cdp.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:point.x,y:point.y,button:'left',clickCount:1});await sleep(30);}
async function setInput(selector,value,event='input'){await cdp.eval(`(()=>{const e=document.querySelector(${JSON.stringify(selector)});e.value=${JSON.stringify(value)};e.dispatchEvent(new Event(${JSON.stringify(event)},{bubbles:true}));})()`);}
function check(name,passed,details){results.push({name,passed:Boolean(passed),...(details?{details}:{})});if(!passed)console.error('FAIL',name,details||'');}
const verifyOnly=process.argv.includes('--verify-only');
try{
  const port=await freePort();const edge='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
  browser=spawn(edge,['--headless=new',`--remote-debugging-port=${port}`,`--user-data-dir=${profile}`,'--no-first-run','--no-default-browser-check','--disable-extensions','--disable-background-networking','--disable-features=msEdgeSidebarV2','about:blank'],{stdio:'ignore',windowsHide:true});
  const targets=await until(async()=>{const r=await fetch(`http://127.0.0.1:${port}/json/list`);return r.json();});
  const target=targets.find(t=>t.type==='page');if(!target)throw Error('No browser target');
  const ws=new WebSocket(target.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
  cdp=new Cdp(ws);await cdp.send('Page.enable');await cdp.send('Runtime.enable');
  for(const scheme of ['a','b','c']){
    console.log('Reviewing scheme',scheme.toUpperCase());
    if(!verifyOnly){
      const dir=path.join(designDir,'screens',scheme);
      for(const page of ['home','foods','recipes','family','login','records','components']){await proto(scheme,page);await shot(path.join(dir,page+'.png'));}
      await proto(scheme,'home',390,844);await shot(path.join(dir,'mobile.png'));
      await proto(scheme,'foods',390,844);await shot(path.join(dir,'mobile-foods.png'));
      await proto(scheme,'home',480,900);await click('[data-action="add"]');await shot(path.join(dir,'add.png'));
      await proto(scheme,'foods',480,900);await click('[data-action="detail"][data-id="1"]');await shot(path.join(dir,'detail.png'));
    }
    // Check real computed layout for every proposed page at representative widths.
    for(const width of [320,390,768,1024,1440,1920]){
      for(const page of ['home','foods','recipes','family','login','records','components']){
        await proto(scheme,page,width,960);
        const layout=await cdp.eval(`({width:innerWidth,scrollWidth:document.documentElement.scrollWidth,brokenImages:Array.from(document.images).filter(i=>!i.complete||!i.naturalWidth).map(i=>i.getAttribute('src'))})`);
        check(`${scheme}/${page}/${width}: layout and assets`,layout.scrollWidth<=layout.width+1&&!layout.brokenImages.length,layout.scrollWidth>layout.width+1||layout.brokenImages.length?layout:undefined);
      }
    }
    await proto(scheme,'home');
    await click('[data-part="left"]');await click('[data-part="right"]');
    check(`${scheme}: doors highlight independently`,await cdp.eval(`document.querySelector('[data-part="left"]').getAttribute('aria-pressed')==='true'&&document.querySelector('[data-part="right"]').getAttribute('aria-pressed')==='true'`));
    await click('[data-action="close-all"]');check(`${scheme}: close all resets parts`,await cdp.eval('window.reviewState().openParts.length===0'));
    await click('[data-action="add"]');await click('#save-food');
    check(`${scheme}: empty name is validated`,await cdp.eval(`document.querySelector('[data-field="name"]').classList.contains('has-error')&&document.activeElement.name==='name'`));
    await setInput('#food-form [name="name"]','审查牛奶');await click('[data-action="close-modal"]');
    check(`${scheme}: draft close asks before discarding`,await cdp.eval(`document.querySelector('#confirm-dialog').open&&document.querySelector('#modal').open`));
    await click('[data-action="cancel-confirm"]');check(`${scheme}: continue preserves draft`,await cdp.eval(`document.querySelector('#food-form [name="name"]').value==='审查牛奶'`));
    await cdp.eval(`document.querySelector('#fail-next').checked=true`);await click('#save-food');
    check(`${scheme}: save locks duplicate submission`,await cdp.eval(`window.reviewState().pending&&document.querySelector('#save-food').disabled`));
    check(`${scheme}: pending locks form values`,await cdp.eval(`Array.from(document.querySelectorAll('#food-form input,#food-form select')).every(e=>e.disabled)`));
    await until(()=>cdp.eval('!window.reviewState().pending'));
    check(`${scheme}: failed save preserves input and retry`,await cdp.eval(`document.querySelector('.form-error').classList.contains('visible')&&document.querySelector('#food-form [name="name"]').value==='审查牛奶'&&!document.querySelector('#save-food').disabled&&window.reviewState().foodCount===8`));
    await click('#save-food');await until(()=>cdp.eval('!document.querySelector("#modal").open'));
    check(`${scheme}: retry succeeds exactly once`,await cdp.eval(`window.reviewState().foodCount===9&&!window.reviewState().pending`));
    await proto(scheme,'foods');await setInput('#food-search','牛奶');
    check(`${scheme}: name filter narrows results`,await cdp.eval(`document.querySelectorAll('.food-table-row').length===1&&document.querySelector('.food-table-row').textContent.includes('鲜牛奶')`));
    await setInput('#zone-filter','冷冻','change');check(`${scheme}: combined filters show empty recovery`,await cdp.eval(`Boolean(document.querySelector('.empty-state [data-action="reset-filters"]'))`));
    await click('[data-action="reset-filters"]');check(`${scheme}: reset restores all data`,await cdp.eval(`document.querySelectorAll('.food-table-row').length===8`));
    await setInput('#role-picker','VIEWER','change');
    check(`${scheme}: read-only disables writes`,await cdp.eval(`document.querySelector('[data-action="add"]').disabled&&Boolean(document.querySelector('.readonly-banner'))`));
    await click('[data-action="detail"][data-id="1"]');
    check(`${scheme}: read-only detail has no enabled writes`,await cdp.eval(`['use','move','edit','discard'].every(a=>document.querySelector('[data-action="'+a+'"]').disabled)`));
    await click('[data-action="close-modal"]');await setInput('#role-picker','OWNER','change');
    await click('[data-action="detail"][data-id="1"]');await click('[data-action="discard"]');
    check(`${scheme}: discard shows explicit confirmation`,await cdp.eval(`document.querySelector('#confirm-dialog').open&&document.querySelector('#confirm-dialog').textContent.includes('鲜牛奶')&&document.activeElement.dataset.action==='cancel-confirm'`));
    await click('[data-action="cancel-confirm"]');check(`${scheme}: cancel discard keeps inventory`,await cdp.eval(`window.reviewState().foodCount===8&&document.querySelector('#modal').open`));
    await click('[data-action="close-modal"]');
    const focus=await cdp.eval(`document.activeElement.dataset.action`);check(`${scheme}: closing detail returns focus`,focus==='detail',{action:focus});
    await click('[data-action="detail"][data-id="5"]');await click('[data-action="edit"]');
    check(`${scheme}: expired food remains editable with valid purchase date`,await cdp.eval(`document.querySelector('#food-form [name="purchase"]').value<=document.querySelector('#food-form [name="date"]').value`));
    await proto(scheme,'home',390,844);await click('[data-action="add"]');
    const modalLayout=await cdp.eval(`({width:innerWidth,scroll:document.querySelector('#modal').scrollWidth,rect:document.querySelector('#modal').getBoundingClientRect().width})`);
    check(`${scheme}: mobile modal fits`,modalLayout.scroll<=modalLayout.width+1&&modalLayout.rect<=modalLayout.width+1,modalLayout);
    check(`${scheme}: save action stays at modal bottom`,await cdp.eval(`Math.abs(document.querySelector('.modal-footer').getBoundingClientRect().bottom-document.querySelector('#modal').getBoundingClientRect().bottom)<=1`));
    const expectedRadius={a:12,b:10,c:6}[scheme];
    check(`${scheme}: dialog uses scheme button shape`,await cdp.eval(`parseFloat(getComputedStyle(document.querySelector('#save-food')).borderRadius)===${expectedRadius}`));
    await click('[data-action="close-modal"]');
    check(`${scheme}: mobile add shares bottom bar instead of covering door controls`,await cdp.eval(`(()=>{const b=document.querySelector('.bottom-add');const r=b.getBoundingClientRect(),nav=b.closest('.bottom-nav').getBoundingClientRect();return r.left>=nav.left&&r.right<=nav.right&&r.top>=nav.top&&r.bottom<=nav.bottom;})()`));
    await cdp.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});
    check(`${scheme}: reduced motion respected`,await cdp.eval(`parseFloat(getComputedStyle(document.querySelector('.btn')).transitionDuration)<.01`));
    await cdp.send('Emulation.setEmulatedMedia',{features:[]});
    console.log('Completed scheme',scheme.toUpperCase());
  }
  if(!verifyOnly){for(const scheme of ['a','b','c']){await viewport(1800,1500);await open(`${base}/board.html?scheme=${scheme}`);await shot(path.join(designDir,`review-${scheme}.png`),true);}}
  await viewport(1440,1100);await open(`${base}/index.html`);
  check('Review entry: all preview images loaded',await cdp.eval('Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0)'));
  if(!verifyOnly)await shot(path.join(designDir,'review-overview.png'),true);
  check('Browser: no runtime exceptions',errors.length===0,errors);
  check('Local resources: no missing assets',resourceFailures.length===0,resourceFailures);
  const contrast=(fg,bg)=>{const lum=h=>{const rgb=h.replace('#','').match(/../g).map(x=>parseInt(x,16)/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4);return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722;};const a=lum(fg),b=lum(bg);return (Math.max(a,b)+.05)/(Math.min(a,b)+.05);};
  for(const [name,fg,bg,min]of [['body','#171a1d','#ffffff',4.5],['secondary','#59636d','#ffffff',4.5],['secondary on cool','#59636d','#e5edf2',4.5],['primary','#ffffff','#171a1d',4.5],['input border','#85919b','#ffffff',3],['focus','#344f66','#ffffff',3],['danger','#963d45','#f6ecee',4.5],['warning','#735522','#f4f0e7',4.5]]){const ratio=contrast(fg,bg);check(`Contrast: ${name}`,ratio>=min,{ratio:Number(ratio.toFixed(2)),minimum:min});}
}catch(error){check('Capture/verification completed',false,error.stack);console.error(error.stack);}
finally{
  const summary={date:'2026-11-10',scope:'Isolated design proposal only; not Flutter, backend or real-world end-to-end acceptance.',checks:results.length,passed:results.filter(r=>r.passed).length,failed:results.filter(r=>!r.passed).length,results};
  fs.mkdirSync(evidenceDir,{recursive:true});fs.writeFileSync(path.join(evidenceDir,'browser-checks.json'),JSON.stringify(summary,null,2)+'\n');
  console.log(JSON.stringify({checks:summary.checks,passed:summary.passed,failed:summary.failed,evidence:path.join(evidenceDir,'browser-checks.json')}));
  if(cdp){try{await cdp.send('Browser.close');}catch{}cdp.socket.close();}
  if(browser){browser.kill();await sleep(300);}
  await new Promise(resolve=>server.close(resolve));
  // Verify the exact, task-owned profile path before a recursive cleanup.
  const safePrefix=path.resolve(os.tmpdir(),'xiaoyi-ui-review-');
  if(path.resolve(profile).startsWith(safePrefix)&&path.dirname(profile)===path.resolve(os.tmpdir())){try{fs.rmSync(profile,{recursive:true,force:true});}catch{}}
  if(summary.failed)process.exitCode=1;
}
