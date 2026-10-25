import type { Metadata, Viewport } from "next";
import { JetBrains_Mono, Source_Sans_3 } from "next/font/google";
import "katex/dist/katex.min.css";
import "./globals.css";
import { AppShell, SidebarProvider } from "@/components/sidebar";
import { ActivityProvider } from "@/components/activity-dock";
import { ServerEventsProvider } from "@/components/server-events";
import { AppearanceProvider } from "@/components/settings/appearance";
import { PwaRegister } from "@/components/pwa-register";
import UpdateBanner from "@/components/update-banner";

// Chrome = JetBrains Mono, teaching prose = Source Sans 3, titles = CMU
// Serif (the bundled lh-cmu @font-face in globals.css — no CDN).
const ui = JetBrains_Mono({ subsets: ["latin"], variable: "--font-jetbrains" });
const prose = Source_Sans_3({ subsets: ["latin"], variable: "--font-sans3" });

export const metadata: Metadata = {
	title: "Learning Harness",
	description: "A teacher agent with a memory — sessions, quizzes, and a knowledge graph of what you know.",
};

/*
 * Installed-app viewport (owner, mobile round 2026-10-26). viewportFit=cover
 * lets the app paint edge-to-edge behind the status/gesture bars; the app
 * frame spends those insets explicitly (sidebar + page roots). resizes-content
 * makes the on-screen keyboard shrink the layout viewport, so the composer
 * rises with it instead of hiding underneath. themeColor matches the app
 * background in the task switcher and in Chrome's UI.
 */
export const viewport: Viewport = {
	width: "device-width",
	initialScale: 1,
	viewportFit: "cover",
	interactiveWidget: "resizes-content",
	themeColor: "#141414",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
	return (
		<html lang="en" className={`dark ${ui.variable} ${prose.variable}`}>
			<body className="min-h-dvh antialiased">
			{/* The notification channel rides OUTSIDE everything: sidebar, dock,
				 and pages all subscribe as the polls retire (push S3, 2026-10-02). */}
			<ServerEventsProvider>
				<AppearanceProvider>
					<SidebarProvider>
						<ActivityProvider>
							<AppShell>{children}</AppShell>
						</ActivityProvider>
					</SidebarProvider>
				</AppearanceProvider>
			</ServerEventsProvider>
			{/* Installs the pass-through service worker in production builds
			    (public/sw.js); renders nothing. */}
			<PwaRegister />
			{/* Auto-update banner (Wave C): fixed card, Electron-only pushes. */}
			<UpdateBanner />
		</body>
		</html>
	);
}
