# Ship Data Schema

The pipeline writes **one JSON file** that the app bundles. Its shape is defined by a JSON Schema, so the pipeline, the app and the validator all agree on it.

| File | What it is |
|---|---|
| `data/schema/ships.schema.json` | The schema (JSON Schema draft 2020-12) |
| `data/samples/ships.sample.json` | Five hand-filled sample ships covering every tricky case |
| `pipeline/validate.py` | Checks a data file against the schema plus the cross-reference rules below |

Run the validator from the repository root:

```bash
pipeline/.venv/Scripts/python.exe pipeline/validate.py data/samples/ships.sample.json
```

(The `.venv` is local and git-ignored. Create it with `python -m venv pipeline/.venv`, then `pipeline/.venv/Scripts/python.exe -m pip install jsonschema`.)

## Top level

| Field | Meaning |
|---|---|
| `schemaVersion` | `1`. Bump it when a change would break the app's parser. |
| `dataVersion` | `modRevision` (the SVN revision the data was read from), `generatedAt`, `generator` |
| `eras` | ENT, TOS, TMP and TNG, with title, year and mod folder |
| `factions` | Each faction's id, name, hull prefixes (`fed`, `kng`…), whether it's playable, the eras it appears in, and optionally a theme id |
| `ships` | The ships |

## A ship

| Field | Source | Notes |
|---|---|---|
| `id` | Hull folder name | e.g. `fed_TNG_galaxy` |
| `era`, `faction` | Mod folder; hull prefix | Must exist in `eras` / `factions` |
| `name` | `.ship` `displayedName` | |
| `subtitle` | `.ship` `sobDescription` | The build-menu subtitle; may differ from the description's first line |
| `showOnlyOn` | Nathan's hull answers | Optional `{month, day}`: an easter egg the app shows only on that date (the USS Brisbane, 28 July) |
| `availability` | Build lists, starting fleets, Keeper archetypes, hull answers | One or more of `buildable`, `starting-fleet`, `keeper`, `special` (included on Nathan's answer though none of the others: mission ships, Invasion-only ships, map stations) |
| `classification` | `.ship` families; `.def` `hullSizeCategory` | `displayFamily` is the engine class (HWRM calls everything above a frigate "Capital") |
| `stats` | `.ship` and `.def` | `maxHealth`, `maxSpeed` (`mainEngineMaxSpeed`), `buildCost` (RU), `buildTime` (seconds), `length` / `width` (`.def` axes). **Null where the mod has no value**, never 0. |
| `roles` | `.def` `aiRoles` | e.g. `AntiFrigate` |
| `weapons` | `.ship` `StartShipWeaponConfig` | See the counting rule below |
| `abilities` | `.ship` `addAbility` | Engine id plus a readable name. Basic commands every ship has (move, waypoint, parade, guard, retire) are left out. |
| `description` | Build list `Description` | Split into `lead`, `crew` (0 for unmanned craft), `armament`, `defences`, `prerequisites`, `summary`, plus `other` for extra sections such as Subsystems or Air Wing. **Null** for ships with no build entry, such as Keepers. |
| `research` | Build list `RequiredResearch` | The raw expression plus `anyOf`, the alternatives, each with its displayed name from the research files. A starting tree (granted at the start of a match) has `startingTree` set to `standard` or `flagship` and a null name. |
| `canon` | Canon Verification Results (Continuum wiki) | `tier` A / B / G / none, a source URL and a note; null until checked |
| `credits` | Ship readme in Source Files | `authors` (empty when unknown) plus a `note` explaining why |
| `media` | Exported assets | `icon` and `turntable` paths relative to the app's assets folder; null until exported or rendered |
| `variants` | See below | Shown on the same ship page with a toggle |
| `source` | | The `.ship`, `.def` and build-list paths, relative to the mod's `HWRM` folder, for tracing problems back |

### Counting weapons

Weapons are counted from the **active** `StartShipWeaponConfig` lines in the `.ship` file:
- Commented-out lines are ignored.
- The `X_` twins (the shield-emulation copies) are left out.
- Kinds come from each weapon's `.wepn` fire type (see [Pipeline](/Pipeline.md)), or from its name when the file can't be found.

### Weapon figures (#428)

`weapons.details` has one row per kind of weapon the ship mounts, read from its `.wepn` file (this era's copy first). Mounts with the same name and figures are merged and counted, so the counts add up to `total`.

| Field | From | Meaning |
|---|---|---|
| `name` | Weapon id | The mod's plain-plural wording with the mark, e.g. "Phaser Beams Mk 11" |
| `kind`, `count` | | As counted above |
| `damage` | `AddWeaponResult` "Hit" "DamageHealth" | The average of the minimum and maximum, plus that of any weapon a hit spawns ("SpawnWeaponFire"). Null when the weapon does no real damage (repair beams, EMPs, the token 1 of an assimilation beam) |
| `cycle`, `shotsPerCycle` | `StartWeaponConfig` fire, burst and wait times | Without a burst, one shot every fire time. With one, as many shots as fit in the burst time, then the wait. Null for mines (they wait to be triggered) and sphere bursts (one-off blasts) |
| `dps` | | `damage` × `shotsPerCycle` ÷ `cycle`, for one mount |
| `range` | `StartWeaponConfig` range | In game units |
| `special`, `disables`, `area` | Activation, "Disable" results, `SphereBurst` | Fired only as a special attack; a hit disables the target; a hit spreads as a blast |

`weapons.dps` is the ship's total: every mount's `dps`, with special attacks left out. It's the rate of fire at its steadiest, so it ignores armour, accuracy, turning and travel time; it's for comparing ships, not predicting a fight.

The `.def` file's weapon counts are **not** used, because the `.def` generator counts commented-out lines too (see below).

### Variants

Your ruling was: variants and subsystem configurations share one ship page, with a toggle that switches the visual. A variant only records **what differs** from the parent ship.

| `kind` | Example | Identified by |
|---|---|---|
| `subsystem` | Oberth sensor suite, rollbar, support suite; the Miranda and Nebula pods | `subsystemId`; one of two or more modules that switch the same hull's model |
| `separation` | Galaxy saucer and stardrive, Prometheus and Brisbane sections, the D'kyr shuttle | `hullId`; each part is a hull of its own with its own stats and render |
| `escort` | Carrier drones (e.g. the Chhavran's Kilhra'en) | `hullId`; craft that launch from or travel with the ship |
| `refit`, `loadout` | Alternative versions of a hull, e.g. Construction Bee types 1–4b, the TMP Ambassador refit | `hullId` when the version is a hull of its own |
| `refit` (subsystem) | A hull's only model-switching subsystem: the NX, T'Garim and TMP Excelsior refits, the Borg Cube's Tactical Armour | `subsystemId`, with `hullId` null |

`stats` and `media` inside a variant hold only the overridden values. The app shows the parent's value for anything missing. For subsystem refits and subsystem variants, `stats` are the parent's with the subsystem's `ThisShipOnly` multipliers applied (speed, hull), and the cost and time to field one: hull plus subsystem. Escorts that share a model are one variant with a `count` and the `hullIds` it stands for (e.g. the Predator's three Warfang drones).

## Rules the validator checks beyond the schema

- Ship ids are unique, and the era code in the id matches `era`.
- Every ship's faction exists, owns the hull prefix, and lists the ship's era.
- Weapon kinds add up to `total`, and `mounts` has that many entries, as do the counts in `details`.
- Variant ids are unique within a ship.
- Every `buildable` ship has a description.

## The five samples

| Ship | Why it's in the samples |
|---|---|
| NX (ENT, Federation) | Baseline buildable ship; has commented-out torpedo mounts |
| D7 (TOS, Klingon) | Different faction; the description's lead ("Medium Battlecruiser") differs from the subtitle ("Battlecruiser") |
| Oberth (TMP, Federation) | **Subsystem variants**; buildable and in a starting fleet; has an "other" weapon (repair beam) |
| Galaxy (TNG, Federation) | **Separation variants** with their own stats; credits where the readme doesn't name the author |
| Crystalline Entity (TNG, unaligned) | **Keeper**: no build entry, no research, no icon, no dimensions |

## Data problems found while building the samples

These belong to the mod and are tracked on the Continuum board (tag `found-by-dex`):

- The `.def` generator counts commented-out weapon lines: the NX's `.def` claims 4 torpedoes, but only 2 are active.
- The Crystalline Entity's `.def` has zero length and width.
- Spelling in mod text: "Cozmazoan" (canon: cosmozoan), "exploritory" and "seperating" (Galaxy description).
