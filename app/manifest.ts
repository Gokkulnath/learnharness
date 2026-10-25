import type { MetadataRoute } from "next";

/*
 * The installed-app shell (owner, mobile round 2026-10-26). Chrome on Android
 * upgrades this manifest into a WebAPK: its own launcher icon, splash screen,
 * task-switcher entry, and no URL bar. The service worker (public/sw.js) is a
 * deliberate pass-through — installability without a cache, so a rebuilt
 * server is never shadowed by stale assets.
 *
 * Secure-context caveat: installs work on http://localhost (trustworthy) and
 * over HTTPS; a plain LAN address such as http://192.168.x.x is not installable.
 */
export default function manifest(): MetadataRoute.Manifest {
	return {
		name: "Learning Harness",
		short_name: "LearnHarness",
		description: "A teacher agent with a memory — sessions, quizzes, and a knowledge graph of what you know.",
		start_url: "/",
		scope: "/",
		display: "standalone",
		orientation: "any",
		background_color: "#141414",
		theme_color: "#141414",
		icons: [
			{ src: "/icons/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
			{ src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
			{ src: "/icons/icon-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
		],
	};
}
