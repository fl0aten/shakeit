-- ShakeIt - Screen shake on critical hits
-- WoW Classic Era

ShakeIt = ShakeIt or {}
ShakeIt.lastShakeTime = 0

-- Configuration
local INTENSITY = 5
local DURATION = 200
local COOLDOWN = 300

-- Shake state
local shakeableFrames = {}
local isShaking = false
local shakeFrame = nil
local isScanning = false
local scanScheduled = false

-- Shake a single frame by name
local function shakeSingleFrame(frameName)
    local targetFrame = _G[frameName]
    if not targetFrame then
        print("|cFFF56900[ShakeIt]|r Frame '" .. frameName .. "' not found!")
        return
    end

    local success, isProtected = pcall(function()
        return targetFrame:IsProtected()
    end)

    if success and isProtected then
        print("|cFFF56900[ShakeIt]|r Frame '" .. frameName .. "' is protected and cannot be shaken!")
        return
    end

    local hasPoint = false
    pcall(function()
        hasPoint = targetFrame:GetPoint(1) ~= nil
    end)

    if not hasPoint then
        print("|cFFF56900[ShakeIt]|r Frame '" .. frameName .. "' has no anchor point!")
        return
    end

    isShaking = true
    local updateInterval = 0.02

    -- Collect all anchor points to preserve frame structure
    local originalPositions = {}
    for i = 1, 6 do  -- WoW frames can have up to 6 anchor points
        local success, point, relativeTo, relativePoint, x, y = pcall(function()
            return targetFrame:GetPoint(i)
        end)
        if success and point then
            table.insert(originalPositions, {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y
            })
        else
            break  -- No more anchors
        end
    end

    if #originalPositions == 0 then
        print("|cFFF56900[ShakeIt]|r Could not get frame positions!")
        isShaking = false
        return
    end

    -- Mark as user-placed to prevent WoW from interfering (e.g. PlayerFrame animations)
    local wasUserPlaced = false
    pcall(function()
        wasUserPlaced = targetFrame:IsUserPlaced()
        targetFrame:SetUserPlaced(true)
    end)

    if not shakeFrame then
        shakeFrame = CreateFrame("Frame")
        shakeFrame:Hide()
    end

    shakeFrame:Show()

    local remainingDuration = DURATION / 1000
    local elapsedTime = 0
    local currentStep = 0

    shakeFrame:SetScript("OnUpdate", function(self, elapsed)
        elapsedTime = elapsedTime + elapsed

        while elapsedTime >= updateInterval do
            elapsedTime = elapsedTime - updateInterval
            remainingDuration = remainingDuration - updateInterval

            if remainingDuration > 0 then
                currentStep = currentStep + 1
                local maxOffset = 101 - INTENSITY - (currentStep - 1)
                local randomX = math.random(-100, 100) / maxOffset * 3
                local randomY = math.random(-100, 100) / maxOffset * 3

                pcall(function()
                    targetFrame:ClearAllPoints()
                    -- Restore all original anchors with offset applied to first one
                    for i, anchor in ipairs(originalPositions) do
                        local offsetX, offsetY = anchor.x, anchor.y
                        if i == 1 then  -- Only offset the first anchor
                            offsetX = offsetX + randomX
                            offsetY = offsetY + randomY
                        end
                        targetFrame:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, offsetX, offsetY)
                    end
                end)
            else
                pcall(function()
                    targetFrame:ClearAllPoints()
                    -- Restore all original anchors
                    for _, anchor in ipairs(originalPositions) do
                        targetFrame:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y)
                    end
                    if not wasUserPlaced then
                        targetFrame:SetUserPlaced(false)
                    end
                end)

                shakeFrame:Hide()
                shakeFrame:SetScript("OnUpdate", nil)
                isShaking = false
                print("|cFFF56900[ShakeIt]|r Shook frame '" .. frameName .. "'!")
                return
            end
        end
    end)
end

-- Scan for unprotected frames (only those with protected parent)
local function scanUnprotectedFrames()
    shakeableFrames = {}
    local foundFrames = {}
    local visited = {}

    local function scanFrame(frame, parentIsProtected, depth)
        if type(frame) ~= "table" or not frame.GetObjectType then
            return
        end

        local pointer = tostring(frame)
        if visited[pointer] then
            return
        end
        visited[pointer] = true

        local isProtected = false
        local hasPoint = false
        local name = "(unnamed)"

        pcall(function()
            isProtected = frame:IsProtected()
        end)
        pcall(function()
            hasPoint = frame:GetPoint(1) ~= nil
        end)
        pcall(function()
            name = frame:GetName() or "(unnamed)"
        end)

        -- Skip frames with special movement/docking logic
        local skipFrame = false
        local isUnitFrame = false
        local hasDynamicPosition = false
        local isAddonFrame = false
        local frameType = ""

        pcall(function()
            isUnitFrame = frame.unit ~= nil
        end)
        -- Frames with dynamic position calculation (CompactRaidFrameManager, etc.)
        pcall(function()
            hasDynamicPosition = frame.dynamicContainerPosition ~= nil
        end)
        -- AddOn-created frames with hex suffix (e.g., "Minimap.24e7df2ce30")
        pcall(function()
            isAddonFrame = string.match(name, "%.%x%x%x%x%x%x%x%x%x$") ~= nil
        end)
        pcall(function()
            frameType = frame:GetObjectType()
        end)

        -- Skip special frame types that have their own positioning logic
        if frameType == "ScrollingMessageFrame" or frameType == "EditBox" or hasDynamicPosition or isAddonFrame then
            skipFrame = true
        else
            skipFrame = isUnitFrame
        end

        if skipFrame then
            -- Skip this frame AND don't recurse into children
            return
        end

        -- Check if frame is anchored to UIParent (even if parent isn't protected)
        local anchoredToUIParent = false
        pcall(function()
            local _, relTo = frame:GetPoint(1)
            anchoredToUIParent = (relTo == UIParent)
        end)

        if not isProtected and hasPoint and (parentIsProtected or anchoredToUIParent) then
            table.insert(foundFrames, {frame = frame, name = name, depth = depth})
            -- Don't return - continue scanning children for independently positioned frames
        end

        if isProtected then
            local success, children = pcall(function()
                return {frame:GetChildren()}
            end)
            if success and children and #children > 0 then
                for _, child in ipairs(children) do
                    scanFrame(child, true, depth + 1)
                end
            end
        else
            -- Also scan children of non-protected frames (e.g., AddOn children)
            local success, children = pcall(function()
                return {frame:GetChildren()}
            end)
            if success and children and #children > 0 then
                for _, child in ipairs(children) do
                    scanFrame(child, false, depth + 1)
                end
            end
        end
    end

    scanFrame(UIParent, true, 0)

    -- Filter out frames that are anchored to another shakeable frame
    -- (e.g. MicroButtons chained together - only shake the first one)
    local filteredFrames = {}
    local shakeableSet = {}

    for _, item in ipairs(foundFrames) do
        local isAnchoredToShakeable = false

        -- Check all anchor points of this frame
        for i = 1, 6 do
            local success, point, relFrame = pcall(function()
                return item.frame:GetPoint(i)
            end)

            if success and relFrame then
                -- Check if relFrame is in our shakeable list
                for _, other in ipairs(foundFrames) do
                    if other.frame == relFrame then
                        isAnchoredToShakeable = true
                        break
                    end
                end
            end
            if isAnchoredToShakeable then
                break
            end
        end

        if not isAnchoredToShakeable then
            table.insert(filteredFrames, item)
            table.insert(shakeableFrames, item.frame)
            shakeableSet[item.frame] = true
        end
    end

    return filteredFrames
end

-- Scan and show message (with flag to prevent duplicate scans)
local function scanWithMessage(quick)
    if isScanning or #shakeableFrames > 0 then
        return false
    end
    isScanning = true
    scanScheduled = false
    scanUnprotectedFrames()
    isScanning = false

    if #shakeableFrames > 0 then
        if quick then
            print("|cFFF56900[ShakeIt]|r Quickly scanned and found " .. #shakeableFrames .. " shakeable frames!")
        else
            print("|cFFF56900[ShakeIt]|r " .. #shakeableFrames .. " shakeable frames found!")
        end
        return true
    else
        print("|cFFF56900[ShakeIt]|r No shakeable frames found.")
        return false
    end
end

-- Trigger shake effect
local function triggerShake()
    if #shakeableFrames == 0 or isShaking then
        return
    end

    isShaking = true
    local updateInterval = 0.02

    local originalPositions = {}
    for i, frame in ipairs(shakeableFrames) do
        local success, p1, parent, anchor, x, y = pcall(function()
            return frame:GetPoint(1)
        end)
        if success and p1 then
            originalPositions[i] = {p1, parent, anchor, x, y}
        end
    end

    if not shakeFrame then
        shakeFrame = CreateFrame("Frame")
        shakeFrame:Hide()
    end

    shakeFrame:Show()

    local remainingDuration = DURATION / 1000
    local elapsedTime = 0
    local currentStep = 0

    shakeFrame:SetScript("OnUpdate", function(frame, elapsed)
        elapsedTime = elapsedTime + elapsed

        while elapsedTime >= updateInterval do
            elapsedTime = elapsedTime - updateInterval
            remainingDuration = remainingDuration - updateInterval

            if remainingDuration > 0 then
                currentStep = currentStep + 1
                local maxOffset = 101 - INTENSITY - (currentStep - 1)
                local randomX = math.random(-100, 100) / maxOffset * 3
                local randomY = math.random(-100, 100) / maxOffset * 3

                for i, frame in ipairs(shakeableFrames) do
                    local orig = originalPositions[i]
                    if orig then
                        pcall(function()
                            frame:ClearAllPoints()
                            frame:SetPoint(orig[1], orig[2], orig[3],
                                         orig[4] + randomX, orig[5] + randomY)
                        end)
                    end
                end
            else
                for i, frame in ipairs(shakeableFrames) do
                    local orig = originalPositions[i]
                    if orig then
                        pcall(function()
                            frame:ClearAllPoints()
                            frame:SetPoint(orig[1], orig[2], orig[3], orig[4], orig[5])
                        end)
                    end
                end

                shakeFrame:Hide()
                shakeFrame:SetScript("OnUpdate", nil)
                isShaking = false
                return
            end
        end
    end)
end

-- Combat log event handler, returns true if player crit
local function onCombatLogEvent()
    local eventInfo = {CombatLogGetCurrentEventInfo()}
    local timestamp, subevent, hideCaster, sourceGUID = unpack(eventInfo)

    if sourceGUID ~= UnitGUID("player") then
        return false
    end

    local isCrit = nil

    if subevent == "SWING_DAMAGE" then
        isCrit = select(18, unpack(eventInfo))
    elseif subevent == "RANGE_DAMAGE" then
        isCrit = select(21, unpack(eventInfo))
    elseif subevent == "SPELL_DAMAGE" then
        isCrit = select(21, unpack(eventInfo))
    elseif subevent == "SPELL_PERIODIC_DAMAGE" then
        isCrit = select(20, unpack(eventInfo))
    elseif subevent == "SPELL_HEAL" then
        isCrit = select(19, unpack(eventInfo))
    elseif subevent == "SPELL_PERIODIC_HEAL" then
        isCrit = select(18, unpack(eventInfo))
    end

    if isCrit then
        local currentTime = GetTime()
        if currentTime - ShakeIt.lastShakeTime >= COOLDOWN / 1000 then
            ShakeIt.lastShakeTime = currentTime
            triggerShake()
        end
        return true
    end
    return false
end

-- Slash commands
SLASH_SHAKEIT1 = "/shakeit"
SlashCmdList["SHAKEIT"] = function(msg)
    local cmd = msg:trim()
    local firstWord = cmd:lower():match("^%w+")

    if firstWord == nil then
        -- Show help
        print("|cFFF56900[ShakeIt]|r Commands:")
        print("  |cFF00FF00/shakeit|r - Show this help")
        print("  |cFF00FF00/shakeit shake|r - Trigger a manual shake")
        print("  |cFF00FF00/shakeit scan|r - Rescan all UI frames")
        print("  |cFF00FF00/shakeit test <framename>|r - Shake a specific frame")
    elseif firstWord == "test" then
        local frameName = cmd:match("^%w+%s+(.+)")
        if frameName then
            frameName = frameName:trim()
            shakeSingleFrame(frameName)
        else
            print("|cFFF56900[ShakeIt]|r Usage: /shakeit test <framename>")
        end
    elseif firstWord == "scan" then
        local results = scanUnprotectedFrames()
        print("|cFFF56900[ShakeIt]|r Found " .. #results .. " frames.")
    elseif firstWord == "shake" then
        if #shakeableFrames == 0 then
            if scanWithMessage(true) then
                triggerShake()
            end
        else
            triggerShake()
        end
    else
        print("|cFFF56900[ShakeIt]|r Unknown command. Use |cFF00FF00/shakeit|r for help.")
    end
end

-- Initialize
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "ShakeIt" then
            print("|cFFF56900[ShakeIt]|r Scanning for shakeable frames in 15 seconds (waiting for other addons)...")
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Fallback: Scan after 15 seconds if no crit happened yet
        C_Timer.After(15, function()
            if not scanScheduled then
                scanWithMessage(false)
            end
        end)
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local playerCrit = onCombatLogEvent()
        -- Scan on first player crit if not done yet
        if playerCrit and #shakeableFrames == 0 and not scanScheduled then
            scanScheduled = true
            C_Timer.After(0.1, function()
                scanWithMessage(true)
            end)
        end
    end
end)
