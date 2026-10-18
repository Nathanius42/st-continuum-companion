# Release

How the Dex is built and packaged for each platform. Builds run in Azure Pipelines from `azure-pipelines.yml`, and the same steps run by hand on this PC.

## Versions (#528)

`version:` in `app/pubspec.yaml` is `<version>+<build>`, for example `1.0.0+1`. The version is what players see; the build number must go up for every release, because it becomes Android's versionCode (Google Play refuses a build that doesn't raise it) and the last part of the Windows file version. Change both in pubspec.yaml and in `app/lib/version.dart`, which the app shows on its front page; a test fails if they differ. The front page also shows the ship data's mod revision and build date, from `ships.json`.

## App icon (#924)

The Star Trek Continuum icon, from the mod's installer. On Windows, `app/windows/runner/resources/app_icon.ico` is the mod's `STC_icon.ico` itself, with its stepped 16, 32, 48 and 256 px images; it's built into the `.exe` and used by the installer. On Android, `tools/make_app_icons.py` makes the launcher icons from the 256 px image (`HW2\Tools\Logos\STC_Icon_256.png`) at every density, plus an adaptive icon: the logo inside the safe zone over LCARS black.

## Windows (#552)

Two downloads, both from `tools/package_windows.ps1`:

| Download | What it is |
|---|---|
| `ContinuumCompanion-<version>-windows-x64.zip` | Portable: unzip anywhere and run `continuum_companion.exe`. |
| `ContinuumCompanion-<version>-setup.exe` | NSIS installer: installs for the current user, adds Start menu and desktop shortcuts and an uninstaller. |

```powershell
.\tools\package_windows.ps1            # build, then package
.\tools\package_windows.ps1 -SkipBuild # package the existing build
```

Outputs go to `dist\`, which Git ignores. The version comes from `app/pubspec.yaml`.

- **Visual C++ runtime.** Flutter's Windows build needs `msvcp140.dll`, `vcruntime140.dll` and `vcruntime140_1.dll`. The script copies them next to the app (app-local deployment), so a clean Windows machine runs it without installing the redistributable.
- **Installer script.** `installer/ContinuumDex.nsi` is adapted from the STCR installer (`HWRM\Tools\Installer and Launcher\STCR Installer\STCR_Installer.nsi`). It installs to `%LOCALAPPDATA%\Programs\Continuum Companion` without administrator rights, shows `installer/notice.txt` (fan-work and font notice) in place of a licence, and its uninstaller removes only the files it installed.
- **NSIS version.** The pipeline uses NSIS 3. The script also compiles with the mod's NSIS 2.46 (`NSIS modified`), which the packaging script falls back to on this PC; it switches Unicode on only under NSIS 3.
- **The STCR skin.** The STCR installer script never calls the Skincrafter plugin, so the installer has no skin to carry over and nothing depends on the plugin working with NSIS 3 (#607).

Sizes at 1.0.0: zip 48.0 MB, installer 44.0 MB. What players see, and how they install each download, is on the [Release Notes](/Release-Notes.md) page.

## Android (#524)

Release builds are signed with the upload key when `app/android/key.properties` exists, and with the debug key otherwise, so `flutter run --release` works on any PC. The file and the keystore are git-ignored and must never be committed.

Set up on 18 October 2026: the keystore `continuum-dex-upload.jks` is kept in the owner's OneDrive, outside this repository (keep a second copy off the PC as well); its certificate's SHA-256 is `ce3ae02058288dc4357f0293982c568790e1edb1049f84c6c2121582078672ac` (`apksigner verify --print-certs` shows it). Release APKs are renamed `ContinuumCompanion-<version>-android-<abi>.apk` for download.

### One-time setup (by the keystore's owner)

1. Create the upload keystore, choosing and recording its passwords somewhere safe:

   ```
   keytool -genkeypair -v -keystore continuum-dex-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   `keytool` is in Android Studio's JDK (`jbr\bin`). Keep the `.jks` outside the repository, with a backup (#525). If it's lost, updates can't be signed with the same key.
2. On this PC, create `app/android/key.properties`:

   ```
   storeFile=<full path to continuum-dex-upload.jks>
   storePassword=<store password>
   keyAlias=upload
   keyPassword=<key password>
   ```
3. For the pipeline (#526): upload the keystore under **Pipelines → Library → Secure files** as `continuum-dex-upload.jks`, add the secret variables `androidStorePassword` and `androidKeyPassword`, and set `androidReleaseSigning` to `true`.

## Pipeline (#522)

`azure-pipelines.yml` builds on every push to `main`:

| Job | Agent | Output artefact |
|---|---|---|
| windows | `windows-latest` | `windows`: the zip and installer, after the widget tests |
| android | `windows-latest` | `android`: release APKs split per ABI |
| ios | `macOS-latest` | none: an unsigned build that proves the target compiles |

To turn it on: **Pipelines → New pipeline → Azure Repos Git → HWRM-Continuum-Dex → Existing YAML file → `/azure-pipelines.yml`**. Microsoft-hosted agents for a private project need the free parallel job, which Azure DevOps grants on request (a form, usually a few days).

## Public repository (GitHub)

The public copy is [github.com/Nathanius42/st-continuum-companion](https://github.com/Nathanius42/st-continuum-companion), working copy `D:\Molla_Workshop\st-continuum-companion`. It gets one commit and tag per major version, never this repository's history:

```bash
pipeline/.venv/Scripts/python.exe tools/public/export.py
```

The script copies main's committed files there, then commit as `Nathan Molla <Nathanius42@users.noreply.github.com>`, tag (`v1.0.0`), push, and create the GitHub release from the tag with the downloads attached and the version's section of [Release Notes](/Release-Notes.md).

- **Left out:** the Star Trek fan fonts (only the OFL fonts may be published; `pubspec.yaml` loses the others' entries, so a public build falls back to the platform font), `CLAUDE.md`, the Tooling page, the phone-session scripts and `tools/public` itself.
- **Written from `tools/public`:** the README, the MIT `LICENSE` (code only) and `NOTICE.md`, which says what the licence doesn't cover: the mod's content, the renders, the generated homeworld scenes and the fonts.
- **Checked:** the export stops if a personal email, a token name, a private key, a keystore password or any signing file is in the copy.
