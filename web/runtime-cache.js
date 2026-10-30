/* Cache only public, content-addressed engine/game assets. Never cache accounts. */
const CACHE='inside-lasu-runtime-v2';
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);
 if(event.request.method!=='GET'||url.origin!==self.location.origin||!/(?:engine-[a-f0-9]{16}\.wasm|campus-[a-f0-9]{16}\.pck|runtime-[a-f0-9]{16}\.js)$/.test(url.pathname))return;
 event.respondWith((async()=>{
  const cache=await caches.open(CACHE);
  const old=await cache.match(event.request);if(old)return old;
  let response;
  if((url.pathname.endsWith('.wasm') || url.pathname.endsWith('.pck')) && typeof DecompressionStream !== 'undefined'){
   try{
    const packed=await fetch(url.href+'.gz');
    if(!packed.ok)throw new Error('No compressed engine');
    response=new Response(packed.body.pipeThrough(new DecompressionStream('gzip')),{headers:{'Content-Type':url.pathname.endsWith('.wasm')?'application/wasm':'application/octet-stream'}});
   }catch(_){response=await fetch(event.request);}
  }else{response=await fetch(event.request);}
  if(response.ok){const copy=response.clone();event.waitUntil((async()=>{try{await cache.put(event.request,copy);const keys=await cache.keys();while(keys.length>8)await cache.delete(keys.shift());}catch(_){/* storage pressure must not prevent play */}})());}
  return response;
 })());
});
