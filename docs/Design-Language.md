# Design Language

The Dex should look like a Starfleet library computer, and change its look to match the era or faction you're browsing. This page sets out what is actually known about LCARS and the other on-screen interfaces, and turns it into a theme framework the app can implement.

## How sure we are

Every rule below carries one of these marks:

| Mark | Meaning |
|---|---|
| **[Canon]** | Seen on screen and recorded by Memory Alpha or similar references |
| **[Fan standard]** | Agreed across the open LCARS implementations; not official, but consistent |
| **[Mod]** | Taken from STCR itself, so the app matches the game |
| **[Proposed]** | Our design choice where nothing is documented |

There is **no official LCARS style guide**. Michael Okuda and his team designed the displays (hence "okudagrams"), but the published detail comes from fans who measured and rebuilt them. The open implementations agree closely, so their numbers are a sound basis.

## LCARS anatomy

### Elements [Fan standard]

| Element | What it is |
|---|---|
| **Bar** | Horizontal band, ending in a semicircular "pill cap" |
| **Sidebar** | Vertical band split into coloured blocks by thin black gaps |
| **Elbow** | L-shaped joint between a bar and the sidebar, with a curved inner corner; four orientations |
| **Sweep** | Two elbows facing opposite ways, forming an S |
| **Pill button** | Rounded-end button; label in capitals |
| **Data cascade** | Columns of small numbers that update constantly |
| **Background** | Always black |

### Proportions [Fan standard]

Measured from a reference layout and expressed against the sidebar width **S**, so they scale to any screen:

| Measure | Ratio | At S = 34 px |
|---|---|---|
| Top bar height | 0.53 S | 18 |
| Bottom bar height | 0.47 S | 16 |
| Elbow inner radius | 0.47 S | 16 |
| Gap between elbow and bar | 0.09 S | 3 |
| Gap between sidebar blocks | 0.06 S | 2 |
| Sidebar blocks | Up to 4; the last takes the remaining height | |
| Pill cap radius | Half the element's height | |
| Content inset | Sidebar + inner radius + gap | 53 |

### Colour roles [Fan standard]

- **Structure** (elbows, bars, sidebar): two or three warm colours (golds, ambers, oranges, peaches).
- **Data**: one or two cool colours (blues).
- **Accent**: one purple.
- **Status**: blue or green for OK, gold for warning, red for alert.
- **Text on bars**: black on warm colours, white on dark or red.

### Typography [Fan standard]

- A **condensed sans-serif in capitals** for labels; values may keep their own case.
- **League Gothic** (SIL Open Font License) stands in for the screen's Swiss 911 Ultra Compressed: the closest free match in weight and width, chosen by the owner over buying the original (#853). Antonio, the usual fan stand-in, is lighter and wider. ENT uses Pathway Gothic One in place of Nova Light Ultra (#854). The App page, Fonts, lists every font and its terms.
- Sizes in a fixed scale. One reference uses 12/14/16/18/20/28/36 px for label, compact, body, value, subtitle, large value and hero number.

### Motion and sound [Fan standard]

- Animations stay **under a second**; about 300 ms is typical for screen transitions.
- Frames assemble in order: elbows, then bars, then sidebar blocks top to bottom.
- Data cascades tick roughly every 50 ms; indicators blink at about 500 ms.
- Interface beeps are short (50–150 ms) tones of roughly 800–2,400 Hz. The STC website's own sounds are the better source for the Dex, and the sounds should be off by default.

### Palettes by production [Fan standard]

TheLCARS.com publishes named palettes for each look. A few anchor colours:

| Look | Anchors |
|---|---|
| **Classic (TNG/DS9)** | butterscotch `#EA9C72`, orange `#EB943A`, bluey `#8899FF`, african-violet `#BAA4E5`, mars `#FF2200` |
| **Voyager** | command-gold `#FFBB33`, autumn-leaves `#FB9004`, frost `#99CCFF`, science-blue `#2288FF`, red-alert `#FF3300` |
| **Nemesis** | evening `#2266FF`, midnight `#0048F0`, ghost `#88BBFF`, honey `#FFCC99`, cardinal `#DA2537` |
| **Lower Decks** | daybreak `#FF9911`, harvestgold `#FFAA44`, orange `#FF7700`, butter `#FFEECC` |
| **Picard** | blue `#37A6D1`, bright-blue `#41C4F7`, orange-red `#E7442A`, starlight `#F3F4F7` |

The mod's own branding kit also carries the long-standing **classic web-safe LCARS chart** (credited to Mike Hodgson and Matt Ridley, `HW2\Tools\Logos\Moddb Page editing\lcars_colors.gif`), used by many fan LCARS sites:

| | | | |
|---|---|---|---|
| `#FF9900` | `#CC99CC` | `#9999CC` | `#CC6666` |
| `#FFCC99` | `#9999FF` | `#FF9966` | `#CC6699` |

The mod's TNG HUD already uses the canonical Federation accents (yellow, mauve, pink, purple) and deliberately leaves them untinted. See the Continuum wiki's Per-Race UI page.

## Before LCARS: the other eras

| Era | What it looked like | Mark |
|---|---|---|
| **ENT (2160)** | Not LCARS. The NX-01 used its own touch-screen language: low-saturation frames, more saturated buttons with a flat "raised" shading, mixed with physical controls. Fans call it pre-LCARS; one source names it SC/OMS. | [Canon] / forum claim for the name |
| **TOS (2250)** | Physical consoles by Matt Jefferies: chunky rectangular buttons and lights in strong primary colours on dark panels. | [Canon] for the designer; detail [Proposed] |
| **TMP and the films (2270s–2290s)** | Lee Cole designed *The Motion Picture* bridge: deliberately plain, smooth consoles, back-projected screens, and the idea of smooth touch panels that TNG later realised. From *Star Trek IV*, Okuda's displays are black panels with slanted edges and thin outlines, holding rows of small oval buttons in light blue, with green radial gauges and sector rings. | [Canon] |
| **TNG (2380)** | LCARS as above. | [Canon] / [Fan standard] |


## Other factions

Little is written down beyond what's on screen, and Federation-built props were often re-dressed for aliens. Where written sources are thin, the rules come from studying on-screen images: reference screenshots are collected locally (not in Git) and the tokens are derived from them.

| Faction | On screen | Shape grammar for the Dex | Mark |
|---|---|---|---|
| **Federation** | LCARS | Elbows, sweeps, pills | [Canon] |
| **Klingon** | Red and orange schemes; angular PADDs | Chamfered 45° corners, wedge bars, no curves | [Canon] colour; shape [Proposed] |
| **Romulan** | Turquoise and green; thin outlined frames with slanted, trapezoid and parallelogram shapes; green bars along the top; red eagle emblem | Outlined frames with sharp slants, parallelogram buttons, short slanted accent bars along the top (`slanted`) | [Canon] |
| **Cardassian** | Muted, cold, near-monochrome displays; blue to purple buttons; square screens with several ellipses; brown and gold hardware | Elliptical frames and panels | [Canon] |
| **Dominion** | Heavy violet keyhole arches round a ringed hub (the Jem'Hadar warship console) | Round arches in place of elbows, arch-topped blocks, pill buttons (`arched`) | Fan (screens) |
| **Borg** | Rarely shown; small monitors in the cube | To be derived from on-screen images (#596). Working assumption: black and green on a rigid grid, no curves | [Proposed] until researched |
| **Voth** | Little written down; *Star Trek Online*'s Voth interface | Rounded rectangles (`rounded`) | Fan (thin) |
| **Gorn** | *Starfleet Command II*'s Gorn interface: khaki stone frames with small bevels round dark green screens, glossy green pill buttons | Bevelled stone rims with a shaded fill, glossy green buttons (`stone`) | Fan (game assets) |
| **Ferengi** | Rounded device bezels with thick rims (the D'Kora console, Quark's PADD) | Rounded rectangles with a thick darker rim (`bezel`) | Fan (thin) |
| **Terran Empire** | The mirror universe's Federation | **TOS Federation theme with a tweaked accent.** Decided 2026-10-17 | Decided |

## The theme framework

Every theme is the same set of **tokens**, so the app can swap themes without changing any screen.

| Token group | Tokens |
|---|---|
| **Colour** | background, structure 1–3, data 1–2, accent, text on structure, text on background, status ok, warning and alert |
| **Shape** | family (LCARS, angular, rounded-rect, elliptical, grid, console), corner radius ratio, chamfer size, gap ratio, sidebar block count |
| **Typography** | heading font (may be decorative), body font (always readable), size scale, capitalisation rule |
| **Motion** | transition duration, assembly order, cascade rate |
| **Sound** | beep set, or none |

Rules:
1. **Body text is always readable.** Decorative faces (Klingon, Romulan glyph fonts and the like) are for headings and emblems only. This is the same two-tier rule the mod uses for its HUD fonts. [Mod]
2. **Colours come from what was on screen.** Each era's and faction's palette is researched from screenshots and fan measurements, with its sources and a confidence (canon, fan or proposed), in `data/themes.source.json`. The images to work from are listed on [Interface References](/Interface-References.md). The mod's HUD tints (`gen_era_theme.py`) are not used: they recolour a teal HUD, and don't describe how each era's or faction's displays looked. Decided 2026-10-17.

   | Theme | Shape | Palette | Confidence |
   |---|---|---|---|
   | ENT | panel | slate blue and cyan; red, pink and yellow tabs | Fan (152 lcars.org.uk NX-01 stills) |
   | TOS | console | yellow, green, red | Fan (replica panels) |
   | TMP (films) | film | bright blue, sky blue, green lamps | Fan (*Star Trek IV* Enterprise-A renders and *Starfleet Command II*'s Federation interface) |
   | TNG | lcars | classic LCARS | Canon |
   | Klingon | angular | red, orange, crimson; gold | Fan (48 lcars.org.uk screens) |
   | Romulan | slanted | cyan, teal and blue; green; salmon accent | Fan (14 lcars.org.uk screens) |
   | Cardassian | elliptical | cyan and teal, tan-gold, rose; pale yellow | Fan (34 lcars.org.uk screens and fan art) |
   | Dominion | arched | lavender-indigo, magenta, cyan, gold | Fan (2 screens; thin) |
   | Borg | radial | bright greens; olive and gold crosshairs | Fan (Voyager screens, LCARS 47 Borg theme) |
   | Ferengi | bezel | bronze, blue, magenta-pink, green | Fan (4 screens; thin) |
   | Voth | rounded | blue-green and blue | Fan, via *Star Trek Online* |
   | Terran | TOS frame | gold accent | Decided |
   | Gorn | stone | khaki-bronze stone panels, glowing green, gold | Fan (*Starfleet Command II*'s Gorn interface, decoded from the game disc) |
| Breen, Tholian, Undine | their era's frame | accent only | Proposed |

3. **Era sets the frame; a faction with its own interface replaces it.** Federation, Terran and unaligned entries use their era's frame. Factions with interfaces of their own (Klingon, Romulan, Cardassian, Dominion, Borg, Voth) bring their whole frame: shape and colours. The rest only change the accent. [Proposed]
4. **Readable contrast everywhere.** Every theme must pass WCAG AA contrast for text, checked automatically. [Proposed]
5. **One switch for purists.** A setting forces classic LCARS everywhere. [Proposed]

In Flutter, a theme is a `ThemeExtension` holding these tokens, and the frame widgets (bar, sidebar, elbow and their angular, elliptical and grid counterparts) read only from it.

**Built so far (2026-10-18):** colour, highlight and shape tokens; palettes for every era and faction from `data/themes.source.json`, each checked for AA contrast; and thirteen shape families: `lcars` (TNG; Dominion until researched), `film` (TMP: slanted, outlined panels with small oval lamps and buttons, rings round the ship, after the *Star Trek IV* Enterprise-A consoles), `radial` (Borg: ringed hubs, capsule blocks, rings round the ship), `angular` (Klingon), `rounded` (Romulan, Voth), `elliptical` (Cardassian: quarter-ellipse corners with an oval inset, trapezoid caps, buttons and chips, nested ellipses round the ship), `grid` (frame cut into square cells, a faint grid behind the content, no curves; built for the Borg, now unused since the references show them in rings and nodes), `console` (TOS: flat square panels, with an indicator lamp on each sidebar block and button), `panel` (ENT, before LCARS: square grey-blue bezels whose bars, blocks and buttons have a flat raised shading, lighter at the top), `slanted` (Romulan: thin outlined frames over a faint fill with sharp 45° slants, parallelogram caps and buttons, and three short slanted accent bars along the top bars), `arched` (Dominion: a heavy round arch in place of each elbow, arch-topped sidebar blocks, pill buttons), `stone` (Gorn: small bevels, a shaded fill with a darker rim, glossy green buttons) and `bezel` (Ferengi: rounded rectangles with a thick darker rim). The section headings, data tiles and lists are shared by every family; only their colours change. Typography (#586): a heading font per era (League Gothic for TNG, Pathway Gothic for ENT, Trek Classic for TOS, Trek Movie for TMP) and for the Klingon (Klingon Dagger) and Romulan (Romulan Eagle) frames; other factions' frames use the platform font. Each faction with a script of its own shows it as decoration beside the screen title. See the App page, Fonts. Motion beyond the transition length and sound are still to come. See the [App](/App.md) page.

## Sources

- Memory Alpha: [Okudagram](https://memory-alpha.fandom.com/wiki/Okudagram), [LCARS](https://memory-alpha.fandom.com/wiki/Library_Computer_Access_and_Retrieval_System), [Desktop monitor](https://memory-alpha.fandom.com/wiki/Desktop_monitor), [PADD](https://memory-alpha.fandom.com/wiki/Personal_Access_Display_Device), [Lee Cole](https://memory-alpha.fandom.com/wiki/Lee_Cole)
- [Michael Okuda (Wikipedia)](https://en.wikipedia.org/wiki/Michael_Okuda), [LCARS (Wikipedia)](https://en.wikipedia.org/wiki/LCARS)
- [TheLCARS.com colour guide](https://www.thelcars.com/colors.php)
- [LCARS-ESP32 design guide](https://github.com/dorofino/LCARS-ESP32/blob/main/LCARS_DESIGN_GUIDE.md), [lcars R package](https://cran.r-project.org/web/packages/lcars/lcars.pdf), [swift-lcars](https://github.com/zak-keown/swift-lcars), [trekcolors](https://leonawicz.github.io/trekcolors/reference/lcars_colors.html)
- [LCARS Fandom: Cardassian Interface](https://lcars.fandom.com/wiki/Cardassian_Interface)
- [Gizmodo: design lessons from Star Trek](https://gizmodo.com/design-lessons-from-star-trek-to-consider-before-creati-5945379) (Enterprise-era interface)
- [Forgotten Trek: designing the *Motion Picture* bridge](https://forgottentrek.com/the-motion-picture/designing-the-motion-picture-bridge/)
- STCR: `locale/English/fontmap.lua` and the Continuum wiki's Per-Race UI page (fonts)
- Image sources for every era and faction: [Interface References](/Interface-References.md)
