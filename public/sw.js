/* The installed-app service worker (owner, mobile round 2026-10-26).
 *
 * PASS-THROUGH BY DESIGN. It exists because Chrome needs a worker with a
 * fetch handler to upgrade the manifest into a WebAPK. It caches nothing:
 * the server is local, and a rebuilt .next must never be shadowed by a
 * stale shell. Do not add a cache here without a versioned invalidation
 * story (the build is replaced in place by the runit service).
 */
self.addEventListener("install", () => {
	self.skipWaiting();
});

self.addEventListener("activate", (event) => {
	event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", () => {
	// No respondWith(): the network answers every request unchanged.
});
