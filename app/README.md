# continuum_dex

The Continuum Companion Flutter app. Targets Android and Windows; iOS is a stretch goal.

## Layout

| Path | Contents |
|---|---|
| `lib/main.dart` | Entry point |
| `lib/app.dart` | Root widget: theme and first screen |
| `lib/data/` | Data models (eras now; ships once the pipeline exists) |
| `lib/theme/` | LCARS theme (placeholder until the theme-token model lands) |
| `lib/screens/` | Full screens |
| `test/` | Widget and unit tests |

## Everyday commands

Run these from this folder:

```bash
flutter run -d windows
```

```bash
flutter analyze
```

```bash
flutter test
```

```bash
dart format lib test
```

For running on a phone over wireless debugging, see the Tooling page in the Dex wiki.
