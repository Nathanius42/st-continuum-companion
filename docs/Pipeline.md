# Pipeline

Python tools in `pipeline/` that read the STCR mod's SVN working copy and produce the Dex's ship data. They only ever **read** the mod.

## Set-up (once)

From the repository root:

```bash
python -m venv pipeline/.venv
```

```bash
pipeline/.venv/Scripts/python.exe -m pip install jsonschema pytest pillow
```

The `.venv` folder and `pipeline/out/` are git-ignored.

## Commands

| Command | What it does |
|---|---|
| `pipeline/.venv/Scripts/python.exe pipeline/rebuild.py` | Rebuilds everything the app bundles, checks it, and lists what changed: see [Rebuilding for a mod release](#rebuilding-for-a-mod-release-436) |
| `pipeline/.venv/Scripts/python.exe pipeline/parse_ships.py` | Parses every hull in the four eras into `pipeline/out/ships.parsed.json` and prints a summary |
| `pipeline/.venv/Scripts/python.exe -m pytest pipeline/tests -q` | Checks the parser against the hand-filled samples |
| `pipeline/.venv/Scripts/python.exe pipeline/content_gaps.py` | Assembles every entry and writes the content-gap report to `data/content-gaps.md` and `.json` |
| `pipeline/.venv/Scripts/python.exe pipeline/review_hulls.py` | Applies the inclusion rules and writes the yes/no list to `data/hull-review.md` |
| `pipeline/.venv/Scripts/python.exe pipeline/validate.py <file>` | Validates a data file against the [Ship Data Schema](/Ship-Data-Schema.md) |
| `pipeline/.venv/Scripts/python.exe pipeline/sample_palette.py <theme>` | Lists the dominant colours in the reference images in `data/reference/<theme>/`, as a starting point for that theme's palette ([Interface References](/Interface-References.md)) |
| `pipeline/.venv/Scripts/python.exe pipeline/mirror_reference.py inventory\|fetch <url>` | Mirrors a reference website (lcars.org.uk) into `data/reference/<host>/`, one request at a time. `fetch <url> stills` gets the pages and stills only; `rest` gets the videos and everything else |
| `pipeline/.venv/Scripts/python.exe pipeline/tools/sfc2/iscab.py list\|get F:/ …` and `q3sprites.py` | Read the *Starfleet Command II* disc's InstallShield cabinet and decode its interface sprites ([Interface References](/Interface-References.md)) |
| `pipeline/.venv/Scripts/python.exe pipeline/sort_reference.py` | Files the mirrored site's stills by theme, from each section's era and each alien screen's race, into `themes.index.json`; `sample_palette.py` reads it |
| `pipeline/.venv/Scripts/python.exe pipeline/build_data.py` | Writes the app's data file, `app/assets/data/ships.json` (all eras), the ship icons (`app/assets/icons/`) and the theme palettes (`app/assets/data/themes.json`). `--era TNG --faction federation` writes just that slice, e.g. `ships.tng-federation.json` for the prototype |

## Rebuilding for a mod release (#436)

When the mod changes, update its SVN working copy (TortoiseSVN, Update), then run:

```
pipeline/.venv/Scripts/python.exe pipeline/rebuild.py
```

It parses the ships, packs the turntable sheets, writes `ships.json`, the icons, logos and themes, refreshes the content-gap report and the hull review, then validates the data and runs the pipeline and app tests. The first failure stops it, so nothing half-built gets past the checks. At the end it lists the files that changed in `app/assets` and `data`, ready to review and commit on a branch. A full run takes about five minutes.

- `--render` renders any turntables still missing first: new or changed models, after deleting their folder in `pipeline/out/turntables/`. It needs Blender and the GPU; complete renders are skipped.
- `--package` then builds the Android APKs and the Windows installer and zip (`tools/package_windows.ps1`).
- `--skip-app-tests` leaves out `flutter test`, and `--list` shows the steps without running them.

The Dex never writes to the working copy. `build_data.py` stamps the data with its revision, and warns when the copy has mixed revisions or local changes. A rebuild that changes nothing keeps the old build time, so `ships.json` only shows as changed when its data really differs.

## How `.ship` files are read

**No Lua interpreter.** A survey of all 596 `.ship` files (#411) found they are pure data: `NewShipType.<field> = <literal>` lines and calls such as `addAbility(...)`, with no `if`, loops, functions, locals or `dofilepath`. So `dexpipe/lua_ship.py` is a small reader for Lua literals (strings, numbers, booleans, tables, nested calls) that:
- strips `--` comments, so commented-out weapons really are ignored;
- reads calls by matching brackets, so calls spread over several lines work (13 files do this);
- copes with bare decimals like `.69`.

It parses all 596 files in under a second.

## Rules applied (`dexpipe/ships.py`)

- **Faction** comes from the hull prefix (`fed`, `kng`, `rom`, `car`, `dom`, `brg`, `vth`, `grn`, `fer`, `thl`, `und`, `brn`, `zzz`). `fed_TES_*` hulls are the Terran Empire. `hgn_*` (stock Hiigaran leftovers) are skipped.
- **Weapons** are counted from active `StartShipWeaponConfig` lines, without the `X_` shield twins. Each weapon's kind comes from its `.wepn` fire type:

  | Fire type | Kind |
  |---|---|
  | `InstantHit` | beam (this includes disruptors) |
  | `Bullet` | pulse |
  | `Missile`, `Mine` | torpedo |
  | `SphereBurst` | other |

  Repair guns, EMPs, stasis weapons and superweapon effects are counted as **other** whatever their fire type.
- **Weapon figures** (`dexpipe/weapons.py`, #428) read each mount's `.wepn` file for damage a hit, the time between shots or bursts, range and damage per second, as set out in the [Ship Data Schema](/Ship-Data-Schema.md#weapon-figures-428).
- **Abilities** leave out the commands every ship has (move, waypoint, parade, guard, retire, launch, dock, attack, gate travel). The rest get readable names. Custom commands are named after the script function they start (`Start_SeparationSplit` becomes "Separation", and so on).

## Which hulls are in (#602)

`dexpipe/inclusion.py` applies the ruling of 2026-10-17, in this order:

1. **Nathan's answers** in `data/hull-decisions.json` win over everything: single-hull `decisions` first, then group answers.
2. `unitCapsFamily = "SeparationPart"` → a **variant** of its parent (Galaxy and Prometheus parts).
3. `*_tutorial` copies, effect and helper objects, and research-tree icon holders → **out**.
4. In any race's build list (`scripts/build/*.lua` or `scripts/def_build.lua`) → **in**.
5. In an era's Keeper list (`KEEP_tArchetypes`) → **in**.
6. Anything else goes on the **yes/no list**, grouped where hulls are alike, with whatever else in the mod refers to each hull as evidence.

Group answers only ever apply to hulls that would otherwise be asked about; they never override the rules above.

Answers can do more than yes or no:

| Answer field | Effect |
|---|---|
| `variantOf` + `kind` (single hull) | The hull appears on another hull's page, e.g. the D'kyr shuttle as a separation part of the D'kyr |
| `escort` (group) | Each hull becomes an **escort** on its carrier's page; the carrier comes from the mod's `DRONE_SetupHostClass` |
| `showOnlyOn` (single hull) | `{month, day}`: the app shows the entry and its variants only on that date |
| `merge` (group) | Hulls with the same era, faction and name collapse into one entry plus variants (Construction Bees) |

Each record also notes its **model**: the HOD it draws, either its own or another hull's via `LoadSharedModel`. 117 hulls borrow a model, and hulls sharing one can share a turntable render.

**Status after Nathan's answers (2026-10-17):** 370 entries in, 135 out, 87 variants (42 Construction Bee variants, 35 escorts including the Hutet's two Norin, 9 separation parts, and the TMP Ambassador refit as a "Refit" toggle on the Ambassador), plus subsystem toggles on nine ships (below). Nothing waits on an answer. The USS Brisbane and its sections carry `showOnlyOn` 28 July, so the app shows them only on that day, matching the in-game easter egg.

## .def files and build lists (#415, #417)

- **`.def`** (`dexpipe/defs.py`): size category, length and width, and AI roles. Zero dimensions become `null` (unknown).
- **Build lists** (`dexpipe/buildlists.py`): read as Lua tables from `scripts/build/*.lua` and `scripts/def_build.lua`. All 284 ship descriptions use the same headings (Crew Complement, Armament, Defences, Prerequisites, Summary); a few add Subsystems or Air Wing, kept as `other`. "N/A" or "Unmanned" crew becomes 0. An empty `RequiredResearch` means none is needed.
- When a `.ship` name is a stock localisation code (`$1546`), the build list's name is used ("Remote Sensor Probe").
- **Subsystem toggles** (`dexpipe/subsystems.py`): the mod switches a ship's model state when certain subsystems are fitted, declared in each era's `EraSpecificShipCode.lua` as `COND_AddConditional(ship, CONDITION_SUBSYSTEM, subsystem, { EFFECT_MADSTATE ... })`. A ship with **one** such subsystem gets a **refit** toggle (labelled with the sub-class the description names, else the build list's name, else "Refit"). A ship with **two or more** gets one **subsystem** toggle per module, labelled with the build list's name. Stats come from the `.subs` file: `AddSubSystemMultiplier(..., "ThisShipOnly", ...)` for MaxSpeed and MaxHealth, and `costToBuild`/`timeToBuild` added to the hull's.
  - Refits: NX (and the ENT flagship, an NX), Tellarite T'Garim, TMP Excelsior, Borg Cube (Tactical Armour).
  - Subsystems: Miranda (Sensor Suite, which makes it a Soyuz; Phaser Cannons; Torpedo Roll-bar), Oberth (Sensor Suite, Torpedo Roll-bar, Support Suite), Nebula (Sensor Phalanx, Torpedo Battery, Warp Nacelles), Tonga (Sensor Suite, Torpedo Pods).
- **`dexpipe/assemble.py`** merges everything into full entries in the schema's shape, attaches variants (escorts sharing a model collapse into one with a `count`), and keeps pipeline-only facts under `_pipeline`.

All 370 assembled entries validate against the schema.

## Research names (#421)

`dexpipe/research.py` reads every race's `scripts/research/*.lua` and fills in each `RequiredResearch` alternative's displayed name, e.g. `Fed_TNG_CapitalTech` → "Capital Sized Chassis". Names are matched without regard to case, as the engine does (build lists and research files disagree on `Fed_` and `FED_`).

Each race also has two AI-only tree cores, `<RACE>_<ERA>_Research_Tree` and `<RACE>_<ERA>_Flagship_Tree`. The game grants one at the start of a match (the flagship tree in flagship modes), so they're marked `startingTree: standard` or `flagship` with a null name, and the app can say "available from the start". Every alternative across the 370 entries resolves: 197 entries need research, 67 need only a starting tree, and 106 have none (no build entry).

## The bundled data file (#431)

`pipeline/build_data.py` assembles every entry, drops the pipeline-only `_pipeline` facts, adds the eras and factions (`dexpipe/catalogue.py`), validates the result and only then writes it, compact, to `app/assets/data/`. The app bundles that folder (`pubspec.yaml`).

- **Data version:** `modRevision` is the highest revision `svnversion` reports for the mod working copy. A mixed or locally modified copy gets a warning, because a release build should come from a clean, updated copy.
- **Factions:** a faction is listed when it has entries, with the eras it has entries in. It's **playable** when the mod has a race folder for it in any era (`scripts/races/<faction>`), not merely when something of theirs is buildable: the Dominion builds the Breen Chel Grett, but the Breen aren't a playable race. The Terran Empire (TOS) shares the `fed` prefix through `fed_TES_flagship`.
- **Size:** all four eras are about 630 KB; TNG Federation alone is about 66 KB.

## Ship icons (#439)

`dexpipe/icons.py` reads each era's `ship/icons/races/*_icons.lua` and `ship/icons/shipicons.lua`. Every hull has a table naming its `LargeIcon` texture, a 2048 × 2048 DDS atlas or a single TGA in the era's `ship/icons` folder, and the pixel rectangle the icon fills: either `textureUV = {left, top, right, bottom}`, or `textureUV_TL = {left, top}` with `textureUV_WH = {width, height}`, as the single-image icons use (both forms are the game's own). The game's icons are glowing outlines, 512 × 256. `build_data.py` crops each one, scales it to 256 × 128 and saves it as WebP at quality 85, about 7 KB each (lossless is about 22 KB with no visible gain). They go to `app/assets/icons/<era>/<hull>.webp`. A variant that's a hull with a different icon (a separated saucer, an escort) gets its own.

Many hulls borrow another's icon by plain assignment in the icon files, sometimes in a chain: `fed_TNG_flagship = fed_TNG_sovereign`, the Construction Bees to their resource collector, `car_TNG_hideki_grey = car_TNG_hideki`. The pipeline follows these, and tables may be indented. Every entry has an icon: 434 files including variants.

The Planet Killer and the Crystalline Entity were the last without, until the icon overhaul gave them their own (#654, #655).

## Themes (#570, #573)

The palettes are hand-researched in `data/themes.source.json`, one frame per era plus, for each faction, either a frame of its own or just an accent. Each entry names its sources and a confidence (canon, fan or proposed). See [Design Language](/Design-Language.md) and [Interface References](/Interface-References.md). The mod's HUD tints aren't used.

`dexpipe/themes.py` adds the text colours (black or white, whichever reads better) and checks every pairing the screens use against WCAG AA (4.5:1):
- text on each structure colour and on the accent;
- the first two structure colours, the data colours, the accent and the highlight as text on black.

`build_data.py` refuses to write `app/assets/data/themes.json` if any pairing fails. Today all pass.

## Credits (#425, #935)

The mod credits its models in two places, read by hand into `data/credits.source.json` (hull, then authors with their part and an optional note):

- **The ship credits table in `Read Me Files\ReadMe.docx`** (the same file in every era folder) names the creator of every model the mod ships, one row per hull, with notes such as "Kitbash by Nathanius" or "Edited by HerbyGuitar". This is the primary source: it is newer than the readmes, and many of the newest models came straight from their makers over Discord with no readme at all (Max Loef's Norway, for one). E-mail addresses in its notes are left out; a Sketchfab link is kept as the source, since those models are licensed for use with attribution.
- **The per-ship readmes** beside each model's source files (`Source Files\Ship mesh and texture files\Ship Files\<hull>\`) and in `Read Me Files\ReadMe files for sourced models` (158 files, named after the hull, with an `aux_` prefix for minor-faction ships, and a few packs that cover several hulls) give the detailed roles: "Aad Moerman (model, textures)". They are used where they agree with the docx creator. Where a readme names someone else it belongs to a model the mod no longer ships, so the docx wins: the Akira is Wholock's, from Sketchfab, though Aad Moerman's Akira readme is still in the folder.

Where neither names anyone but a readme uses an author's known template, the note says the credit was attributed from that wording.

`dexpipe/credits.py` credits an entry from its own hull, or failing that from the hull whose model it loads (`LoadSharedModel`); the note then says "Shares the X model." Entries with no credit get no authors and a note saying so.

343 of 370 entries are credited. `content_gaps.py` writes the other 27 to `data/credits-missing.md` (#427), for the team to fill from what they know.

## Notable ships (#934)

`dexpipe/notable.py` reads `stc_shipnames` from each era's `scripts\continuum\shipscope\EraSpecific\era_ship_names.lua`: one list of names per hull, which `stc_rego.lua` hands out in order as ships of the class are built. Lists that repeat a single placeholder (every Brisbane and Prometheus vector part is "Vector Alpha") name no ships and are dropped; the Mirror Universe list (`stc_mirrornames`) isn't shown.

The game has registries only as lettering in the hulls' `_NAME` texture atlases (in each hull's Ship Files folder), and the lettering on the hull is authoritative (#942). Every Federation hull with an atlas was read by eye, and its registries are kept in `data/registries.source.json`, hull to registries in the names' order. The few hulls without an atlas (the Minuteman and the single-ship classes) take the team's `Source Files\Ship mesh and texture files\Ship Names.xlsm` (Regos sheet). The team's sheet and the lua's names were then corrected to match the hulls (Graf Zeppelin, Friedland, Rienecker for Grissom, San Francisco, Wilhelmina Amalia, Aquilia Severa, Merrimak, Bozeman, Krasnye Barrikady, Gourard and Berman for Glenn and Discovery, and S.S. for the DY-750s), and the Mirror Universe lists that had fallen out of step (Excelsior, Galaxy, Akira, Intrepid) were rebuilt from the main lists. The table below records what was found.

What the atlases showed against the sheet and the lua:

| Where | Sheet or lua | On the hull |
|---|---|---|
| Class leads (Excelsior, Miranda, Akira, Galaxy, Intrepid, Nebula, Norway, Sabre, Steamrunner) | NX-… in the sheet | NCC-… |
| Excelsior | The sheet skips the Lamisa, so every row from the 7th on is one ship out, and has Grissom for NCC-42857 | Lamisa NCC-14700; Rienecker NCC-42857 |
| Galaxy, Akira, Intrepid | The sheet has 7, 6 and 3 of the 14, 15 and 13 ships | All of them |
| Centaur | Fadlallah NCC-42087, Iskandarov NCC-42084 | The other way round |
| Sovereign | Warspite NCC-73821, Musashi NCC-74633, Ark Royal NCC-90222 | NCC-74922, NCC-74660, NCC-75922 |
| TOS Constitution | Potemkin NCC-1657 | NCC-1659 |
| McQuarrie | Glenn, Discovery (14th, 15th) | Gourard NCC-1030, Berman NCC-1031 |
| DY-750 | U.S.S. Lief Ericson … | S.S. Leif Ericson …, all twenty as S.S. |

Three names look misspelt on the hull itself, so the sheet and the lua keep the correct spelling: Daedalus "Kearsage" (Kearsarge), Ambassador "Zarnita" (Zarnitza), Midway "Harrurabi" (Hammurabi). The Intrepid atlas also has plates out of step with their names: the Gallant's large plate reads NCC-76719 (the Blackthorne's), the Jefferson's and Mercutio's large plates are one ship behind, and the Nelson's, Sagan's and Zealous's curved plates show the wrong number. The Dex uses the registry each name's own plate repeats most.

155 entries list notable ships; 644 of those ships have a registry, all Federation (other factions' hulls carry no registry).

## Canon (#423)

`data/canon.source.json` gives each class the highest tier of source it has: **A** Memory Alpha (seen on screen), **B** Memory Beta or another licensed work (novels, games, Eaglemoss), **G** Memory Gamma or the STO wiki (fan works and Star Trek Online), or **none** (the mod's own design, always with a note saying what the name refers to). `dexpipe/canon.py` attaches it by hull only, because two hulls can share a model and still be different classes. Shipyards, miners, turrets, outposts and Construction Bees have no class, so their `canon` stays null.

How the table was built:
1. The decisions in the HWRM-Continuum wiki's [Canon Verification Results](https://dev.azure.com/molla-workshop/HWRM-Continuum/_wiki) (name fixes, Gorn from Starfleet Command II, role notes).
2. `pipeline/canon_check.py` asks Memory Alpha's and Memory Beta's MediaWiki APIs which titles exist for each entry's name ("<name> class", "<faction> <name>", "<name> type", the plain name) and writes the hits to `pipeline/out/canon.candidates.json`. The wikis' HTML pages refuse scripted requests, but the APIs answer. The STO wiki sits behind a bot check, so it isn't asked.
3. Every hit was reviewed by hand. Redirects often land on the wrong thing (the Kazon Predator, a person, a video game's article), and those were corrected with targeted titles. The rest were searched on the web.
4. Where the Eaglemoss Official Starships Collection has an issue on the ship (`Source Files\Ship Reference Materials\Eaglemoss`), the note names it.
5. Every URL in the table was checked through the APIs.

Result: 237 of 370 entries have a canon source: 87 at tier A, 97 at B, 2 at G, and 51 marked as the mod's own with a note. The other 133 are structures.

## Turntable renders (#446, #457, #916)

Every model the Dex shows is rendered as a turntable in Blender 4.1, headless, then packed into one sprite sheet per model for the app:

```
python pipeline/render/batch.py              # render every model (about 20 minutes)
python pipeline/render/sheet.py --all        # pack the sheets (18 frames, 256 px) and write data/turntables.json
python pipeline/build_data.py                # attach them to the entries
```

- **Matching textures to materials.** A DAE material reaches its image through its effect, by id. Images are matched on their whole id, not their name: names can contain one another (the Grendel's two hull images are both named `IMG[grn_TMP_grendel01_DIFF]`), and a name match gave both materials one texture.
- **The DAE first.** Each model renders from its DAE, which is what the game's HOD is built from. The FBX beside it is a 3ds Max export, and some disagree with the game: the TMP flagship's is upside down, the Brisbane's lies sideways, the Hutet's doors float above it, the TES flagship's names the TOS Dreadnought's textures, and a few predate their textures being packed into an atlas. The FBX is used only when a model has no DAE, or its DAE fails to render.
- **Reading the DAE.** Blender's Collada importer reports success on the mod's FCollada exports but creates no objects, so `dae.py` reads them itself: node transforms, triangles and polylists with normals and UVs, material bindings, and the animation channels on joint transforms. `dae_to_fbx.py` uses it to write an FBX for other tools.
- **Aliases.** A few sources live under other names: the Klingon and Dominion flagships use the Negh'Var's and the carrier's models (their `.def` sizes match), and the Crystalline Entity's DAE is in `zzz_TNG_crystalline`. The TMP outpost and TMP Spacedock have no source model, so they show their TNG counterparts' renders (`REUSE` in `dexpipe/turntables.py`).
- **One model per Blender.** Each job renders in its own headless Blender, so one bad file can't stop the run. A job whose frames are complete and not empty is skipped, so a stopped run resumes; a file that fails or renders nothing gives way to the next, and `pipeline/out/turntables/report.json` lists what failed, what has no source, and any textures still missing.

What `turntable.py` does with a model:
- **Keep only `MULT[...]_LOD[0]`.** The FBX also carries collision and shield meshes, nav lights, joints, dock paths and lower-detail meshes.
- **Bake the transforms.** The importer stands the Y-up game model upright on its root joint; unparenting the meshes loses that turn, so each mesh's world transform is baked into its vertices first. A few models were exported without the turn and stand on their tails; when the `.def` length matches the vertical extent, they're laid flat.
- **Textures.** The file an image loads names its texture stem first (`fed_TES_flagship_1_DIFF.tga`); failing that, the image's name (`IMG[K_Vorcha_A_DIFF]_FMT[DXT5]`, or any channel of it, such as `IMG[fed_ENT_NX_GLOW]`). They're looked up in the hull's folder, then anywhere in Ship Files, because some hulls borrow another's textures (the Brisbane sections use the Prometheus's). `_DIFF` is the colour, and its alpha cuts holes (grilles, open frames); `_GLOW` is a greyscale mask for lit windows and engines, used as emission; `_NORM` gives the surface detail (DirectX normals, so green is flipped for Blender); `_SPEC` sets how shiny each part is and `_REFL` how mirror-like. `DEX_FULL_MAPS=0` renders colour and glow only, for comparison. A part with no texture to be found shows in plain hull grey. Engine-flare geometry (`SHD[thruster]`) is hidden.
- **Registry plates are hull skin.** Faces with the `shipplatekai` shader are part of the hull, not an overlay; hiding them leaves holes. A plate with a real texture of its own is drawn like any hull (the NX refit's whole upper hull uses the shader). Template plates take the typical colour of the hull texture they sit on (the part's own, or the hull material on the same mesh), with the lettering of the part's `_NAME` atlas. That colour is the median of a sample, so lit windows don't lighten it, converted from the texture's sRGB to the linear values a material expects.
- **Model states and poses.** The game shows a ship through model states in its `ship/<hull>/<hull>.madstate`, Lua with one function per state that calls `setJointVisible(ship, "<joint>", 0 or 1)` and `startAnim(ship, "<animation>")`, then holds the animation on its last frame. `dexpipe/madstates.py` reads them, `OnPause` included (the T'Garim swaps its turret once deployed). Animations are frame ranges marked `ANIM[<name>]_STF[<start>]_ENF[<end>]` at 30 frames a second; `dae.py` samples each channel an animation drives at that animation's end, and leaves the rest at their rest transform.
  - The ship renders as built: its `Normal` state. Probes and sensor satellites render deployed (their `Open` state), and the D'Kyr with its warp ring raised.
  - Each toggle renders again, as `<model>@<key>`, in the state it switches to: subsystems (the Nebula's pods, the Tonga's sensors and pods), research upgrades (`CONDITION_RESEARCH` in `EraSpecificShipCode.lua`: the Negh'Var's Heavy Pulse Cannons, the K'Toch'Vah's Disruptor Array), and Attack Mode (the `CodeRed` state: wings down on the ENT Bird-of-Prey, the B'rel and the TNG fighter, and the Cardassian turret swung round into its firing position). The ship's own choice on that toggle is called Flight Mode, or Stand-By Mode for the turret. Other ships animate `CodeRed` too, but nothing a render would show: the TOS Constitution family deploys small phaser turrets, and the Dominion light cruiser spins a gatling gun.
  - Meshes under a hidden joint are dropped.
- **Output.** 387 renders: 371 models and 16 subsystem states. 36 frames at 384 px with a transparent background, from slightly above, starting bow-left. EEVEE takes about 3 seconds a model.

`sheet.py --all` crops each model's frames to the box that holds the ship in all of them, so the turning axis stays centred, and lays them out in a WebP sheet in `app/assets/turntables/<model>.webp`. The frame count (`--step`, 2 by default: 18 of the 36 frames) and cell width (`--width`, 256 by default) are chosen when packing, not rendering, and the WebP is lossy in colour (quality 80) and alpha (quality 70), all set by the size budget in [App](/App.md#size-and-performance-budget-504), so the app's download size can be tuned without rendering again. `data/turntables.json` records each sheet's frame count, columns and cell size; assembly attaches it as `media.turntable` to every entry, to variants whose model differs from their parent's, and to each subsystem variant, so the toggle on the ship page swaps the turntable.

`pipeline/render/measure.py` uses the same import to measure hulls whose `.def` gives no size (#650). Model units are metres, as in the `.def` files: the Galaxy measures 651 × 466 against 652 × 464. Fourteen entries take their dimensions from it through the content overlay, including the Planet Killer and the Crystalline Entity from their converted DAEs. The TMP Spacedock, which has no source model, takes the TNG Spacedock's size with its render, and the transwarp gate is measured mesh by mesh: it really is a ring 7.3 km across and 6.6 km tall, 591 m deep, with no effect mesh inflating it. Every entry now has dimensions.

## Dex-written content (#638)

Some entries have no text in the mod at all: flagships, outposts, starbases, Construction Bees, civilian stations and the Keeper and mission ships have no build-list entry. The Dex writes their text itself in `data/content/<era>.json`, and `dexpipe/content.py` merges it over the mod's during assembly.

- An entry can give a `subtitle`, any of the description fields (`lead`, `crew`, `armament`, `defences`, `prerequisites`, `summary`), `dimensions`, and a `source` naming where its facts come from.
- `"auto"` derives a field from the ship's own data, so it can't drift from the game. Armament comes from its weapon mounts, in the mod's plain-plural wording ("Disruptor Pulses"). Defences come from its abilities (shields, or a regenerative hull for the Borg, plus a cloaking device where it has one). Prerequisites come from its first research alternative.
- Crew is given only where a source states it; the rest stay open for the team. The Eaglemoss Official Starships Collection (`Source Files\Ship Reference Materials\Eaglemoss`) gives most of them, issue by issue, and the source note names the issue (#914). An automated weapon such as the Planet Killer has 0, which the app shows as Unmanned. Structures show no crew and the gap report doesn't ask for one: outposts, starbases, civilian stations, turrets and Regula I (the Platform and Megalith classes), and the Crystalline Entity, a creature (`is_structure` in `content_gaps.py`). The 20 ships still without a figure are the mod's own designs or classes no source gives a crew for; they stay in the report for the team.
- Each entry records the fields that came from the Dex in `_pipeline.dexWritten`, and the gap report counts them under "Dex-written content".
- Text that would also improve the game can be offered back to the mod through the Continuum board (decision #637).

## Content gaps

`pipeline/content_gaps.py` checks every entry for the same level of detail: proper name, subtitle, description lead, crew, armament, defences, prerequisites, summary (at least 60 characters, and written for that ship rather than shared), dimensions, roles, and a `RequiredResearch` field on buildable ships.

First report (2026-10-17): **201 of 370 complete.**

| Gap | Entries |
|---|---|
| No build-list description (flagships, outposts, stations, Construction Bees, mission and Keeper ships) | 86 |
| Summary shared with other ships (12 groups of generic text) | 62 |
| Summary under 60 characters | 19 |
| No lead line (all Borg) | 16 |
| No dimensions | 16 |
| `RequiredResearch` misspelt in the mod (2 Borg; fixed in the working copy, #651) | 2 |

Filling these is the content pass, feature #636. Where Dex-written text lives is decision #637.

## Current output (2026-10-17, mod r4014)

| Era | Hulls |
|---|---|
| ENT | 100 |
| TOS | 81 |
| TMP | 121 |
| TNG | 290 |

That's 592 in total, with none failing. Every weapon resolved to a `.wepn` fire type, and every custom command has a name.

42 hulls have no speed, cost or build time. They aren't ships: they're effect and helper objects (shockwaves, the black hole, camera, ticker, the Jach'Eng wave, the Romulan singularity). The inclusion rules (#609) will leave them out.

## Still to come

Credits for the remaining models (#427), icons (#439), per-weapon statistics (#428), a validation report (#434) and a one-command rebuild for each mod release (#436).
