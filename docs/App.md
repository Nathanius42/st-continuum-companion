# App

How the Flutter app in `app/` is put together. For the language and framework basics, see the [Dart and Flutter Primer](/Dart-and-Flutter-Primer.md).

## Screens

| Screen | File | Board |
|---|---|---|
| Splash: the STC website's "access restricted" door, with its login beep | `lib/screens/splash_screen.dart` | #941 |
| Front page: the S-shaped frame, the mod's animated logo, the stardate, and the menu | `lib/screens/front_page.dart` | #941 |
| About (mission, team, Steam Workshop awards), Credits (from About), Comms, Access, Media | `lib/screens/info_screens.dart` | #941 |
| Factions: every faction by name, then an era | `lib/screens/factions_screen.dart` | #941 |
| Search and filters across every era | `lib/screens/search_screen.dart`, `lib/data/search.dart` | #495 |
| Compare two ships | `lib/screens/compare_screen.dart` | #498 |
| Starship Database: pick an era, on the trunk of a subsystem status display | `lib/screens/ship_library_screen.dart` | #480 |
| Factions in that era (playable first; non-playable ones greyed) | `lib/screens/faction_list_screen.dart` | #482 |
| A faction's ships, grouped by class, with the fleet's flagship in a group of its own above Capital | `lib/screens/ship_browser_screen.dart` | #484, #931 |
| The ship page: variant toggle, specifications, game specs, summary, weapons, research, abilities, description, notable ships, canon, credits | `lib/screens/ship_detail.dart` | #487, #605, #934, #423, #425 |

**Phone and desktop (#542).** Below 840 logical pixels wide, it works like a phone: one screen at a time, and tapping a ship opens its page. At 840 or wider, the ship list and the ship page sit side by side, and clicking a ship in the list changes the page beside it. The breakpoint is `wideLayoutWidth` in `ship_browser_screen.dart`.

**Getting around.** The sidebar lists the options of the screen one level up, so a sibling is one tap away. The faction list's sidebar lists the eras, and the ship list's sidebar lists that era's factions by their badges alone (the name is the tooltip and what a screen reader says). The current one is drawn in the highlight colour. Switching replaces the screen instead of stacking it, so BACK still goes up a level. A ship page on its own screen has a plain sidebar, because BACK at the top already returns to the list. On every screen below the front page, the bottom elbow is HOME and returns to it. Whether a screen shows BACK and HOME depends on whether there's a screen below it (`ModalRoute.canPop`), not on whether anything sits above it.

**Front page (#941).** The app opens on the splash from the STC website: "LCARS online", the library database, "access restricted" blinking, and REQUEST ACCESS, which plays the website's login beep, grants access and fades to the front page. The splash replaces itself, so the front page is the first screen and HOME returns there. The front page is modelled on a TNG status display, in that display's corals, salmon, orange, lavender and pink, and has no sidebar: the menu is the page. An elbow frames the top section down the left, with the stardate in figures at the end of the top bar and the mod's logo filling the section (`animatics/STC_Logo.webm`, converted to an animated WebP). A bar sweeps across the middle and turns down the right like an S. The bottom section holds the menu, a row per section in the display's style: a rounded block with the name, a figure and a square tail with a caption. STARSHIP DATABASE (the ship library, by era) comes first with its entry count; Search, Factions and Media show their counts of eras, factions and trailers, which a screen reader reads with the caption. The right-hand column holds the settings, and the bottom bar the versions. The frame is worked out from the window's width and height, so it fills the screen: the logo (drawn without the black margin of its frame) is up to 200 high, on a short window it shrinks (to 70 high) before the page scrolls, and on a tall phone the menu rows grow (to 64) instead of leaving empty space. The logo plays once, then the still takes over; a tap plays it again. The animation opens on black frames, so as soon as another screen covers the front page the still stands in, and coming back never finds it stalled on a black frame. The section screens keep a sidebar of the sections, so each is one tap from the others, and each takes its look from a TNG display:

| Section | Modelled on | Shows |
|---|---|---|
| About | Starfleet personnel files | Facts about the mod, the crew, each Steam Workshop release's rating, subscribers and awards; the file holds the mission and what the mod is about; CREDITS in the top section |
| Credits | Personnel files, as the mod database archive | The non-ship credits from the mod's ReadMe.docx (scripts, effects and shaders, music, maps), split between the facts and the file |
| Comms | Personnel files, as the communications net | The Discord (where help is given), the Steam group and the guides; the file holds how to report a bug |
| Access | Personnel files, as online records access ("The Hunted") | The Steam Workshop page for each era; the file holds ModDB |
| Media | Holodeck programming ("The Outrageous Okona") | The trailers and teasers as numbered programs |

About, Comms, Access and Credits follow the personnel files: "KEY: VALUE" facts down the left in periwinkle and orange, and a framed panel on the right with a large heading over the long text in condensed capitals. On a phone the panel folds in under the facts. Media is a grid of programs, each a numbered block and a pill with the trailer's name and where it's hosted (one column on a phone, two in a wide window). Tapping a program opens its thumbnail underneath, with a play mark; tapping that plays the trailer on YouTube (or ModDB), in the browser or the YouTube app. The thumbnails are bundled (`assets/media/<YouTube id>.webp`, or the ModDB video's name), 640 × 360, so the page needs no network until a trailer plays. Steam ratings read "rating 5/5", because the LCARS font has no star glyphs.

**Display frame.** `lib/ui/lcars_display.dart` draws the section screens modelled on TNG displays (the personnel files, subsystem status and command interface), in their palette of orange, gold, peach, lilac, periwinkle and coral (`LcarsColours`): an optional top section, framed by an elbow under BACK, with the title in large capitals at the top right; a band across the middle whose elbow turns down into the sidebar; and an optional framed panel on the right, whose own elbow turns down into a column of blocks. HOME is the sidebar's last block. A display that's only the lower half (the Starship Database) has BACK and the title in a slim row above the band. Everything is placed from the window's size, so the frame always fills the screen.

**Starship Database.** The era picker is the lower half of a subsystem status display: a blue bar and a gold bar run down the middle as a trunk, curving off along the top, and the eras zigzag either side as pills joined to it, ENT and TMP on the blue side, TOS and TNG on the gold. Each pill shows the era's name and, large, its year; a screen reader also hears how many ships the era has. It's plain TNG LCARS whatever the era; each era's own look starts on the next screen.

**Factions** is a tactical cartography display (DS9 "Apocalypse Rising") holding a galaxy star chart after the Starfleet cartography displays ("The Game", "Milky Way Galaxy"), in `lib/ui/territory_map.dart`. The eras run along the top section as pills; the one lit is the chart shown. The chart is the galaxy as a tilted disc over a starfield, its core glowing, with gold rings and the lines between the Alpha, Beta, Gamma and Delta Quadrants. Each power stands on it as a translucent cylinder in its own colour (blue Federation, red Klingons, green Romulans and so on), where the shows put it: the Federation, Klingons, Romulans, Cardassians and Ferengi about the Alpha and Beta Quadrants, the Dominion in the Gamma Quadrant, the Borg and Voth in the Delta Quadrant, and fluidic space and the mirror universe off the disc. Names run down each side, level with their powers, with a line to each. Each era shows only the powers it has, at its size then: the Federation grows from United Earth in ENT to the centre of TNG; the Romulans are smaller in TOS than in ENT, after the Earth-Romulan War, and recover by TMP; the Klingons are as big in TNG as in TMP, held back by the Praxis disaster. Tapping a power or its name chooses that faction, and the fleet evaluation beside the chart (under it on a phone) opens with the faction's homeworld scene, framed in its colour as a personnel file frames its photograph, then gives a short blurb about it, its ships in that era with OPEN FLEET RECORDS for the list, and its classes. The blurbs are our own words, in `assets/data/home.json` under `factions`: the Federation, Klingons and Romulans have one per era, as they change across the eras, and the rest one each.

The homeworld scenes (`assets/factions/`, 768 x 597 WebPs, about 1 MB together) are the Dex's own, generated in the local image pipeline in the manner of SFC2's empire cityscapes, with those as a style reference only: Starfleet Headquarters in San Francisco, Qo'noS's First City and Great Hall, and the Romulan capital, one for each era; then Gornar, Tholia, the Terran Empire's Earth, Cardassia Prime, the Great Link, the Borg Unicomplex, a high-tech Voth waterfall city, Ferenginar in the rain, the frozen Breen homeworld and the reefs of fluidic space. Unaligned has none. Factions with nowhere to stand (Unaligned) are pills under the chart.

The chart is the Dex's own drawing; published maps (*Star Trek: Star Charts*) are copyright, and no openly licensed ones were found.

The text and links come from `assets/data/home.json`, bundled so the app needs no network. The Steam figures are a snapshot with its date; update them there.

**Search (#495).** Search is a front-page section, on a TNG command display (`LcarsDisplay`, below). The search box, CLEAR and the count of matches are in the top section, the results below. Typing narrows the list as you go. The text matches a ship's name, subtitle, hull id and class, its variants (a saucer, a refit), and the ships the game names for its class with their registries, so "Yamato" or "NCC-71807" finds the Galaxy, with the match shown under it. Accents, case and punctuation don't matter. The best matches come first: the name starting with the text, then containing it, then the rest. The filters are in the framed panel on the right: its column lists the categories (era, faction, class, where flagships are their own class as on the ship list, role, size, and how the ship appears in the game), each with how many of its options are set, and beside the column are the options of the category chosen, as pills that fill orange when chosen. Any choice within a category matches, and every category must. On a phone the panel is just its column, and tapping a category opens its options over the results, with DONE to close them. In a window wide enough for both (about 1600 pixels), the selected ship's page sits beside the results, in its own era's look; otherwise a tap opens it. The search screen can also act as a picker (`onPick`), handing back the ship tapped.

**Compare (#498).** COMPARE on a ship page opens the search screen as a picker; the ship tapped is set beside the first, and the picker gives way to the comparison, so BACK returns to the ship page. The comparison, in classic LCARS, has a column per ship (CHANGE swaps either for another, SWAP trades sides): length, width, crew and class, then hull, speed, cost and build time, damage per second and the weapons by type, and roles and abilities. Each figure has a bar scaled to the larger of the two, and the better one is lit: more hull, speed, damage and weapons, less cost and build time. It compares the ships as built; variants stay on their own pages. A ship's class and size show once when they're the same word (Capital, not Capital · Capital), here and on the ship page.

The sidebar's blocks shrink (to 0.7 of their height at most) so every section fits before the sidebar has to scroll.

**Motion.** `lib/ui/lcars_motion.dart` has the small animations: lamps (`LcarsLamp`), ticking readouts (`LcarsReadout`), a sweeping scan line (`LcarsScanBar`) and today's stardate in the Kelvin films' format, which keeps real dates positive: the year, then the day of the year (18 October 2026 is 2026.291, as "Stardate 2258.42" is the 42nd day of 2258). When the system asks for reduced motion, they all hold still: lamps stay lit, the logo shows its last frame, and the splash goes straight to the front page.

**Accessibility (#503).** `test/accessibility_test.dart` holds the app to these, at phone size:
- **Screen readers.** Everything you can press says what it is and can be pressed: sidebar blocks, BACK and HOME, LCARS buttons, the splash's REQUEST ACCESS. Where a label stands in for a widget's contents (`excludeSemantics`), the tap goes with it, or TalkBack couldn't press it. Labels are read as written, not in the capitals they're shown in, and a button's caption follows its label ("Starship Database, 370 entries"). The screen title and section headings are headings, so a screen reader can jump between them. Each stat tile reads as a pair ("Length: 652"), the audio button says whether it's on, and decoration (the number grids, the logo's frame) is silent.
- **Touch targets and contrast.** Flutter's guidelines for tap target size, labelled targets and text contrast pass on the front page and the ship page. The themes' colours are checked separately in `theme_test.dart`.
- **Large text.** At 150% and 200% text the front page, About, Factions, Media and a whole ship page lay out without overflow. Labels that must stay on one line (sidebar blocks, the screen title, ACCESS RESTRICTED) shrink to fit; a button's caption drops below its label when there's no room beside it; the splash scrolls.
- **Motion.** Reduced motion is respected, as above.

**Settings and versions.** In the front page's right-hand column are two switches: AUDIO (the beeps) and CLASSIC LCARS / ERA INTERFACES (#592). With classic LCARS on, every screen, eras and factions included, is drawn in classic TNG LCARS: the app swaps in the theme library that has no era or faction looks. Both are remembered in `settings.json` (`lib/data/settings.dart`). The bottom bar shows the app version and the ship data's mod revision and build date (#528). The app version lives in `lib/version.dart`, kept equal to pubspec.yaml by a test, because reading it at run time would need a plugin.

**Sounds.** Every LCARS button, sidebar block and elbow beeps, with the STC website's sound set (`assets/sounds/`, converted to small WAVs): a tap, a select for opening a section, processing for the Starship Database, a hail for Comms, and the login beep on the splash. `lib/ui/sound.dart` plays them without a plugin: Windows calls winmm's `PlaySound` on the WAVs Flutter bundles beside the executable, and Android plays them through a `SoundPool` in `MainActivity.kt`. The front page's AUDIO switch mutes them, remembered in `settings.json` (in `%APPDATA%\Continuum Companion` on Windows, the app's files folder on Android). Tests are silent.

**Keyboard and mouse (#546, #547).** Tab and the arrow keys move between controls, and Enter or Space presses one (Flutter's own); the focused button or block shows a light wash. Escape or Alt+Left goes back, as BACK does, and Alt+Home returns to the front page, as HOME does (`shortcuts` in `lib/app.dart`). On a turntable, dragging turns the ship; with the turntable focused (clicked or tabbed to, shown by a ring), Left and Right step it a frame and the mouse wheel turns it. Shift+wheel, or a sideways trackpad scroll, turns it without focus. The plain wheel otherwise scrolls the page, so scrolling doesn't catch on the turntable at the top of it.

**Ship page order.** Specifications are the real-world measures (length, width, crew, class). Game specs follow them: hull, speed, cost and build time, which only matter in play. The summary comes next, so the page says what the ship is for before its weapons, then Armaments with Defences under them, research, abilities and the rest of the description. Armaments list each kind the ship mounts with its count and figures (damage a hit, how often, damage per second, range), one per line so they read on a phone, then the ship's total damage per second; the description's own armament list only shows for a ship without weapons, since it says the same thing. Notable ships lists the names the game gives the class's ships as they're built, each with its registry where the hull carries one, in at least two columns; classes the game doesn't name skip the section. A Canon section says where the class comes from (seen on screen, licensed works, fan works or Star Trek Online, or the mod's own design), with a link to the wiki page. Links open in the system browser through `lib/ui/open_link.dart`, without a plugin: Flutter plugins on Windows need Developer Mode to build, so Android hands the link to an intent in `MainActivity.kt` and Windows passes it to the shell's URL opener. Credits close the page: the model's makers from the mod's readmes, or a note that there's no readme to credit from. An author with a site (`$authorLinks` in `data/credits.source.json`, such as Aad Moerman's downloads on msfc.com.au) is a link, to the model's own download page where the entry gives one (every Gorn ship goes to his Continuum Gorn fleet), and a web address in a note (a Sketchfab source) is a link too. COMPARE is a block in the ship page's sidebar, or in the faction's sidebar when the page sits beside the list.

**Variant toggle (#605).** The first choice is the ship itself; each variant follows. On a carrier, whose variants are the craft it carries, the section is titled "Carrier and complement" (#931). Only one is shown at a time, because the mod's subsystem options exclude each other.

- Specifications the selected variant changes are highlighted in orange.
- A refit or subsystem keeps the ship's name as the title and shows what it adds underneath ("Sensor Suite: Refit into the Soyuz sub-class").
- A variant that's a hull of its own (a separated saucer, an escort, a Construction Bee type) takes its own name. The data has only its stats, so the page says that the weapons, abilities and description are the parent ship's.

**Date-gated entries (#635).** An entry with `showOnlyOn` is listed only on that day. The USS Brisbane appears only on 28 July.

## Data

- The pipeline writes `app/assets/data/ships.json` ([Pipeline](/Pipeline.md), `build_data.py`). It's bundled as an asset (`pubspec.yaml`) and read once at start-up.
- `lib/data/models.dart` holds a Dart class for each part of the [Ship Data Schema](/Ship-Data-Schema.md). Each has a hand-written `fromJson`. Generated code (json_serializable) would add a build_runner step for little gain at this size, and hand-written parsing is easier to read while learning Dart.
- `lib/data/ship_repository.dart` is everything the screens ask for: the eras, the factions in an era, a faction's ships grouped by class, and a ship by id. It all stays in memory: the whole file is about 630 KB, so a database isn't needed. Its clock can be replaced, so tests can check the date gate.
- `lib/data/ship_view.dart` merges a selected variant over its parent ship for display.

## Look

**Theme (#566, #569).** `lib/theme/dex_theme.dart` holds the tokens as a Flutter `ThemeExtension` called `DexTheme`:
- **Colours:** background, three structure colours with their text colours, two data colours, accent, and status ok, warning and alert.
- **Shape family:** `lcars`, `film`, `radial`, `angular`, `rounded`, `elliptical`, `grid` or `console`.
- **Highlight:** the colour for titles, the selected item and values a variant changes.
- **Transition length.**

Screens and widgets read only `DexTheme.of(context)`.

`ThemeLibrary` reads `assets/data/themes.json` (see [Pipeline](/Pipeline.md), Themes) and resolves a theme for an era and a faction. The era sets the frame. A faction with an interface of its own (Klingon, Romulan, Cardassian, Dominion, Borg, Voth) replaces the whole frame; other factions only change the accent. `DexThemeScope(era:, faction:)` applies it to a screen and animates the change:
- The home screen is classic TNG LCARS, with each era button in its own era's colour.
- The faction list takes the era theme, with each faction button in its accent.
- The ship list and ship page take the era and faction together.

`toThemeData()` maps the tokens onto Material's colour scheme too, so stock widgets such as chips and list tiles match the frame.

**Frame (#511).** `lib/ui/lcars.dart` builds every screen inside `LcarsFrame`:
- **Top:** an elbow, with the title bar and an end cap. The top elbow is the back button.
- **Left:** a sidebar of coloured blocks, either with small labels (`sidebarLabels`) or as navigation (`sidebarNav`, a list of `LcarsNavItem`). The navigation blocks scroll when there are more than fit, and `replaceWithSibling` swaps screens without an animation.
- **Bottom:** a closing elbow and bar, with a footer. The bottom elbow is the home button.

Proportions follow the fan-standard ratios on the [Design Language](/Design-Language.md) page, scaled from the sidebar width: 52 on a phone, 80 on a wider window. The same widgets draw each shape family:

| Shape | Corners | Bar ends, buttons, chips | Extras |
|---|---|---|---|
| `lcars` (TNG; Dominion for now) | Rounded outer and inner elbow | Pill caps | |
| `film` (TMP) | A chamfered corner drawn as a thin outline over a faint fill | Slanted outlined panels with a small oval lamp; oval caps, chips, tags and section markers | Outlined bars and sidebar blocks with lettering in the frame colour; rings round the ship's icon |
| `radial` (Borg) | A ringed hub instead of an elbow; the hub is the back button | Pills; capsule sidebar blocks | Rings and tick marks round the ship's icon |
| `angular` (Klingon) | 45° chamfers | Wedges | |
| `rounded` (Romulan, Voth) | Small rounded elbow | Rounded rectangles | Rounded sidebar blocks |
| `elliptical` (Cardassian) | Quarter-ellipses with an oval inset | Trapezoids (`lib/ui/shapes.dart`) | Oval-ended sidebar blocks; nested ellipses round the ship's icon |
| `grid` (unused for now) | Square, cut into cells | Square | Cells on every frame block; faint grid behind the content; the back label gets a solid backing |
| `console` (ENT, TOS) | Square | Square, slightly softened | |

Section titles and tags take the accent, so the faction always shows. Long titles shrink to fit the bar. Frame lettering, buttons, section titles and ship names use the theme's heading font where it has one; body text always stays in the platform font (see Fonts).

**Turntables (#491, #616).** The top of the ship page shows the model turning, from a pre-rendered sprite sheet (see Pipeline). `lib/ui/turntable_view.dart` cuts each frame out of the sheet as it paints, so a whole turn is one decoded image.
- It turns slowly on its own, about once every 14 seconds, and stops when the platform asks for reduced motion.
- Dragging sideways turns it by hand, one full turn per width of the view, by touch or mouse. Auto-rotation pauses while dragging and resumes three seconds after.
- With keyboard focus (tap or click it), the arrow keys step a frame at a time.
- A variant with a model of its own (a separated saucer, an escort) shows its own turntable; a refit or subsystem keeps the ship's.
- Until the sheet loads, or if it can't, the game icon shows instead.

**Icons (#439, #486).** `lib/ui/ship_icon.dart` shows the game's icon in the list, and at the top of the ship page for a ship with no turntable. The icon switches to a variant's own when it has one. Icons are decoded at the size they're drawn (`cacheWidth`), so long lists stay light. Ships without an icon get an outlined placeholder with their initial. Faction emblems come from the mod's badges (`STC - <year>/badges/*.tga`, #442). `data/logos.source.json` picks one per faction per era, and the pipeline exports them to `assets/logos/<era>/<faction>.webp`, 192 px and lossless.

- **Where they appear:** on each faction's button, and on the faction blocks in the ship list's sidebar.
- **Not from the mod:** the Tholian, Breen and Undine emblems come from images saved in `data/reference/badges/` (git-ignored; only the exported logos are committed). They're named in `logos.source.json` as `reference/badges/<file>`. Emblems are fitted into the square without stretching, and a JPEG's white background is made transparent.
- **Unaligned:** a plain white disc (`"white circle"`), because anything closer to a real emblem reads as a faction.
- **No emblem chosen:** a lettered circle.

## Fonts

Bundled in `app/assets/fonts/` after checking every font in the mod's `Source Files\Fonts` and `STC Website\font` (#515, #853–#857). Each era and faction has a heading face for frame lettering, buttons and titles; body text always stays in the platform font.

| Font (family) | Used for | Source and terms |
|---|---|---|
| **League Gothic** (`LeagueGothic`) | TNG and classic LCARS | The League of Moveable Type; SIL Open Font License. Chosen over the commercial Swiss 911 Ultra Compressed (#853) |
| **Pathway Gothic One** (`PathwayGothic`) | ENT | Eduardo Tunni; SIL Open Font License. Stands in for Nova Light Ultra SSi, a commercial clone (#854) |
| **Trek Classic** (`TrekClassic`, the mod's `TOS_Title.ttf`) | TOS | No author recorded (#855) |
| **Trek Movie** (`TrekMovie`, the mod's `Final_Frontier.ttf`), by Allen R. Walden | TMP | "UNPROTECTED - Please distribute freely" |
| **Klingon Dagger** (`KlingonDagger`) | Klingon frame | No author recorded (#857) |
| **Romulan Eagle** (`RomulanEagle`) | Romulan frame | No author recorded (#857) |

The OFL text is `assets/fonts/OFL.txt`; `main.dart` registers it, so it's listed with the app's licences, and `installer/notice.txt` carries it on Windows.

**Faction scripts** (`<Race>Glyphs`: Klingon pIqaD from `Klingon TNG.ttf`, Romulan, Cardassian, Dominion, Borg, Voth, Gorn, Ferengi, Tholian) only decorate, by the Design Language's two-tier rule: on a faction's screens the title bar repeats the title in the faction's script beside the readable one, and the Factions fleet evaluation repeats the faction's name under it. Both are hidden from screen readers. The theme's `scriptFont` names it (`data/themes.source.json`, checked by the pipeline). Cardassian, Dominion, Borg, Voth and Ferengi are charityware by "Tommy of Escondido", cleared by a donation to charity; the rest have no author recorded.

**The licence ruling (18 October 2026).** Fan fonts whose author can't realistically be contacted (no name, or only a long-dead address such as Airborne's) are used as they are, credited where there's a name. Commercial faces, and the 1992 Southern Software clones of them (Context, Nova, Beijing) and `Swiss911.ttf` (Adobe's Helvetica), are never bundled. None of these files may go in the public GitHub mirror, which builds without them; the OFL fonts may.

Okuda (Pixel Sagas), the TNG font before League Gothic, is no longer bundled. Airborne (Charles Casimiro Design, the TOS hull lettering) and Federation and Federation Wide (#856) are cleared for use but not bundled, since nothing draws hull lettering or uses those titles yet. Klingon Blade.ttf is a damaged file and can't be used.

## Tests

```bash
cd app
flutter test
```

- `test/data_test.dart` covers parsing (against the hand-checked samples and the full data file), grouping, the Brisbane date gate, factions per era and variant stats.
- `test/theme_test.dart` covers theme resolution (TNG Federation is classic; era frame and faction accent and shape) and WCAG AA contrast for every text colour.
- `test/navigation_test.dart` covers era → faction → ship page and the variant toggle in a phone-sized window, and the side-by-side layout in a wide one.

Those run in Flutter's test environment. To run the **real app** on a device or desktop, loading the bundled data, themes, fonts and icons exactly as a release does:

```bash
flutter test integration_test/app_test.dart -d windows
```

It walks era → faction → ship page → variant toggle at phone (412 × 900), tablet (800 × 1100) and desktop (1440 × 900) sizes, and saves a screenshot of each step to `build/integration_shots/`. Swap `-d windows` for the phone's device id to run it on Android.

## Android

- The real-app test passes on Nathan's Galaxy S26 Ultra over wireless debugging (`flutter test integration_test/app_test.dart -d <device id>`; `adb devices -l` lists the id). The test runner removes the app afterwards, so for a hands-on look install a release build instead.
- `flutter build apk --release --split-per-abi` makes one APK per processor type. The 64-bit ARM one, for modern phones, is 53.1 MB; a universal APK is 82 MB. Release builds are signed with the release key on the PC that holds it, and with the debug key elsewhere (#524; see [Release](/Release.md)).
- Checked on the phone: specification tiles size to the screen, at least two to a row. Faction buttons show each faction's main frame colour where it has its own interface, and its accent where it shares the era's frame.

## Windows

- The window opens at 1280 × 800, titled "Continuum Companion". It can't be dragged smaller than 400 × 640 logical pixels (`windows/runner`, #548).
- It reopens where it was closed: size, position and whether it was maximised are saved on close in `HKEY_CURRENT_USER\Software\Molla Workshop\Continuum Companion` (`windows/runner/window_placement.cpp`, #550). A saved place that's no longer on any monitor is ignored, and it never reopens minimised.
- The file details name the product Continuum Companion, from Molla Workshop, and the exe is `continuum_companion.exe`.
- A release build (`flutter build windows --release`) is 64 MB unpacked: the exe, the 21 MB Flutter engine DLL and the 44 MB `data` folder. `tools/package_windows.ps1` packs it into a 44.0 MB installer and a 48.0 MB zip.

## Size and performance budget (#504)

Most of the download is the turntables: 391 sprite sheets, 32 MB. Each has 18 frames (every other one of the 36 rendered), at most 256 pixels wide, in lossy WebP at quality 80 with the alpha at quality 70. The alpha was nearly half of each sheet while lossless, and lossy alpha doesn't show at the edges even at twice the size.

| | Budget | 18 October 2026 |
|---|---|---|
| Android APK, 64-bit ARM | 55 MB | 53.1 MB |
| Windows installer | 50 MB | 44.0 MB |
| `assets/turntables` | 35 MB | 32 MB |
| `assets/icons` | 5 MB | 4 MB |
| `assets/data/ships.json` | 1.2 MB | 0.96 MB |

`pipeline/tests/test_budget.py` fails when an asset folder goes over its budget, so a change that grows the sheets or the data shows up in the pipeline tests rather than in the download.

To keep scrolling smooth, long lists are built as they scroll into view (the ship lists and search results), list icons are decoded at the size they're drawn, and a ship's whole turn is one decoded sheet. To check scrolling on a phone, run `flutter run --profile -d <device id>`, press `P` for the performance overlay, and scroll the longest list (TNG Federation) and the search results: both bars should stay under the line (16 ms a frame at 60 Hz).

## Still to come

Shapes for the remaining factions once their interfaces are researched (#577, #585), and a manual check of window resizing on Windows (#544).
