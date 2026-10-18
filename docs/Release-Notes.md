# Release Notes

What's in each release of Continuum Companion, and how to install it. The build and packaging steps behind these downloads are on the [Release](/Release.md) page.

## Installing

### Windows 10 and 11 (64-bit)

There are two downloads; pick one.

| Download | Size | For |
|---|---|---|
| `ContinuumCompanion-<version>-setup.exe` | 44.0 MB | Most people: a normal install with shortcuts and an uninstaller |
| `ContinuumCompanion-<version>-windows-x64.zip` | 48.0 MB | A portable copy, for a USB stick or a PC where you can't install |

**Installer.**
1. Run `ContinuumCompanion-<version>-setup.exe`.
2. Windows SmartScreen may say "Windows protected your PC", because the installer isn't code-signed. Choose **More info**, then **Run anyway**.
3. Read the notice and choose **Install**. It installs for your account only, to `%LOCALAPPDATA%\Programs\Continuum Companion`, so it doesn't need administrator rights.
4. Start it from the Start menu or the desktop shortcut.

To remove it, use **Settings → Apps → Installed apps → Continuum Companion → Uninstall**. Your settings stay in `%APPDATA%\Continuum Companion` and the window's place in the registry (`HKEY_CURRENT_USER\Software\Molla Workshop\Continuum Companion`); delete them as well for a clean removal.

**Portable.**
1. Unzip `ContinuumCompanion-<version>-windows-x64.zip` anywhere you can write to.
2. Run `continuum_companion.exe` from the unzipped folder. Keep the folder together: the exe needs the `data` folder and the DLLs beside it.

Nothing else needs installing: the Visual C++ runtime comes with the app.

To update, install the new version over the old one, or replace the portable folder. Settings carry over.

### Android 7.0 and later

The app is sideloaded as an APK; it isn't on Google Play. Pick the APK for your phone's processor:

| APK | Size | For |
|---|---|---|
| `ContinuumCompanion-<version>-android-arm64-v8a.apk` | 53.1 MB | Nearly every phone from the last several years. Choose this one if you're unsure |
| `ContinuumCompanion-<version>-android-armeabi-v7a.apk` | 50.6 MB | Older 32-bit phones |
| `ContinuumCompanion-<version>-android-x86_64.apk` | 54.5 MB | Emulators and Chromebooks |

1. Copy the APK to the phone, or download it there.
2. Open it from the Files app or the browser's downloads. Android asks once to let that app install unknown apps: allow it, then go back and choose **Install**.
3. On a Samsung phone with **Auto Blocker** on (Settings → Security and privacy → Auto Blocker), sideloading is blocked. Turn it off to install, then turn it back on.
4. Google Play Protect may warn that it doesn't recognise the app. Choose **More details → Install anyway**.

To update, install the new APK over the old one. Every release is signed with the same key, so updates keep your settings. A test build from before 1.0.0 was signed differently: uninstall it first, which resets its two settings.

The APKs' signing certificate (SHA-256), to check a download against: `ce3ae02058288dc4357f0293982c568790e1edb1049f84c6c2121582078672ac`.

### iOS

Not available. An iOS build compiles in the pipeline, but it isn't signed or distributed.

## 1.0.0 (18 October 2026)

The first release, built from *Star Trek: Continuum Remastered* revision 4024.

### What's in it

- **Starship Database.** 370 ships across the four eras (Enterprise, The Original Series, The Motion Pictures, The Next Generation) and 14 factions, picked by era, then faction, then ship. Each era and faction has its own interface, after the shows; a front-page switch puts everything in classic TNG LCARS instead.
- **Ship pages.** A turntable of the in-game model you can drag round, specifications and game stats, a summary, armaments with each weapon's damage, rate, damage per second and range, defences, research, abilities, the description, notable ships with their registries, where the class comes from in canon with a Memory Alpha or Memory Beta link, and the model's credits. Refits, subsystems, separated saucers and carrier complements are a toggle on the same page.
- **Search.** Finds ships by name, class, hull id, variant or a named ship's registry ("Yamato" or "NCC-71807" finds the Galaxy), with filters for era, faction, class, role, size and how the ship appears in the game.
- **Compare.** Any two ships side by side, with the better figure lit.
- **Factions.** A tactical star chart of the galaxy, with each power where the shows put it and at its size in the era chosen. Each faction has a homeworld scene, a short history (per era for the Federation, Klingons and Romulans) and its fleet.
- **About, Credits, Comms, Access and Media.** The mod's team, Steam Workshop releases and awards, its Discord, Steam group and guides, the Workshop page for each era, and the trailers, each a tap from YouTube or ModDB.
- **Works offline.** Everything ships with the app; only the links and trailers need a connection.
- **Phone and desktop.** Touch on a phone, mouse and keyboard in a window (Tab, arrows, Enter, Escape to go back, the wheel to turn a ship). Wide windows put the ship list and the ship page side by side.
- **Accessibility.** Screen reader labels throughout, text up to 200% without clipping, and reduced motion respected.
- **Sound.** The STC website's LCARS beeps, with a switch to turn them off.
- **Typography.** Each era and faction in its own lettering: League Gothic for TNG LCARS, Pathway Gothic One for ENT, the mod's title fonts for TOS and TMP, Klingon Dagger and Romulan Eagle for those empires, and each alien empire's script beside its screen titles.

### Known issues

- **Unsigned Windows installer.** SmartScreen warns on first run, as above.
- **Fonts.** The Cardassian, Dominion and other faction interfaces without a font of their own use the system font for their titles.
- **Not yet checked by hand:** TalkBack on a phone, and scrolling speed on a phone with the performance overlay.

### Credits and notice

An unofficial fan work, free, and not endorsed by CBS Studios, Paramount or any Star Trek rights holder. Ship data, icons and emblems come from *Star Trek: Continuum Remastered* by the Continuum team; ship models are by the authors credited on each ship's page. The installer and the zip carry the full notice (`notice.txt`) with the font credits and the Open Font License.
