-- Functions for blurring layers on export.
--
-- A blur flag on an image layer blurs that layer's pixels. On a group it blurs
-- every layer exported from the group: the flattened result for a merged group,
-- or each child layer otherwise. A child's own blur flag overrides the amount
-- inherited from its group.

local p = require "abase-properties"

-- Number of box blur passes; three passes approximate a gaussian blur.
local PASSES = 3

-- Gaussian standard deviation, in pixels, per step of the blur amount.
local SIGMA_PER_AMOUNT = 0.5

-- Box radius for each pass: `r` whole pixels plus a fraction `f` of the pixels
-- just beyond them (an "extended box"), so the strength isn't limited to whole
-- pixel radii. Chosen so the passes together match a gaussian of the amount's
-- standard deviation.
local function boxRadius(amount)
    local sigma = amount * SIGMA_PER_AMOUNT
    local v = sigma * sigma / PASSES
    local r = math.floor((math.sqrt(1 + 12 * v) - 1) / 2)
    local f = (v * (2 * r + 1) - r * (r + 1) * (2 * r + 1) / 3) / (2 * (r + 1) ^ 2 - 2 * v)
    return r, f
end

-- One extended box blur pass along one axis of a `w`x`h` array: `n` pixels per
-- line, `lines` lines, `step` between neighbouring pixels and `stride` between
-- lines. Pixels beyond the ends repeat the end pixels.
local function boxPass(src, dst, n, lines, step, stride, r, f)
    local inv = 1 / (2 * r + 1 + 2 * f)
    local last = n - 1
    for line = 0, lines - 1 do
        local base = line * stride + 1
        local first, final = src[base], src[base + last * step]
        local sum = 0
        for i = -r, r do
            if i < 0 then sum = sum + first
            elseif i > last then sum = sum + final
            else sum = sum + src[base + i * step] end
        end
        for i = 0, last do
            local lo, hi = i - r - 1, i + r + 1
            local before = lo < 0 and first or src[base + lo * step]
            local after = hi > last and final or src[base + hi * step]
            dst[base + i * step] = (sum + f * (before + after)) * inv
            local out = i - r
            sum = sum + after - (out < 0 and first or src[base + out * step])
        end
    end
end

local function boxH(src, dst, w, h, r, f) boxPass(src, dst, w, h, 1, w, r, f) end
local function boxV(src, dst, w, h, r, f) boxPass(src, dst, h, w, w, 1, r, f) end

-- How far, in pixels, a blur of `amount` spreads.
local function blurReach(amount)
    local r = boxRadius(amount)
    return PASSES * (r + 1)
end

local floor = math.floor

local function clampByte(v)
    v = floor(v + 0.5)
    if v < 0 then return 0 elseif v > 255 then return 255 end
    return v
end

-- Returns `img` blurred by `amount` (see SIGMA_PER_AMOUNT). Pixels beyond the image edges repeat the
-- edge pixels, so pad the image with transparent pixels to let the blur spread
-- outwards. Only RGB and grayscale images are supported.
local function BlurImage(img, amount)
    local r, f = boxRadius(amount)
    local bpp = img.colorMode == ColorMode.RGB and 4 or 2
    local w, h = img.width, img.height
    local bytes = img.bytes

    -- Premultiplied channels, alpha last
    local channels = {}
    for c = 1, bpp do channels[c] = {} end
    local alpha = channels[bpp]
    for y = 0, h - 1 do
        local start = y * w * bpp + 1
        local row = { bytes:byte(start, start + w * bpp - 1) }
        for x = 0, w - 1 do
            local k = y * w + x + 1
            local a = row[x * bpp + bpp]
            alpha[k] = a
            for c = 1, bpp - 1 do
                channels[c][k] = row[x * bpp + c] * a / 255
            end
        end
    end

    local tmp = {}
    for c = 1, bpp do
        local data = channels[c]
        for pass = 1, PASSES do
            boxH(data, tmp, w, h, r, f)
            boxV(tmp, data, w, h, r, f)
        end
    end

    local rows = {}
    local row = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local k = y * w + x + 1
            local a = alpha[k]
            for c = 1, bpp - 1 do
                row[x * bpp + c] = a > 0 and clampByte(channels[c][k] * 255 / a) or 0
            end
            row[x * bpp + bpp] = clampByte(a)
        end
        rows[y + 1] = string.char(table.unpack(row, 1, w * bpp))
    end

    local result = Image(img.spec)
    result.bytes = table.concat(rows)
    return result
end

-- Blurs every cel of the image layer `layer`, letting the blur spread past the
-- cel bounds but not past the sprite edges.
local function blurLayer(spr, layer, radius)
    -- Linked cels share one image, so blur each image once
    local done = {}
    local results = {}
    for _, cel in ipairs(layer.cels) do
        local key = cel.image.id
        if not done[key] then
            done[key] = true
            local reach = blurReach(radius)
            local area = Rectangle(cel.bounds.x - reach, cel.bounds.y - reach,
                cel.bounds.width + 2 * reach, cel.bounds.height + 2 * reach)
            area = area:intersect(spr.bounds)
            if not area.isEmpty then
                local spec = cel.image.spec
                spec.width, spec.height = area.width, area.height
                local padded = Image(spec)
                padded:drawImage(cel.image, Point(cel.position.x - area.x, cel.position.y - area.y))
                local blurred = BlurImage(padded, radius)
                local rect = blurred:shrinkBounds()
                table.insert(results, { cel = cel, image = Image(blurred, rect),
                    position = Point(area.x + rect.x, area.y + rect.y) })
            end
        end
    end

    for _, r in ipairs(results) do
        r.cel.image = r.image
        r.cel.position = r.position
    end
end

-- Blurs the image layers in `layers` (recursively) that have a blur flag or
-- are inside a group with one. `inherited` is the blur radius of the
-- enclosing group, or nil.
local function blurLayers(spr, layers, inherited)
    for _, layer in ipairs(layers) do
        local radius = p.IsBlur(layer) and p.GetBlurRadius(layer) or inherited
        if layer.isGroup then
            blurLayers(spr, layer.layers, radius)
        elseif radius and layer.isImage and not layer.isTilemap then
            blurLayer(spr, layer, radius)
        end
    end
end

-- Blurs the flagged layers inside merged groups, so they are blurred before
-- the group is flattened. Should be called before FlattenLayers.
local function blurInsideMergedGroups(spr, layers)
    for _, layer in ipairs(layers) do
        if layer.isGroup then
            if p.IsMerged(layer) then
                blurLayers(spr, layer.layers, nil)
            else
                blurInsideMergedGroups(spr, layer.layers)
            end
        end
    end
end

-- Apply the blur flags to the export copy `spr`: ApplyBlurBeforeFlatten before
-- FlattenLayers and ApplyBlurAfterFlatten after it. Both return false for
-- indexed sprites, which can't be blurred.
local function ApplyBlurBeforeFlatten(spr)
    if spr.colorMode == ColorMode.INDEXED then return false end
    blurInsideMergedGroups(spr, spr.layers)
    return true
end

local function ApplyBlurAfterFlatten(spr)
    if spr.colorMode == ColorMode.INDEXED then return false end
    blurLayers(spr, spr.layers, nil)
    return true
end

-- True if any layer in `layers` (recursively) has a blur flag.
local function HasBlur(layers)
    for _, layer in ipairs(layers) do
        if p.IsBlur(layer) or (layer.isGroup and HasBlur(layer.layers)) then
            return true
        end
    end
    return false
end

local export = {
    BlurImage = BlurImage,
    ApplyBlurBeforeFlatten = ApplyBlurBeforeFlatten,
    ApplyBlurAfterFlatten = ApplyBlurAfterFlatten,
    HasBlur = HasBlur,
}
return export
