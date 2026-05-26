const CACHE_NAME   = "cobranca-em-dia-v2";
const SHARED_CACHE = "shared-receipts";

// App shell: pages to pre-cache on install
const APP_SHELL = [
  "/app",
  "/offline"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME && key !== SHARED_CACHE)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// ── Web Share Target handler ──────────────────────────────────────────
async function handleShareTarget(request) {
  try {
    const formData = await request.formData();
    const file = formData.get("receipt");
    if (!file || !file.size) {
      return Response.redirect("/app/share-receipt?error=no_file", 303);
    }
    const token = crypto.randomUUID();
    const cache = await caches.open(SHARED_CACHE);
    const headers = new Headers({
      "Content-Type": file.type || "application/octet-stream",
      "X-Filename":   encodeURIComponent(file.name || "comprovante"),
    });
    await cache.put(`/__shared/${token}`, new Response(file, { headers }));
    return Response.redirect(`/app/share-receipt?token=${token}`, 303);
  } catch {
    return Response.redirect("/app/share-receipt?error=failed", 303);
  }
}

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  // Intercept Web Share Target POST before the early non-GET return
  if (
    event.request.method === "POST" &&
    url.origin === self.location.origin &&
    url.pathname === "/app/share-receipt"
  ) {
    event.respondWith(handleShareTarget(event.request));
    return;
  }

  if (event.request.method !== "GET") return;

  // Only handle same-origin requests
  if (url.origin !== self.location.origin) return;

  if (event.request.mode === "navigate") {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          return response;
        })
        .catch(() =>
          caches.match(event.request).then((cached) => cached || caches.match("/offline"))
        )
    );
    return;
  }

  // Cache-first for assets (JS, CSS, images)
  if (
    url.pathname.startsWith("/assets/") ||
    url.pathname.startsWith("/packs/") ||
    url.pathname.endsWith(".png") ||
    url.pathname.endsWith(".jpg") ||
    url.pathname.endsWith(".svg") ||
    url.pathname.endsWith(".ico")
  ) {
    event.respondWith(
      caches.match(event.request).then(
        (cached) =>
          cached ||
          fetch(event.request).then((response) => {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
            return response;
          })
      )
    );
  }
});

// ── Web Push ─────────────────────────────────────────────────────────
self.addEventListener("push", (event) => {
  if (!event.data) return;

  let data = {};
  try { data = JSON.parse(event.data.text()); } catch {}

  const title = data.title || "Cobrança em Dia";
  const options = {
    body:  data.body  || "",
    icon:  "/icon-192.png",
    badge: "/icon-72.png",
    data:  { url: data.url || "/app" },
    vibrate: [100, 50, 100],
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = event.notification.data?.url || "/app";

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && "focus" in client) {
          client.navigate(target);
          return client.focus();
        }
      }
      return clients.openWindow(target);
    })
  );
});
