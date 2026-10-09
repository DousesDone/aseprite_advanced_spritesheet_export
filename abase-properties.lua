-- functions for retrieving and modifying layer properties
local extKey = "annabunches/abase"

local function IsIgnored(layer)
    return layer.properties(extKey).ignored
end

local function IsMerged(layer)
    return layer.isGroup and layer.properties(extKey).merged
end

-- Blurred layers and groups have their own content blurred on export
local function IsBlur(layer)
    return layer.properties(extKey).blur == true
end

local DEFAULT_BLUR_RADIUS = 2
local MAX_BLUR_RADIUS = 16

local function GetBlurRadius(layer)
    local radius = layer.properties(extKey).blurRadius or DEFAULT_BLUR_RADIUS
    return math.max(1, math.min(radius, MAX_BLUR_RADIUS))
end

local function SetIgnored(layer, ignore)
    layer.properties(extKey).ignored = ignore
end

local function SetMerged(layer, merge)
    if not layer.isGroup then return end
    layer.properties(extKey).merged = merge
end

local function SetBlur(layer, blur)
    layer.properties(extKey).blur = blur
end

local function SetBlurRadius(layer, radius)
    layer.properties(extKey).blurRadius = radius
end

local export = {
    extKey = extKey,
    MAX_BLUR_RADIUS = MAX_BLUR_RADIUS,
    IsIgnored = IsIgnored,
    IsMerged = IsMerged,
    IsBlur = IsBlur,
    GetBlurRadius = GetBlurRadius,
    SetIgnored = SetIgnored,
    SetMerged = SetMerged,
    SetBlur = SetBlur,
    SetBlurRadius = SetBlurRadius,
}
return export