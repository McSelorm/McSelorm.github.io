// Grow With Selorm service worker: lets the app open fast and show a friendly page when offline.
// It only stores the website's own pages and pictures. It never stores logins, IDs or database data.
const CACHE = 'gws-v1';
const CORE = ['/', '/planner/', '/about/', '/privacy/', '/terms/', '/offline.html', '/icons/icon-192.png', '/manifest.webmanifest'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== location.origin) return; // never touch Supabase, forms or other sites
  if (req.mode === 'navigate') {
    // pages: try the internet first (always newest), fall back to saved copy, then the offline page
    e.respondWith(fetch(req).then(res => {
      const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); return res;
    }).catch(() => caches.match(req).then(r => r || caches.match('/offline.html'))));
    return;
  }
  // pictures, icons and scripts from this site: saved copy first, update in the background
  e.respondWith(caches.match(req).then(cached => {
    const net = fetch(req).then(res => { if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); } return res; }).catch(() => cached);
    return cached || net;
  }));
});
