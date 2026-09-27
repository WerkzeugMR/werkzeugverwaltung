const CACHE="werkzeug-v2026-09-27";
self.addEventListener("install",event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(["./","./index.html","./manifest.webmanifest"]))));
self.addEventListener("activate",event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))));
self.addEventListener("fetch",event=>event.respondWith(caches.match(event.request).then(r=>r||fetch(event.request))));
