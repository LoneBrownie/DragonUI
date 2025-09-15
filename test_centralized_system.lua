-- =====================================================
-- DRAGONUI CENTRALIZED EDITOR SYSTEM - TEST FILE
-- =====================================================

-- This file contains verification commands to test the new centralized system
-- Copy and paste these commands in-game to test

print("|cFFFFFF00[DragonUI Test]|r Starting centralized editor system verification...")

-- ✅ TEST 1: Verify system is loaded
if addon and addon.EditableFrames then
    print("|cFF00FF00[SUCCESS]|r Centralized system loaded")
else
    print("|cFFFF0000[ERROR]|r Centralized system NOT loaded")
end

-- ✅ TEST 2: Verify player frame is registered
if addon.EditableFrames and addon.EditableFrames["player"] then
    print("|cFF00FF00[SUCCESS]|r Player frame registered:", addon.EditableFrames["player"].name)
else
    print("|cFFFF0000[ERROR]|r Player frame NOT registered")
end

-- ✅ TEST 3: Verify minimap frame is registered  
if addon.EditableFrames and addon.EditableFrames["minimap"] then
    print("|cFF00FF00[SUCCESS]|r Minimap frame registered:", addon.EditableFrames["minimap"].name)
else
    print("|cFFFF0000[ERROR]|r Minimap frame NOT registered")
end

-- ✅ TEST 4: List all registered frames
print("|cFFFFFF00[DragonUI Test]|r Registered editable frames:")
if addon.EditableFrames then
    for name, frameData in pairs(addon.EditableFrames) do
        print("  - " .. name .. " (frame: " .. tostring(frameData.frame and "OK" or "MISSING") .. ")")
    end
end

-- ✅ TEST 5: Verify database widgets
print("|cFFFFFF00[DragonUI Test]|r Database widgets check:")
if addon.db and addon.db.profile.widgets then
    for widgetName, widgetData in pairs(addon.db.profile.widgets) do
        print("  - " .. widgetName .. ": " .. (widgetData.anchor or "NONE") .. " (" .. (widgetData.posX or 0) .. "," .. (widgetData.posY or 0) .. ")")
    end
else
    print("|cFFFF0000[ERROR]|r No widgets found in database")
end

print("|cFFFFFF00[DragonUI Test]|r Test commands:")
print("  /dragonui edit - Toggle editor mode")
print("  /duiedit - Alternative editor toggle")

print("|cFFFFFF00[DragonUI Test]|r Verification complete!")