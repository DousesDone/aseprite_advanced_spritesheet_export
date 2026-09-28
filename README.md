# Advanced Spritesheet Export

This is a fork of the original Advanced Spritesheet Export, available at [Advanced Spritesheet Export by annabunches](https://annabunches.itch.io/advanced-spritesheet-export). Focused on updating the API for Aseprite 1.3 and fixing the correct export of visible layers.

[![Image 1](https://img.itch.zone/aW1nLzE3MTcwODE2LnBuZw==/347x500/vc8hmw.png)](https://img.itch.zone/aW1nLzE3MTcwODE2LnBuZw==/original/Y1PwYA.png)

## Description

Do you make spritesheets with Aseprite?

Are you annoyed when you have to toggle visibility on all your layers every time you want to export a spritesheet?

Are you tired of having to flatten layer groups down if you want them to be exported as a single sprite in the sheet?

Then Advanced Spritesheet Export is for you! This extension allows you to customize exactly how your Aseprite layers get exported into a spritesheet, without having to make temporary modifications to your layers before every export. Just configure the Advanced Export settings for layers and groups once, and get a perfect export every time.

## Features

*   Export layers regardless of visibility. (layers and groups can instead be explicitly ignored)
*   Selectively export layer groups as single sprites without modifying or flattening the groups.
*   Configure layer settings via Layer menu, right click menu, or keyboard shortcut.
*   Modify settings for multiple selected layers at once.
*   Compare two layers on the selected frames and extract the result (subtract, intersect, exclude, union, changed pixels, color difference) into a new layer.

## Usage

*   All layers are exported by default. To ignore the active layer or group, select Layer -> Advanced Export -> Toggle Ignore.
*   To export a layer group as a single sprite, select Layer -> Advanced Export -> Toggle Merge Group.
*   Invoke the tool via File -> Export -> Export Sprite Sheet (Advanced).
*   To compare layers, select the layers and/or frames in the timeline, right click a layer, frame or cel and choose Compare Layers... (also under Layer -> Advanced Export). Pick layers A and B and an operation, check the live preview, and the result is created as a new layer above A, only on the selected frames.

### Compare operations

| Operation | Result contains |
| --- | --- |
| Subtract (A - B) / (B - A) | Pixels of one layer that are not covered by the other |
| Intersect (A and B) | Pixels present in both layers |
| Exclude (A xor B) | Pixels present in exactly one layer |
| Union (A or B) | Pixels present in either layer |
| Changed pixels | Pixels whose color differs between A and B (within the tolerance) |
| Color difference \|A - B\| | Per-channel absolute difference (RGB sprites only) |

"Color from" picks whether kept pixels use A's color, B's color or a single highlight color. "Min alpha" sets how opaque a pixel must be to count as present, and "Tolerance" lets small color differences count as equal.

### Keyboard Shortcuts

All of the Aseprite commands are available as keyboard shortcuts as well:

| Command | Shortcut (Windows/Linux) | Shortcut (MacOS) |
| --- | --- | --- |
| Toggle Ignore Layer(s) | Ctrl+Alt+I | Cmd+Ctrl+I |
| Toggle Merge Group(s) | Ctrl+Alt+M | Cmd+Ctrl+M |
| Export Spritesheet (Advanced) | Ctrl+Alt+E | Cmd+Ctrl+E |

### Additional Notes

*   Ignored layers always take precedence over merging; if a sublayer in a group is ignored, it will not be merged into the final sprite.
*   Toggling the advanced export settings on a layer will modify the layer colors. The extension will attempt to detect and preserve user-colored layers. If you happen to use one of the exact colors we have chosen, this will fail. We have chosen odd alpha values to reduce the likelihood of a false negative, but if you are using layer colors extensively, this extension may not work well for you.
*   To force a layer's color to be controlled by the extension, simply reset the layer's color to all 0 values. (red, green, blue, and alpha should all be 0) You may need to toggle the export settings of a parent layer or create a new layer before the changes take effect.

