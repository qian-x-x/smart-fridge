// Serves the actual release build and proxies its API to a gateway.
// Defaults to a loopback-only preview of the isolated acceptance gateway.
// Set PREVIEW_HOST=0.0.0.0 to expose it on the LAN (Docker Desktop on Windows
// publishes container ports on loopback only, so a LAN entry needs a host-side
// listener); set PREVIEW_API/PREVIEW_PORT to point at another gateway/port.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const build=path.join(root,'apps/fridge-app/build/web');
const port=Number(process.env.PREVIEW_PORT||18000);
const host=process.env.PREVIEW_HOST||'127.0.0.1';
const api=new URL(process.env.PREVIEW_API||'http://127.0.0.1:18080');
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml','.wasm':'application/wasm','.ttf':'font/ttf','.otf':'font/otf'};
const server=http.createServer((req,res)=>{
  const url=new URL(req.url,'http://local');
  if(url.pathname.startsWith('/api/')) {
    const proxy=http.request(new URL(url.pathname+url.search,api),{method:req.method,headers:{...req.headers,host:api.host}},incoming=>{
      res.writeHead(incoming.statusCode,incoming.headers);incoming.pipe(res);
    });
    proxy.on('error',()=>{if(!res.headersSent)res.writeHead(502);res.end('Acceptance API unavailable');});
    req.pipe(proxy);return;
  }
  let rel;
  try{rel=decodeURIComponent(url.pathname).replace(/^\/+/, '');}catch{res.writeHead(400);res.end();return;}
  let base=build;
  for(const prefix of ['docs/design/ui-redesign-2026-11-10/','apps/fridge-app/assets/']) {
    if(rel.startsWith(prefix)){base=path.resolve(root,prefix);rel=rel.slice(prefix.length);break;}
  }
  let file=path.resolve(base,rel||'index.html');
  if(!file.startsWith(base+path.sep)){res.writeHead(403);res.end();return;}
  if(!fs.existsSync(file)||fs.statSync(file).isDirectory()){
    if(path.extname(rel)){res.writeHead(404);res.end('Not found');return;}
    file=path.join(build,'index.html');
  }
  res.setHeader('Cache-Control','no-store');
  res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');
  const stream=fs.createReadStream(file);stream.on('error',()=>{if(!res.headersSent)res.writeHead(404);res.end();});stream.pipe(res);
});
server.listen(port,host,()=>console.log(`Quiet-white preview: http://${host}:${port}`));
process.on('SIGINT',()=>server.close(()=>process.exit(0)));
