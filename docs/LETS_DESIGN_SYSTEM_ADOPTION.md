# Lets family adoption map

`LETS_DESIGN_SYSTEM.md`, `tokens/lets-design-tokens.json`, `css/lets-design-system.css`, and
`js/lets-design-system.js` are the single source of truth for all Lets services.

## Repository contract

| Service | Repository | Adoption status |
|---|---|---|
| NewsBoard v2 | `pyw31337/news` | main integrated; v2 home/live/reports use LDS 1.1 |
| Lets Calendar | `pyw31337/calendar` | `design-system/lds-v1.1` PR branch |
| Let's Insu (렛츠인슈) | `pyw31337/insu` | main integrated; LDS/PWA shell |
| Let's Law (렛츠로) | `pyw31337/law` | main integrated; LDS/PWA shell |
| Lets People | `pyw31337/people` | `design-system/lds-v1.1` PR branch |
| Lets Asset | `pyw31337/asset` | `design-system/lds-v1.1` PR branch |
| Lets Art | `pyw31337/art` | `design-system/lds-v1.1` PR branch |

Each service keeps its domain data and business logic, but must consume the shared
tokens and primitives. Service-specific exceptions are documented locally before merge.

## Release checklist

Before a service merge, verify at 320, 375, 768, 1024, and 1440px: no page-level
horizontal overflow, 4→2→1 responsive stacking, keyboard focus, 44px minimum targets,
WCAG AA contrast, reduced-motion behavior, safe-area padding, manifest/service-worker,
notification settings, and OG/favicon/app icons. Run `git diff --check` and record the
commit hash in the service handoff document.

## Change ownership

Shared visual changes land in `pyw31337/lets` first. Feature repos pin a cache-busted
LDS version and never fork tokens locally. Data ingestion and analysis remain owned by
the feature repository; LDS only governs presentation and interaction behavior.
