// One-time release UI review. Demo account only; no backend business writes.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {setTimeout as sleep} from 'node:timers/promises';

const out='docs/reviews/evidence/2026-11-10-scope-cleanup';
fs.mkdirSync(out,{recursive:true});
const checks=[],events=[],pending=new Map();
let browser,ws,id=0;
function check(name,pass,detail=''){checks.push({name,pass:Boolean(pass),detail});console.log(`${pass?'PASS':'FAIL'} ${name}`);if(!pass)throw Error(name);}
async function until(fn,ms=35000){const end=Date.now()+ms;while(Date.now()<end){const value=await fn();if(value)return value;await sleep(120);}throw Error('UI wait timed out');}
function send(method,params={}){return new Promise((resolve,reject)=>{const key=++id;const timer=setTimeout(()=>{pending.delete(key);reject(Error(method+' timed out'));},20000);pending.set(key,{resolve,reject,timer});ws.send(JSON.stringify({id:key,method,params}));});}
async function evaluate(expression){const result=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(result.exceptionDetails)throw Error(result.exceptionDetails.exception?.description||result.exceptionDetails.text);return result.result?.value;}
async function clickLabel(label){const point=await until(()=>evaluate(`(()=>{const nodes=[...document.querySelectorAll('flt-semantics,[aria-label]')].filter(e=>{const s=(e.getAttribute('aria-label')||e.textContent||'').trim(),r=e.getBoundingClientRect();return s===${JSON.stringify(label)}&&r.width>0&&r.height>0&&r.top>=0&&r.bottom<=innerHeight;}).sort((a,b)=>a.getBoundingClientRect().width*a.getBoundingClientRect().height-b.getBoundingClientRect().width*b.getBoundingClientRect().height);const r=nodes[0]?.getBoundingClientRect();return r?{x:r.x+r.width/2,y:r.y+r.height/2}:null;})()`));for(const type of ['mousePressed','mouseReleased'])await send('Input.dispatchMouseEvent',{type,...point,button:'left',clickCount:1});await sleep(250);}
async function shot(label){const {data}=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,label+'.png'),Buffer.from(data,'base64'));}
async function labels(){return evaluate("[...document.querySelectorAll('flt-semantics')].map(e=>(e.getAttribute('aria-label')||e.textContent||'').trim()).filter(Boolean)");}
try{
  browser=spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--remote-debugging-port=9347','--window-size=1440,1000','--force-device-scale-factor=1','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-first-run','--no-default-browser-check','--disable-extensions','--user-data-dir='+path.join(os.tmpdir(),'xiaoyi-scope-'+Date.now()),'about:blank'],{stdio:'ignore',windowsHide:true});
  await until(async()=>{try{return(await fetch('http://127.0.0.1:9347/json/version')).ok;}catch{return false;}});
  const target=await fetch('http://127.0.0.1:9347/json/new?about:blank',{method:'PUT'}).then(r=>r.json());
  ws=new WebSocket(target.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
  ws.addEventListener('message',event=>{const message=JSON.parse(event.data);if(message.method)events.push(message);if(message.id){const p=pending.get(message.id);if(p){pending.delete(message.id);clearTimeout(p.timer);message.error?p.reject(Error(message.error.message)):p.resolve(message.result);}}});
  for(const method of ['Page.enable','Runtime.enable','Network.enable'])await send(method);
  await send('Page.navigate',{url:'http://127.0.0.1:18000/'});
  await until(()=>evaluate("Boolean(document.querySelector('flt-semantics-placeholder'))"));
  await evaluate("document.querySelector('flt-semantics-placeholder').click();true");
  await clickLabel('先用演示数据看看');
  await until(async()=> (await labels()).some(s=>s==='家庭设置'));
  await clickLabel('家庭设置');
  for(const [width,height,label]of [[1440,1000,'desktop'],[390,844,'mobile'],[320,740,'narrow']]){
    await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<1000});await sleep(450);
    let text=await labels();
    check(label+'-family-heading',text.some(s=>s==='家庭协作'));
    check(label+'-no-placeholder-settings',!text.some(s=>/临期提醒|冰箱布局|偏好设置|外观与可访问性|尚未接入/.test(s)));
    fs.writeFileSync(path.join(out,'semantics-'+label+'.json'),JSON.stringify(text,null,2));
    check(label+'-family-actions-retained',text.some(s=>s.includes('创建家庭'))&&text.some(s=>s.includes('加入家庭'))&&text.some(s=>s.includes('我的家庭')));
    check(label+'-logout-retained',text.some(s=>s==='退出当前账号'));
    await shot('family-'+label);
    for(let i=0;i<6;i++){
      const visible=await evaluate("(()=>{const r=[...document.querySelectorAll('flt-semantics')].find(e=>(e.getAttribute('aria-label')||'').trim()==='退出当前账号')?.getBoundingClientRect();return r&&r.top>=70&&r.bottom<innerHeight-90;})()");
      if(visible)break;
      await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:width-8,y:height*.55,deltaX:0,deltaY:240});await sleep(200);
    }
    await clickLabel('退出当前账号');
    check(label+'-logout-confirmation', (await labels()).some(s=>s==='要离开冰箱了吗？'));
    await clickLabel('留下');
    check(label+'-cancel-preserves-session', (await labels()).some(s=>s==='家庭协作'));
  }
  check('no-runtime-exceptions',!events.some(e=>e.method==='Runtime.exceptionThrown'));
  check('no-backend-business-writes',!events.some(e=>e.method==='Network.requestWillBeSent'&&e.params.request.url.includes('/api/')&&e.params.request.method!=='GET'));
}catch(error){checks.push({name:'completed',pass:false,detail:String(error)});console.error(error.stack);process.exitCode=1;if(ws?.readyState===1)await shot('failure');}
finally{
  fs.writeFileSync(path.join(out,'browser-review.json'),JSON.stringify({date:'2026-11-10',scope:'Actual current release, demo session, Edge software rendering; no real-account E2E or physical-device acceptance.',checks,passed:checks.filter(c=>c.pass).length,failed:checks.filter(c=>!c.pass).length},null,2));
  if(ws?.readyState===1){try{await send('Browser.close');}catch{}ws.close();}browser?.kill();
  console.log(JSON.stringify({passed:checks.filter(c=>c.pass).length,failed:checks.filter(c=>!c.pass).length}));
}
