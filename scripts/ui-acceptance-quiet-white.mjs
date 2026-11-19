// Actual release Flutter/WebGL checks, native CDP input and isolated recipe DB.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {spawn} from 'node:child_process';
import {setTimeout as sleep} from 'node:timers/promises';
const APP=process.env.APP_URL||'http://127.0.0.1:18000';
const OUT='docs/reviews/evidence/2026-11-10-quiet-white';
const checks=[],events=[];let cdp,edge;
fs.mkdirSync(OUT,{recursive:true});
function check(name,pass,detail=''){checks.push({name,pass:Boolean(pass),detail});console.log(`${pass?'PASS':'FAIL'} ${name} ${detail}`);if(!pass)throw Error(name);}
async function until(fn,timeout=30000){const deadline=Date.now()+timeout;while(Date.now()<deadline){const value=await fn();if(value)return value;await sleep(150);}throw Error('Timed out waiting for UI state');}
class Cdp{
 constructor(ws){this.ws=ws;this.id=0;this.pending=new Map();ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.method)events.push(m);if(m.id){const p=this.pending.get(m.id);if(p){this.pending.delete(m.id);clearTimeout(p.timer);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}}});}
 send(method,params={}){return new Promise((resolve,reject)=>{const id=++this.id;const timer=setTimeout(()=>{this.pending.delete(id);reject(Error(method+' timeout'));},20000);this.pending.set(id,{resolve,reject,timer});this.ws.send(JSON.stringify({id,method,params}));});}
 async eval(expression){const r=await this.send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description||r.exceptionDetails.text);return r.result?.value;}
 async click(x,y){await this.send('Input.dispatchMouseEvent',{type:'mouseMoved',x,y});for(const type of ['mousePressed','mouseReleased'])await this.send('Input.dispatchMouseEvent',{type,x,y,button:'left',clickCount:1});await sleep(250);}
 async label(text,scroll=false){let tries=0;const r=await until(async()=>{const rect=await this.eval(`(()=>{const elements=[...document.querySelectorAll('[aria-label],flt-semantics')].filter(e=>{const text=(e.getAttribute('aria-label')||e.textContent||'').trim(),r=e.getBoundingClientRect();return(text===${JSON.stringify(text)}||text.startsWith(${JSON.stringify(text+'\n')}))&&r.width>0&&r.height>0&&r.top>=0&&r.bottom<=innerHeight;}).sort((a,b)=>a.getBoundingClientRect().width*a.getBoundingClientRect().height-b.getBoundingClientRect().width*b.getBoundingClientRect().height);const r=elements[0]?.getBoundingClientRect();return r?{x:r.x+r.width/2,y:r.y+r.height/2}:null;})()`);if(!rect&&scroll&&tries++<10)await wheel(400);return rect;},12000);await this.click(r.x,r.y);}
 async shot(name){const {data}=await this.send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(OUT,name+'.png'),Buffer.from(data,'base64'));}
}
async function viewport(width,height){await cdp.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<761});await cdp.send('Page.captureScreenshot',{format:'png'});await sleep(350);}
async function wheel(delta,edge=false){const {w,h}=await cdp.eval('({w:innerWidth,h:innerHeight})');await cdp.send('Input.dispatchMouseEvent',{type:'mouseWheel',x:edge?w-6:w/2,y:h*.58,deltaX:0,deltaY:delta});await sleep(350);}
async function semantics(){await cdp.eval("document.querySelector('flt-semantics-placeholder')?.click();true");await until(()=>cdp.eval("document.querySelectorAll('flt-semantics').length>2"));}
const frameFunction=`function(){const roots=[document];for(let i=0;i<roots.length;i++){for(const e of roots[i].querySelectorAll('*'))if(e.shadowRoot)roots.push(e.shadowRoot);for(const frame of roots[i].querySelectorAll('iframe')){const r=frame.getBoundingClientRect();if(r.width>100&&r.height>100&&frame.contentDocument?.querySelector('#scene'))return frame;}}return null;}`;
async function sceneReady(){return until(()=>cdp.eval(`(()=>{const f=(${frameFunction})();const s=f?.contentDocument?.querySelector('#scene');return Boolean(s?.dataset.ready==='true'&&s.dataset.settled==='true');})()`),40000);}
async function sceneClick(id){let point,visible=false;for(let i=0;i<10;i++){point=await cdp.eval(`(()=>{const f=(${frameFunction})();const e=f?.contentDocument?.getElementById(${JSON.stringify(id)});if(!e)return null;const a=f.getBoundingClientRect(),b=e.getBoundingClientRect();return{x:a.x+b.x+b.width/2,y:a.y+b.y+b.height/2,h:innerHeight,w:innerWidth};})()`);if(point&&point.y>80&&point.y<point.h-(point.w<1000?160:30)){visible=true;break;}await wheel(point&&point.y<80?-180:180,true);}if(!point||!visible)throw Error('Scene control is outside the visible content: '+id);await cdp.click(point.x,point.y);await sceneReady();}
async function sceneState(){return cdp.eval(`(()=>{const f=(${frameFunction})();const d=f.contentDocument,s=d.querySelector('#scene'),c=d.querySelector('canvas').getBoundingClientRect(),b=d.querySelector('.controls').getBoundingClientRect();return{open:(s.dataset.openParts||'').split(',').filter(Boolean).sort(),count:Number(s.dataset.inventoryCount),version:s.dataset.sceneVersion,noOverlap:c.bottom<=b.top+1,buttons:[...d.querySelectorAll('.controls button')].every(e=>e.getBoundingClientRect().height>=44)};})()`);}
async function api(route,{token,method='GET',body,expect=200}={}){const r=await fetch(APP+route,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(body?{body:JSON.stringify(body)}:{})});const data=await r.json();if(r.status!==expect)throw Error(`${method} ${route}: ${r.status} ${data.message}`);return data.data;}
async function createFixture(){
 const username='quiet_ui_'+Date.now(),password='QuietWhite2026!';
 const session=await api('/api/v1/auth/register',{method:'POST',body:{username,password,displayName:'静白验收'},expect:201});
 const token=session.accessToken;
 const created=await api('/api/v1/families/workspaces',{token,method:'POST',body:{name:'静白验收厨房',requestId:'quiet_'+Date.now()},expect:201});
 const family=created.family,workspace=await api('/api/v1/fridges?familyId='+family.id,{token});
 const fresh=workspace.zones.find(z=>z.code==='FRESH'||z.code==='fresh'||z.name==='冷藏');
 if(!fresh)throw Error('Fresh zone missing');
 const date=offset=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Shanghai',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(Date.now()+offset*86400000));
 for(const [name,quantity,unit,category,offset] of [['番茄',3,'个','蔬菜',1],['鸡蛋',6,'枚','蛋类',6],['食用油',50,'毫升','调味品',60],['盐',100,'克','调味品',90],['西兰花',1,'棵','蔬菜',2],['鲜牛奶',1,'盒','奶制品',2],['鸡胸肉',250,'克','肉类',3],['嫩豆腐',350,'克','豆制品',2]]){
   await api('/api/v1/foods',{token,method:'POST',body:{fridgeId:workspace.id,zoneId:fresh.id,name,quantity,unit,category,productionDate:date(-2),expiresOn:date(offset),tags:[]},expect:201});
 }
 const recipes=await api('/api/v1/recipes',{token});check('real-gateway-catalog-has-18-recipes',recipes.length===18);
 const viewerUsername='quiet_view_'+Date.now();
 const viewer=await api('/api/v1/auth/register',{method:'POST',body:{username:viewerUsername,password,displayName:'只读验收'},expect:201});
 await api('/api/v1/fridges?familyId='+family.id,{token:viewer.accessToken,expect:404});check('real-cross-family-access-is-rejected',true,'404 hides inaccessible family existence');
 await api('/api/v1/families/join',{token:viewer.accessToken,method:'POST',body:{inviteCode:family.inviteCode}});
 await api('/api/v1/foods',{token:viewer.accessToken,method:'POST',body:{fridgeId:workspace.id,zoneId:fresh.id,name:'只读不能新增',quantity:1,unit:'份',category:'其他',productionDate:date(-1),expiresOn:date(2),tags:[]},expect:403});check('real-viewer-write-is-rejected',true);
 const expected=JSON.parse(fs.readFileSync('apps/fridge-app/assets/data/home-recipes-v2.json','utf8'));
 check('real-mysql-catalog-matches-demo-names-and-steps',expected.every(r=>recipes.some(v=>v.id===r.id&&v.name===r.name&&JSON.stringify(v.steps)===JSON.stringify(r.steps))));
 fs.writeFileSync(path.join(OUT,'ui-fixture.json'),JSON.stringify({date:'2026-11-10',username,familyId:family.id,fridgeId:workspace.id,foodCount:8,recipeCount:18,scope:'New local acceptance account and family only; tokens omitted'},null,2));
 return{username,password,token,family,workspace,viewerUsername};
}
async function main(){
 const fixture=await createFixture();
 edge=spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--remote-debugging-port=9342','--window-size=1440,1000','--force-device-scale-factor=1','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-first-run','--no-default-browser-check','--disable-extensions',`--user-data-dir=${path.join(os.tmpdir(),'xiaoyi-white-ui-'+Date.now())}`,'about:blank'],{stdio:'ignore',windowsHide:true});
 await until(async()=>{try{return(await fetch('http://127.0.0.1:9342/json/version')).ok;}catch{return false;}});
 const target=await fetch('http://127.0.0.1:9342/json/new?about:blank',{method:'PUT'}).then(r=>r.json());const ws=new WebSocket(target.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});cdp=new Cdp(ws);
 for(const method of ['Page.enable','Runtime.enable','Network.enable'])await cdp.send(method);
 await viewport(1440,1000);await cdp.send('Page.navigate',{url:APP});await sleep(5000);await semantics();await cdp.shot('ui-login-desktop');
 await cdp.label('用户名或手机号');await cdp.send('Input.insertText',{text:fixture.username});await cdp.label('密码');await cdp.send('Input.insertText',{text:fixture.password});await cdp.label('进入我的冰箱');
 await until(()=>cdp.eval("location.href.includes('/home')"));await sceneReady();await sleep(600);
 let scene=await sceneState();check('real-ui-inventory-synced-to-scene',scene.count===8,JSON.stringify(scene));check('new-scene-controls-do-not-cover-canvas',scene.noOverlap&&scene.buttons);
 await cdp.shot('ui-home-desktop');
 for(const [width,height,label]of [[1440,1000,'desktop'],[390,844,'mobile']]){
   await viewport(width,height);await sceneReady();await sceneClick('close-all');
   const ids=['left-door','right-door','variable-drawer','freezer-drawer'],parts=['leftDoor','rightDoor','middleDrawer','freezerDrawer'];let mask=0;
   for(let i=0;i<16;i++){const next=i^(i>>1);for(let bit=0;bit<4;bit++)if((next^mask)&(1<<bit))await sceneClick(ids[bit]);mask=next;scene=await sceneState();const expected=parts.filter((_,bit)=>mask&(1<<bit)).sort();check(`${label}-door-combination-${mask}`,JSON.stringify(scene.open)===JSON.stringify(expected));}
   await sceneClick('close-all');scene=await sceneState();check(`${label}-scene-control-layout`,scene.noOverlap&&scene.buttons);
   if(label==='mobile')await cdp.shot('ui-home-mobile');
 }
 await viewport(1440,1000);await cdp.label('菜谱灵感');await sleep(1200);await cdp.shot('ui-recipes-desktop');
 check('recipes-page-loaded-through-real-api',events.some(e=>e.method==='Network.responseReceived'&&e.params.response.url.endsWith('/api/v1/recipes')&&e.params.response.status===200));
 await cdp.label('搜索菜谱名称');await cdp.send('Input.insertText',{text:'麻婆豆腐'});await sleep(500);await cdp.shot('ui-recipe-search');await cdp.label('麻婆豆腐');await sleep(500);await cdp.shot('ui-recipe-detail');
 check('new-recipe-details-rendered',await cdp.eval("[...document.querySelectorAll('flt-semantics')].some(e=>(e.getAttribute('aria-label')||e.textContent||'').includes('嫩豆腐'))"));
 check('optional-ingredients-have-explicit-neutral-state',await cdp.eval("['花椒粉','小葱'].every(name=>[...document.querySelectorAll('flt-semantics')].some(e=>(e.getAttribute('aria-label')||e.textContent||'').startsWith('可选原料\\n'+name)))"));
 await cdp.label('关闭菜谱详情');await sleep(300);await cdp.label('清除搜索');
 for(let i=0;i<6;i++)await wheel(600);
 const photos=new Set(events.filter(e=>e.method==='Network.responseReceived'&&e.params.response.status===200&&e.params.response.url.includes('/quiet-white-v2/')&&e.params.response.url.endsWith('.jpg')).map(e=>e.params.response.url.split('/').pop()));
 check('all-eighteen-new-photos-load-in-real-grid',photos.size===18,'images='+photos.size);
 await viewport(390,844);await wheel(-10000);await sleep(500);await cdp.shot('ui-recipes-mobile');
 await cdp.label('家庭');await sleep(500);await cdp.shot('ui-family-mobile');
 await viewport(1440,1000);await cdp.label('家庭设置');await sleep(300);await cdp.shot('ui-family-desktop');
 await cdp.label('菜谱灵感');await wheel(-10000);await cdp.label('搜索菜谱名称');await cdp.send('Input.insertText',{text:'番茄滑蛋'});await sleep(400);await cdp.label('番茄滑蛋');await cdp.label('用现有食材做这道菜',true);await sleep(300);await cdp.shot('ui-cook-confirm');
 await cdp.label('确认做饭并扣减');await until(()=>events.some(e=>e.method==='Network.responseReceived'&&e.params.response.url.includes('/cook-records')&&e.params.response.status===201));await sleep(700);
 const records=await api('/api/v1/fridges/'+fixture.workspace.id+'/cook-records',{token:fixture.token});check('new-ui-cook-recorded-once',records.length===1&&records[0].recipeId===1);
 await cdp.label('家庭设置');await cdp.label('退出当前账号',true);await cdp.label('退出');await until(()=>cdp.eval("location.href.includes('/login')"));
 await cdp.label('用户名或手机号');await cdp.send('Input.insertText',{text:fixture.viewerUsername});await cdp.label('密码');await cdp.send('Input.insertText',{text:fixture.password});await cdp.label('进入我的冰箱');await until(()=>cdp.eval("location.href.includes('/home')"));await sceneReady();
 check('real-viewer-ui-disables-add-food',await cdp.eval("[...document.querySelectorAll('[aria-disabled=\"true\"]')].some(e=>(e.getAttribute('aria-label')||e.textContent||'').includes('新增食材'))"));await cdp.shot('ui-home-viewer');
 const exceptions=events.filter(e=>e.method==='Runtime.exceptionThrown');check('no-browser-runtime-exceptions',exceptions.length===0);
 const failedAssets=events.filter(e=>e.method==='Network.responseReceived'&&e.params.response.url.includes('/assets/')&&e.params.response.status>=400);check('no-failed-assets',failedAssets.length===0);
 await viewport(1800,1400);await cdp.send('Page.navigate',{url:APP+'/docs/design/ui-redesign-2026-11-10/recipe-gallery.html'});await until(()=>cdp.eval('document.images.length===18&&[...document.images].every(i=>i.complete&&i.naturalWidth>0)'));await cdp.eval('document.fonts.ready.then(()=>true)');await cdp.shot('recipe-gallery');
}
try{await main();}catch(error){console.error(error.stack);if(cdp){await cdp.shot('ui-failure');fs.writeFileSync(path.join(OUT,'ui-debug.json'),JSON.stringify(await cdp.eval(`(()=>({url:location.href,labels:[...document.querySelectorAll('[aria-label],flt-semantics')].map(e=>(e.getAttribute('aria-label')||e.textContent||'').trim()).filter(Boolean).slice(-160)}))()`),null,2));}checks.push({name:'acceptance-completed',pass:false,detail:String(error)});process.exitCode=1;}
finally{fs.writeFileSync(path.join(OUT,'browser-acceptance.json'),JSON.stringify({date:'2026-11-10',scope:'Actual Flutter release + isolated MySQL recipe/gateway + existing local auth/fridge; new acceptance account only. Software WebGL, not device/GPU acceptance.',checks,passed:checks.filter(c=>c.pass).length,failed:checks.filter(c=>!c.pass).length},null,2));if(cdp){try{await cdp.send('Browser.close');}catch{}cdp.ws.close();}edge?.kill();console.log(JSON.stringify({passed:checks.filter(c=>c.pass).length,failed:checks.filter(c=>!c.pass).length}));}
