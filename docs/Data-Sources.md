# Data Sources

All paths are under `D:\Modding Tools\HW2TREKMOD\HWRM\STC - <era>` unless noted. The pipeline reads these; it never writes to them.

| App field | Source | Notes |
|---|---|---|
| Name | `.ship` `displayedName`, or `DisplayedName` in the build list | |
| Subtitle | `.ship` `sobDescription` | Style C: canon role plus a tactical modifier |
| Health, speed | `.ship` `maxhealth`, `maxspeed` | |
| Cost, build time | `.ship` `buildCost`, `buildTime` | |
| Class and families | `.ship` `DisplayFamily`, `BuildFamily`, `UnitCapsFamily` | |
| Abilities | `.ship` `addAbility(...)` lines | Translate engine names into readable ones |
| Weapons | `.ship` `StartShipWeaponConfig(...)`; `.def` weapon counts | Per-weapon stats from `weapon/*/*.wepn` later |
| Size | `.def` `longestAxis`, `midAxis`, `hullSizeCategory` | |
| Roles | `.def` `aiRoles` | |
| Description (crew, armament, defences, prerequisites, summary) | `scripts/races/<race>/scripts/build/<era>_build.lua`, `Description` | Sections separated by `<b>` headings and `\n` |
| Research needed | Build list `RequiredResearch`, names from `scripts/races/<race>/scripts/research/*.lua` | |
| Icon | `ship/icons/races/*_icons.lua` and `shipicons.lua` (tables and aliases) plus the atlas DDS and TGA files | Cropped to 256 x 128 WebP by the pipeline |
| Canon tier and source | Continuum wiki, *Writing and Canon / Canon Verification Results* | 243 hulls, tiers A, B, G or none |
| Author credit | `D:\Modding Tools\HW2TREKMOD\Source Files\Ship mesh and texture files\Ship Files\<ship>\<name> Readme.txt` | Not every ship has one |
| Turntable | Source DAE in the same Ship Files folders (about 470), or the compiled `.hod` | Folder naming is inconsistent; match fuzzily |
| LCARS fonts, sounds, logos | `D:\Modding Tools\HW2TREKMOD\Source Files\STC Website\` (`font/`, `sounds/`, `images/`) | Check licences before bundling |
| Era and faction colours and shapes | `data/themes.source.json` in this repository, researched from on-screen images | Not from the mod: its HUD tints don't describe the eras' and factions' displays. See [Interface References](/Interface-References.md) |

## Example: Galaxy (TNG Federation)

- `.ship`: `displayedName = "Galaxy"`, `sobDescription = "Heavy Explorer"`, `maxhealth = 111700`, `buildCost = 9200`, `buildTime = 239`
- `.def`: `longestAxis = 652`, `aiRoles = { "AntiFrigate", "AntiCapital" }`, 8 weapons (6 beam, 2 torpedo)
- Build list: crew 1,200; phaser arrays and photon torpedoes; energy shields; requires Capital Sized Chassis; a summary paragraph and the saucer-separation note

## Branding and artwork

`D:\Modding Tools\HW2TREKMOD\HW2\Tools\Logos` holds the mod's branding kit (in SVN; copy what the app needs into `app/assets/`):

| File | Size | Use in the Dex |
|---|---|---|
| `STC_Icon_256.png`, `STC_Icon_48.png`, `STC_Icon_32.png` | 256, 48, 32 px | **App icon** source: the gold Starfleet delta with "Star Trek Continuum" lettering |
| `STC_Logo.png` | 64 px | Small logo |
| `STC_Header_nolens.png`, `STC_Header.png` | 1280 × 480 | **Splash screen and About page**: gold "Star Trek" over silver "CONTINUUM" on black (`_nolens` has no lens flare) |
| `STC_Cinematic.webm` (also `.mov`, `.avi`), `STC_Cinematic*.png` | 1280 × 480 | The mod's intro logo animation; a possible animated splash |
| `STC_Preview_1024x768.png`, `Moddb/preview image.jpg` | 1024 × 768 | Store-style preview art for download pages |
| `Newbanner*.jpg`, `Moddb/Profile Header*.jpg`, `moddb_headerimage_TNGcontentupdate.png` | Banners | Download pages (ModDB, itch.io) |
| `Moddb Page editing/lcars_colors.gif` | Chart | The classic web-safe LCARS colour chart; see Design Language |
| `Moddb Page editing/STC_style.css`, `konsole3.jpg`, `headerSTC.png` | Web | The ModDB page's LCARS styling, for reference |
| `STC_Userbar.png`, `Installer.bmp` | Misc | Forum userbar; the NSIS installer's side image (useful for the Dex installer) |

There are no faction logos in this kit; those still come from the website images or need making (#442).
