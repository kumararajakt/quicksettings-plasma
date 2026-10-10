# AGENTS.md

KDE Plasma 6 QML applet (KPackage `Plasma/Applet`). No build system, CI, or tests — the `package/` source is the artifact. Remotes: `upstream` = luciotorelli/quicksettings-plasma, `origin` = fork; work lands on `main`.

## Layout

- `install.sh` — `kpackagetool6 --install|--upgrade package` by `package/metadata.json` Id. Changing Id forces reinstall.
- `tools/grab.sh` — offscreen verification harness (runs working tree).
- `package/contents/config/main.xml` — kcfg schema (settings live here first).
- `package/contents/config/config.qml` — settings dialog categories.
- `package/contents/ui/main.qml` — `PlasmoidItem`; instantiates all backends and re-exports as `app.*` aliases. **Backends live here**, not in popup (panel button works without popup built).
- `package/contents/ui/backends/*.qml` — one file per subsystem.
- `package/contents/ui/CompactRepresentation.qml` / `FullRepresentation.qml` — panel button and popup.
- `package/contents/ui/panels/*.qml` — expansion panels (`PanelBody` subclasses).
- `package/contents/ui/components/*.qml` — `Style.qml` and shared widgets.
- `package/contents/ui/config/*.qml` — settings pages.
- `package/contents/ui/DevGrab.qml` — dev-only; loaded only with `qs-grab=`.

## Verification (no test suite)

```bash
tools/grab.sh /tmp/out.png                    # renders popup off-screen
tools/grab.sh /tmp/out.png qs-check-config    # also compiles all settings pages
```

- `grab.sh` runs the **working tree** (no `install.sh` needed). QML warnings go to `<out>.log` next to the image; exits non-zero if no image produced. Read the log.
- Defaults to software renderer (cannot tint icons). Use `QS_QUICK_BACKEND=` for GPU.
- Mutates `~/.config/plasmawindowedrc` (deletes `geometry=` lines).
- Live: `./install.sh && systemctl --user restart plasma-plasmashell` or `plasmawindowed com.github.luciotorelli.quicksettings`.

### Harness flags (see `DevGrab.qml`)

| Flag | Effect |
|---|---|
| `qs-expand=<key>` | open panel first (`audio`, `wifi`, `vpn`, `power`, `fan`, …) |
| `qs-switch=<key>` | switch to second panel |
| `qs-collapse` | close panel (exercise closing animation) |
| `qs-delay=<ms>` | wait before grab (default 2000; ddcutil needs ~14000) |
| `qs-toggle=nightlight\|awake` | flip setting with side effects |
| `qs-check-config` | compile all settings pages |
| `qs-check-shell` | prove two Shell runners don't share execution |
| `qs-second-awake[=<ms>]` | spawn second Keep Awake backend |
| `qs-demo` | replace SSID with "Home" (public screenshots) |
| `qs-menu-test`, `qs-menu-fire`, `qs-check-enums` | tray DBusMenu/enum probes |
| `qs-media-dump`, `qs-tray-dump`, `qs-order-dump` | dump state |
| `qs-grab-compact` | grab panel button instead of popup |

### Harness traps
- **`qs-check-shell` not idempotent**: creates `$XDG_RUNTIME_DIR/qs-shell-check` and never cleans up; second run reports failures. Run `rmdir "$XDG_RUNTIME_DIR/qs-shell-check"` between runs.
- Writing to `docs/*.log` creates untracked files; prefer `/tmp` for output images.
- `qs-toggle=awake` takes a real PowerDevil inhibition and leaves `quicksettings-keep-awake-test` in `$XDG_RUNTIME_DIR`.

## qmllint

```bash
qmllint $(find package -name '*.qml')
```

Parse-only. Silent on unknown props/wrong types/bad signal signatures. **Use `tools/grab.sh` as the real gate.** Do not run `qmlformat`.

## Adding a pill

The steps span five files and are easy to half-do:

1. `backends/Foo.qml` — `Item { visible: false }`, exposing state as properties and mutating via `set*` functions. Add `readonly property bool available` so it can hide itself when missing.
2. `main.qml` — instantiate it and add a matching `readonly property alias`.
3. `config/main.xml` — a `showFoo` entry in the `Pills` group.
4. `config/ConfigPills.qml` — a `property alias cfg_showFoo: …`, a checkbox, and a `{ key: "foo", box: … }` entry in `pills` (reorder list).
5. `FullRepresentation.qml` — add the key to `pillKeys`, a `case` in `tileVisible`, and a `Pill { }` instance. Grid position comes from index in `tileOrder` (resolved from stored order + defaults).
6. If it opens a panel: `panels/FooPanel.qml` extending `PanelBody`, a `Component` in `FullRepresentation`, and an entry in `ExpansionPanel.panels`.

Adding a *settings page* also means adding it to `DevGrab.qml`'s `qs-check-config` array — otherwise it's never compiled.

## Backends

- `Item { visible: false }` with real bindings. Must stay in tree and keep evaluating.
- Anything with no Plasma API goes through `Backends.Shell` (`required property var shell`, injected by `main.qml`).
- `available: false` (missing command/empty device list) hides the control; do not error.
- One file per subsystem. Network and audio are Plasma-internal and break on upgrades — that's why the split exists.

## QML and Plasma traps

- **Property named `onFoo`** (lowercase `on` + capital) is parsed as a signal handler and silently never gets its value (`onAccent` is the trap).
- **Popup window never changes size while open.** On bottom panel + Wayland, move lands before taller content causing jump. Panels get room inside fixed-size window; height applied a frame late while `full.idle`. Never bind popup `Layout.*Height` mid-animation.
- **Each widget copy has its own QML engine** (even same plasmashell). `pragma Singleton` is not shared. Cross-copy state goes via file or shared D-Bus (see `KeepAwake.qml`).
- **`executable` data engine is shared process-wide** and keys runs by command line (ignores repeat while in flight). `Shell.qml` appends per-runner token ` #qs<token>-<serial>` to every command — do not remove or reuse command lines.
- **`Kirigami.Theme` only resolves for visible items.** Reading from invisible helper gives disabled text/black highlight. `Style.qml` takes `text` and `systemAccent` as `required property` bound from visible popup.

## Conventions

- User-facing strings via `i18n()`/`i18nc()`. No `.ts` files committed.
- Shared widgets take `required property Style style`; panels take `required property var app`. Set at instantiation.
- `textFormat: Text.PlainText` on every label (prevents markup injection).
- Comments explain *why*, not what; match existing workarounds.
- Commit messages are prose (short imperative subject + paragraph explaining what/why).

## Adding a pill

The steps span five files and are easy to half-do:

1. `backends/Foo.qml` — `Item { visible: false }`, exposing state as properties
   and mutating state via `set*` functions. Add `readonly property bool available`
   so it can hide itself when its subsystem is missing.
2. `main.qml` — instantiate it and add a matching `readonly property alias`.
3. `config/main.xml` — a `showFoo` entry in the `Pills` group.
4. `config/ConfigPills.qml` — a `property alias cfg_showFoo: …`, a checkbox, and
   a `{ key: "foo", box: … }` entry in `pills` (the reorder list).
5. `FullRepresentation.qml` — add the key to `pillKeys`, a `case` in
   `tileVisible`, and a `Pill { }` instance. The grid assigns rows/columns from
   each pill's index in `tileOrder`, which is the stored order with every key
   `pillKeys` has and the stored list has not been appended to it.
6. If it opens a panel: `panels/FooPanel.qml` extending `PanelBody`, a
   `Component` in `FullRepresentation`, and an entry in that `ExpansionPanel`'s
   `panels` map.

Adding a *settings page* also means adding it to the array in
`DevGrab.qml` (`qs-check-config`) — otherwise it is never compiled and a broken
page ships unnoticed.

## Backends

- `Item { visible: false }` with real bindings. Not decoration: they must stay in
  the tree and keep evaluating.
- Anything with no Plasma API goes through `Backends.Shell` (`required property
  var shell`), injected by `main.qml`.
- `available: false` (a command not installed, a device list empty) hides the
  control; do not error.
- Keep the one-file-per-subsystem split. The network and audio modules are
  Plasma-internal and break on Plasma upgrades; that is the whole point of the
  split.

## QML and Plasma traps, all learned the hard way

- **A property named `onFoo`** (lowercase `on` + capital) is parsed as a signal
  handler and silently never gets its value. `onAccent` is the trap.
- **The popup window never changes size while it is open.** A Plasma popup on a
  bottom panel must be resized *and* moved, and on Wayland the move lands before
  the taller content, so it jumps. Panels get room inside a fixed-size window,
  and the window height is applied a frame late, only while `full.idle`.
  Never bind a popup `Layout.*Height` to something mid-animation.
- **Each copy of the widget gets its own QML engine**, even inside one
  plasmashell, so `pragma Singleton` is *not* shared between two copies. There
  is currently no singleton in the tree. Cross-copy state goes through a file or
  a shared D-Bus service (see `KeepAwake.qml`).
- **The `executable` data engine is shared process-wide** and keys a run by its
  command line, ignoring a repeat while one is in flight. Two runners issuing
  identical text get one execution and the same result. `Shell.qml` appends a
  per-runner random token (` #qs<token>-<serial>`) to every command — do not
  remove it, and do not reuse a command line.
- **`Kirigami.Theme` only resolves for a visible item.** Read from an invisible
  helper it yields the disabled text colour and a black highlight. `Style.qml`
  therefore takes `text` and `systemAccent` as `required property`, bound from
  the popup itself, which is visible.
- D-Bus basic types come back wrapped (`{ value: 25 }`); lists do not. See
  `KeepAwake._call`.

## Conventions

- Every user-facing string goes through `i18n()` / `i18nc()`. No `.ts` files are
  committed, so there is no translation workflow to follow.
- Shared widgets take `required property Style style`; panels also take
  `required property var app`. Set them at the instantiation site.
- `textFormat: Text.PlainText` on every label, so a network name or app name
  cannot inject markup.
- Comments explain *why*, not what, and record the reasoning behind a workaround.
  Match that — a comment that restates the next line is out of place here.
- Commit messages are prose, not conventional commits: a short imperative subject
  then a paragraph on what was actually wrong and why the fix works.
