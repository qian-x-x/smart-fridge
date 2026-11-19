// Capture the actual release home in demo mode; no accounts or business writes.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {setTimeout as sleep} from 'node:timers/promises';

const app=process.env.APP_URL||'http://127.0.0.1:18000';
const out='docs/reviews/evidence/2026-11-10-kitchen-tone';
fs.mkdirSync(out,{recursive:true});
const checks=[],events=[];
let browser,ws,id=0;
const pending=new Map();
function check(name,pass,detail){checks.push({name,pass:Boolean(pass),detail});if(!pass)throw Error(name);console.log('PASS '+name);}
async function until(fn,ms=40000){const end=Date.now()+ms;while(Date.now()<end){const result=await fn();if(result)return result;await sleep(120);}throw Error('UI wait timed out');}
function send(method,params={}){return new Promise((resolve,reject)=>{const key=++id;const timer=setTimeout(()=>{pending.delete(key);reject(Error(method+' timed out'));},20000);pending.set(key,{resolve,reject,timer});ws.send(JSON.stringify({id:key,method,params}));});}
async function evaluate(expression){const result=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(result.exceptionDetails)throw Error(result.exceptionDetails.text);return result.result?.value;}
async function click(x,y){for(const type of ['mousePressed','mouseReleased'])await send('Input.dispatchMouseEvent',{type,x,y,button:'left',clickCount:1});await sleep(180);}
async function screenshot(name){const {data}=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(data,'base64'));}
async function viewport(width,height){await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<1000});await sleep(300);}
const frameFinder=`function(){const roots=[document];for(let i=0;i<roots.length;i++){for(const e of roots[i].querySelectorAll('*'))if(e.shadowRoot)roots.push(e.shadowRoot);for(const f of roots[i].querySelectorAll('iframe'))if(f.getBoundingClientRect().width>100&&f.contentDocument?.querySelector('#scene'))return f;}return null;}`;
async function sceneReady(){await until(()=>evaluate(`(()=>{const f=(${frameFinder})();const s=f?.contentDocument?.querySelector('#scene');return s?.dataset.ready==='true'&&s.dataset.settled==='true';})()`));}
async function action(button){await evaluate(`(()=>{(${frameFinder})().contentDocument.getElementById(${JSON.stringify(button)}).click();return true;})()`);await sceneReady();}
async function sceneInfo(){return evaluate(`(()=>{const f=(${frameFinder})();const d=f.contentDocument,s=d.querySelector('#scene'),a=d.querySelector('canvas').getBoundingClientRect(),b=d.querySelector('.controls').getBoundingClientRect();return{version:s.dataset.sceneVersion,open:(s.dataset.openParts||'').split(',').filter(Boolean).sort(),inventory:Number(s.dataset.inventoryCount),noOverlap:a.bottom<=b.top+1,buttons:[...d.querySelectorAll('.controls button')].every(e=>e.getBoundingClientRect().height>=44)};})()`);}
async function scrollToScene(){for(let i=0;i<10;i++){const p=await evaluate(`(()=>{const r=(${frameFinder})().getBoundingClientRect();return{top:r.top,bottom:r.bottom,h:innerHeight,w:innerWidth};})()`);if(p.top>=70&&p.bottom<=p.h-150)return;await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:p.w-5,y:p.h*.55,deltaX:0,deltaY:p.bottom>p.h-150?140:-120});await sleep(200);}throw Error('Scene cannot fit in mobile content');}

try{
 browser=spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--remote-debugging-port=9343','--window-size=1440,1000','--force-device-scale-factor=1','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-first-run','--no-default-browser-check','--disable-extensions','--user-data-dir='+path.join(os.tmpdir(),'xiaoyi-tone-'+Date.now()),'about:blank'],{stdio:'ignore',windowsHide:true});
 await until(async()=>{try{return(await fetch('http://127.0.0.1:9343/json/version')).ok;}catch{return false;}});
 const target=await fetch('http://127.0.0.1:9343/json/new?about:blank',{method:'PUT'}).then(r=>r.json());
 ws=new WebSocket(target.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
 ws.addEventListener('message',event=>{const result=JSON.parse(event.data);if(result.method)events.push(result);if(result.id){const p=pending.get(result.id);if(p){pending.delete(result.id);clearTimeout(p.timer);result.error?p.reject(Error(result.error.message)):p.resolve(result.result);}}});
 for(const method of ['Page.enable','Runtime.enable','Network.enable'])await send(method);
 await viewport(1440,1000);await send('Page.navigate',{url:app});
 await until(()=>evaluate("Boolean(document.querySelector('flt-semantics-placeholder'))"));await evaluate("document.querySelector('flt-semantics-placeholder').click();true");
 await until(()=>events.some(e=>e.method==='Network.responseReceived'&&e.params.response.url.includes('/kitchen-gray-white-v2.0.1.png')&&e.params.response.status===200));
 check('new-login-reference-loaded',true);await screenshot('login-desktop');
 const entry=await until(()=>evaluate("(()=>{const e=[...document.querySelectorAll('flt-semantics,[aria-label]')].filter(e=>(e.getAttribute('aria-label')||e.textContent||'').trim()==='先用演示数据看看').sort((a,b)=>a.getBoundingClientRect().width*a.getBoundingClientRect().height-b.getBoundingClientRect().width*b.getBoundingClientRect().height)[0];const r=e?.getBoundingClientRect();return r&&r.width>0?{x:r.x+r.width/2,y:r.y+r.height/2}:null;})()"));
 await click(entry.x,entry.y);await sceneReady();
 for(const [width,height,label]of [[1440,1000,'desktop'],[390,844,'mobile']]){
   await viewport(width,height);await sceneReady();await action('close-all');
   if(label==='mobile')await scrollToScene();
   let info=await sceneInfo();check(label+'-new-scene-version',info.version==='quiet-white-v2.0.1',info);
   check(label+'-controls-and-inventory',info.noOverlap&&info.buttons&&info.inventory>0,info);
   check(label+'-closed-state',info.open.length===0);await screenshot('home-'+label+'-closed');
   await action('overview');info=await sceneInfo();check(label+'-open-state',info.open.length===4,info);
   await screenshot('home-'+label+'-open');
 }
 check('no-runtime-exceptions',!events.some(e=>e.method==='Runtime.exceptionThrown'));
 check('no-failed-scene-assets',!events.some(e=>e.method==='Network.responseReceived'&&e.params.response.url.includes('/fridge3d/')&&e.params.response.status>=400));
}catch(error){console.error(error.stack);checks.push({name:'completed',pass:false,detail:String(error)});process.exitCode=1;if(ws?.readyState===1)await screenshot('failure');}
finally{
 fs.writeFileSync(path.join(out,'browser-review.json'),JSON.stringify({date:'2026-11-10',scope:'Actual release home, demo inventory, software WebGL; no business writes or physical device acceptance.',checks,passed:checks.filter(c=>c.pass).length,failed:checks.filter(c=>!c.pass).length},null,2));
 if(ws?.readyState===1){try{await send('Browser.close');}catch{}ws.close();}browser?.kill();
 console.log(JSON.stringify({passed:checks.filter(c=>c.pass).length,failed:checks.filter(c=>!c.pass).length}));
}
