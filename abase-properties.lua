-- functions for retrieving and modifying layer properties
local extKey = "annabunches/abase"

local function IsIgnored(layer)
    return layer.properties(extKey).ignored
end

local function IsMerged(layer)
    return layer.isGroup and layer.properties(extKey).merged
end

local function SetIgnored(layer, ignore)
    layer.properties(extKey).ignored = ignore
end

local function SetMerged(layer, merge)
    if not layer.isGroup then return end
    layer.properties(extKey).merged = merge
end

local export = {
    extKey = extKey,
    IsIgnored = IsIgnored,
    IsMerged = IsMerged,
    SetIgnored = SetIgnored,
    SetMerged = SetMerged,
}
return export