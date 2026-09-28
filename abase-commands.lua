-- New commands to be executed via Aseprite menus / keyboard shortcuts
local l = require "abase-layer"
local c = require "abase-color"
local p = require "abase-properties"
local cmp = require "abase-compare"

local function ExportSpritesheetAdvanced()
    if not app.sprite then
        return app.alert "Must have a sprite open to export."
    end

    local spr = Sprite(app.sprite)

    l.DeleteLayers(spr, spr.layers)
    l.FlattenLayers(spr.layers)

    app.command.ExportSpriteSheet {
        ui = true,
        splitLayers = true,
    }

    spr:close()
end

local function ExportSpritesheetAdvancedReversed()
    if not app.sprite then
        return app.alert "Must have a sprite open to export."
    end

    local spr = Sprite(app.sprite)

    l.DeleteLayers(spr, spr.layers)
    l.FlattenLayers(spr.layers)
    l.ReverseLayers(spr.layers)

    app.command.ExportSpriteSheet {
        ui = true,
        splitLayers = true,
    }

    spr:close()
end

-- Toggle ignore for all selected layers
local function ToggleIgnore()
    app.transaction("Toggle Ignore", function()
        -- Determine whether we are setting or clearing the flag
        local ignore = false
        for _, layer in ipairs(app.range.layers) do
            if not p.IsIgnored(layer) then
                ignore = true
            end
        end

        for _, layer in ipairs(app.range.layers) do
            p.SetIgnored(layer, ignore)
            c.SetColorFromRoot(layer)
        end
    end)
end

-- Toggle Merge on Export for all selected group layers
local function ToggleExportAsSprite()
    app.transaction("Toggle Merge on Export", function()
        -- Determine whether we are setting or clearing the flag
        local merge = false
        for _, layer in ipairs(app.range.layers) do
            if layer.isGroup and not p.IsMerged(layer) then
                merge = true
            end
        end

        for _, layer in ipairs(app.range.layers) do
            p.SetMerged(layer, merge)
            c.SetColorFromRoot(layer)
        end
    end)
end

-- "Group/Layer" path of a layer, used to tell layers apart in the dialog.
local function layerPath(layer)
    if layer.parent == layer.sprite then
        return layer.name
    end
    return layerPath(layer.parent) .. "/" .. layer.name
end

-- "1-3, 5" style description of a list of frames.
local function describeFrames(frames)
    local parts = {}
    local first, last
    for _, frame in ipairs(frames) do
        local n = frame.frameNumber
        if last and n == last + 1 then
            last = n
        else
            if first then
                table.insert(parts, first == last and tostring(first) or (first .. "-" .. last))
            end
            first, last = n, n
        end
    end
    if first then
        table.insert(parts, first == last and tostring(first) or (first .. "-" .. last))
    end
    return table.concat(parts, ", ")
end

-- Compare two layers on the selected frames and extract the result into a
-- new layer.
local function CompareLayers()
    local spr = app.sprite
    if not spr then
        return app.alert "Must have a sprite open to compare layers."
    end

    local layers = cmp.ComparableLayers(spr.layers)
    if #layers < 2 then
        return app.alert "The sprite needs at least two image layers to compare."
    end

    -- Unique labels for the layer comboboxes
    local labels, byLabel = {}, {}
    for _, layer in ipairs(layers) do
        local label = layerPath(layer)
        local n = 2
        while byLabel[label] do
            label = layerPath(layer) .. " (" .. n .. ")"
            n = n + 1
        end
        table.insert(labels, label)
        byLabel[label] = layer
    end

    -- Default A and B: the first two selected layers (top to bottom), else the
    -- active layer and the one below it.
    local selected = {}
    for _, layer in ipairs(app.range.layers) do
        selected[layer] = true
    end
    local defaults = {}
    for i, layer in ipairs(layers) do
        if selected[layer] and #defaults < 2 then
            table.insert(defaults, i)
        end
    end
    if #defaults < 2 then
        local active = 1
        for i, layer in ipairs(layers) do
            if layer == app.layer then active = i end
        end
        defaults = { active, active < #layers and active + 1 or active - 1 }
    end

    local frames = {}
    for _, frame in ipairs(app.range.frames) do
        table.insert(frames, frame)
    end
    if #frames == 0 then
        frames = { app.frame }
    end

    local operations = {}
    for _, op in ipairs(cmp.OPERATIONS) do
        if not op.rgbOnly or spr.colorMode == ColorMode.RGB then
            table.insert(operations, op.label)
        end
    end

    local PREVIEW_SIZE = 256
    local dlg = Dialog { title = "Compare Layers" }
    -- Preview the current frame when it is part of the selection
    local previewIndex = 1
    for i, frame in ipairs(frames) do
        if frame == app.frame then previewIndex = i end
    end
    local preview = { frame = frames[previewIndex] }

    local function readOptions()
        local data = dlg.data
        return {
            operation = data.operation,
            source = data.source,
            highlight = data.highlight,
            threshold = data.threshold,
            tolerance = data.tolerance,
        }
    end

    -- Recomputes the preview images for the previewed frame and repaints.
    local function refreshPreview()
        local data = dlg.data
        local layerA, layerB = byLabel[data.a], byLabel[data.b]
        local count
        preview.a = cmp.CanvasFor(spr, layerA, preview.frame)
        preview.b = cmp.CanvasFor(spr, layerB, preview.frame)
        preview.result, count = cmp.CompareFrame(spr, layerA, layerB, preview.frame, readOptions())
        dlg:modify { id = "stats", text = count .. " px in frame " .. preview.frame.frameNumber }
        dlg:repaint()
    end

    local function updateVisibility()
        local op = cmp.FindOperation(dlg.data.operation)
        local usesSource = op.id ~= "difference"
        dlg:modify { id = "source", visible = usesSource }
        dlg:modify { id = "highlight", visible = usesSource and dlg.data.source == "Highlight" }
        dlg:modify { id = "threshold", visible = op.id ~= "difference" and spr.colorMode ~= ColorMode.INDEXED }
        dlg:modify { id = "tolerance", visible = (op.id == "changed" or op.id == "difference")
            and spr.colorMode ~= ColorMode.INDEXED }
    end

    local function onOptionChange()
        updateVisibility()
        refreshPreview()
    end

    local function paintPreview(ev)
        local gc = ev.context
        local w, h = gc.width, gc.height

        -- Checkerboard background
        local cell = 8
        for y = 0, h - 1, cell do
            for x = 0, w - 1, cell do
                local light = ((x + y) // cell) % 2 == 0
                gc.color = light and Color { gray = 204 } or Color { gray = 153 }
                gc:fillRect(Rectangle(x, y, cell, cell))
            end
        end

        if not preview.result then return end

        -- Fit the sprite into the canvas, with integer zoom when it is smaller
        local scale = math.min(w / spr.width, h / spr.height)
        if scale >= 1 then scale = math.floor(scale) end
        local dw, dh = math.floor(spr.width * scale), math.floor(spr.height * scale)
        local dst = Rectangle((w - dw) // 2, (h - dh) // 2, dw, dh)
        local src = Rectangle(0, 0, spr.width, spr.height)

        if dlg.data.ghost then
            gc.opacity = 64
            gc:drawImage(preview.b, src, dst)
            gc:drawImage(preview.a, src, dst)
        end
        gc.opacity = 255
        gc:drawImage(preview.result, src, dst)

        gc.color = Color { gray = 64 }
        gc:strokeRect(dst)
    end

    dlg:combobox { id = "a", label = "Layer A", option = labels[defaults[1]], options = labels,
        onchange = onOptionChange }
    dlg:combobox { id = "b", label = "Layer B", option = labels[defaults[2]], options = labels,
        onchange = onOptionChange }
    dlg:button { text = "Swap A/B", onclick = function()
        local a, b = dlg.data.a, dlg.data.b
        dlg:modify { id = "a", option = b }
        dlg:modify { id = "b", option = a }
        refreshPreview()
    end }
    dlg:separator()
    dlg:combobox { id = "operation", label = "Operation", option = operations[1], options = operations,
        onchange = onOptionChange }
    dlg:combobox { id = "source", label = "Color from", option = "A", options = { "A", "B", "Highlight" },
        onchange = onOptionChange }
    dlg:color { id = "highlight", label = "Highlight", color = Color { r = 255, g = 0, b = 255 },
        onchange = refreshPreview }
    dlg:slider { id = "threshold", label = "Min alpha", min = 1, max = 255, value = 1,
        onchange = refreshPreview }
    dlg:slider { id = "tolerance", label = "Tolerance", min = 0, max = 255, value = 0,
        onchange = refreshPreview }
    dlg:separator { text = "Preview" }
    dlg:canvas { id = "preview", width = PREVIEW_SIZE, height = PREVIEW_SIZE, onpaint = paintPreview }
    dlg:check { id = "ghost", text = "Show A and B faded", selected = true,
        onclick = function() dlg:repaint() end }
    if #frames > 1 then
        dlg:slider { id = "previewFrame", label = "Preview frame", min = 1, max = #frames, value = previewIndex,
            onchange = function()
                preview.frame = frames[dlg.data.previewFrame]
                refreshPreview()
            end }
    end
    dlg:label { id = "stats", label = "Result", text = "" }
    dlg:separator()
    dlg:label { label = "Frames", text = describeFrames(frames) }
    dlg:button { id = "ok", text = "&OK", focus = true }
    dlg:button { id = "cancel", text = "&Cancel" }

    updateVisibility()
    refreshPreview()

    -- Canvas onpaint callbacks are ignored until the dialog is shown, and the
    -- canvas is not repainted on open if its size didn't change, so repaint
    -- once the dialog is up.
    local repaintOnOpen
    repaintOnOpen = Timer {
        interval = 0,
        ontick = function()
            repaintOnOpen:stop()
            dlg:repaint()
        end,
    }
    repaintOnOpen:start()
    dlg:show()
    repaintOnOpen:stop()

    local data = dlg.data
    if not data.ok then return end

    local layerA, layerB = byLabel[data.a], byLabel[data.b]
    if layerA == layerB then
        return app.alert "Layer A and Layer B must be different layers."
    end

    app.transaction("Compare Layers", function()
        local options = readOptions()
        local result = cmp.Compare(spr, layerA, layerB, frames, options)
        app.layer = result
    end)
    app.refresh()
end

local export = {
    ExportSpritesheetAdvanced = ExportSpritesheetAdvanced,
    ExportSpritesheetAdvancedReversed = ExportSpritesheetAdvancedReversed,
    ToggleIgnore = ToggleIgnore,
    ToggleExportAsSprite = ToggleExportAsSprite,
    CompareLayers = CompareLayers,
}
return export
