# Ande Currency Info

A World of Warcraft addon that shows the currencies you care about in a small movable frame, with formatting you control.

## Features

- Track any currency and show it with an icon, a label and a format of your choice
- Pick currencies from a searchable list instead of looking up IDs
- Presets such as `Current / Max`, `Weekly Progress` and `Percentage`, or write your own template
- Cap handling per currency: change the text color or hide the currency once it is capped
- Per-currency text color
- `+150` / `-20` gain and loss text when a value changes
- Column or row layout, left or right alignment, font, sizes, spacing, scale and background opacity
- Hide in combat, hide while the Currency tab is open, or fade when the mouse is away
- Drag to reorder, drag to move the frame, lock it in place
- Opens with a right-click on the frame, `/ci`, the minimap button, the Addon Compartment button, or Esc > Options > AddOns

## Installation

Copy the `CurrencyInfo` folder (the folder name stays `CurrencyInfo`, even though the addon is called Ande Currency Info) into `World of Warcraft/_retail_/Interface/AddOns/` and restart the game or `/reload`.

[LibSharedMedia-3.0](https://www.curseforge.com/wow/addons/libsharedmedia-3-0) is optional. If another addon loads it, its fonts appear in the font dropdown.

## Getting started

1. Right-click the frame, or type `/ci`, to open settings.
2. Click **Browse list...** and click the currencies you want. You can also type an ID and press **Add**, or click **Add all capped** to start with every currency that has a maximum.
3. Adjust the format, label and look in the settings window.

Dragging the frame moves it. Right-clicking it opens settings. The minimap button opens settings with a left-click and shows or hides the display with a right-click. You can drag it around the minimap, or hide it in the display settings or with `/ci minimap`.

## Settings

### Tracked currencies

Each row has:

| Column | What it does |
| --- | --- |
| Grip | Drag to reorder |
| Format | Choose a preset or `Custom` |
| Custom | The template. Shows the preset's template greyed out, and becomes editable when the format is `Custom` |
| Preview | What the display will show |
| Icon | Show or hide the icon |
| Hide name | Drop the currency name from the text. Presets only, so it is disabled for `Custom` |
| Gear | Text color and cap behaviour (see below) |

### Templates

Pick `Custom` in the Format column to edit the template. It starts from the preset you were using. Write any text you like around the tokens, for example to rename a currency or hide its name. The box turns red if it contains a token that does not exist.

| Token | Value |
| --- | --- |
| `{label}` | Currency name |
| `{current}` | Current quantity |
| `{max}` | Maximum quantity |
| `{earned}` | Total earned |
| `{left}` | Left to earn (max - earned) |
| `{weekly}` | Earned this week |
| `{weeklycap}` | Weekly cap |
| `{pct}` | Current / max as a percentage |

Examples: `{label}: {current} ({weekly}/{weeklycap} this week)` or `Valor: {current} / {max}`

### Cap behaviour

Open a row's gear button to choose what happens when a currency is capped:

- **Do nothing**
- **Change color**: the text switches to the cap color (green by default, so a capped currency does not look like an error)
- **Hide currency**: the currency disappears once capped

**Capped at** sets the percentage that counts as capped, from 50% to 100%. Progress is the highest of current / max (or total earned / max for seasonal caps) and weekly earned / weekly cap.

### Display settings

Layout, alignment, font, font size, icon size, spacing, scale, background opacity and padding, plus toggles for background, lock position, show display, gain/loss text, hide in combat, hide on Currency tab, fade when not hovered and the minimap icon. **Reset to defaults** restores layout, visibility rules and the accent color. It keeps your tracked currencies and the frame position.

The accent color of the settings window can be changed with the swatch in its header.

## Slash commands

| Command | Action |
| --- | --- |
| `/ci` | Open settings |
| `/ci browse` | Open the currency list |
| `/ci add <id, name or link>` | Track a currency |
| `/ci remove <id, name or link>` | Stop tracking a currency |
| `/ci list` | List tracked currencies |
| `/ci show`, `hide`, `toggle` | Show or hide the display |
| `/ci minimap` | Show or hide the minimap button |
| `/ci lock` | Lock or unlock the frame |
| `/ci reset` | Move the frame back to the center of the screen |

`/aci` and `/currencyinfo` work as well, for example `/aci browse`.

## Notes

- The currency list only includes currencies your character has discovered. Use the ID box for any others.
- Settings are saved account-wide in the `CurrencyInfoDB` saved variable.
