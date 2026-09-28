-- Functions for comparing two layers pixel by pixel and extracting the result
-- into a new layer.

local pc = app.pixelColor

-- Operations, in the order they appear in the dialog.
-- `keep(hasA, hasB, same)` decides whether a pixel ends up in the result.
local OPERATIONS = {
    { id = "subtract", label = "Subtract (A - B)", symbol = "-",
      keep = function(a, b) return a and not b end },
    { id = "subtract_reverse", label = "Subtract (B - A)", symbol = "-", swap = true,
      keep = function(a, b) return a and not b end },
    { id = "intersect", label = "Intersect (A and B)", symbol = "&",
      keep = function(a, b) return a and b end },
    { id = "xor", label = "Exclude (A xor B)", symbol = "^",
      keep = function(a, b) return a ~= b end },
    { id = "union", label = "Union (A or B)", symbol = "+",
      keep = function(a, b) return a or b end },
    { id = "changed", label = "Changed pixels", symbol = "~",
      keep = function(a, b, same) return (a or b) and not same end },
    { id = "difference", label = "Color difference |A - B|", symbol = "|-|", rgbOnly = true },
}

local function FindOperation(label)
    for _, op in ipairs(OPERATIONS) do
        if op.label == label or op.id == label then return op end
    end
end

-- Alpha (0..255) of a pixel value, according to the image color mode.
local function alphaOf(colorMode, value, transparentIndex)
    if colorMode == ColorMode.RGB then
        return pc.rgbaA(value)
    elseif colorMode == ColorMode.GRAYSCALE then
        return pc.grayaA(value)
    end
    return value == transparentIndex and 0 or 255
end

-- Whether two opaque pixel values are equal within `tolerance` (per channel).
local function isSame(colorMode, a, b, tolerance)
    if a == b then return true end
    if tolerance <= 0 or colorMode == ColorMode.INDEXED then return false end

    if colorMode == ColorMode.RGB then
        return math.abs(pc.rgbaR(a) - pc.rgbaR(b)) <= tolerance
            and math.abs(pc.rgbaG(a) - pc.rgbaG(b)) <= tolerance
            and math.abs(pc.rgbaB(a) - pc.rgbaB(b)) <= tolerance
            and math.abs(pc.rgbaA(a) - pc.rgbaA(b)) <= tolerance
    end
    return math.abs(pc.grayaV(a) - pc.grayaV(b)) <= tolerance
        and math.abs(pc.grayaA(a) - pc.grayaA(b)) <= tolerance
end

-- Pixel value of `color` in the sprite's color mode.
local function pixelOf(spr, color)
    if spr.colorMode == ColorMode.RGB then
        return color.rgbaPixel
    elseif spr.colorMode == ColorMode.GRAYSCALE then
        return color.grayPixel
    end
    return color.index
end

-- The cel of `layer` at `frame`, drawn onto a sprite-sized canvas so that
-- cels with different bounds line up.
local function canvasFor(spr, layer, frame)
    local img = Image(spr.spec)
    local cel = layer:cel(frame)
    if cel then
        img:drawImage(cel.image, cel.position)
    end
    return img
end

-- Returns a sprite-sized image with the result of `op` applied to layers A and
-- B at `frame`, and the number of pixels in the result.
local function compareFrame(spr, layerA, layerB, frame, op, opts)
    local imgA = canvasFor(spr, layerA, frame)
    local imgB = canvasFor(spr, layerB, frame)
    local out = Image(spr.spec)

    local mode = spr.colorMode
    local ti = spr.transparentColor
    local threshold = opts.threshold or 1
    local tolerance = opts.tolerance or 0
    local source = opts.source or "A"
    local highlight = opts.highlight and pixelOf(spr, opts.highlight)
    local count = 0

    for it in out:pixels() do
        local pa = imgA:getPixel(it.x, it.y)
        local pb = imgB:getPixel(it.x, it.y)
        local alphaA = alphaOf(mode, pa, ti)
        local alphaB = alphaOf(mode, pb, ti)

        if op.id == "difference" then
            if alphaA > 0 or alphaB > 0 then
                local r = math.abs(pc.rgbaR(pa) - pc.rgbaR(pb))
                local g = math.abs(pc.rgbaG(pa) - pc.rgbaG(pb))
                local b = math.abs(pc.rgbaB(pa) - pc.rgbaB(pb))
                if r > tolerance or g > tolerance or b > tolerance or alphaA ~= alphaB then
                    it(pc.rgba(r, g, b, math.max(alphaA, alphaB)))
                    count = count + 1
                end
            end
        else
            local hasA = alphaA >= threshold
            local hasB = alphaB >= threshold
            local same = hasA and hasB and isSame(mode, pa, pb, tolerance)

            if op.keep(hasA, hasB, same) then
                count = count + 1
                if source == "Highlight" then
                    it(highlight)
                elseif (source == "A" and hasA) or not hasB then
                    it(pa)
                else
                    it(pb)
                end
            end
        end
    end

    return out, count
end

-- Resolves `opts.operation` and the A/B order it implies.
local function resolve(layerA, layerB, opts)
    local op = opts.operation
    if type(op) ~= "table" then op = FindOperation(op) end
    assert(op, "Unknown operation")

    if op.swap then
        return op, layerB, layerA
    end
    return op, layerA, layerB
end

-- Result of comparing `layerA` and `layerB` at `frame`, without modifying the
-- sprite. Returns a sprite-sized image and the number of pixels in it.
local function CompareFrame(spr, layerA, layerB, frame, opts)
    local op
    op, layerA, layerB = resolve(layerA, layerB, opts)
    return compareFrame(spr, layerA, layerB, frame, op, opts)
end

-- Compares `layerA` and `layerB` on each frame in `frames` and puts the result
-- into a new layer above `layerA`. Returns the new layer.
--
-- opts:
--   operation  one of the OPERATIONS (table, id or label)
--   source     "A", "B" or "Highlight": where kept pixels take their color from
--              when both layers have one (intersect, changed)
--   highlight  Color used when source == "Highlight"
--   threshold  minimum alpha (1..255) for a pixel to count as present
--   tolerance  per-channel difference (0..255) still considered the same color
local function Compare(spr, layerA, layerB, frames, opts)
    local op
    op, layerA, layerB = resolve(layerA, layerB, opts)

    local result = spr:newLayer()
    result.name = layerA.name .. " " .. op.symbol .. " " .. layerB.name
    result.parent = layerA.parent
    result.stackIndex = layerA.stackIndex + 1

    for _, frame in ipairs(frames) do
        local img = compareFrame(spr, layerA, layerB, frame, op, opts)
        local bounds = img:shrinkBounds()
        if not bounds.isEmpty then
            spr:newCel(result, frame, Image(img, bounds), Point(bounds.x, bounds.y))
        end
    end

    return result
end

-- All layers that can be compared (image layers, including those inside
-- groups), from top to bottom as shown in the timeline.
local function ComparableLayers(layers, list)
    list = list or {}
    for i = #layers, 1, -1 do
        local layer = layers[i]
        if layer.isGroup then
            ComparableLayers(layer.layers, list)
        elseif layer.isImage and not layer.isTilemap then
            table.insert(list, layer)
        end
    end
    return list
end

local export = {
    OPERATIONS = OPERATIONS,
    FindOperation = FindOperation,
    Compare = Compare,
    CompareFrame = CompareFrame,
    CanvasFor = canvasFor,
    ComparableLayers = ComparableLayers,
}
return export
