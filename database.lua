local addon = select(2, ...);

-- Default values for new profiles (only used when creating new profiles)
local defaults = {
    profile = {
        -- Widgets
        widgets = {
            minimap = {
                anchor = "TOPRIGHT",
                posX = 14,
                posY = 14
            },
            player = {
                anchor = "TOPLEFT",
                posX = -19,
                posY = -4
            },
            target = {
                anchor = "TOPLEFT",
                posX = 250,
                posY = -4
            }
        },
        -- Quest Tracker
        questtracker = {
            anchor = "TOPRIGHT",
            x = -140,
            y = -255,
            show_header = false
        },
        -- ACTIONBAR SETTINGS
        mainbars = {
            -- ✅ Cada barra ahora tiene su propia configuración de posición y override.
            player = {
                override = false,
                y_position_offset = 25, -- Offset vertical para el modo automático.
                x = 0,
                y = 0
            },
            left = {
                override = false,
                x = 0,
                y = 0,
                horizontal = false
            },
            right = {
                override = false,
                x = 0,
                y = 0,
                horizontal = false

            },

            -- La escala sigue siendo global para las barras.
            scale_actionbar = 0.9,
            scale_rightbar = 0.9,
            scale_leftbar = 0.9,
            scale_vehicle = 1
        },

        micromenu = {
            -- Legacy/shared settings
            hide_on_vehicle = false,
            bags_collapsed = false,
            grayscale_icons = false,

            -- Grayscale icons configuration
            grayscale = {
                scale_menu = 1.5,
                x_position = 5,
                y_position = -54,
                icon_spacing = 15 -- Gap between icons
            },

            -- Normal colored icons configuration  
            normal = {
                scale_menu = 0.9,
                x_position = -113,
                y_position = -53,
                icon_spacing = 26
            }
        },

        bags = {
            scale = 0.9,
            x_position = 1,
            y_position = 41
        },

        xprepbar = {
            bothbar_offset = 39,
            singlebar_offset = 24,
            nobar_offset = 18,
            repbar_abovexp_offset = 16,
            repbar_offset = 2
        },

        style = {
            gryphons = 'new',
            xpbar = 'new'
        },

        buttons = {
            only_actionbackground = true,
            hide_main_bar_background = false,
            count = {
                show = true
            },
            hotkey = {
                show = true,
                range = true,
                shadow = {0, 0, 0, 1},
                font = {"Fonts\\ARIALN.TTF", 12, "OUTLINE"}
            },
            macros = {
                show = true,
                color = {.67, .80, .93, 1},
                font = {"Fonts\\ARIALN.TTF", 10, "OUTLINE"}
            },
            pages = {
                show = true,
                font = {"Fonts\\ARIALN.TTF", 12, "OUTLINE"}
            },
            cooldown = {
                show = true,
                color = {1, 1, 1, 1},
                min_duration = 3,
                font = {"Fonts\\ARIALN.TTF", 16, "OUTLINE"},
                font_size = 16,
                position = {'CENTER', 0, 1}
            },
            border_color = {1, 1, 1, 1}
        },

        additional = {
            size = 27,
            spacing = 6,
            -- Pretty actionbar compatibility values (hardcoded for optimal positioning)
            leftbar_offset = 90, -- Offset when bottom left is shown (for pretty_actionbar)
            rightbar_offset = 40, -- Offset when bottom right is shown (for pretty_actionbar)
            stance = {
                x_position = -80,
                y_offset = -44 -- Additional Y offset for fine-tuning position
            },
            pet = {
                x_position = -134,
                y_offset = 0, -- Additional Y offset for fine-tuning position
                grid = false -- Disable grid by default (matches original Dragonflight port)
            },
            vehicle = {
                x_position = 0,
                artstyle = true
            },
            totem = {
                x_position = -210,
                y_offset = 0 -- Additional Y offset for fine-tuning position
            }
        },

        -- MINIMAP SETTINGS
        minimap = {
            scale = 0.9,
            border_alpha = 1,
            tracking_icons = true,
            zoom_buttons = true,
            calendar = true,
            clock = true,
            clock_font_size = 12,
            player_arrow_size = 40,
            zonetext_font_size = 12,
            mail_icon_x = -4,
            mail_icon_y = -5,
            addon_button_skin = true,
            addon_button_fade = false
        },

        -- ✅ BUFFS SETTINGS (NUEVO)
        buffs = {
            enabled = true,
            anchor = "TOPRIGHT",
            posX = -260,
            posY = -20,
            show_toggle_button = true,
            position = {
                override = false,
                anchor = "TOPRIGHT",
                anchorParent = "TOPRIGHT",
                x = -260,
                y = -20
            }
        },

        -- CASTBAR SETTINGS
        castbar = {
            enabled = true,
            scale = 1,
            anchorFrame = "UIParent",
            anchor = "BOTTOM",
            anchorParent = "BOTTOM",
            x_position = 0,
            y_position = 230,
            text_mode = "simple",
            precision_time = 1,
            precision_max = 1,
            sizeX = 256,
            sizeY = 16,
            showIcon = false,
            sizeIcon = 27,
            holdTime = 0.3,
            holdTimeInterrupt = 0.8,
            position = {
                override = false,
                anchor = "BOTTOM",
                anchorParent = "BOTTOM",
                x = 256,
                y = 16
            },

            -- TARGET CASTBAR SETTINGS
            target = {
                enabled = true,
                scale = 1,
                x_position = -20,
                y_position = -20,
                text_mode = "simple", -- "simple" (centered spell name only) or "detailed" (name + time)
                precision_time = 1,
                precision_max = 1,
                sizeX = 150,
                sizeY = 10,
                showIcon = true,
                sizeIcon = 20,
                holdTime = 0.3,
                holdTimeInterrupt = 0.8,
                -- AUTO-ADJUST BY AURAS SETTINGS
                autoAdjust = true, -- Enable automatic positioning based on target auras
                anchorFrame = 'TargetFrame',
                anchor = 'TOP',
                anchorParent = 'BOTTOM',
                showTicks = false
            },

            -- FOCUS CASTBAR SETTINGS
            focus = {
                enabled = true,
                scale = 1,
                x_position = -20,
                y_position = -20,
                text_mode = "simple", -- "simple" (centered spell name only) or "detailed" (name + time)
                precision_time = 1,
                precision_max = 1,
                sizeX = 150,
                sizeY = 10,
                showIcon = true,
                sizeIcon = 20,
                holdTime = 0.3,
                holdTimeInterrupt = 0.8,
                -- AUTO-ADJUST BY AURAS SETTINGS
                autoAdjust = true, -- Enable automatic positioning based on focus auras
                anchorFrame = 'FocusFrame',
                anchor = 'TOP',
                anchorParent = 'BOTTOM',
                showTicks = false
            }
        },

        -- CHAT SETTINGS
        chat = {
            enabled = true, -- Por defecto deshabilitado para no interferir con el chat original
            scale = 1.0,
            x_position = 42, -- X relativo a BOTTOM LEFT
            y_position = 35, -- Y relativo a BOTTOM LEFT
            size_x = 295, -- Ancho del chat
            size_y = 120 -- Alto del chat
        },

        -- UNIT FRAMES SETTINGS
        unitframe = {
            player = {
                enabled = true,
                breakUpLargeNumbers = true,
                scale = 1.0,
                classcolor = false,
                healthFormat = "both",
                manaFormat = "both",
                dragon_decoration = "none"
            },
            target = {
                classcolor = false,
                breakUpLargeNumbers = true,
                textFormat = 'both',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                enableNumericThreat = true,
                enableThreatGlow = true,
                scale = 1.0
            },
            focus = {
                classcolor = false,
                breakUpLargeNumbers = true, -- Changed to false - no commas by default
                textFormat = 'both', -- Changed to 'numeric' - Current Value Only by default
                showHealthTextAlways = false, -- true = always visible, false = only on hover
                showManaTextAlways = false, -- true = always visible, false = only on hover
                scale = 0.9,
                override = false,
                anchor = 'TOPLEFT',
                anchorParent = 'TOPLEFT',
                x = 250,
                y = -170
            },
            pet = {
                breakUpLargeNumbers = true,
                textFormat = 'numeric',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                enableThreatGlow = false,
                scale = 1.0,
                override = true,
                anchor = 'TOPRIGHT',
                anchorParent = 'BOTTOMRIGHT',
                x = -1275,
                y = 750
            },
            party = {
                enabled = true,
                classcolor = false,
                textFormat = 'both',
                breakUpLargeNumbers = true,
                showHealthTextAlways = false,
                showManaTextAlways = false,
                orientation = 'vertical',
                padding = 10,
                scale = 1.0,
                override = false,
                anchor = 'TOPLEFT',
                anchorParent = 'TOPLEFT',
                x = 10,
                y = -200
            },
            tot = {
                classcolor = false,
                scale = 1.0,
                x = -30,
                y = -20,
                textFormat = 'numeric',
                breakUpLargeNumbers = false,
                showHealthTextAlways = false,
                showManaTextAlways = false,
                override = false,
                anchor = 'BOTTOMRIGHT',
                anchorParent = 'BOTTOMRIGHT',
                anchorFrame = 'TargetFrame'
            },
            fot = {
                classcolor = false,
                scale = 1.0,
                x = -20,
                y = -20,
                textFormat = 'numeric',
                breakUpLargeNumbers = false,
                showHealthTextAlways = false,
                showManaTextAlways = false,
                override = false,
                anchor = 'BOTTOMRIGHT',
                anchorParent = 'BOTTOMRIGHT',
                anchorFrame = 'FocusFrame'
            }
        }
    }
};

-- Initialize AceDB immediately to ensure it's available for modules
-- This is a temporary placeholder that will be replaced in OnInitialize
addon.db = {
    profile = addon.defaults and addon.defaults.profile or {}
};

-- Function to recursively copy tables  
local function deepCopy(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            end
            deepCopy(value, target[key])
        else
            target[key] = value
        end
    end
end

-- Copy defaults to the temporary profile immediately
if defaults and defaults.profile then
    deepCopy(defaults.profile, addon.db.profile);
end

-- Export defaults for use in core.lua
addon.defaults = defaults;

-- Function to get database values
function addon:GetConfigValue(section, key, subkey)
    if subkey then
        return self.db.profile[section][key][subkey];
    elseif key then
        return self.db.profile[section][key];
    else
        return self.db.profile[section];
    end
end

-- Function to set database values
function addon:SetConfigValue(section, key, subkey, value)
    if subkey then
        self.db.profile[section][key][subkey] = value;
    elseif key then
        self.db.profile[section][key] = value;
    else
        self.db.profile[section] = value;
    end
end
