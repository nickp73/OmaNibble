# OmaMath — your first Omarchy plugin

A bar calculator and decimal / binary / hexadecimal converter for the
Quickshell-based Omarchy shell. It uses Omarchy's current shared UI components
and follows the active theme. It does not work with the older Waybar setup.

## Using it

Click **OmaMath** in the bar (`=` on a vertical bar). Type an expression or edit
any of the three integer fields. Results update as you type. Use Tab / Shift+Tab
to move between fields, Ctrl+A then Ctrl+C to copy a value, and Escape or an
outside click to close. **Clear** resets all inputs. Inputs survive closing and
reopening, but are not saved across shell restarts or plugin reloads.

| Input | Result |
| --- | --- |
| `(12 + 5) * 3` | `51`, binary `110011`, hexadecimal `33` |
| `0xFF + 0b10` | `257`, binary `100000001`, hexadecimal `101` |
| `5 / 2` | `2.5`; integer conversion fields remain empty |
| `2^8` or `2**8` | `256` |
| Binary field: `0b1010` | Decimal `10`, hexadecimal `A` |
| Hexadecimal field: `-FF` | Decimal `-255`, binary `-11111111` |

Arithmetic supports `+`, `-`, `*`, `/`, `%` (remainder), `^` / `**` (power),
parentheses, decimal fractions and scientific notation such as `1e3`.
Use the ordinary keyboard hyphen for subtraction. Powers associate right to
left: `2^3^2` means `2^(3^2)`. A leading minus applies after powers: `-2^2 = -4`.
There are no variables, function calls, implicit multiplication or bitwise
operators; `^` means exponentiation, not JavaScript XOR.

Conversion fields accept whole integers only. Binary and hex prefixes (`0b`,
`0x`) are optional in their respective fields and required in expressions.
Negative values use a minus sign, not fixed-width two's complement.
Invalid or unfinished input shows an explanation and clears old results.
The active conversion field keeps its original text and cursor position.
Editing a conversion field clears the previous expression.

Arithmetic uses JavaScript floating point, so `0.1 + 0.2` displays
`0.30000000000000004`. Literals and intermediate results are limited in magnitude
to 9,007,199,254,740,991 (JavaScript's maximum safe integer). Integer conversions
within that range are exact; decimal arithmetic is approximate. Expressions
are limited to 512 characters and conversion fields to 128.

## How the files fit together

```text
manifest.json              Omarchy discovers the plugin and loads BarWidget.qml
    └── BarWidget.qml      The bar button and the host's popup interface
            └── Panel.qml  Input fields, synchronization, error messages and popup
                    └── Calculator.js  Parsing, arithmetic and base conversions
```

### 1. The manifest describes the plugin

`id` must match the installation directory and the QML `moduleName` values.
`kinds: ["bar-widget"]` tells Omarchy where this component belongs;
`entryPoints.barWidget` names the QML file to load. `defaultSection` only selects
its initial placement when enabling it. Your existing layout places it in the
centre, which takes precedence over the manifest's `right` default.

The popup is owned by the widget, so it needs no separate manifest entry point.
The manifest's MIT declaration is retained from your original; add a matching
LICENSE file before publishing a repository under that license.

### 2. The bar widget is a small adapter

`import qs.Ui as Ui` gives access to Omarchy components. `Ui.BarWidget` explicitly
selects the framework base class, even though our own file is also named
`BarWidget.qml`. Omarchy provides `bar` (host geometry and operations) and
`settings` (the widget's inline configuration).

`Ui.WidgetButton` provides theme styling, tooltip behavior and mouse handling.
The local `Panel` instance gets its `bar`, `settings`, `anchorItem` and
`hostWidget` through property bindings. Bindings automatically follow changes;
no Loader or manual property injection is needed for this small plugin.

The root forwards `open()`, `close()`, `togglePanel()` and
`closeForPopoutSwitch()` and exposes `opened`. This lets Omarchy coordinate the
popup with other widgets and open it through shell IPC.

### 3. The panel separates state from the window

`Ui.Panel` supplies the open/close lifecycle. Its child `Ui.KeyboardPanel`
provides the anchored window, keyboard focus, outside-click dismissal and
coordination with other popups. Note the distinction:

- `Ui.Panel.open()` is a function that changes the lifecycle state.
- `Ui.KeyboardPanel.open` is a boolean bound to `root.opened`.

`focusTarget: mathInput` focuses the expression field when opening. The
Flickable allows scrolling if the screen cannot fit the form. `Style` and
`Color` come from `qs.Commons` and keep the plugin consistent with your theme.

Inputs use `onTextEdited`, which runs for user edits. Programmatic assignments
to the other fields do not trigger that signal, avoiding conversion loops.
`objectName` values let the smoke test identify fields; QML `id` values are
local references used by the component itself.

### 4. The calculator is ordinary JavaScript

`Calculator.js` contains no UI code. It exposes `evaluate`, `parseInteger`,
`convert` and `isSafeInteger`. The parser only recognizes numbers and the
supported operators; it never evaluates input as JavaScript code.

The parser is recursive descent: `sum` handles addition/subtraction, `product`
handles multiplication/division/remainder, `unary` handles leading signs,
`power` handles exponentiation and `primary` handles numbers/parentheses.
Splitting precedence into functions makes it easier to add an operator later.

## Install or update your working copy

Run from the project directory. Only the five runtime/documentation files are
copied; your IDE configuration and tests stay in the project.

```bash
plugin_dir="$HOME/.config/omarchy/plugins/io.github.BinDecHex.omamath"
mkdir -p "$plugin_dir"
cp manifest.json Calculator.js Panel.qml BarWidget.qml README.md "$plugin_dir/"
omarchy-shell shell rescanPlugins
```

For a **first installation**, also run:

```bash
omarchy plugin enable io.github.BinDecHex.omamath
```

Your current installation is already enabled. Saving files in the installed
plugin directory triggers hot reload; editing the project does not update the
installed copy until you copy it again. A hot reload can clear calculator state.
Back up the installed directory before replacing it if you edited that copy.

If a rescan still reports old code or an old error, use `omarchy restart shell`
to clear the running QML component cache. This was necessary when replacing the
original broken widget on this machine; it briefly restarts the desktop shell.

To open the panel from a terminal:

```bash
omarchy-shell shell summon io.github.BinDecHex.omamath
```

## Check changes

Run the arithmetic and conversion tests with Node.js (no packages needed):

```bash
node tests/calculator.test.cjs
```

In your active Wayland desktop session, run the Quickshell integration check:

```bash
./tests/smoke.sh
```

It creates a temporary configuration with links to Omarchy's `Ui` and `Commons`,
loads the real widget and panel, then exercises the actual text-edit handlers.
It checks conversion updates, cursor preservation, error clearing and fractional
results. It opens no window and does not change your installed shell. It prints
`OMAMATH_SMOKE_OK` on success. This test does not replace checking visible layout,
mouse clicks and keyboard focus in your desktop.

For loading errors, inspect recent shell logs:

```bash
journalctl --user -b --no-pager -n 20 -g 'omamath|Plugin widget'
```

A useful learning sequence is to change the bar label, add a small panel control,
then add an operation in `Calculator.js` with a test. For your next plugin, reuse
the widget/panel structure and give it a new manifest ID and matching module names.
