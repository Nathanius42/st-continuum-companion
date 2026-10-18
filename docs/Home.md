# Continuum Companion

Continuum Companion (developed as the Continuum Dex, the name the repository and code still use) is an offline **ship library** for *Star Trek: Continuum Remastered*, in the LCARS style of the original STC website, built in **Flutter** for Android and Windows desktop, with iOS as a stretch goal. The desktop app replaces the old STC website. Every ship in all four eras gets its stats, its build-menu description, its canon source, credits for its author, and a spin-around turntable view.

The idea came from the STC website work (September 2026): rather than finish and host the website, build an app from the same content. Partly that's a better home for a ship database, and partly it's a way to learn modern development beyond Lua 4. The Windows build also gives the community an easy download.

| | |
|---|---|
| **Status** | Planned. Prototype next: a TNG Federation vertical slice on Android and Windows. |
| **Work tracking** | [Azure Boards](https://dev.azure.com/molla-workshop/HWRM-Continuum-Dex/_boards/board/t/HWRM-Continuum-Dex%20Team/Stories) |

## Pages

- **[Plan](/Plan.md)**: architecture, milestones and the decisions still open
- **[Design Language](/Design-Language.md)**: what is known about LCARS and the other eras and factions' interfaces, and the theme framework built from it
- **[Interface References](/Interface-References.md)**: where to find on-screen images of each era's and faction's interfaces, and how much there is to go on
- **[Data Sources](/Data-Sources.md)**: where every field comes from in the mod
- **[Ship Data Schema](/Ship-Data-Schema.md)**: the shape of the data file the app bundles, with samples and a validator
- **[Pipeline](/Pipeline.md)**: the Python tools that read the mod, how to run them, and what they currently produce
- **[App](/App.md)**: how the Flutter app is put together: screens, phone and desktop layouts, the variant toggle, the data layer and tests
- **[Release](/Release.md)**: packaging the Windows zip and installer, Android release signing, and the Azure Pipelines builds
- **[Release Notes](/Release-Notes.md)**: what's in each release, known issues, and how to install it on Windows and Android
- **[Dart and Flutter Primer](/Dart-and-Flutter-Primer.md)**: the development loop, Flutter's core ideas and the Dart essentials for working on the app

See also [Conventions](/Conventions.md) and [Contributing](/Contributing.md).
