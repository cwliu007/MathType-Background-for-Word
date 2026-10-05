# MathType Background for Microsoft Word

[繁體中文說明](README.zh-TW.md)

> **Windows only.** This project is designed for Microsoft Word on Windows. It is **not intended for macOS, Word for Mac, Word Online, iOS, or Android**.

Unofficial Windows utilities for fixing or customizing the background color of MathType equations in Microsoft Word. **The full Ribbon version can change the background color of existing MathType equations even when MathType itself is not installed on the computer.**

## Problems this solves

This project is intended for people searching for solutions to MathType equation background problems in Microsoft Word, including:

- MathType equation background does not match the Word page
- MathType equations appear with an unwanted white box, gray background, black background, or other mismatched background
- MathType formula background color changes unexpectedly
- Need to force newly inserted MathType equations to a white background automatically
- Need to change MathType equation background colors in Word
- Need to update the background of many MathType equations in an existing document
- Need to recolor existing MathType equations on a Windows PC where MathType is not installed
- MathType equations look wrong when switching Word themes or page background colors
- Need a lightweight MathType background fix without continuous document scanning

Search terms this project is relevant to include **MathType white background**, **MathType equation background color**, **MathType formula background**, **MathType white box in Word**, **MathType dark mode background**, and **Word MathType background fix**.

This repository contains two variants that share the same lightweight insertion-hook design:

- **`wb_v0.0.65.cmd`** — full Ribbon version with selectable colors, light/medium/dark shades, automatic recoloring of the selected MathType equation, and an Update All command.
- **`wb_no_v0.0.13.cmd`** — minimal no-Ribbon version that automatically applies a white background to newly inserted MathType equations.

> **Compatibility note:** **Windows only.** For changing the background of **existing MathType OLE equations**, the full Ribbon version does **not require MathType to be installed**. MathType is only required for features that depend on MathType's own insertion commands, such as automatically processing newly inserted Inline / Display / Right-numbered equations. When that integration is used, the installers are expected to work with MathType 6.9d and nearby earlier releases that retain a compatible Word Ribbon/template structure.

## Why this exists

MathType equations embedded in Word are OLE inline objects. Depending on Word themes, document backgrounds, display rendering, or copied content, an equation may not visually blend with the surrounding page.

These tools add a small post-processing step after MathType inserts an equation so its background can be controlled automatically.

## Core design

Both variants deliberately keep MathType's own insertion logic intact.

The flow is:

```text
MathType Ribbon command
        ↓
wb wrapper callback
        ↓
original MathType callback
        ↓
MathType inserts the equation normally
        ↓
wb locates the newly inserted MathType OLE object
        ↓
background is applied
```

The installer does **not** rewrite the MathType VBA project. It patches compatible MathType Ribbon XML callbacks and places the wb VBA code in a separate Word global template.

Before and after patching, the installer verifies that MathType's `vbaProject.bin` and VBA signature streams remain unchanged.

## How the new equation is located

Before MathType is called, the current Word insertion position is recorded as an **anchor**.

After MathType returns:

1. If Word directly exposes the inserted equation as the current inline-shape selection, that object can be used immediately.
2. Otherwise, wb examines only a small local area: the current paragraph plus the previous and next paragraph.
3. It filters the inline shapes to MathType OLE objects.
4. It selects the MathType object whose position is nearest to the original insertion anchor.

This is useful because typical MathType behavior is:

- **Inline equation:** the cursor ends just to the right of the inserted equation.
- **Display equation:** the cursor ends at the beginning of the following line.
- **Right-numbered display equation:** the cursor also ends at the beginning of the following line.

The local previous/current/next-paragraph search therefore covers these normal insertion patterns without scanning the whole document.

## Variants

| Feature | `wb_no_v0.0.13` | `wb_v0.0.65` |
|---|---:|---:|
| Automatic white background after insertion | Yes | Yes |
| MathType Inline / Display / Right-numbered insertion hooks | Yes | Yes |
| Additional Ribbon UI | No | Yes |
| Background color selection | No | Yes |
| Light / Medium / Dark shades | No | Yes |
| No Background option | No | Yes |
| Auto-apply selected color when clicking one MathType equation | No | Yes |
| Update all equations in the document | No | Yes |
| Change existing MathType equation backgrounds without MathType installed | No | Yes |
| `WindowSelectionChange` handler | No | Yes, lightweight |
| Timer / polling | No | No |
| Continuous document scanning | No | No |

### Minimal version: `wb_no_v0.0.13.cmd`

This is the smallest and lowest-overhead version.

It is dormant during normal Word use. The code runs only when one of the hooked MathType insertion commands is used.

It does not install a timer, polling loop, `SelectionChange` handler, or background document scanner.

A compatible MathType Word template is required because this version hooks MathType's existing Ribbon insertion callbacks directly.

### Full Ribbon version: `wb_v0.0.65.cmd`

This version adds an equation-background Ribbon UI with:

- Update All
- Background color selector
- White, Gray, Beige, Yellow, Blue, Green, Pink, and No Background
- Light / Medium / Dark shades
- Automatic application of the currently selected background when a single MathType equation is selected
- Dynamic Traditional Chinese / English Ribbon labels according to the current Word UI language

Its `WindowSelectionChange` handler is intentionally lightweight. Ordinary text selections exit immediately; there is no timer, polling loop, paragraph scan, or document-wide scan in the selection handler.

If MathType is not installed, or if no verified-compatible MathType Ribbon is found, the full version can install its background controls as a standalone Word Ribbon. In that mode, it can still change the background color of existing MathType OLE equations already present in Word documents. What is unavailable without MathType is the automatic hook into MathType's own equation-insertion commands.

## Resource usage

### `wb_no`

Normal Word use: effectively dormant.

It performs work only when a hooked MathType equation insertion command completes, and the fallback search is limited to a very small local range.

### `wb_v`

Also very lightweight. Word raises one `WindowSelectionChange` event when the selection changes, but ordinary text selections exit after a few checks.

A whole-document scan occurs only when **Update All** is explicitly pressed.

Neither variant uses a background timer or polling loop.

## Installation

1. Close Microsoft Word. The installer can also force-close Word when necessary.
2. Run the desired `.cmd` file.
3. Accept the Windows UAC prompt when requested.
4. The installer detects the current Word Startup path and compatible MathType template locations dynamically.
5. When installation succeeds, the installer offers to restore immediately. The default is **No**; if no response is given within 15 seconds, the installation is kept and the CMD window closes.

The launchers use a temporary local staging copy before UAC elevation. This avoids known reliability problems when the original installer is launched from OneDrive or another synchronized folder. The original file can remain in OneDrive; the staging copy is temporary.

## Switching between the two variants

The installers are mutually exclusive.

- Installing `wb_v` detects and safely removes an installed `wb_no` variant first.
- Installing `wb_no` detects and safely removes an installed `wb_v` variant first.

The switch is performed only when the existing MathType backup and VBA integrity checks are safe.

## Restore

Each installer supports a restore mode:

```cmd
wb_v0.0.65.cmd restore
```

or

```cmd
wb_no_v0.0.13.cmd restore
```

Restore returns the patched MathType template to its pristine backup when applicable and removes the wb Word global add-in.

## Compatibility notes

The installers dynamically inspect the current Word Startup path, Word installation directory, registry information, Program Files / Program Files (x86), and available `Office*` locations rather than relying only on a single hard-coded Office directory.

The MathType Ribbon is modified only when its structure contains the verified callbacks required by the hook. An unfamiliar MathType structure is not blindly patched.

Expected compatibility range:

- **Windows only**
- Windows 10 / Windows 11
- Microsoft Word 16.x family (including Office 2021 / Microsoft 365 style installations)
- For editing backgrounds of existing MathType OLE equations with the full Ribbon version: **MathType does not need to be installed**
- For automatic processing of newly inserted MathType equations: MathType 6.9d and nearby earlier releases are expected to work when the Word Ribbon/template structure is compatible

Compatibility with other MathType releases matters only for the MathType insertion-hook features and depends on whether the expected Ribbon callbacks and template structure are present.

This project does **not** support Word for Mac or other non-Windows versions of Word.

## Safety notes

- Save open Word documents before running an installer; Word may be force-closed during installation or restore.
- The installer maintains a `.wb_original` pristine backup before patching a MathType template.
- MathType VBA integrity is checked before replacement of the patched package.
- These tools are unofficial and are not affiliated with or endorsed by Wiris / MathType or Microsoft.

## Files

- [`installers/wb_v0.0.65.cmd`](installers/wb_v0.0.65.cmd) — full Ribbon version
- [`installers/wb_no_v0.0.13.cmd`](installers/wb_no_v0.0.13.cmd) — minimal white-background version