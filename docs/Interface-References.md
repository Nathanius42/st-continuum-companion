# Interface References

Where to find on-screen images of each era's and faction's computer interfaces, for building their themes (#589 reference boards, #585 interface rules). It goes with the [Design Language](/Design-Language.md) page, and the palettes themselves live in `data/themes.source.json`.

Reference images stay on your machine, not in Git: the screen graphics belong to the studio. Collect screenshots from the galleries below into a local folder and derive the colours and shapes from them.

## The main resource: lcars.org.uk

[lcars.org.uk](http://www.lcars.org.uk/Adges%20Welcome.htm) (itself built in LCARS) is the main resource. It holds thousands of recreated screen animations, made since 1999 from screen captures, with stills for each. There are sections for TOS, TNG, DS9, Voyager, Enterprise, the TNG films, *Star Trek* (2009) and alien screens. `pipeline/mirror_reference.py` mirrors it into `data/reference/lcars.org.uk/` on this machine, git-ignored. It goes one request at a time, and it follows the site's `lcarstemplate.htm?Page=` links.

What it covers for the Dex's themes, counted from its pages:

| Theme | On lcars.org.uk |
|---|---|
| TNG Federation | A whole section (TNG, DS9, Voyager and the TNG films) |
| ENT (and the Terran NX-01 screen) | A whole section: over 300 stills of NX-01 displays |
| TOS | A section page; the replica panels you saved add more |
| Film era (TMP to VI) | Very little: mentioned, but the films section is the TNG films. Two *Star Trek IV* Enterprise-A console renders in `data/reference/tmp` carry the theme for now. **Still thin** |
| Klingon | Plenty: about 80 alien-screen entries |
| Cardassian | Plenty: about 60 |
| Romulan | Good: about 30, including the *Nemesis* Valdore |
| Borg | Some: about 13 |
| Ferengi, Dominion | Thin: about 7 and 6 |
| Undine (Species 8472) | Barely: 2 |
| Gorn, Breen, Tholian, Voth | None. **Gaps** |

The per-theme folders under `data/reference/` stay for anything from elsewhere: game captures (*Starfleet Command II* for the Gorn) and fan art.

## How much there is to go on

| Era or faction | On-screen interfaces | Difficulty | Current palette |
|---|---|---|---|
| **TNG Federation** (LCARS) | Hundreds of episodes; fully documented by fans | Easy | Canon |
| **TOS** | Every bridge episode; replica panels documented | Easy | Fan |
| **Film era (TMP)** | Five films; Okuda's radial displays from *Star Trek IV* on | Moderate | Fan |
| **ENT** | Every NX-01 bridge episode, but the displays are video, so stills vary | Moderate | Fan |
| **Klingon** | Bird-of-Prey and K't'inga bridges in films III–VI; DS9 Klingon ships | Moderate | Fan |
| **Romulan** | TNG warbird bridges; *Nemesis*; *Picard* | Moderate | Fan |
| **Cardassian** | DS9 Ops in almost every episode; Galor bridges | Easy | Fan |
| **Dominion** | Little: Jem'Hadar ships use headset displays rather than screens; DS9 Ops under Dominion control | Hard | Fan |
| **Borg** | Very little: no bridge, decentralised controls, a few floating screens; *Armada II* has a Borg interface | Hard | Proposed |
| **Voth** | One episode (VOY "Distant Origin") | Hard | Fan, via *Star Trek Online* |
| **Gorn** | No ship interface shown in any series; *Starfleet Command II*'s Gorn interface is decoded and used | Done (via the game) | Fan |
| **Ferengi** | Brief Marauder and shuttle interiors | Hard | Proposed |
| **Breen, Tholian, Undine** | Next to none | Very hard | Proposed |
| **Terran Empire** | ENT "In a Mirror, Darkly" (ISS *Enterprise* and *Defiant*); TOS "Mirror, Mirror" | Moderate | Decided: TOS Federation with a gold accent |

Where nothing was shown on screen, the theme is our design choice and is marked **proposed**. Games and fan art fill those gaps (below): licensed games designed interfaces for races the shows never gave one, and fan designers have worked out the rest.

## Games and fan art

These aren't canon, but they were designed for each race and are better than guessing:

| Source | Races with their own interface | Notes |
|---|---|---|
| ***Starfleet Command II: Empires at War*** (Taldren, 2000) | Federation, Klingon, Romulan, **Gorn**, Lyran, Hydran, ISC, Mirak, Orion | Each race has its own interface look with the controls in the same places. Modding notes say Gorn has its own colour scheme. The [manual](https://gaming.trekcore.com/starfleetcommand2/downloads/sfc2.pdf) covers controls, not styling, so it needs screenshots from the game. Best source for the **Gorn**. |
| ***Star Trek: Armada II*** (2001) | Federation, Klingon, Romulan, **Borg**, **Cardassian**, **Species 8472** | Every race has its own interface files (`<race>.cfg` and `.spr`; [Armada modding wiki](https://armadamodding.fandom.com/wiki/ODF_-_Race_Files)). Fans recall a jade green for the Borg. Best source for **Borg** and **Undine**. |
| ***Star Trek: Deep Space Nine – Dominion Wars*** (2001) | Federation, Klingon, **Dominion** | A possible **Dominion** source. |
| ***Star Trek Online*** (installed here) | All factions | LCARS-based, with a design per faction and colour schemes to choose from ([STO wiki: User interface](https://sto.fandom.com/wiki/User_interface)). Jem'Hadar captains keep their own interface. Klingon: orange controls, maroon frames. Its designers also describe Voth tech (glowing blue and green, curved). |
| ***Star Trek: Bridge Commander***, ***Klingon Academy*** | Federation; Klingon | Full bridge interfaces; *Klingon Academy* is a whole Klingon one. |
| **[LCARS 47](https://www.lcars47.com)** (Sollertia Station) | Federation (TNG era) | Free, closed-source LCARS software that aims to be canon-accurate: a good check for our TNG theme's proportions and behaviour. **Look, don't copy:** Sollertia Station claims its interface colours as trademarks, so our palette stays sourced from TheLCARS.com and screencaps. |
| **[System 47](https://www.mewho.com/system47/)** (meWho) | Federation (TNG era; *Lower Decks* in the browser at [mewho.com/ritos](https://www.mewho.com/ritos)) | Free LCARS screensaver with ship schematics. Useful for motion: how panels animate and data cascades tick. |
| **Fan art** | Mostly Klingon and Romulan | [LCARSGFX](https://www.deviantart.com/lcarsgfx) (Klingon D7 [interface](https://www.deviantart.com/lcarsgfx/art/Klingon-D7-Class-Interface-1209809289) and [engineering](https://www.deviantart.com/lcarsgfx/art/Klingon-D7-Engineering-Display-1209807833) displays), [PlagueJester: Klingon Interface](https://www.deviantart.com/plaguejester/art/Klingon-Interface-150413892) (triangular grid), [Chinook-the-Orca: Klingon LCARS](https://www.deviantart.com/chinook-the-orca/art/Klingon-LCARS-wip-777834143), [FanTrek LCARS gallery](https://www.deviantart.com/fantrek/gallery/39201892/lcars), and the Scifi-Meshes redraws above. Little or nothing found for Gorn or Ferengi. |

## Starfleet Command II, decoded

Nathan's SFC2 disc (Interplay, 2000) is read without installing anything. Its InstallShield 5 cabinet won't install on Windows 11, so we open it directly:
- `pipeline/tools/sfc2/iscab.py` lists the files in `data1.hdr`/`data1.cab` and extracts them.
- `pipeline/tools/sfc2/q3sprites.py` decodes the interface art in `Assets\Sprites\sprites.q3`. That's Taldren's "MDM!" archive: 18,935 sprites, each with width, height, hotspot and 16-bit 555 colour, run-length encoded per row (`0xC000|n` skip, `0x4000|n` repeat, `n` literal). We worked the format out from the file; there's no published documentation.

The decoded sprites stay local, in `data/reference/sfc2/`, `data/reference/gorn/sfc2_*` and `data/reference/tmp/sfc2_fed/`. Each race has a full interface set:
- **Federation:** blue outlined panels with green oval lamps, and ship schematics ringed with shield dots.
- **Klingon:** red.
- **Romulan:** green.
- **Gorn:** glowing green on khaki-bronze stone panels.
- **Others:** further races in violet and indigo.

Continuum feature #889 plans TMP ship icons after those schematics.

## Building a palette from images

1. Put screenshots, game captures and fan art for one theme in `data/reference/<theme>/`, for example `data/reference/gorn/`. A folder for each theme is already there (ent, tos, tmp, tng, klingon, romulan, cardassian, dominion, borg, voth, gorn, ferengi, breen, tholian, undine, terran). Name each file after its source, or add a `sources.txt`. The folder is git-ignored: the images belong to their owners and stay on this machine.
2. Run the sampler, which lists the dominant colours, how much of the images each covers, and whether each reads as text on black:

```bash
pipeline/.venv/Scripts/python.exe pipeline/sample_palette.py gorn
```

3. Pick the structure, data and accent colours from the list. Write them into `data/themes.source.json` with the images as the theme's sources, and change its confidence from proposed to fan (or canon for screencaps).
4. Rebuild with `pipeline/build_data.py`, which checks contrast, then look at the screens.

## Galleries and catalogues

These cover many factions:

- **TrekCore** screencap galleries, by series and episode: [TOS](https://tos.trekcore.com/gallery/thumbnails.php?album=137) (the bridge set tour shown), and the TNG, DS9, VOY, ENT and films galleries on the same site. Best for checking a graphic against the episode it appears in.
- **Ex Astris Scientia**:
  - [Bridge photos](https://www.ex-astris-scientia.org/gallery/bridges2.htm): Federation, Klingon and Romulan bridges, including the *Nemesis* Valdore and Scimitar.
  - [Alien bridge illustrations](https://www.ex-astris-scientia.org/gallery/bridges1a.htm).
  - [Re-used props: stationary consoles](https://www.ex-astris-scientia.org/inconsistencies/reused_props_consoles.htm): which Klingon and other consoles appear where.
  - The emblem histories ([Klingon](https://www.ex-astris-scientia.org/inconsistencies/klingon_emblem.htm), [Romulan](https://www.ex-astris-scientia.org/inconsistencies/romulan_emblem.htm), [Cardassian](https://www.ex-astris-scientia.org/inconsistencies/cardassian_emblem.htm), [Dominion](https://www.ex-astris-scientia.org/inconsistencies/dominion_emblem.htm)): useful for faction colours.
- **lcars.org.uk, [Alien Screen Animation](http://www.lcars.org.uk/lcars_Alien_panels.htm)**: a numbered catalogue of Klingon, Romulan and Cardassian screens by episode, for example Klingon displays from DS9 "The House of Quark", "Blood Oath", "Return to Grace" and "Soldiers of the Empire". The site's certificate is out of date, so it may only open over plain HTTP.
- **Memory Alpha**: [Okudagram](https://memory-alpha.fandom.com/wiki/Okudagram), [Viewscreen](https://memory-alpha.fandom.com/wiki/Viewscreen) (Klingon angular screens, Cardassian oval holo-frames, Jem'Hadar headsets) and [Bridge](https://memory-alpha.fandom.com/wiki/Bridge).
- **Scifi-Meshes forums**: fan redraws of [Romulan](https://forums.scifi-meshes.com/discussion/66573/romulan-graphics) and [Cardassian](https://forums.scifi-meshes.com/discussion/77018/cardassian-interfaces) graphics, and [film-era displays](https://forums.scifi-meshes.com/discussion/82688/filling-in-some-of-the-23rd-24th-century-aka-my-unskilled-ps-trek-doodles). They're good for shapes, but check colours against screencaps.
- **Peter Thomas, [50 Years of Star Trek Interfaces](https://peterthomasvfx.wordpress.com/2016/08/29/50-years-of-star-trek-interfaces/)**: hex palettes for TOS, the films, TNG and ENT, measured from screenshots.

## By era and faction

### TOS (2250)
- TrekCore's TOS bridge set tour; the [Prop Authority post on the exhibition bridge panels](http://www.startrekpropauthority.com/2009/02/star-trek-exhibition-in-detroit-bridge.html) (library computer, communications, engineering and environmental stations).
- TrekBBS threads on [replicating the bridge displays](https://www.trekbbs.com/threads/replicating-star-trek-tos-bridge-displays.308412/) and [a bridge graphics myth](https://www.trekbbs.com/threads/a-bridge-station-graphics-myth.317374/).
- Look: square windows of blinking red, green and yellow lights on dark grey panels.

### Film era (TMP, 2310)
- Okuda proposed circular, radial displays after *Star Trek II*'s round screens showed rectangular graphics ([Space.com interview](https://www.space.com/entertainment/whats-it-like-bringing-star-trek-to-life-sci-fi-franchise-icon-michael-okuda-shares-tales-from-the-final-frontier-interview)). His work starts with the *Star Trek IV* Enterprise-A bridge ([Wrath of Dhan: Okudagrams part 4](http://wrathofdhanprops.blogspot.com/2018/06/okudagrams-part-4-seven-seconds-that.html)).
- *The Motion Picture*'s pictograms: [Ex Astris Scientia, peel-off graphics book](https://www.ex-astris-scientia.org/inconsistencies/movie-pictograms.htm).
- [TrekBBS: TOS movie bridge displays](https://www.trekbbs.com/threads/trek-tos-movie-bridge-displays.171460/).
- Episodes to screencap: *Star Trek II* (refit bridge tactical displays), *IV*, *V* and *VI* (Enterprise-A).
- Look: blues, cyan and green; rings, radial gauges, circular readouts.

### ENT (2160)
- Ex Astris Scientia's [NX-class gallery](https://www.ex-astris-scientia.org/scans/nx1.htm) and [Starfleet bridge illustrations](https://www.ex-astris-scientia.org/gallery/bridges1.htm); the [Prop Authority post on the tactical console](http://www.startrekpropauthority.com/2010/10/star-trek-enterprise-nx-01-bridge.html).
- Memory Alpha's [NX class](https://memory-alpha.fandom.com/wiki/NX_class) page: the displays were played from about twenty Apple G4 Cubes.
- Look: greys with blue and yellow; boxy, fewer curves, small protruding tabs.

### Klingon
- Bird-of-Prey bridge (*Star Trek III*–*VI*, *Generations*): Okuda built its displays on *The Motion Picture*'s Klingon lettering. The viewscreen is octagonal ([Memory Alpha: Klingon Bird-of-Prey](https://memory-alpha.fandom.com/wiki/Klingon_Bird-of-Prey_(2280s))).
- DS9: "Soldiers of the Empire" (*Rotarran* bridge), "Once More Unto the Breach", "The House of Quark", "Blood Oath". TNG: "Redemption", "A Matter of Honor".
- *Star Trek Online*: orange for controls, maroon frames.
- Look: angular, chamfered; reds, oranges and maroon.

### Romulan
- TNG "Face of the Enemy" and "Contagion" (warbird bridges); *Nemesis* (Valdore and Scimitar); *Picard* season 1. Ex Astris Scientia's bridge gallery covers all of these.
- Look: greens and turquoise, rounded-square screens, green bars along the top.

### Cardassian
- DS9 Ops (almost every episode), "Duet", "Defiant" and "Tribunal" (Galor bridges).
- Herman Zimmerman: "Cardassians like things in sets of three. They like ellipses, triangles and trapezoids rather than squares and rectangles" ([LCARS Fandom: Cardassian Interface](https://lcars.fandom.com/wiki/Cardassian_Interface)). Several small displays per operator; dark, near-monochrome; oval holo viewscreens.
- Look: elliptical elements in square frames; muted browns and golds with blue to purple buttons.

### Dominion
- Jem'Hadar ships have no viewscreen; the Vorta and the First wear headset displays ([Memory Alpha: Jem'Hadar fighter](https://memory-alpha.fandom.com/wiki/Jem'Hadar_fighter), [battle cruiser](https://memory-alpha.fandom.com/wiki/Jem'Hadar_battle_cruiser)). DS9 "The Ship" shows a fighter's interior; "Favor the Bold" and "Sacrifice of Angels" show Ops under Dominion control.
- Look: violet with cyan or green, from the emblem.

### Borg
- No bridge; decentralised controls, and four floating square screens in a cube pattern ([Memory Alpha: Bridge](https://memory-alpha.fandom.com/wiki/Bridge)). TNG "Q Who" and "The Best of Both Worlds", *First Contact*, VOY "Scorpion" and "Unimatrix Zero".
- Look: green light on black, a rigid grid, no curves.

### Voth
- VOY "Distant Origin" is the only appearance. *Star Trek Online*'s designers describe Voth tech as glowing mainly blue and green, with streamlined, curved forms and few sharp corners ([StarTrek.com: Designing the Voth](https://www.startrek.com/news/guest-blog-designing-the-voth)).

### Gorn, Ferengi, Breen, Tholian, Undine
- **Gorn:** no interface shown. ENT "In a Mirror, Darkly" shows a Gorn aboard the *Defiant*, but not Gorn tech.
- **Ferengi:** TNG "The Last Outpost", "Peak Performance" and "The Battle" (Marauder); DS9 "Little Green Men" (shuttle).
- **Breen:** DS9 "The Changing Face of Evil" and "The Dogs of War".
- **Tholian:** ENT "Future Tense" and "In a Mirror, Darkly" (ships only).
- **Undine (Species 8472):** VOY "Scorpion" and "In the Flesh" (bio-ships, little interface).
- For these, follow the games: *Starfleet Command II* for the Gorn and Tholians, *Armada II* for Species 8472 (Undine), and *Star Trek Online* for the Ferengi and Breen. They stay proposed until their palettes are sampled from those.
