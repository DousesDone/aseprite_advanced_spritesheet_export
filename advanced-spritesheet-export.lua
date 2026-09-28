local cmd = require "abase-commands"
local listeners = require "abase-listeners"

local function IsLayerSelectionMergable()
    for _, layer in ipairs(app.range.layers) do
        if layer.isGroup then return true end
    end
    return false
end

function init(plugin)
    -- New menu UI elements
    plugin:newMenuSeparator{
        group="layer_popup_merge"
    }

    plugin:newMenuSeparator{
        group="layer_merge"
    }

    plugin:newMenuGroup{
        id="abase_layer_settings",
        title="Advanced Export",
        group="layer_merge",
    }

    plugin:newMenuGroup{
        id="abase_layer_settings_popup",
        title="Advanced Export",
        group="layer_popup_merge",
    }

    -- Menu plumbing for export command
    plugin:newCommand{
        id="ABASEExportSpritesheetAdvanced",
        title="Export Spritesheet (Advanced)",
        group="file_export_1",
        onclick=cmd.ExportSpritesheetAdvanced,
        onenabled=function()
            return app.activeSprite ~= nil
        end,
    }

    plugin:newCommand{
        id="ABASEExportSpritesheetAdvancedReversed",
        title="Export Spritesheet (Advanced, Reversed)",
        group="file_export_1",
        onclick=cmd.ExportSpritesheetAdvancedReversed,
        onenabled=function()
            return app.activeSprite ~= nil
        end,
    }

    -- Menu plumbing for ToggleIgnore
    plugin:newCommand{
        id="ABASEToggleIgnoreLayer",
        title="Toggle Ignore",
        group="abase_layer_settings",
        onclick=cmd.ToggleIgnore,
    }

    plugin:newCommand{
        id="ABASEToggleIgnoreLayerPopup",
        title="Toggle Ignore",
        group="abase_layer_settings_popup",
        onclick=cmd.ToggleIgnore,
    }

    -- Menu plumbing for ToggleExportAsSprite
    plugin:newCommand{
        id="ABASEToggleExportAsSprite",
        title="Toggle Merge Group",
        group="abase_layer_settings",
        onclick=cmd.ToggleExportAsSprite,
        onenabled=IsLayerSelectionMergable,
    }

    plugin:newCommand{
        id="ABASEToggleExportAsSpritePopup",
        title="Toggle Merge Group",
        group="abase_layer_settings_popup",
        onclick=cmd.ToggleExportAsSprite,
        onenabled=IsLayerSelectionMergable,
    }

    -- Menu plumbing for CompareLayers
    local function CanCompare()
        return app.sprite ~= nil and #app.sprite.layers > 0
    end

    plugin:newCommand{
        id="ABASECompareLayers",
        title="Compare Layers...",
        group="abase_layer_settings",
        onclick=cmd.CompareLayers,
        onenabled=CanCompare,
    }

    plugin:newCommand{
        id="ABASECompareLayersLayerPopup",
        title="Compare Layers...",
        group="layer_popup_merge",
        onclick=cmd.CompareLayers,
        onenabled=CanCompare,
    }

    plugin:newCommand{
        id="ABASECompareLayersFramePopup",
        title="Compare Layers...",
        group="frame_popup_reverse",
        onclick=cmd.CompareLayers,
        onenabled=CanCompare,
    }

    plugin:newCommand{
        id="ABASECompareLayersCelPopup",
        title="Compare Layers...",
        group="cel_popup_links",
        onclick=cmd.CompareLayers,
        onenabled=CanCompare,
    }

    -- Event hooks
    app.events:on(
        "aftercommand",
        function(ev)
            if (ev.name == "NewLayer") then
                listeners.RecolorLayers()
            end
        end
    )
end