# Termux / mobile work: learnings and change log

Dated record of the Android/Termux service work and the compact phone/PWA UI
round.

- Date: **2026-10-26**
- Patch base: `0795ef1`
- Source branch: `termux-mobile-setup`
- Fork artifact: `termux-mobile-setup-squashed` — one commit on `main`; single
  patch at `dist/termux-mobile-setup-squashed.patch`
- Final state: production webpack build running under runit on
  `0.0.0.0:3000`; local and LAN endpoints returning 200.
- Operational runbook: [`termux-mobile-deployment.md`](termux-mobile-deployment.md).
- Quick start: [`../TERMUX.md`](../TERMUX.md).
- Patch install guide: [`../patches/README.md`](../patches/README.md).

## Goal and scope

Make LearnHarness usable as a supervised LAN service on Android/Termux, and make
the browser UI feel native on a phone without touching desktop or Electron.

In scope:

- production build that works on Android/arm64;
- runit-supervised service on `0.0.0.0:3000`;
- patch packaging for reproducible installs;
- compact phone drawer, safe areas, touch targets;
- PWA shell that is installable but never caches;
- `0.8×` phone density and a questionnaire dock that fits long questions.

Explicitly out of scope:

- a native APK wrapper;
- offline caching;
- swipe-to-close drawer;
- changing desktop or Electron layout behavior;
- authentication on the LAN service.

The LAN service has **no authentication**. Keep it on a trusted network.

## Final state

| Item | State |
|---|---|
| Source branch | `termux-mobile-setup` |
| Fork artifact | `termux-mobile-setup-squashed` (one commit on `main`) |
| Patch base | `0795ef1` |
| Node / npm | 26.3.1 / 11.17.0 |
| Next.js | 16.3.2 |
| Build | `npm run build -- --webpack` — success |
| Build ID at verification | `YhVbT4-Ddn_BBrImv22Bs` |
| Service | runit `learnharness`, running |
| Bind | `0.0.0.0:3000` |
| Local URL | `http://127.0.0.1:3000` — 200 |
| LAN URL | `http://192.168.0.10:3000` — 200 |
| Logs | `$PREFIX/var/log/sv/learnharness/current` |

The build took ~7–8 minutes (94 s webpack, 25 s TypeScript, 1.3 s static
generation, then tracing). `.next` was ~850 MB; `.next/standalone` ~118 MB.

## Decisions and rationale

| Decision | Why | Guardrail |
|---|---|---|
| Production build, not dev server | Turbopack has no Android/arm64 native bindings; a supervised production service is more stable | Always pass `--webpack` |
| Serve from repo-root `.next` | `ROOT`, `data/`, `auth.json`, and prompt assets resolve correctly | Do not switch to `.next/standalone/server.js` without checking paths |
| Bind `0.0.0.0:3000` | Phone and other LAN devices need access | No port-forwarding; trusted LAN only |
| No authentication | Deliberate scope choice for a home LAN | Anyone on the Wi-Fi can read/write app state; warn |
| runit + direct Next exec | `npm start` did not reliably forward SIGTERM; old `next-server` held port 3000 | Keep `exec node node_modules/next/dist/bin/next ...` |
| Patch bundle for changes | Reproducible install without committing environment setup | `0001` source, `0002` service units, `0003` mobile/PWA, `0004` docs; fork uses the single squashed branch |
| Compact breakpoint 928 / CSS 927 | Matches `SIDEBAR_AUTOCLOSE` in the Electron shell (640 px content floor + 288 px sidebar) | Keep `SIDEBAR_AUTOCLOSE` and the CSS breakpoint in sync |
| Compact drawer is transient | A phone should not inherit a desktop “sidebar open” preference and cover the lesson | Do not write mobile open/close to `lh:sidebar-open`; leaving compact restores the stored desktop preference |
| Electron keeps its behavior | Desktop windows need expand-to-restore and persisted sidebar state | Gate compact layout with `IS_ELECTRON` and `html:not(.lh-electron)` |
| Safe areas owned by the app frame | One owner prevents double padding | `SidebarProvider` frame pays insets; page roots use `h-full`; fixed drawer pays its own insets |
| PWA shell, pass-through worker | Chrome needs a fetch-handling worker to upgrade the manifest to a WebAPK; a local app must not serve stale assets | Production-only registration; no caching without versioned invalidation |
| `0.8×` phone density | More content and controls fit without a browser zoom transform | Scale only ≤927 px browser; exclude Electron; keep focused controls at 16 px |
| Conditional dock fit | Long questionnaires must not push confidence/answer/stats under the conversation clip | Apply only while `pending || practice`; leave desktop/Electron untouched |
| Core barrel fix | `coverage.ts` imports `node:crypto`; webpack exposed that a client component pulled it through the barrel | Keep `export * from "./coverage.ts"` removed; import coverage directly where needed |

## Change inventory

### Source fix

| File | Change | Patch |
|---|---|---|
| `src/core/index.ts` | Removed the `coverage.ts` barrel re-export; documented why | `0001` |

`coverage.ts` hashes with `node:crypto`. `components/activity-dock.tsx` imports
the barrel, so webpack tried to bundle `node:crypto` into the browser and failed
with `UnhandledSchemeError`. Server/agent/tests import `core/coverage.ts`
directly, and no shell code uses coverage functions.

### PWA shell

| File | Change | Patch |
|---|---|---|
| `app/manifest.ts` | New standalone manifest: name/short name, `start_url`/`scope` `/`, `display: standalone`, orientation any, `#141414`, icons | `0003` |
| `components/pwa-register.tsx` | New production-only `/sw.js` registration; failures are silent | `0003` |
| `public/sw.js` | New pass-through worker: `skipWaiting`, `clients.claim`, fetch handler, no `respondWith`, no cache | `0003` |
| `public/icons/icon-192.png` | Generated PWA icon | `0003` |
| `public/icons/icon-512.png` | Generated PWA icon | `0003` |
| `public/icons/icon-maskable-512.png` | Generated maskable icon on `#141414` with the glyph inside the safe zone | `0003` |
| `scripts/make-icons.mjs` | Extended to emit the PWA icon set from `build/icon-flat.svg` via resvg | `0003` |
| `app/layout.tsx` | Added `Viewport` (`viewportFit: cover`, `interactiveWidget: resizes-content`, `themeColor #141414`) and `<PwaRegister />` | `0003` |

The service worker is intentionally empty on `fetch`. Chrome needs the handler
for installability; caching would risk serving a stale build after the runit
service replaces `.next`.

### Compact phone shell

| File | Change | Patch |
|---|---|---|
| `components/sidebar.tsx` | Compact overlay drawer, backdrop, pathname auto-close, Escape capture dismissal, safe-area padding on the fixed panel, touch-target classes, search height, Electron preference gating | `0003` |
| `app/globals.css` | Mobile baseline: overscroll suppression, tap-highlight suppression, text-size-adjust, coarse-pointer 16 px form floor, compact scale, dock-fit rules | `0003` |
| `components/chat.tsx` | Page root `h-full`; dock overlay classes and conditional `lh-dock-fit`; dock flex chain | `0003` |
| `components/question-dock.tsx` | `lh-dock-panel`, `lh-dock-scroll` for question/options, `lh-dock-fixed` for confidence/form; coarse option and submit heights | `0003` |
| `components/practice-dock.tsx` | `lh-dock-panel`, `lh-dock-scroll` for the problem, `lh-dock-fixed` for the thinking field | `0003` |
| `components/composer.tsx` | Coarse send/next/textarea sizing | `0003` |
| `components/home.tsx` | Page root `h-full`; coarse home composer sizing | `0003` |
| `components/new-session.tsx` | Page root `h-full` | `0003` |
| `components/md-blocks.tsx` | Copy/expand controls visible on coarse pointers | `0003` |
| `components/ui/button.tsx` | `icon` / `icon-lg` coarse sizes | `0003` |

### Operational wrappers

These are committed on `termux-mobile-setup`; they are not part of `0003`.

| File | Change |
|---|---|
| `TERMUX.md` | Current quick start, everyday commands, PWA/security notes, and the “patches are already applied here” warning |
| `scripts/termux/build.sh` | Stop service, optional install, clean webpack build, restart, local health check |
| `scripts/termux/install.sh` | Prerequisite check, build, service install, URLs |
| `scripts/termux/service.sh` | Install/remove/start/stop/restart/status/logs for the runit unit; supports `LH_HOST`, `LH_PORT`, `LH_SERVICE_NAME` |

### Service packaging

| File | Change | Patch |
|---|---|---|
| `$PREFIX/var/service/learnharness/run` | Wake lock; `cd` to repo; `NEXT_TELEMETRY_DISABLED=1`; exec Next on `0.0.0.0:3000` | `0002` |
| `$PREFIX/var/service/learnharness/log/run` | `svlogd -tt` under `$LOGDIR/sv/learnharness` | `0002` |
| `patches/0001-core-barrel-browser-safe.patch` | Source fix | bundle |
| `patches/0002-termux-runit-service.patch` | Service units | bundle |
| `patches/0003-mobile-pwa-shell.patch` | Mobile/PWA/density/dock changes, including binary icons | bundle |
| `patches/0004-termux-mobile-docs.patch` | Adds the two reference docs; docs-only, no rebuild needed | bundle |
| `patches/README.md` | Install, verify, security, rollback, phone/PWA notes, `0004` steps | bundle |
| `patches/SHA256SUMS` | Checksums for the patch files and README | bundle |

### Generated / documentation

| File | Status |
|---|---|
| `next-env.d.ts` | Committed with `.next/dev/types/*`; `next build` rewrites it to `.next/types/*`. Keep that generated diff out of commits. |
| `docs/termux-mobile-deployment.md` | Operational runbook; added by `0004`. |
| `docs/termux-mobile-notes.md` | This learnings/change log; added by `0004`. |

The 2026-10-26 zip bundle was written to
`dist/learnharness-termux-mobile-patches.zip` (gitignored), with a copy at
`~/learning/learnharness-termux-mobile-patches.zip`. It contains `0001`–`0004`.

## Patch bundle and validation

The bundle contains:

```text
patches/
  0001-core-barrel-browser-safe.patch
  0002-termux-runit-service.patch
  0003-mobile-pwa-shell.patch
  0004-termux-mobile-docs.patch
  README.md
  SHA256SUMS
```

Validated on a pristine `HEAD` worktree:

- `0001` applies cleanly.
- `0003` applies cleanly with `--binary`.
- All 19 code files changed by `0003` match the current tree byte-for-byte.
- `0002` applies into an empty service directory and matches the installed units.
- `0004` applies cleanly **after** `0003`; both docs match the current files.
- Reversing `0004`, then `0003`, then `0001` returns a clean tree.
- The extracted zip’s `sha256sum -c patches/SHA256SUMS` passes.

`0003` contains binary PNG deltas, so use `git apply --binary`. `0004` is
documentation-only and has no build effect.

## Lessons learned

### Build and platform

- **Turbopack cannot run on Android/arm64.** There are no native bindings.
  `next dev` and `next build` both fail unless `--webpack` is supplied.
- The first production build is expensive: webpack ~94 s, TypeScript ~25 s,
  then tracing/caching for several minutes. Budget ~7–8 minutes.
- `.next` is large (~850 MB) while building; `.next/standalone` is ~118 MB.
  Disk pressure is real on a phone.
- `next start` with `output: "standalone"` emits a warning. Serving the
  repo-root `.next` is intentional here because it keeps runtime paths correct.

### Client/server boundary

- Turbopack tolerated the core barrel re-export that pulled `node:crypto` into a
  client bundle; webpack did not. The failure surfaced at build time as
  `UnhandledSchemeError`.
- The barrel’s contract is “browser-safe modules only.” `coverage.ts` belongs to
  the server/tooling side and is imported directly there.
- Removing one re-export was safer than making `coverage.ts` browser-safe: no
  shell code used it.

### Service supervision

- `npm start` is the wrong process to supervise: npm did not reliably forward
  SIGTERM, so the old `next-server` stayed alive and held port 3000.
- Direct `exec` of `node_modules/next/dist/bin/next` makes the supervised PID
  the actual server. `sv down` / `sv up` then behave predictably.
- `sv down` can leave a process in `got TERM`. `sv kill` is the reliable escape
  hatch before restarting.
- `runsvdir` rescans every few seconds; after creating the unit, `sv up` may need
  a retry.
- Logs through `svlogd -tt` are at
  `$PREFIX/var/log/sv/learnharness/current`.
- Android restricts `ss` and `/proc/net/*`; use `os.networkInterfaces()` to find
  the phone’s LAN address.

### Safe areas and the compact drawer

- Safe-area insets must have one owner. The `SidebarProvider` frame pays them;
  page roots use `h-full`. The fixed compact drawer escapes that frame, so it
  pays its own insets.
- The compact breakpoint is 928 px (`max-width: 927px`), matching the Electron
  sidebar auto-close threshold.
- Browser compact mode starts closed and ignores the stored desktop sidebar
  preference. Opening the drawer must not rewrite that preference. Leaving
  compact restores the stored desktop state.
- Navigation, Escape (capture phase), and backdrop tap all dismiss the drawer.
  There is no swipe gesture.
- Electron is not compact: it keeps its persisted sidebar preference and
  expand-to-restore behavior.

### `0.8×` density

- The scale is a CSS variable, not a `transform`; safe areas, fixed drawer, and
  scroll geometry stay meaningful.
- The type ladder and `--spacing` are scaled, plus `--lh-prose-size`. The scale
  is applied in a `max-width: 927px` media query gated by
  `html:not(.lh-electron)`, so Electron is unaffected.
- Custom properties are computed where declared. `--lh-prose-size` must be
  recalculated in the compact media block; changing `--lh-ui-scale` lower in the
  tree would not recompute it.
- Focused form controls stay at `max(16px, 1em)` to prevent Chrome Android’s
  focus zoom. This overrides the `.lh-input` class too.
- Coarse-pointer controls intentionally shrink from 44 px to 35.2 px at `0.8×`.
  This is part of the approved density, not a regression.
- Not everything is scaled:
  - `text-xs` lands at 8.8 px (low end of legibility);
  - arbitrary sizes such as `text-[10px]`, `text-[11px]`, `text-[13px]` stay
    unscaled;
  - in normal composer mode, the `h-24` gradient scales to 76.8 px while
    `GRADIENT_H` reserves 96 px, leaving a small extra transcript gap. Fit mode
    pins the gradient to 96 px.

### Dock fit

- The old question sheet could let confidence, answer, and stats push the top
  of the dock under the conversation’s overflow clip.
- The fit is a compact-only flex chain: overlay capped to the conversation
  column, gradient fixed at 96 px, one flexible scroller, fixed rows at
  `flex: 0 0 auto`.
- Only the question/options area scrolls; confidence/answer/stats stay pinned.
- The fit is conditional on `pending || practice`; desktop and Electron never
  receive `lh-dock-fit`.
- `min-height: 0` is essential at every flex parent in the chain; without it,
  the scroll area refuses to shrink.

### PWA

- A manifest alone is not enough for Chrome Android’s WebAPK upgrade; a service
  worker with a fetch handler is required. The worker can be pass-through.
- `http://localhost` is a secure context on the phone; `http://192.168.x.x` is
  not. LAN installs need HTTPS.
- The worker must not cache. The app is updated by replacing `.next` in place;
  a cached shell would hide the new build.
- Register only in production. Dev module URLs are not content-hashed the same
  way, and a leftover worker could confuse a later build.
- Maskable icons need the glyph inside Android’s safe zone; the generated icon
  places it on `#141414` with room for launcher cropping.

### Verification and environment

- There is no system Chrome/Chromium on the phone, so the compact drawer,
  `0.8×` density, long-questionnaire fit, and PWA install were **not visually
  tested** on-device.
- The `demo` sub-agent’s browser check fails for the same reason. PDF/SVG
  rendering works because the Android arm64 `@napi-rs/canvas` and
  `@resvg/resvg-js` binaries load.
- `next-env.d.ts` is generated and flips between `.next/dev/types/*` and
  `.next/types/*` depending on whether `dev` or `build` ran. It is committed at
  the dev-types version; do not commit the build-generated diff.
- The full test suite last ran before the final density/dock change: 2,127
  passed, 3 failed, 0 skipped (~254 s). The failures were environment/pre-existing:
  - `tests/demos.test.tsx` — no Chrome/Chromium;
  - `tests/provider-tracing.test.ts` — host-platform Next ignore check;
  - `tests/svg-native-render.test.ts` — Termux system-font render is 395 bytes.
- After the final change, the production build’s TypeScript step passed, lint
  passed, and 107 targeted UI tests passed across `render-cards`,
  `render-practice-surface`, `render-sidebar`, `render-composer`,
  `render-minimal-home`, and `render-new-session`.

## Verification matrix

| Check | Result |
|---|---|
| `next build --webpack` | Pass |
| Production TypeScript step | Pass |
| `npm run lint` | Pass |
| Targeted UI tests | 107/107 pass |
| Full suite | 2,127 pass / 3 environment failures (last full run, before final density change) |
| `/`, `/chat/new`, `/api/graph`, `/api/keys`, `/api/settings/prompts` | 200 |
| `/settings` | 307 → `/chat/new` |
| `/manifest.webmanifest` | 200, `application/manifest+json`, 561 bytes |
| `/sw.js` | 200, `application/javascript`, 704 bytes |
| PWA icons | 200; 192×192, 512×512, maskable 512×512 |
| Viewport/theme/manifest tags | Present |
| Built CSS | `--lh-ui-scale:.8`, `lh-dock-fit`, `@media (max-width:927px)`, `pointer:coarse` present |
| Local + LAN HTTP | 200 |
| Patch apply/rollback | Pass; 19 code files reproduced byte-for-byte; `0004` adds both docs after `0003` |
| Visual phone/PWA check | Not performed (no Chrome on device) |

## Known limitations and follow-ups

- **Visual browser verification is still pending**: compact drawer, `0.8×`
  density, long questionnaire fit, and PWA install on a real phone browser.
- **PWA install requires HTTPS or localhost.** The LAN IP browses but does not
  install.
- **No authentication.** Add a token/basic-auth gate or bind to `127.0.0.1` if
  the network is not trusted.
- **Provider keys/model slots** were not configured or verified in this round.
  `auth.json` exists at the repo root (gitignored) but its contents were not
  inspected.
- **Termux:Boot is not installed.** Services start when a Termux shell opens and
  `start-services.sh` runs.
- **Density edge cases** remain: 8.8 px `text-xs`, unscaled arbitrary text
  sizes, and the normal-mode gradient/reserve mismatch.
- **Full test suite** should be rerun after the final density change; expect the
  same three environment failures.

## Guardrails

Keep these true unless deliberately revisiting the design:

- Pass `--webpack` on this platform.
- Keep the `coverage.ts` barrel export removed.
- Keep the runit unit exec’ing Next directly.
- Stop the service before rebuilding.
- Keep the service bound to `0.0.0.0` only for trusted LANs, or add auth.
- Keep `html:not(.lh-electron)` on the compact scale and dock fit.
- Keep focused form controls at 16 px.
- Keep safe-area ownership in the app frame plus the fixed drawer.
- Keep the service worker pass-through; do not add caching without invalidation.
- Keep desktop and Electron layout behavior unchanged.
- On `termux-mobile-setup`, do not reapply the patches; they are already
  committed.
- Prefer the `scripts/termux/*.sh` wrappers for ordinary install/build/service
  work; they encode the same webpack and direct-exec rules.
- Do not commit the build-generated `.next/types/*` change in `next-env.d.ts`.
- Do not add swipe-to-close, an APK wrapper, or offline mode without a new
  decision.

## Timeline

1. Installed dependencies on Android/arm64 and confirmed native renderers
   (`@napi-rs/canvas`, `@resvg/resvg-js`).
2. Hit the Turbopack platform failure; switched to webpack production builds.
3. Hit the `node:crypto` client bundle failure; removed the `coverage.ts` barrel
   re-export.
4. Installed the runit service on `0.0.0.0:3000`; fixed signal forwarding by
   exec’ing Next directly.
5. Added compact drawer, safe areas, touch targets, and the PWA shell.
6. Added production-only service worker registration and generated icons.
7. Added `0.8×` phone density and the conditional questionnaire dock fit.
8. Rebuilt, restarted, verified endpoints/CSS, packaged patches, and validated
   apply/rollback.
9. Added the operational quick path (`TERMUX.md`, `scripts/termux/*.sh`).
10. Added the runbook and this change log; packaged them as `0004` and included
    them in the zip; squashed the branch work for the fork artifact.

## References

- [`termux-mobile-deployment.md`](termux-mobile-deployment.md) — current
  install/build/run/verify commands.
- [`../TERMUX.md`](../TERMUX.md) — current quick start and everyday wrappers.
- [`../scripts/termux/install.sh`](../scripts/termux/install.sh) — one-shot
  installer.
- [`../scripts/termux/build.sh`](../scripts/termux/build.sh) — rebuild/restart.
- [`../scripts/termux/service.sh`](../scripts/termux/service.sh) — service
  management.
- [`../patches/README.md`](../patches/README.md) — patch install guide.
- [`development.md`](development.md) — general development commands.
- [`architecture.md`](architecture.md) — layering and the barrel/import law.
- [`desktop-release.md`](desktop-release.md) — desktop release flow, not used
  here.
