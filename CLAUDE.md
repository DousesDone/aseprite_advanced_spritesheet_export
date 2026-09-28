# CLAUDE.md

Aseprite extension (Lua) forked from annabunches' "Advanced Spritesheet Export", updated for Aseprite 1.3. It exports spritesheets with per-layer ignore/merge settings stored in layer properties, without the user having to toggle visibility or flatten groups by hand.

## Layout

- `package.json`: extension manifest. `contributes.scripts` points at the entry script, `contributes.keys` at the shortcuts file.
- `advanced-spritesheet-export.lua`: entry point. `init(plugin)` registers menu groups and commands (`plugin:newCommand`) and the `aftercommand` listener. It holds only menu plumbing, not logic.
- `abase-commands.lua`: the command handlers invoked from menus and shortcuts.
- `abase-layer.lua`: recursive layer operations (delete ignored/hidden, flatten merged groups, reverse order).
- `abase-properties.lua`: reads and writes extension flags via `layer.properties("annabunches/abase")`. Keep this key as it is, because existing `.aseprite` files depend on it.
- `abase-color.lua`: sets layer colors to show ignore/merge state, and leaves user-chosen colors alone.
- `abase-compare.lua`: pixel-by-pixel layer comparison (subtract, intersect, xor, union, changed, color difference). `Compare()` is UI-free and can be tested headless; the dialog lives in `abase-commands.lua`.
- `abase-listeners.lua`: event handlers.
- `advanced-spritesheet-export.aseprite-keys`: default shortcuts, keyed by command `id`.

Modules use `local x = require "abase-..."` and end with `local export = {...} return export`. New modules should use the `abase-` prefix and the same pattern. Functions use PascalCase and locals use snake_case or camelCase, matching the existing files.

## Conventions

- Export commands never modify the user's sprite. They work on a copy (`local spr = Sprite(app.sprite)`), change it, run `app.command.ExportSpriteSheet`, and then `spr:close()`.
- Wrap edits to the user's document in `app.transaction("Name", function() ... end)` so they undo in one step.
- Collect layers first and mutate them afterwards. Deleting or flattening while iterating `layer.layers` skips entries.
- `app.command.*` acts on the current selection, so set `app.range.layers = {layer}` before calling commands such as `FlattenLayers`.
- Any command id added to `.aseprite-keys` must match an id passed to `plugin:newCommand`.

## Running / testing

There is no build step and no test suite. The installed Aseprite is `aseprite` (1.x-dev, API version 39).

- **Headless checks:** `aseprite -b --script file.lua` runs Lua with the full `app` API and no UI, and `print()` writes to stdout. Use it to check API behaviour and pure image logic. UI commands and dialogs don't work in batch mode (`Dialog` is `nil`). Put throwaway scripts in the scratchpad, not in the repo.
- **Installing for manual testing:** the extension is installed as a copied folder (not a symlink) at `~/.config/aseprite/extensions/advanced-spritesheet/`. Copy the changed `.lua`/`.json`/`.aseprite-keys` files there and restart Aseprite. Otherwise, zip the repo files, rename the zip to `.aseprite-extension`, and install it through Edit → Preferences → Extensions.
- API reference: https://www.aseprite.org/api/

## Aseprite API gotchas (verified on API 39)

- A missing field on an Aseprite userdata object throws an error rather than returning `nil`. Test for the root layer with `layer.parent == layer.sprite`.
- `Image:drawImage(src, pos, opacity, blendMode)` accepts the Porter-Duff `BlendMode`s (`SRC_IN`, `DST_OUT`, `XOR`, ...) but draws them like `NORMAL`, so they can't be used for masking. `SUBTRACT` and `DIFFERENCE` operate on colour channels, not alpha.
- Pixel values depend on the colour mode. RGB uses `app.pixelColor.rgbaA(v)`, grayscale uses `grayaA(v)`, and indexed values are palette indices where transparent means `v == sprite.transparentColor`. Tilemap layers store tile indices, not pixels.
- A cel image covers only the cel's bounds. Before comparing cels, draw them onto a sprite-sized canvas with `Image(spr.spec)` and `img:drawImage(cel.image, cel.position)`.
- To trim an image, use `img:shrinkBounds()`, which returns an empty rect if the image is fully transparent, then `Image(img, rect)`, and create the cel at `Point(rect.x, rect.y)`.
- Speed: an `img:pixels()` loop over 512×512 pixels takes about 30 ms, and a scan of the `img.bytes` string takes about 15 ms.
- `Dialog:canvas` `onpaint` is not called before `dlg:show()`, and `dlg:modify` before showing already sizes the canvas, so it is not repainted on open. Repaint from a zero-interval `Timer` started just before `dlg:show()`.
