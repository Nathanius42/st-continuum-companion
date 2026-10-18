# Dart and Flutter Primer

What you need to know to work on the Dex, distilled from the "Your first Flutter app" codelab (worked through in the `D:\Dev\hello_dex` sandbox; lesson snapshots in `hello_dex\lessons`) and the Dart language tour. Comparisons are with Lua 4, since that's the mod's language.

## The development loop

| Action | How |
|---|---|
| Run | `flutter run -d windows`, or `-d <device>` for a phone |
| Hot reload | `r` in the run session: applies code changes in about a second and **keeps the app's state** |
| Hot restart | `R`: reloads everything and resets state. Needed after changing app start-up or adding packages. |
| Check code | `flutter analyze`: catches errors before anything runs |
| Tidy code | `dart format lib test` (refuses to run on broken code, which is a useful signal) |
| Test | `flutter test` |
| Add a package | `flutter pub add <name>`; packages come from [pub.dev](https://pub.dev) |

A broken edit never crashes a running app: hot reload just refuses it until it's fixed.

## Flutter's core ideas

1. **Everything is a widget**, including layout. Centring is wrapping in `Center`; a gap is a `SizedBox`; side by side is a `Row`; stacked is a `Column`; space inside is `Padding`; scrolling is `ListView`.
2. **The screen is a function of the data.** Never edit a label directly. Change the data and tell Flutter, and `build()` runs again.
3. **Two kinds of state:**
   - **Widget state** (`StatefulWidget` + `setState`) for UI details only one widget cares about, such as which tab is selected.
   - **App state** (a `ChangeNotifier` class, provided with `ChangeNotifierProvider` and read with `context.watch`) for data the whole app shares, such as ships, the current era and favourites.
4. **Change shared data only through methods that call `notifyListeners()`.** Changing a list directly from a button updates the data but not the screen. This is the most common Flutter bug.
5. **Buttons ask, the state decides.** Buttons call one method on the state; the logic lives in the state class.
6. **Small named widgets.** Extract pieces (`BigCard`, later `LcarsElbow`, `ShipCard`, `Turntable`) so screens read like a description.
7. **Take colours and text sizes from the theme** (`Theme.of(context)`), never hard-coded, so one theme change restyles everything.
8. **Responsive layout with `LayoutBuilder`:** under 600 px is a phone (bottom `NavigationBar`), 600 px and over gets a side `NavigationRail`, and from 800 px the rail is extended with labels. `SafeArea` keeps content clear of the status bar.

## Dart essentials

**Types and variables.** Dart is statically typed; `var` lets it infer the type, but the type is still fixed.

| Keyword | Meaning |
|---|---|
| `var` | Can be reassigned |
| `final` | Set once, at run time. **The Dex's default.** |
| `const` | Fixed at compile time. Lets Flutter skip rebuilding widgets. |

**Null safety.** A variable can never be `null` unless its type ends in `?`.
```dart
String name = 'Galaxy';      // never null
String? subtitle;            // may be null; Dart makes you check before using it
subtitle ?? 'Unknown class'  // fallback when null
ship.canon?.source           // null if canon is null, otherwise its source
data!                        // "it's not null": crashes if wrong; use sparingly
```
This replaces Lua's `attempt to index a nil value` with an error before the code ever runs.

**Privacy.** A name starting with `_` is private to its file (`_counter`). There is no `private` keyword.

**Functions.**
- `() { ... }` and `() => expr` are anonymous functions. A button's `onPressed` takes one with **no** inputs.
- `onPressed: appState.getNext` (no brackets) passes the method itself; `getNext()` would call it immediately.
- A function written inside a loop **captures** that iteration's variables. That's a closure.

**Strings.** `'USS ${ship.name}'` and `'$count ships'` interpolate values, replacing Lua's `..`.

**Control flow.**
```dart
if (list.isEmpty) return;            // brackets around the condition
if (a) { ... } else { ... }
for (final ship in ships) { ... }
switch (index) { case 0: ...; case 1: ...; default: throw UnimplementedError(); }
final year = switch (era) { Era.ent => 2160, Era.tos => 2250, Era.tmp => 2310, Era.tng => 2380 };
```
A `switch` expression over an enum must cover every value, or the analyser complains.

**Collections.**
```dart
final ships = <Ship>[];                       // List: typed array
ships.add(s); ships.remove(s); ships.removeLast(); ships.contains(s);
ships.isEmpty; ships.length;                  // properties: no brackets
final hp = <String, int>{'fed_TNG_galaxy': 111700};   // Map: Lua's keyed table, typed
[ Header(), for (final s in ships) ShipTile(s) ]       // "collection for" inside a list
```

**Classes and named constructors.**
```dart
class Ship {
  const Ship({required this.id, required this.name, this.subtitle});
  final String id;
  final String name;
  final String? subtitle;
}
```
`required` makes an argument compulsory. Many classes have extra named constructors such as `ElevatedButton.icon(...)`, `EdgeInsets.all(20)` and `Color(0xFFEB943A)`.

**Enums** give a fixed set of choices, and can carry data (see `lib/data/era.dart`). A typo like `'TGN'` becomes a compile error.

**Async.** `Future<T>` is a value that arrives later; `await` pauses the current function, not the app.
```dart
Future<List<Ship>> loadShips() async {
  final text = await rootBundle.loadString('assets/ships.json');
  ...
}
```

**Generated code.** `json_serializable` writes the JSON-reading code from an annotation into `*.g.dart` files. Never edit those; regenerate them.

## Mistakes we've already made (so you don't again)

| Symptom | Cause |
|---|---|
| "The method 'x' isn't defined" | Calling a method that doesn't exist yet; the analyser catches it before the app runs |
| Several errors on one line of an `if` | Lua habits: Dart needs `if (condition)`, and properties like `isEmpty` take no `()` |
| "The named parameter 'shape' isn't defined" | A parameter given to the wrong widget (shape belongs to `Card`, not the text style) |
| "Too many positional arguments" | A widget wasn't closed with `),` before the next item in a list |
| "Invalid constant value" | `const` on something that changes |
| Button changes data but the screen doesn't update | No `notifyListeners()`; change shared data through a state method |

## Further reading

- [Dart language tour](https://dart.dev/language)
- [Flutter layout guide](https://docs.flutter.dev/ui/layout)
- [Your first Flutter app (codelab)](https://codelabs.developers.google.com/codelabs/flutter-codelab-first)
