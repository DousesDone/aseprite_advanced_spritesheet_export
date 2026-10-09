-- Remembers the Export Sprite Sheet dialog settings per file.
--
-- Advanced exports run the dialog on a temporary copy of the sprite, so the
-- settings Aseprite saves into the copy's document preferences are lost when
-- the copy closes. These functions move them between the copy and the
-- original sprite's properties, which are saved in .aseprite files. The plugin
-- preferences keep a copy keyed by filename for files that can't store
-- properties (.png, ...) or are closed without saving.

local p = require "abase-properties"

-- Options of the document preferences' sprite_sheet section (see Aseprite's
-- data/pref.xml), except `defined`.
local OPTIONS = {
    "type", "columns", "rows", "width", "height",
    "texture_filename", "data_filename", "data_format",
    "filename_format", "tagname_format",
    "border_padding", "shape_padding", "inner_padding",
    "trim_sprite", "trim", "trim_by_grid", "extrude",
    "merge_duplicates", "ignore_empty", "open_generated",
    "layer", "layer_index", "frame_tag",
    "split_layers", "split_tags", "split_grid",
    "list_layers", "list_frame_tags", "list_slices",
}

local preferences = nil

-- Settings of sprites that were never saved, kept for this session only
local unsaved = setmetatable({}, { __mode = "k" })

-- Must be called from init(plugin) so settings persist between sessions.
local function SetPreferences(prefs)
    preferences = prefs
    preferences.exportSettings = preferences.exportSettings or {}
end

local function isSaved(spr)
    return app.fs.filePath(spr.filename) ~= ""
end

-- True if `spr` is saved in a format that stores sprite properties.
local function storesProperties(spr)
    local ext = app.fs.fileExtension(spr.filename):lower()
    return isSaved(spr) and (ext == "aseprite" or ext == "ase")
end

local function sameSettings(a, b)
    if not a or not b then return false end
    for _, option in ipairs(OPTIONS) do
        if a[option] ~= b[option] then return false end
    end
    return true
end

-- The saved settings table for `spr`, or nil.
local function get(spr)
    local stored = spr.properties(p.extKey).exportSettings
    if stored then return stored end
    if isSaved(spr) then
        return preferences and preferences.exportSettings[spr.filename]
    end
    return unsaved[spr]
end

local function set(spr, settings)
    if isSaved(spr) then
        if preferences then
            preferences.exportSettings[spr.filename] = settings
        end
    else
        unsaved[spr] = settings
    end

    if sameSettings(spr.properties(p.extKey).exportSettings, settings) then return end

    -- Property changes don't mark the sprite as modified, so save the file to
    -- keep them, but only if that writes nothing else: with unsaved edits the
    -- settings wait for the user's next save.
    local wasModified = spr.isModified
    spr.properties(p.extKey).exportSettings = settings
    if storesProperties(spr) and not wasModified then
        spr:saveAs(spr.filename)
    end
end

-- Loads the settings remembered for `source` into the export copy `copy`.
-- Returns false if there are none yet.
local function Load(source, copy)
    local settings = get(source)
    if not settings then return false end

    local sheet = app.preferences.document(copy).sprite_sheet
    for _, option in ipairs(OPTIONS) do
        if settings[option] ~= nil then
            sheet[option] = settings[option]
        end
    end
    sheet.defined = true
    return true
end

-- Remembers the settings the export dialog stored in `copy` for `source`.
-- Does nothing if the dialog was cancelled before any export.
local function Save(source, copy)
    local sheet = app.preferences.document(copy).sprite_sheet
    if not sheet.defined then return end

    local settings = {}
    for _, option in ipairs(OPTIONS) do
        settings[option] = sheet[option]
    end
    set(source, settings)
end

local export = {
    SetPreferences = SetPreferences,
    Load = Load,
    Save = Save,
}
return export
