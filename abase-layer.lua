-- Functions for modifying layers recursively based on configuration flags

local p = require "abase-properties"

-- Deletes any layers with the 'ignored' property, and any hidden layers.
local function DeleteLayers(spr, layers)
    local to_delete = {}
    
    local function collect(lyrs)
        for _, layer in ipairs(lyrs) do
            if p.IsIgnored(layer) or not layer.isVisible then
                table.insert(to_delete, layer)
            elseif layer.isGroup then
                collect(layer.layers)
            end
        end
    end
    
    collect(layers)
    
    for _, layer in ipairs(to_delete) do
        spr:deleteLayer(layer)
    end
end

-- Flattens any layers that have the 'exportedAsSprite' property.
-- Should be called after deleteLayers.
local function FlattenLayers(layers)
    local to_flatten = {}
    
    local function collect(lyrs)
        for _, layer in ipairs(lyrs) do
            if not layer.isGroup then
                goto continue
            end

            if p.IsMerged(layer) then
                table.insert(to_flatten, layer)
            else
                collect(layer.layers)
            end

            ::continue::
        end
    end
    
    collect(layers)
    
    for _, layer in ipairs(to_flatten) do
        local name = layer.name
        app.range.layers = {layer}
        app.command.FlattenLayers { visibleOnly = false }
        if app.layer then
            app.layer.name = name
        end
    end
end

local function ReverseLayers(layers)
    local reordered = {}
    for _, layer in ipairs(layers) do
        table.insert(reordered, layer)
    end

    local count = #reordered
    for index, layer in ipairs(reordered) do
        layer.stackIndex = count - index + 1
    end

    for _, layer in ipairs(reordered) do
        if layer.isGroup then
            ReverseLayers(layer.layers)
        end
    end
end

local function RevealLayers(layers)
    for _, layer in ipairs(layers) do
        if layer.isGroup then
            RevealLayers(layer.layers)
        end

        if not layer.isVisible then
            layer.isVisible = true
        end
    end
end

local export = {
    DeleteLayers = DeleteLayers,
    FlattenLayers = FlattenLayers,
    RevealLayers = RevealLayers,
    ReverseLayers = ReverseLayers,
}
return export