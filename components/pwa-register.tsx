"use client";

import { useEffect } from "react";

/**
 * Registers the installed-app service worker (public/sw.js) after load.
 *
 * Production only: a dev server's module URLs are not content-hashed the way
 * build output is, and this component must never leave a worker behind that
 * could confuse a later build. The worker itself is a pass-through — it
 * exists for installability, not offline caching.
 */
export function PwaRegister() {
	useEffect(() => {
		if (process.env.NODE_ENV !== "production") return;
		if (typeof navigator === "undefined" || !("serviceWorker" in navigator)) return;

		const register = () => {
			void navigator.serviceWorker.register("/sw.js", { scope: "/" }).catch(() => {
				// Installability is a bonus: a failed registration must never
				// surface as an app error.
			});
		};

		if (document.readyState === "complete") register();
		else window.addEventListener("load", register, { once: true });
		return () => window.removeEventListener("load", register);
	}, []);

	return null;
}
