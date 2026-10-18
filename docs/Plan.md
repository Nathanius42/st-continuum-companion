# Plan

## Architecture

```
SVN working copy (read-only)          Python tools (pipeline/)           Flutter app (app/)
──────────────────────────           ────────────────────────           ──────────────────
.ship .def build/*.lua   ──►  ship data pipeline  ──►  ships.json  ──►  data layer ─┐
research/*.lua                (validation report)       + icons/*.webp               ├─► LCARS screens
shipicons.lua + atlases  ──►  icon exporter       ──►                               │   (phone + desktop)
Source Files DAE/HOD     ──►  Blender turntable   ──►  renders/*.webp ──► turntable ┘
                                                                         │
                                         Android APK · Windows zip · iOS (TestFlight)
```

- **The mod is the source of truth.** The pipeline only reads the SVN working copy. Text problems it finds, such as typos in build descriptions, get fixed in the mod (HWRM-Continuum board), not in the app.
- **One data file, versioned by mod revision.** The same output could feed a website later, so the data work isn't tied to the app.
- **Offline first.** Everything is bundled with the app; no server.
- **Renders are pre-baked.** Headless Blender renders a turntable of about 24 frames per ship into one WebP sprite sheet, tens of KB each. The app maps a drag (touch or mouse) to a frame.
- **Themes follow the era and faction.** Era sets the frame and faction the accent, with colours from the mod's own HUD parameters. See [Design Language](/Design-Language.md).
- **One codebase, three targets.** Phone screens show one view at a time; a wide desktop window shows the ship list and detail side by side.

## Stack

| Concern | Choice |
|---|---|
| Language and UI | **Flutter** (Dart), decided 2026-10-17 |
| Targets | Android and Windows desktop; iOS as a stretch goal |
| Data | Bundled JSON parsed with `json_serializable`; a database (Isar or sqflite) only if search needs it |
| Images | Flutter's image cache with sized decoding |
| Builds | Azure Pipelines: Android and Windows on a Windows agent, iOS on a Microsoft-hosted macOS agent |
| Local tools | Flutter SDK, Android Studio, Visual Studio "Desktop development with C++"; `flutter doctor` |

## Distribution

| Platform | Plan |
|---|---|
| Android | Signed APK for sideloading |
| Windows | Portable zip **and** an NSIS installer, hosted where the community is (ModDB, itch.io) and linked from the Workshop pages. The installer starts from the STCR installer script in `Tools\Installer and Launcher\STCR Installer` and builds with NSIS 3. |
| iOS | Stretch goal at the bottom of the backlog: TestFlight, which needs the Apple Developer Program (about A$149 a year) |

Official stores carry takedown risk because Star Trek and LCARS are Paramount property. The **desktop app replaces the STC website**, which is shelved.

### Code signing explained

When Windows runs a program, it checks whether the file carries a **digital signature**: a cryptographic stamp that says who published it and proves it hasn't been altered since. The stamp comes from a **code-signing certificate**, which a certificate authority issues only after checking the publisher's identity.

- **Unsigned** apps still run, but Windows SmartScreen shows "Windows protected your PC" on first launch, and people must click *More info → Run anyway*. Some antivirus tools are also quicker to flag unsigned programs.
- **Signed** apps show the publisher's name instead. SmartScreen also builds up a reputation for a signed publisher over time, so the warning fades as more people install it.
- Signing costs money every year. The cheaper modern option is Microsoft's cloud signing service (formerly Azure Trusted Signing), at a few dollars a month, but check whether it accepts individual developers in Australia at the time. The alternative is a traditional certificate from a certificate authority, typically a few hundred dollars a year.
- Android has its own, free signing (the release keystore), which is already planned. iOS signing comes with the Apple Developer Program.

**The plan:** ship the Windows build unsigned with clear instructions for the SmartScreen prompt, and sign it when warnings or antivirus flags start putting people off (backlog story #617).

## Milestones

| Iteration | Goal |
|---|---|
| **Prototype** | Decisions settled; Flutter set up; schema; TNG Federation data; one ship rendered; era → faction → ship → detail with the turntable, running on your phone and on Windows, with the wide-window layout |
| **1.0** | All four eras and factions; batch renders; variants on one ship page with a toggle; search and filters; credits and canon sources; mouse and keyboard polish; accessibility and performance passes; signed Android release; Windows zip and installer |
| **Backlog** | Per-weapon statistics, ship comparison, Windows code signing; **iOS last** |

## Decisions

All decided 2026-10-17:

| Decision | Ruling |
|---|---|
| App stack | Flutter |
| Website | Shelved; the desktop app replaces it |
| Distribution | Android APK; Windows zip and NSIS installer; iOS via TestFlight as a stretch goal |
| Which hulls | Every buildable ship and the Keepers. Obvious tutorial and internal copies are left out. Anything unclear goes on a yes/no list for Nathan. Variants and subsystem configurations share one ship page, with a toggle that switches the visual. |
| Contributor permissions | Already granted: every contributor allowed their models to be used in any mod context, which covers the Dex. Credit every known author. |
| Fonts | As accurate to the screen as possible. Where a licence is a problem, raise a ticket to sort it out rather than settling for a substitute. |
| Windows code signing | Sign when it becomes necessary (see above) |
| iOS | Stretch goal, bottom of the backlog |

## Risks

- **Blender import of STCR models** has failed before on some DAE files. A spike proves the route on one ship before any batch work.
- **GPU stability:** this machine has frozen under heavy ROCm load, so the batch render needs a retry list and supervision for the first run.
- **iOS without a Mac:** if the stretch goal is taken up, builds run in the pipeline and testing happens through TestFlight, so iOS problems will surface late.
- **IP:** keep the app free, non-commercial and clearly marked as fan work.
