# GRUB Theme for DankMaterialShell

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) plugin that paints the GRUB boot menu in the Material You colors DMS takes from the wallpaper, and repaints it every time the wallpaper changes. Wallpaper cycling included: with a new wallpaper every half hour, the next boot shows the colors of the last one.

The theme is deliberately quiet: the surface color with a soft glow of the primary container behind the menu, Inter, a fully rounded highlight on the selected entry, the host name above the menu, the countdown and key hints below. It always uses the dark variant of the palette, since GRUB runs before anything else lights the screen.

## How it works

DMS writes the palette it generates with matugen to `~/.cache/DankMaterialShell/dms-colors.json`. The plugin watches that file. When the colors change, it waits for matugen to finish and hands seven color roles, the screen size and two labels to a helper:

```
dms-grub-theme apply --size auto --fade surface=#111318 primary_container=#224876 …
```

The helper draws the background and the highlight with Pillow, writes `theme.txt` and swaps the new theme into `/boot/grub/themes/dms` in one rename, so GRUB never finds half a theme. Fonts are made once at install time with `grub-mkfont` (Inter if installed, otherwise the default sans-serif font), covering Latin, Cyrillic and Greek.

`grub.cfg` only needs regenerating when the screen size or the timeout changes. The helper then writes `/etc/default/grub.d/90-dms-grub-theme.cfg` (visible menu, timeout, resolution, theme) and runs `update-grub`. A new palette is just a few small files in `/boot`.

`/boot` belongs to root. The helper is installed with a polkit action that lets the **active local session** run it without a password, so wallpaper changes don't ask for anything. It accepts only `#RRGGBB` colors for known roles, a size, a timeout from 0 to 30 seconds and two labels stripped of quotes, and it writes nowhere but the theme directory and its drop-in.

GRUB's own `GRUB_GFXMODE=auto` falls back to 800×600 when the screen reports a native mode 4096 pixels wide or more, which ultrawide and 5K screens do. So by default the plugin asks for 2560×1440, then 1920×1080, the modes nearly every firmware offers, and draws the layout and the fonts for 1440p; a mode you pick gets them for its own height (1080p, 1440p or 2160p). Firmware often can't drive very wide or 4K screens at their full size and shows GRUB in a box with black bars around it. With **Fade the sides to black** (on by default) the picture eases into pure black on the left and right, so the bars blend in instead of framing a hard-edged rectangle; the top and bottom keep the full color.

## Requirements

- DMS 2.0.0 or newer
- GRUB with `/etc/grub.d` and `update-grub` (Debian, Ubuntu and their derivatives)
- `python3-pil`, `grub-mkfont` (grub-common), polkit (`pkexec`)
- Optional: Inter (`fonts-inter-variable`) for the intended look

## Installation

### From a registry

In DMS Settings → Plugins, add the registry `https://github.com/ilyamen/dms-plugin-registry.git`. Then install **GRUB Theme** from Browse, or run:

```sh
dms plugins install grubTheme
```

### Manually

```sh
git clone https://github.com/ilyamen/dms-grub-theme ~/.config/DankMaterialShell/plugins/grubTheme
```

Enable the plugin in Settings → Plugins and open its settings. Press **Install helper** and enter your password once. The theme is drawn right away, and the settings page shows its colors and when it was drawn.

## Settings

- **Resolution**: Auto, or the size of one of the connected screens if the firmware can drive it in GRUB. Screens taller than 1080 lines are also offered at 1080 lines in their own shape, such as 3840×1080 for a 5120×1440 ultrawide: firmware that can't drive the full size often can that one, and the screen fills it edge to edge. To see the modes the firmware has, press C in the menu and type `videoinfo`.
- **Fade the sides to black**: for wide screens where the firmware leaves black bars beside the menu.
- **Follow the wallpaper**: repaint on every new palette. Off keeps the current colors.
- **Menu timeout**: 1 to 10 seconds.
- **Repaint now**: draw the theme again, for example after connecting a bigger screen.

## Command line

```sh
dms ipc call grubTheme apply      # repaint now
dms ipc call grubTheme status     # JSON: helper, applied palette, GRUB settings
```

## Works well with

[Dual Boot](https://github.com/ilyamen/dms-dual-boot), which adds a Windows entry to the same menu that starts Windows through EFI BootNext, so BitLocker doesn't ask for the recovery key.

## Removal

Press **Remove helper and theme** in the plugin settings, or run `sudo sh system/install.sh uninstall`. That deletes the theme, its fonts and the drop-in and runs `update-grub`, which brings back the distribution's own menu settings.

## License

MIT
