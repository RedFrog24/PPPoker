-- pppoker.lua 23rd anniversary task (init2 prototype)
-- Created by: RedFrog
-- Original creation date: 03/18/2026
-- Quest: https://everquest.allakhazam.com/db/quest.html?quest=10723
-- Version: 2.11
-- Changelog:
-- 2.11: Journal prime runs once BEFORE mq.imgui.init so first ImGui frame never reads stale TLO (chicken/egg with main-loop-only prime). getQuestProgress returns hasQuest + Title() match; Run logs resume index from step table. Completion still objectiveIsComplete (not obj()-only).
-- 2.10: getQuestProgress() — percent + per-objective done table (16) via objectiveIsComplete; status bar ticks green/gray per step. getObjectiveProgress wraps same data. Automation remains runQuest + waitObjectiveDone (no raw Done-only wait in ImGui).
-- 2.09: Journal prime CANNOT use mq.delay inside ImGui (non-yieldable thread). Prime only from main while-loop; GUI shows "Syncing task journal…" until primed. Fixes spam/crash "Cannot delay from non-yieldable thread".
-- 2.08: Task journal prime runs in ImGui path BEFORE getTask (open→delay→fetch→delay→close); main loop no longer primed first (GUI was reading stale TLO). Run still does full sync. Matches RedGuides TaskWnd fetch pattern.
-- 2.07: One-time TaskWnd open/close at script start + every Run so Task TLO matches journal; getTask() requires Title() match; prime Objective slot (obj()) before Done/Status. Fixes idle snapshot + resume thinking obj 1 is open when MQ data was stale.
-- 2.06: objectiveIsComplete — check Done() BEFORE Status(). Status "0/1" was returning false and skipping Done() (journal could show complete while Status lagged). Widen Status text ("done"/"complete", trailing punctuation). Wait loop debug logs Status+Done.
-- 2.05: taskHasAnyObjectiveRow — any non-nil Objective(i) counts again (Status/Instruction can be empty briefly on Live). Run preflight uses warn+return instead of fail() so script/GUI keep running.
-- 2.04: Objective completion uses Status() first ("Done" or cur/tot like 0/1); Done() as fallback. Row detection requires non-empty Status or Instruction so empty TLO slots don't count as "has quest".
-- 2.03: Require at least one Task.Objective(i) row before resuming (fixes false step 1 / Tassel when journal had no objectives). Idle + Run: no task or no rows → "Get Quest from Big Slick"; distinguish quest complete vs not started.
-- 2.02: Task/objective reads no longer require Objective(i)() truthy (fixes idle snapshot + progress when MQ leaves () false). getTask() falls back to scanning Task(1..30) by Title().
-- 2.01: Versioning — 0.01 bumps like init.lua; PP.VERSION in window title + GUI `(v#)` line.
-- 2.00: New clean objective-index runner (16 objectives), compact GUI, shared nav/plugin helpers.
--       Quest state via mq.TLO.Task (memory); TaskWnd/journal open not required for automation.
--       Status bar uses fixed 16 objective slots (ticks + X/16); dynamic scan under-counted when MQ leaves gaps.
--       On open (and while idle), Status / Current Objective refresh from Task TLO — no Run required.

local mq = require('mq')
local imgui = require('ImGui')
local ImGui = imgui
local Icons = require('mq.icons')
local ImAnim = require('ImAnim')

local stopRequested = false

local PP = {
    VERSION = "2.11",
    QUEST_TITLE = "Paintings Playing Poker",
    --- Journal has 16 objectives for this quest; use for bar ticks and X/Y display (not dynamic scan).
    QUEST_OBJECTIVE_COUNT = 16,
    MAX_OBJECTIVES = 30,

    -- GUI defaults (from init.lua)
    WINDOW_W = 400,
    WINDOW_H = 780,
    WINDOW_PAD_X = 10,
    WINDOW_PAD_Y = 6,
    pppokerApplyInitialLayout = true,

    -- Commemoratives icon row (from init.lua)
    COMMEMORATIVE_ITEM_ICON_ID = 5901,
    DRAGITEM_ICON_ATLAS_OFFSET = 500,

    -- Header art (from init.lua)
    ATLAS_FILE = "pictest_triptych.png",
    USE_TRIPTYCH_ATLAS = true,
    ATLAS_W = 500,
    ATLAS_H = 900,
    SEGMENT_COUNT = 3,
    PANEL_W = 500,
    PANEL_H = 300,
    PANELS = {
        { name = "Roosters", file = "pictest_roosters.png", segment = 0 },
        { name = "Dogs", file = "pictest_dogs.png", segment = 1 },
        { name = "Fish", file = "pictest_fish.png", segment = 2 },
    },
    SEGMENT_H = 300, -- set just below table
    CHILD_MAX_HEIGHT = 1000,
    ATLAS_CROP_X0_PX = 8,
    ATLAS_CROP_X1_PX = 490,
    FISH_TOP_PAD_PX = 0,
    FISH_CURSOR_Y_LIFT_PX = 0,
    FISH_LAYOUT_EXTRA_BOTTOM_PX = 10,
    FISH_UV_BOTTOM_TRIM_PX = 8,
    ATLAS_CROP_TOP_IN_SEG = { 0, -44, -92 },
    ATLAS_CROP_BOTTOM_IN_SEG = { 248, 204, 193 },
    FORCE_IMAGE = nil,

    textures = {},
    loadedOk = {},
    selectedIndex = 1,
    texturesLoadedOnce = false,

    GATE_ZONE_ID = 202,
    GATE_ALT_ACT_ID = 1217,
    GATE_POTION_NAME = "Philter of Major Translocation",

    ZONE = {
        WEST_FP = 383,
        EAST_FP = 382,
        NERIAK_A = 40,
        NERIAK_B = 41,
        HIGHPASS = 407,
        MOORS = 395,
        NQ = 2,
        SQ = 1,
        POK = 202,
    },

    NPC = {
        BIG_SLICK = { "Big Slick Jones" },
        BETTY = { "Bluffing Betty", "Bluffing" },
        QUINN = { "Quinn of Quads", "Quads" },
        MHRAI = { "Mhrai, Queen of Tails", "Queen", "Mhrai" },
    },

    LOC = {
        SLICK = { 19, 136, -54 },
        TASSEL = { -177, -415, -85 },
        BETTY = { 153, -806, 7 },
        BULL = { -352, -207, 22 },
        SLUG = { 204, -243, 3 },
        BLIND_FISH = { 12, -850, -52 },
        TOADSTOOL = { -148, -994, -26 },
        QUINN = { 454, -620, 22 },
        LUMBER_1 = { -442, -215, -12 },
        LUMBER_2 = { -426, -263, -12 },
        LUMBER_3 = { -408, -267, -12 },
        TIGER = { -125, 540, -13 },
        NQ = { 118, 335, 1 },
        SQ_FISH = { -282, -230, 2 },
        SQ_LION = { 311, -173, 4 },
    },

    cwtnState = { pausedApplied = false, alreadyPausedAtStart = false },
}

PP.SEGMENT_H = math.floor(PP.ATLAS_H / PP.SEGMENT_COUNT)

local gui = {
    open = true,
    running = false,
    status = "Idle",
    debugOpen = false,
    debugLog = {},
    step = 0,
    --- Set by refreshIdleQuestSnapshot when all objectives read complete (Status/Done).
    questComplete = false,
    --- No task in journal, or task has zero objective rows (not started / not loaded).
    needBigSlickQuest = false,
    --- After first main-loop tick: TaskWnd flash so MQ populates Task.Objective before idle reads.
    taskJournalPrimed = false,
}

-- Status bar options (same style defaults used in init.lua).
PP.PIC_TEST_BAR_OPTS = {
    height = 22,
    padEnd = 12,
    textFmt = "Quest %.0f%%",
    rounding = 4,
    border = true,
    borderThickness = 1,
    showTicks = true,
    tickEvery = 0.125,
    tickAlpha = 72,
    tickThickness = 1.25,
    shimmer = true,
    shimmerFollows = true,
    shimmerSpeed = 0.45,
    shimmerWidth = 48.0,
    fillGradient = true,
    fillGradientMode = "dynamic",
    fillGradientDir = "tb",
}

-- Forward decl so header-art loader can log.
local debugLog

local function getImVec2(x, y)
    if imgui.ImVec2 then
        return imgui.ImVec2(x, y)
    end
    if ImVec2 then
        return ImVec2(x, y)
    end
    error("ImVec2 not available")
end

local function getImVec4(r, g, b, a)
    if imgui.ImVec4 then
        return imgui.ImVec4(r, g, b, a)
    end
    if ImVec4 then
        return ImVec4(r, g, b, a)
    end
    return nil
end

local function getContentRegionAvail2()
    local a, b = imgui.GetContentRegionAvail()
    if type(a) == "table" then
        return tonumber(a.x or a["x"]) or 0, tonumber(a.y or a["y"]) or 0
    end
    return tonumber(a) or 0, tonumber(b) or 0
end

local function getCursorScreenPos2()
    local a, b = imgui.GetCursorScreenPos()
    if type(a) == "table" then
        return tonumber(a.x or a["x"]) or 0, tonumber(a.y or a["y"]) or 0
    end
    return tonumber(a) or 0, tonumber(b) or 0
end

local function imCol32White()
    if type(IM_COL32) == "function" then
        return IM_COL32(255, 255, 255, 255)
    end
    if imgui.IM_COL32 and type(imgui.IM_COL32) == "function" then
        return imgui.IM_COL32(255, 255, 255, 255)
    end
    return 0xFFFFFFFF
end

local function getWindowDrawList()
    if imgui.GetWindowDrawList then
        return imgui.GetWindowDrawList()
    end
    if ImGui and ImGui.GetWindowDrawList then
        return ImGui.GetWindowDrawList()
    end
    return nil
end

local function childNoScrollFlags()
    if not ImGuiWindowFlags then
        return 0
    end
    local ns = ImGuiWindowFlags.NoScrollbar
    local nsm = ImGuiWindowFlags.NoScrollWithMouse
    if bit32 and bit32.bor and ns and nsm then
        return bit32.bor(ns, nsm)
    end
    if bit and bit.bor and ns and nsm then
        return bit.bor(ns, nsm)
    end
    return 0
end

-- Debug toggle: right-aligned label + green/red icon (from init.lua).
local function pppokerDrawDebugToggle()
    local dbgAvailX = select(1, getContentRegionAvail2()) or 0
    local dbgBlockW = 90 -- "Debug" text + toggle icon
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + math.max(0, (dbgAvailX or 0) - dbgBlockW))
    ImGui.PushID("PPPokerDebugV2")
    ImGui.Text("Debug")
    ImGui.SameLine()
    if gui.debugOpen then
        if Icons and Icons.FA_TOGGLE_ON then
            ImGui.TextColored(0.0, 1.0, 0.0, 1.0, Icons.FA_TOGGLE_ON)
        else
            ImGui.TextColored(0.0, 1.0, 0.0, 1.0, "ON")
        end
    else
        if Icons and Icons.FA_TOGGLE_OFF then
            ImGui.TextColored(1.0, 0.0, 0.0, 1.0, Icons.FA_TOGGLE_OFF)
        else
            ImGui.TextColored(1.0, 0.0, 0.0, 1.0, "OFF")
        end
    end
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(gui.debugOpen and "On (click to turn off)" or "Off (click to turn on)")
        if ImGui.IsMouseClicked(0) then
            gui.debugOpen = not gui.debugOpen
        end
    end
    ImGui.PopID()
end

math.randomseed(os.time())
for _ = 1, 3 do
    math.random()
end

local function getScriptDir()
    local dir = nil
    pcall(function()
        mq.delay(0)
        local lastPID = mq.TLO.Lua.PIDs():match("(%d+)$")
        local scriptFolder = mq.TLO.Lua.Script(lastPID).Name()
        if scriptFolder and scriptFolder ~= "" then
            dir = string.format("%s/%s", mq.luaDir, scriptFolder):gsub("\\", "/")
        end
    end)
    if not dir then
        local source = debug.getinfo(1, "S").source
        if source:sub(1, 1) == "@" then
            source = source:sub(2)
        end
        dir = (source:match("^(.*)[/\\].-$") or "."):gsub("\\", "/")
    end
    return dir
end

local function loadTextures()
    local dir = getScriptDir():gsub("/+$", "")
    local any = false

    if PP.USE_TRIPTYCH_ATLAS then
        local path = dir .. "/" .. PP.ATLAS_FILE
        local ok, result = pcall(function()
            return mq.CreateTexture(path)
        end)
        if ok and result and result.GetTextureID and result:GetTextureID() then
            for i = 1, #PP.PANELS do
                PP.textures[i] = result
                PP.loadedOk[i] = true
            end
            any = true
            debugLog("Loaded atlas " .. PP.ATLAS_FILE .. " (" .. PP.ATLAS_W .. "x" .. PP.ATLAS_H .. ")")
        else
            for i = 1, #PP.PANELS do
                PP.textures[i] = nil
                PP.loadedOk[i] = false
            end
            warn("Missing or bad atlas: " .. path)
        end
    else
        for i, p in ipairs(PP.PANELS) do
            local path = dir .. "/" .. p.file
            local ok, result = pcall(function()
                return mq.CreateTexture(path)
            end)
            if ok and result and result.GetTextureID and result:GetTextureID() then
                PP.textures[i] = result
                PP.loadedOk[i] = true
                any = true
            else
                PP.loadedOk[i] = false
                warn("Missing or bad: " .. path)
            end
        end
    end
    return any
end

local function pickRandomPanel()
    local choices = {}
    for i = 1, #PP.PANELS do
        if PP.loadedOk[i] then
            choices[#choices + 1] = i
        end
    end
    if #choices == 0 then
        PP.selectedIndex = 1
        return
    end
    if PP.FORCE_IMAGE and PP.FORCE_IMAGE >= 1 and PP.FORCE_IMAGE <= #PP.PANELS and PP.loadedOk[PP.FORCE_IMAGE] then
        PP.selectedIndex = PP.FORCE_IMAGE
        return
    end
    PP.selectedIndex = choices[math.random(#choices)]
end

local function drawHeaderImage()
    local tex = PP.textures[PP.selectedIndex]
    if not tex or not PP.loadedOk[PP.selectedIndex] then
        return
    end

    local availW, availH = getContentRegionAvail2()
    if availW < 4 or availH < 4 then
        return
    end

    local frameW = math.floor(availW + 0.5)
    local srcW = PP.PANEL_W
    local seg = PP.PANELS[PP.selectedIndex].segment
    local topIn = 0
    local botIn = PP.PANEL_H - 1
    local uvSrcH = PP.PANEL_H
    local layoutSrcH = PP.PANEL_H
    if PP.USE_TRIPTYCH_ATLAS then
        srcW = math.max(1, PP.ATLAS_CROP_X1_PX - PP.ATLAS_CROP_X0_PX)
        topIn = PP.ATLAS_CROP_TOP_IN_SEG[seg + 1] or 0
        botIn = PP.ATLAS_CROP_BOTTOM_IN_SEG[seg + 1] or (PP.SEGMENT_H - 1)
        uvSrcH = math.max(1, botIn - topIn)
        layoutSrcH = uvSrcH
        if seg == 1 or seg == 2 then
            local rTop = PP.ATLAS_CROP_TOP_IN_SEG[1] or 0
            local rBot = PP.ATLAS_CROP_BOTTOM_IN_SEG[1] or (PP.SEGMENT_H - 1)
            layoutSrcH = math.max(1, rBot - rTop)
            if seg == 2 then
                layoutSrcH = layoutSrcH + PP.FISH_LAYOUT_EXTRA_BOTTOM_PX
            end
        end
    end
    local naturalH = math.max(1, math.floor(frameW * (layoutSrcH / srcW)))
    local frameH = naturalH
    if frameH > availH - 4 then
        frameH = math.max(1, math.floor(availH - 4))
    end
    if frameH > PP.CHILD_MAX_HEIGHT then
        frameH = PP.CHILD_MAX_HEIGHT
    end

    local u0, u1 = nil, nil
    if PP.USE_TRIPTYCH_ATLAS then
        local nudge = 0.5
        local x0 = math.max(0, math.min(PP.ATLAS_W, PP.ATLAS_CROP_X0_PX))
        local x1 = math.max(0, math.min(PP.ATLAS_W, PP.ATLAS_CROP_X1_PX))
        topIn = PP.ATLAS_CROP_TOP_IN_SEG[seg + 1] or 0
        botIn = PP.ATLAS_CROP_BOTTOM_IN_SEG[seg + 1] or (PP.SEGMENT_H - 1)
        local y0 = seg * PP.SEGMENT_H + topIn
        local y1 = seg * PP.SEGMENT_H + botIn
        if seg == 2 and PP.FISH_UV_BOTTOM_TRIM_PX > 0 then
            y1 = y1 - PP.FISH_UV_BOTTOM_TRIM_PX
            if y1 <= y0 + 4 then
                y1 = y0 + 4
            end
        end
        u0 = getImVec2((x0 + nudge) / PP.ATLAS_W, (y0 + nudge) / PP.ATLAS_H)
        u1 = getImVec2((x1 - nudge) / PP.ATLAS_W, (y1 - nudge) / PP.ATLAS_H)
    else
        u0 = getImVec2(0, 0)
        u1 = getImVec2(1, 1)
    end

    local stylePushCount = 0
    if ImGuiStyleVar and ImGuiStyleVar.ItemSpacing and imgui.PushStyleVar then
        pcall(function()
            imgui.PushStyleVar(ImGuiStyleVar.ItemSpacing, getImVec2(0, 0))
            stylePushCount = stylePushCount + 1
        end)
    end
    if ImGuiStyleVar and ImGuiStyleVar.WindowPadding and imgui.PushStyleVar then
        pcall(function()
            imgui.PushStyleVar(ImGuiStyleVar.WindowPadding, getImVec2(0, 0))
            stylePushCount = stylePushCount + 1
        end)
    end

    local flags = childNoScrollFlags()
    local childOk = pcall(function()
        imgui.BeginChild("##PPPokerPicPanelV2", getImVec2(frameW, frameH), false, flags)
    end)
    if not childOk then
        childOk = pcall(function()
            imgui.BeginChild("##PPPokerPicPanelV2", getImVec2(frameW, frameH), false)
        end)
    end
    if not childOk then
        if stylePushCount > 0 then
            imgui.PopStyleVar(stylePushCount)
        end
        return
    end

    local innerW, innerH = getContentRegionAvail2()
    if innerW < 1 or innerH < 1 then
        imgui.EndChild()
        if stylePushCount > 0 then
            imgui.PopStyleVar(stylePushCount)
        end
        return
    end

    local texId = tex:GetTextureID()
    local dl = getWindowDrawList()
    local colW = imCol32White()
    local laidOut = false

    local imgW, imgH = innerW, innerH
    local padTop = 0
    if PP.USE_TRIPTYCH_ATLAS and seg == 1 then
        local scaledH = math.max(1, math.floor(innerW * (uvSrcH / srcW) + 0.5))
        if scaledH < innerH then
            padTop = innerH - scaledH
            imgH = scaledH
        elseif scaledH > innerH then
            imgH = innerH
        end
    end

    local fishTopPad = 0
    if PP.USE_TRIPTYCH_ATLAS and seg == 2 and PP.FISH_TOP_PAD_PX > 0 then
        fishTopPad = PP.FISH_TOP_PAD_PX
        imgH = math.max(1, innerH - fishTopPad)
    end

    local tint = getImVec4(1, 1, 1, 1)
    local bcol = getImVec4(0, 0, 0, 0)
    if texId and tint and bcol then
        local okImg = pcall(function()
            if padTop > 0 then
                imgui.Dummy(getImVec2(innerW, padTop))
            end
            if fishTopPad > 0 then
                imgui.Dummy(getImVec2(innerW, fishTopPad))
            end
            imgui.Image(texId, getImVec2(imgW, imgH), u0, u1, tint, bcol)
            local usedH = padTop + fishTopPad + imgH
            if usedH < innerH then
                imgui.Dummy(getImVec2(innerW, innerH - usedH))
            end
        end)
        if okImg then
            laidOut = true
        end
    end
    if not laidOut and texId and dl and dl.AddImage then
        pcall(function()
            if padTop > 0 then
                imgui.Dummy(getImVec2(innerW, padTop))
            end
            if fishTopPad > 0 then
                imgui.Dummy(getImVec2(innerW, fishTopPad))
            end
            local sx, sy = getCursorScreenPos2()
            dl:AddImage(texId, getImVec2(sx, sy), getImVec2(sx + imgW, sy + imgH), u0, u1, colW)
            local usedH = padTop + fishTopPad + imgH
            if usedH < innerH then
                imgui.Dummy(getImVec2(innerW, innerH - usedH))
            end
        end)
        laidOut = true
    end
    if not laidOut and texId then
        pcall(function()
            if padTop > 0 then
                imgui.Dummy(getImVec2(innerW, padTop))
            end
            if fishTopPad > 0 then
                imgui.Dummy(getImVec2(innerW, fishTopPad))
            end
            imgui.Image(texId, getImVec2(imgW, imgH), u0, u1)
            local usedH = padTop + fishTopPad + imgH
            if usedH < innerH then
                imgui.Dummy(getImVec2(innerW, innerH - usedH))
            end
        end)
        laidOut = true
    end
    if not laidOut then
        imgui.Dummy(getImVec2(innerW, innerH))
    end

    imgui.EndChild()
    if stylePushCount > 0 then
        imgui.PopStyleVar(stylePushCount)
    end
end

-- ========== Inlined horizontal progress bar (from init.lua style) ==========
local BarColors = {
    XPMin = getImVec4(0.293, 0.416, 0.791, 1.000),
    XPMax = getImVec4(0.782, 0.905, 0.009, 1.000),
    borders = getImVec4(0.8, 0.8, 0.8, 1.0),
}

local statusBarGlobalOpts = {
    height = 22.0,
    width = 0,
    padEnd = 12.0,
    rounding = 4.0,
    showText = true,
    textFmt = "Quest %.0f%%",
    tickEvery = 0.125,
    tickAlpha = 72,
    tickThickness = 1.25,
    shimmer = true,
    shimmerFollows = true,
    shimmerSpeed = 0.45,
    shimmerWidth = 48.0,
    shimmerDeadzone = 0.001,
    glow = true,
    fillGradient = true,
    fillGradientMode = "dynamic",
    fillGradientDir = "tb",
    border = true,
    borderThickness = 1.0,
    borderColor = BarColors.borders,
}

local function sbClamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function sbTo01(percent)
    if percent > 1.0 then return sbClamp01(percent / 100.0) end
    return sbClamp01(percent)
end

local function sbShallowCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do copy[k] = v end
    return copy
end

local function drawObjectiveBar(label, percent, lowCol, highCol, opts)
    opts = opts or {}
    local dl = ImGui.GetWindowDrawList and ImGui.GetWindowDrawList() or nil
    if not dl then
        return 0
    end
    local progress = sbTo01(percent)
    local height = opts.height or 22.0
    local width = opts.width or 0.0
    local padEnd = opts.padEnd or 12.0
    local rounding = opts.rounding or 4.0
    local showText = (opts.showText ~= false)
    local textFmt = opts.textFmt or "Quest %.0f%%"
    local showTicks = (opts.showTicks ~= false)
    local tickEvery = opts.tickEvery or 0.125
    local tickAlpha = opts.tickAlpha or 72
    local tickTh = opts.tickThickness or 1.25

    local bar_pos = ImGui.GetCursorScreenPosVec()
    local avail = ImGui.GetContentRegionAvailVec()
    local bar_size = width > 0 and ImVec2(width, height) or ImVec2(avail.x - padEnd, height)
    local bar_max = ImVec2(bar_pos.x + bar_size.x, bar_pos.y + bar_size.y)

    local bgU32 = IM_COL32(30, 32, 40, 255)
    dl:AddRectFilled(bar_pos, bar_max, bgU32, rounding)

    local filled_w = bar_size.x * progress
    if filled_w > 2.0 then
        local fill_max = ImVec2(bar_pos.x + filled_w, bar_pos.y + bar_size.y)
        local colorLeft = lowCol
        local colorRight = highCol
        local colorLow = ImGui.ColorConvertFloat4ToU32(colorLeft)
        local colorHigh = ImGui.ColorConvertFloat4ToU32(colorRight)
        if (opts.fillGradientDir or "tb") == "tb" then
            dl:AddRectFilledMultiColor(fill_max, bar_pos, colorHigh, colorHigh, colorLow, colorLow)
        else
            dl:AddRectFilledMultiColor(bar_pos, fill_max, colorLow, colorHigh, colorHigh, colorLow)
        end
    end

    local perStep = opts.perStepDone
    if perStep and type(perStep) == "table" then
        local insetY = 3.0
        local y1 = bar_pos.y + insetY
        local y2 = bar_pos.y + bar_size.y - insetY
        local n = PP.QUEST_OBJECTIVE_COUNT
        for k = 1, n do
            local x = bar_pos.x + (bar_size.x * (k / n))
            local done = perStep[k] and true or false
            local a = done and 220 or 110
            local col = done and IM_COL32(90, 210, 130, a) or IM_COL32(160, 160, 170, a)
            dl:AddRectFilled(ImVec2(x - tickTh * 0.5, y1), ImVec2(x + tickTh * 0.5, y2), col, 0.0)
        end
    elseif showTicks and tickEvery > 0 then
        local insetY = 3.0
        local y1 = bar_pos.y + insetY
        local y2 = bar_pos.y + bar_size.y - insetY
        local steps = math.floor(1.0 / tickEvery + 0.5)
        for i = 0, steps do
            local t = i * tickEvery
            if t > 1.00001 then break end
            local x = bar_pos.x + (bar_size.x * t)
            dl:AddRectFilled(ImVec2(x - tickTh * 0.5, y1), ImVec2(x + tickTh * 0.5, y2), IM_COL32(255, 255, 255, tickAlpha), 0.0)
        end
    end

    if showText then
        local txt = string.format(textFmt, progress * 100.0)
        local txtSize = ImGui.CalcTextSizeVec(txt)
        local txtPos = ImVec2(
            bar_pos.x + (bar_size.x - txtSize.x) * 0.5,
            bar_pos.y + (bar_size.y - txtSize.y) * 0.5
        )
        dl:AddText(txtPos, IM_COL32(255, 255, 255, 220), txt)
    end

    if opts.border then
        local bc = opts.borderColor or BarColors.borders
        local colU32
        if type(bc) == "number" then
            colU32 = bc
        elseif bc and ImGui.ColorConvertFloat4ToU32 then
            colU32 = ImGui.ColorConvertFloat4ToU32(bc)
        else
            colU32 = IM_COL32(255, 255, 255, 120)
        end
        dl:AddRect(bar_pos, bar_max, colU32, rounding, 0, opts.borderThickness or 1.0)
    end

    ImGui.Dummy(ImVec2(bar_size.x, bar_size.y + 6.0))
    return progress
end

local barLiveOpts = nil
local function ensureObjectiveBarLive()
    if barLiveOpts then return barLiveOpts end
    barLiveOpts = sbShallowCopy(statusBarGlobalOpts)
    for k, v in pairs(PP.PIC_TEST_BAR_OPTS) do
        barLiveOpts[k] = v
    end
    return barLiveOpts
end

debugLog = function(msg)
    local s = tostring(msg or "")
    gui.debugLog[#gui.debugLog + 1] = os.date("%H:%M:%S") .. " " .. s
    if #gui.debugLog > 120 then
        table.remove(gui.debugLog, 1)
    end
end

local function info(msg)
    local s = tostring(msg or "")
    print(string.format("\ao[\agPPPoker\ao]\at %s", s))
    debugLog(s)
end

local function warn(msg)
    local s = tostring(msg or "")
    print(string.format("\ao[\ayPPPoker\ao]\at %s", s))
    debugLog("WARN: " .. s)
end

local function getCommemorativeCount()
    local ok, n = pcall(function() return tonumber(mq.TLO.Me.Commemoratives() or 0) end)
    if ok and n then return math.floor(n) end
    return 0
end

local commemorativeIconTex = nil
local function drawCommemorativeCoinsRow()
    local cnt = getCommemorativeCount()
    local green = getImVec4(0.15, 0.92, 0.38, 1.0)
    pcall(function()
        if commemorativeIconTex == nil and mq.FindTextureAnimation then
            local okT, tex = pcall(mq.FindTextureAnimation, "A_DragItem")
            if okT and tex then commemorativeIconTex = tex end
        end
        if commemorativeIconTex and commemorativeIconTex.SetTextureCell and imgui.DrawTextureAnimation then
            local cell = PP.COMMEMORATIVE_ITEM_ICON_ID - PP.DRAGITEM_ICON_ATLAS_OFFSET
            commemorativeIconTex:SetTextureCell(cell)
            imgui.DrawTextureAnimation(commemorativeIconTex, 22, 22)
            if imgui.SameLine then imgui.SameLine() end
        end
    end)
    if imgui.TextColored then
        imgui.TextColored(green, string.format("Commemoratives: %d", cnt))
    else
        imgui.Text(string.format("Commemoratives: %d", cnt))
    end
end

--- MQ often needs Objective TLO "primed" with obj() before Done/Status match /lua parse.
local function primeObjectiveSlot(obj)
    if not obj then
        return
    end
    pcall(function()
        local _ = obj()
    end)
end

--- Journal completion: Done() first (checkbox); then Status() (/lua parse … "0/1" vs "Done"). Never return false from Status "0/1" without checking Done() first — Status can lag after objective credits.
local function objectiveIsComplete(obj)
    if not obj then
        return false
    end
    primeObjectiveSlot(obj)
    local okD, d = pcall(function()
        if obj.Done and type(obj.Done) == "function" then
            return obj.Done()
        end
        return false
    end)
    if okD and d == true then
        return true
    end

    local okSt, st = pcall(function()
        if obj.Status and type(obj.Status) == "function" then
            return obj.Status()
        end
        return nil
    end)
    if okSt and st ~= nil then
        local raw = tostring(st)
        local s = raw:lower():match("^%s*(.-)%s*$")
        s = s:gsub("%p+$", "")
        if s == "done" or s == "complete" then
            return true
        end
        local cur, tot = raw:match("^%s*(%d+)%s*/%s*(%d+)%s*$")
        if cur and tot then
            local c, t = tonumber(cur), tonumber(tot)
            if t and t > 0 and c and c >= t then
                return true
            end
        end
    end

    return false
end

local function haltNavigationForStop()
    pcall(function() mq.cmd('/squelch /travelto stop') end)
    pcall(function() mq.cmd('/squelch /nav stop') end)
end

local function shouldStop()
    if not stopRequested then return end
    haltNavigationForStop()
    error("Stopped by user")
end

local function fail(msg)
    warn(msg)
    haltNavigationForStop()
    error(msg)
end

local function waitForZoneOrFalse(zoneId, timeoutMs)
    timeoutMs = timeoutMs or 120000
    local start = os.time()
    while mq.TLO.Zone.ID() ~= zoneId do
        shouldStop()
        mq.delay(500)
        if (os.time() - start) * 1000 > timeoutMs then
            return false
        end
    end
    return true
end

local function zoning(zoneId, timeoutMs)
    if not waitForZoneOrFalse(zoneId, timeoutMs) then
        fail("Zoning timeout waiting for zone " .. tostring(zoneId))
    end
end

local function navigationIsActive()
    local function readActive(tlo)
        if not tlo or not tlo.Active then return false end
        local ok, v = pcall(function()
            local a = tlo.Active
            if type(a) == "function" then return a() end
            return a
        end)
        if not ok then return false end
        if type(v) == "boolean" then return v end
        if type(v) == "number" then return v ~= 0 end
        if type(v) == "string" then
            local s = v:lower()
            return s == "true" or s == "1" or s == "on" or s == "running" or s == "active"
        end
        return false
    end
    if mq.TLO.Navigation then return readActive(mq.TLO.Navigation) end
    if mq.TLO.Nav then return readActive(mq.TLO.Nav) end
    return false
end

local function moving(timeoutMs)
    timeoutMs = timeoutMs or 120000
    mq.delay(300)
    local start = os.time()
    while navigationIsActive() do
        shouldStop()
        mq.delay(100)
        if (os.time() - start) * 1000 > timeoutMs then
            warn("Navigation timeout; stopping nav and continuing.")
            haltNavigationForStop()
            mq.delay(800)
            return true
        end
    end
    return true
end

local function ensureZone(zoneId, travelToArg, label, timeoutMs)
    if mq.TLO.Zone.ID() == zoneId then
        info(string.format("Already in %s (%d), skipping /travelto.", tostring(label), zoneId))
        return
    end
    info(string.format("Traveling to %s via /travelto %s", tostring(label), tostring(travelToArg)))
    mq.cmdf('/squelch /travelto %s', travelToArg)
    zoning(zoneId, timeoutMs or 240000)
end

local function targetMatches(names)
    if not (mq.TLO.Target and mq.TLO.Target()) then return false end
    local ok, n = pcall(function() return mq.TLO.Target.CleanName() end)
    local tn = tostring((ok and n) or ""):lower()
    if tn == "" then return false end
    for _, cand in ipairs(names or {}) do
        local c = tostring(cand or ""):lower()
        if c ~= "" and (tn == c or tn:find(c, 1, true) or c:find(tn, 1, true)) then
            return true
        end
    end
    return false
end

local function targetOrFail(names, failMsg, timeoutMs)
    timeoutMs = timeoutMs or 12000
    local start = os.time()
    while (os.time() - start) * 1000 < timeoutMs do
        for _, n in ipairs(names or {}) do
            if n and n ~= "" then
                mq.cmdf('/target "%s"', n)
                mq.delay(250)
                if targetMatches(names) then return true end
            end
        end
        mq.delay(150)
    end
    fail(failMsg or "Could not target expected NPC")
end

local function navLoc(loc, settleMs)
    mq.cmdf('/squelch /nav locyxz %.1f %.1f %.1f', loc[1], loc[2], loc[3])
    moving()
    mq.delay(settleMs or 1000)
end

local function tryGateToPoK()
    if mq.TLO.Me.ZoneBound.ID() ~= PP.GATE_ZONE_ID then return false end
    if mq.TLO.Me.AltAbilityReady('Gate')() then
        mq.cmd('/alt act ' .. tostring(PP.GATE_ALT_ACT_ID))
        mq.delay(10000)
        if waitForZoneOrFalse(PP.GATE_ZONE_ID, 50000) then return true end
    end
    if mq.TLO.FindItem(PP.GATE_POTION_NAME)() then
        mq.cmd('/useitem "' .. PP.GATE_POTION_NAME .. '"')
        mq.delay(12000)
        if waitForZoneOrFalse(PP.GATE_ZONE_ID, 50000) then return true end
    end
    return false
end

local function expectedCWTNPluginName()
    local short = (mq.TLO.Me.Class.ShortName() or ""):upper()
    local map = {
        BRD = "MQ2Bard", BST = "MQ2Bst", BER = "MQ2Berserker", CLR = "MQ2Cleric",
        DRU = "MQ2Druid", ENC = "MQ2Enchanter", MAG = "MQ2Mage", MNK = "MQ2Monk",
        NEC = "MQ2Necromancer", PAL = "MQ2Paladin", RNG = "MQ2Ranger", ROG = "MQ2Rogue",
        SHD = "MQ2ShadowKnight", SHM = "MQ2Shaman", WAR = "MQ2Warrior", WIZ = "MQ2Wizard",
    }
    return map[short]
end

local function isExpectedCWTNPluginLoaded()
    local pluginName = expectedCWTNPluginName()
    if not pluginName then return false, nil end
    local ok, loaded = pcall(function() return mq.TLO.Plugin(pluginName).IsLoaded() end)
    return ok and loaded or false, pluginName
end

local function pauseCWTNPlugins()
    local loaded = select(1, isExpectedCWTNPluginLoaded())
    if not loaded then return false end
    mq.cmd('/CWTN pause on')
    PP.cwtnState.pausedApplied = true
    return true
end

local function unpauseCWTNPlugins()
    if not PP.cwtnState.pausedApplied then return end
    local loaded = select(1, isExpectedCWTNPluginLoaded())
    if loaded then mq.cmd('/CWTN pause off') end
    PP.cwtnState.pausedApplied = false
end

local rgmercState = { pausedApplied = false }
local function pauseRGMercs()
    local ok, status = pcall(function() return mq.TLO.Lua.Script('rgmercs').Status() end)
    if ok and status == 'RUNNING' then
        mq.cmd('/rgm pauseall')
        rgmercState.pausedApplied = true
    end
end
local function unpauseRGMercs()
    if rgmercState.pausedApplied then mq.cmd('/rgm unpauseall') end
    rgmercState.pausedApplied = false
end

-- Quest progress: mq.TLO.Task. Journal prime uses mq.delay — ONLY call from script main thread (while gui.open), never from ImGui draw.
-- Completion signal: objectiveIsComplete (Done() then Status()). Indices: /lua parse mq.TLO.Task("Paintings Playing Poker").Objective(N).Status()

--- One-time from main loop: open → delay → fetch → delay → close. ImGui callbacks cannot mq.delay (non-yieldable thread).
local function primeTaskJournalFromMainLoop()
    if gui.taskJournalPrimed then
        return
    end
    pcall(function()
        mq.cmd("/windowstate TaskWnd open")
    end)
    mq.delay(200)
    pcall(function()
        mq.cmd("/windowstate TaskWnd fetch")
    end)
    mq.delay(100)
    pcall(function()
        mq.cmd("/windowstate TaskWnd close")
    end)
    gui.taskJournalPrimed = true
    print("\ay[PPPoker] Journal primed: Task TLO synced for startup.\ax")
    debugLog("Journal primed (TaskWnd open/fetch/close, main loop).")
end

--- Every Run: full sync so resume sees current journal (repeatable; not gated by taskJournalPrimed).
local function syncTaskJournalWindowFull()
    pcall(function()
        mq.cmd("/windowstate TaskWnd open")
    end)
    mq.delay(200)
    pcall(function()
        mq.cmd("/windowstate TaskWnd fetch")
    end)
    mq.delay(100)
    pcall(function()
        mq.cmd("/windowstate TaskWnd close")
    end)
    mq.delay(100)
end

local function taskIsPaintingsPlayingPoker(task)
    if not task or not task() then
        return false
    end
    local ok, title = pcall(function()
        return task.Title()
    end)
    return ok and title and tostring(title) == PP.QUEST_TITLE
end

local function getTask()
    local t = mq.TLO.Task(PP.QUEST_TITLE)
    if t and t() and taskIsPaintingsPlayingPoker(t) then
        return t
    end
    for i = 1, 30 do
        local ti = mq.TLO.Task(i)
        if ti and ti() and taskIsPaintingsPlayingPoker(ti) then
            return ti
        end
    end
    return nil
end

--- Progress: percent01, stepStatus[1..N], completedCount, hasQuest. Title must match PP.QUEST_TITLE. Completion via objectiveIsComplete (Done+Status); do not require obj() for slot (MQ can leave () false).
local function getQuestProgress(task)
    local stepStatus = {}
    for i = 1, PP.QUEST_OBJECTIVE_COUNT do
        stepStatus[i] = false
    end
    if not task or not task() then
        return 0, stepStatus, 0, false
    end
    if not taskIsPaintingsPlayingPoker(task) then
        return 0, stepStatus, 0, false
    end
    local completedCount = 0
    for i = 1, PP.QUEST_OBJECTIVE_COUNT do
        local obj = task.Objective(i)
        local ok = (obj and objectiveIsComplete(obj)) or false
        stepStatus[i] = ok
        if ok then
            completedCount = completedCount + 1
        end
    end
    local percent01 = completedCount / PP.QUEST_OBJECTIVE_COUNT
    return percent01, stepStatus, completedCount, true
end

local function getObjectiveProgress(task)
    local _, _, c, hasQuest = getQuestProgress(task)
    if not hasQuest then
        return 0, PP.QUEST_OBJECTIVE_COUNT
    end
    return c, PP.QUEST_OBJECTIVE_COUNT
end

--- True if at least one Objective(i) handle exists (non-nil). Status/Instruction may be empty briefly after zoning; do not require them.
local function taskHasAnyObjectiveRow(task)
    if not task or not task() then
        return false
    end
    for i = 1, PP.QUEST_OBJECTIVE_COUNT do
        if task.Objective(i) then
            return true
        end
    end
    return false
end

--- Objective TLO ref; do not gate on obj() — see getObjectiveProgress / MQ docs (() can be false briefly).
local function getObjective(task, idx)
    if not task then
        return nil
    end
    return task.Objective(idx)
end

local function objDone(task, idx)
    local obj = getObjective(task, idx)
    if not obj then
        if idx <= PP.QUEST_OBJECTIVE_COUNT then
            return false
        end
        return true
    end
    return objectiveIsComplete(obj)
end

local function objInstruction(task, idx)
    local obj = getObjective(task, idx)
    if not obj then
        return ""
    end
    local ok, s = pcall(function()
        return tostring(obj.Instruction() or "")
    end)
    return ok and s or ""
end

local function firstIncompleteObjective(task)
    if not task or not task() or not taskHasAnyObjectiveRow(task) then
        return nil, nil
    end
    for i = 1, PP.QUEST_OBJECTIVE_COUNT do
        if not objDone(task, i) then
            return i, getObjective(task, i)
        end
    end
    return nil, nil
end

local function waitObjectiveDone(taskName, idx, timeoutMs)
    timeoutMs = timeoutMs or 120000
    local t0 = mq.gettime()
    local nextLog = t0
    while mq.gettime() - t0 < timeoutMs do
        shouldStop()
        local t = getTask()
        local obj = (t and t()) and t.Objective(idx) or nil
        if obj and objectiveIsComplete(obj) then
            return true
        end
        if mq.gettime() >= nextLog then
            local instr = ""
            local t2 = getTask()
            local obj = (t2 and t2()) and t2.Objective(idx) or nil
            if obj then
                local okI, ins = pcall(function()
                    return tostring(obj.Instruction() or "")
                end)
                if okI then
                    instr = ins
                end
            end
            local stStr, dnStr = "?", "?"
            pcall(function()
                if obj.Status and type(obj.Status) == "function" then
                    stStr = tostring(obj.Status() or "")
                end
            end)
            pcall(function()
                if obj.Done and type(obj.Done) == "function" then
                    dnStr = tostring(obj.Done() and "true" or "false")
                end
            end)
            debugLog(string.format(
                "Waiting objective %d... %s | Status=%s Done=%s",
                idx,
                instr,
                stStr,
                dnStr
            ))
            nextLog = mq.gettime() + 8000
        end
        mq.delay(250)
    end
    return false
end

--- While not running Run, keep Status / Current Objective in sync with mq.TLO.Task (startup + live).
--- Call only when gui.taskJournalPrimed (main loop has run journal sync).
local function refreshIdleQuestSnapshot(task, done, total)
    if gui.running then
        return
    end
    gui.needBigSlickQuest = false
    if not task then
        gui.step = 0
        gui.questComplete = false
        gui.needBigSlickQuest = true
        gui.status = "Get Quest from Big Slick"
        return
    end
    if not taskHasAnyObjectiveRow(task) then
        gui.step = 0
        gui.questComplete = false
        gui.needBigSlickQuest = true
        gui.status = "Get Quest from Big Slick"
        return
    end
    local idx = select(1, firstIncompleteObjective(task))
    if not idx then
        gui.step = 0
        gui.questComplete = true
        gui.status = string.format("Quest complete (%d/%d).", done or 0, total or PP.QUEST_OBJECTIVE_COUNT)
        return
    end
    gui.questComplete = false
    gui.step = idx
    local instr = objInstruction(task, idx)
    gui.status = string.format("Next: objective %d — %s", idx, instr)
end

local function runObjectiveStep(idx, task)
    local instr = objInstruction(task, idx)
    gui.step = idx
    gui.status = string.format("Objective %d: %s", idx, instr)
    info(gui.status)

    if idx == 1 then
        ensureZone(PP.ZONE.WEST_FP, "freeportwest", "West Freeport")
        navLoc(PP.LOC.TASSEL, 1500)
    elseif idx == 2 then
        ensureZone(PP.ZONE.EAST_FP, "freeporteast", "East Freeport")
        navLoc(PP.LOC.BETTY, 1500)
    elseif idx == 3 then
        ensureZone(PP.ZONE.EAST_FP, "freeporteast", "East Freeport")
        navLoc(PP.LOC.BETTY, 1000)
        targetOrFail(PP.NPC.BETTY, "Could not target Bluffing Betty")
        mq.cmd('/keypress hail')
        mq.delay(1800)
        mq.cmd('/target ${Me.Name}')
    elseif idx == 4 then
        ensureZone(PP.ZONE.NERIAK_A, "neriaka", "Neriak Foreign Quarter")
        navLoc(PP.LOC.BULL, 1500)
    elseif idx == 5 then
        ensureZone(PP.ZONE.NERIAK_A, "neriaka", "Neriak Foreign Quarter")
        mq.cmd('/squelch /nav locyx 204 -243 3')
        moving()
        mq.delay(1500)
    elseif idx == 6 then
        ensureZone(PP.ZONE.NERIAK_B, "neriakb", "Neriak Commons", 360000)
        navLoc(PP.LOC.BLIND_FISH, 1500)
    elseif idx == 7 then
        ensureZone(PP.ZONE.NERIAK_B, "neriakb", "Neriak Commons", 360000)
        navLoc(PP.LOC.TOADSTOOL, 1000)
        mq.cmd('/face heading 315')
        mq.delay(1200)
        tryGateToPoK()
    elseif idx == 8 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        navLoc(PP.LOC.QUINN, 1000)
    elseif idx == 9 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        navLoc(PP.LOC.QUINN, 800)
        targetOrFail(PP.NPC.QUINN, "Could not target Quinn")
        mq.cmd('/keypress hail')
        mq.delay(1500)
        mq.cmd('/target ${Me.Name}')
    elseif idx == 10 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        navLoc(PP.LOC.LUMBER_1, 900)
        navLoc(PP.LOC.LUMBER_2, 900)
        navLoc(PP.LOC.LUMBER_3, 1000)
    elseif idx == 11 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        navLoc(PP.LOC.LUMBER_3, 900)
        targetOrFail(PP.NPC.MHRAI, "Could not target Mhrai")
        mq.cmd('/keypress hail')
        mq.delay(1500)
        mq.cmd('/target ${Me.Name}')
    elseif idx == 12 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        navLoc(PP.LOC.TIGER, 1000)
        tryGateToPoK()
    elseif idx == 13 then
        ensureZone(PP.ZONE.NQ, "qeynos2", "North Qeynos")
        navLoc(PP.LOC.NQ, 1500)
    elseif idx == 14 then
        ensureZone(PP.ZONE.SQ, "qeynos", "South Qeynos")
        navLoc(PP.LOC.SQ_FISH, 1500)
    elseif idx == 15 then
        ensureZone(PP.ZONE.SQ, "qeynos", "South Qeynos")
        navLoc(PP.LOC.SQ_LION, 1500)
        tryGateToPoK()
    elseif idx == 16 then
        ensureZone(PP.ZONE.WEST_FP, "freeportwest", "West Freeport")
        navLoc(PP.LOC.SLICK, 700)
        targetOrFail(PP.NPC.BIG_SLICK, "Could not target Big Slick Jones")
        mq.cmd('/keypress hail')
        mq.delay(1800)
    else
        fail("Unhandled objective index " .. tostring(idx))
    end
end

--- Main automation: first incomplete objective → runObjectiveStep → waitObjectiveDone (objectiveIsComplete). Same data as getQuestProgress / GUI bar.
local function runQuest()
    syncTaskJournalWindowFull()
    mq.cmd(string.format('/popup Starting: Paintings Playing Poker v%s (init2)', PP.VERSION))
    pauseCWTNPlugins()
    pauseRGMercs()

    local task = getTask()
    if not task then
        unpauseRGMercs()
        unpauseCWTNPlugins()
        gui.status = "Get Quest from Big Slick — no Paintings Playing Poker task in journal."
        warn(gui.status)
        return
    end
    if not taskHasAnyObjectiveRow(task) then
        unpauseRGMercs()
        unpauseCWTNPlugins()
        gui.status = "Get Quest from Big Slick — journal has no objectives for this task yet (open journal or hail Big Slick in West Freeport)."
        warn(gui.status)
        return
    end

    do
        local _, stepStatus, _, hasQuest = getQuestProgress(task)
        if not hasQuest then
            unpauseRGMercs()
            unpauseCWTNPlugins()
            gui.status = "Get Quest from Big Slick — task title mismatch or journal not synced."
            warn(gui.status)
            return
        end
        if stepStatus then
            local resumeIdx = nil
            for i = 1, PP.QUEST_OBJECTIVE_COUNT do
                if not stepStatus[i] then
                    resumeIdx = i
                    break
                end
            end
            if resumeIdx then
                info(string.format("Paintings Playing Poker — progress table: next incomplete objective index %d.", resumeIdx))
            else
                info("Paintings Playing Poker — progress table: all objectives complete.")
            end
        end
    end

    while true do
        shouldStop()
        task = getTask()
        if not task then
            unpauseRGMercs()
            unpauseCWTNPlugins()
            gui.status = "Task became unavailable — stopping."
            warn(gui.status)
            return
        end
        if not taskHasAnyObjectiveRow(task) then
            unpauseRGMercs()
            unpauseCWTNPlugins()
            gui.status = "Get Quest from Big Slick — objectives not visible; open journal or re-hail."
            warn(gui.status)
            return
        end

        local idx, obj = firstIncompleteObjective(task)
        if not idx then
            gui.status = "Quest complete."
            info("All objectives are Done.")
            break
        end

        local instr = objInstruction(task, idx)
        info(string.format("Resume: first incomplete objective %d: %s", idx, instr))
        runObjectiveStep(idx, task)
        if not waitObjectiveDone(PP.QUEST_TITLE, idx, 120000) then
            fail(string.format("Timeout waiting objective %d to complete: %s", idx, instr))
        end
        info(string.format("Objective %d completed.", idx))
        mq.delay(500)
    end

    unpauseRGMercs()
    unpauseCWTNPlugins()
end

local function drawGUI()
    if not gui.open then return end
    if PP.pppokerApplyInitialLayout then
        local condAlways = 1
        if ImGuiCond then
            condAlways = ImGuiCond.Always
        end
        pcall(function()
            local mv = imgui.GetMainViewport()
            if mv and mv.WorkPos then
                imgui.SetNextWindowPos(mv.WorkPos.x + 600, mv.WorkPos.y + 20, condAlways)
            end
        end)
        pcall(function()
            if imgui.SetNextWindowSize then
                imgui.SetNextWindowSize(getImVec2(PP.WINDOW_W, PP.WINDOW_H), condAlways)
            end
        end)
        PP.pppokerApplyInitialLayout = false
    end
    if not PP.texturesLoadedOnce then
        if loadTextures() then
            pickRandomPanel()
        end
        PP.texturesLoadedOnce = true
    end

    local mainPadPushed = false
    if ImGuiStyleVar and ImGuiStyleVar.WindowPadding and imgui.PushStyleVar then
        pcall(function()
            imgui.PushStyleVar(ImGuiStyleVar.WindowPadding, getImVec2(PP.WINDOW_PAD_X, PP.WINDOW_PAD_Y))
            mainPadPushed = true
        end)
    end

    local winFlags = 0
    if ImGuiWindowFlags and ImGuiWindowFlags.NoSavedSettings then
        winFlags = ImGuiWindowFlags.NoSavedSettings
    end
    local okBegin, open, draw = pcall(function()
        return imgui.Begin(string.format("PPPoker v%s###PPPokerV2", PP.VERSION), gui.open, winFlags)
    end)
    if not okBegin then
        open, draw = imgui.Begin(string.format("PPPoker v%s###PPPokerV2", PP.VERSION), gui.open)
    end
    gui.open = open
    if draw then
        local okDraw, errDraw = pcall(function()
            local activeTask, doneObjectives, totalObjectives, percent01, stepStatus
            local hasQuest = false
            if gui.taskJournalPrimed then
                activeTask = getTask()
                percent01, stepStatus, doneObjectives, hasQuest = getQuestProgress(activeTask)
                totalObjectives = PP.QUEST_OBJECTIVE_COUNT
                if not hasQuest then
                    stepStatus = stepStatus or {}
                    for i = 1, totalObjectives do
                        if stepStatus[i] == nil then
                            stepStatus[i] = false
                        end
                    end
                end
                refreshIdleQuestSnapshot(activeTask, doneObjectives, totalObjectives)
            else
                activeTask = nil
                percent01, stepStatus, doneObjectives = 0, {}, 0
                totalObjectives = PP.QUEST_OBJECTIVE_COUNT
                for i = 1, totalObjectives do
                    stepStatus[i] = false
                end
                gui.status = "Syncing task journal…"
                hasQuest = false
            end
            local percent = (percent01 or 0) * 100.0
            local barOpts = ensureObjectiveBarLive()
            barOpts.tickEvery = 1.0 / PP.QUEST_OBJECTIVE_COUNT
            if gui.taskJournalPrimed and stepStatus then
                barOpts.perStepDone = stepStatus
            else
                barOpts.perStepDone = nil
            end

            drawHeaderImage()
            imgui.Text(string.format("Paintings Playing Poker - 23rd Anniversary  (v%s)", PP.VERSION))
            imgui.Separator()
            imgui.Text(string.format("Status: %s", gui.status))
            imgui.Text(string.format("Progress: %d / %d objectives", doneObjectives or 0, totalObjectives or PP.QUEST_OBJECTIVE_COUNT))
            drawObjectiveBar("PPPokerV2ObjectiveBar", percent, BarColors.XPMin, BarColors.XPMax, barOpts)
            if not gui.taskJournalPrimed then
                imgui.Text("Current Objective: — (syncing journal…)")
            elseif gui.questComplete then
                imgui.Text("Current Objective: — (all done)")
            elseif gui.needBigSlickQuest or not activeTask or not hasQuest then
                imgui.Text("Current Objective: — (get quest from Big Slick)")
            else
                imgui.Text(string.format("Current Objective: %d", gui.step or 0))
            end

            if imgui.Button((gui.running and Icons.FA_STOP or Icons.FA_PLAY) .. " " .. (gui.running and "Running" or "Run")) then
                if not gui.running then
                    gui.running = true
                    stopRequested = false
                end
            end
            imgui.SameLine()
            if imgui.Button(Icons.FA_BAN .. " Stop") then
                stopRequested = true
                gui.running = false
                gui.status = "Stopping..."
            end
            imgui.SameLine()
            pppokerDrawDebugToggle()

            imgui.Separator()
            drawCommemorativeCoinsRow()
            imgui.Separator()

            if gui.debugOpen then
                local childOpen = imgui.BeginChild("PPPokerV2Debug", 0, 220)
                if childOpen then
                    for i = math.max(1, #gui.debugLog - 60), #gui.debugLog do
                        imgui.TextWrapped(gui.debugLog[i])
                    end
                    imgui.SetScrollHereY(1.0)
                end
                imgui.EndChild()
            end
        end)
        if not okDraw then
            local em = tostring(errDraw)
            debugLog("GUI draw error: " .. em)
            warn("GUI draw error: " .. em)
        end
    end
    imgui.End()
    if mainPadPushed and imgui.PopStyleVar then
        pcall(function() imgui.PopStyleVar(1) end)
    end
end

primeTaskJournalFromMainLoop()
mq.imgui.init("PPPokerGUIV2", drawGUI)

while gui.open do
    primeTaskJournalFromMainLoop()
    if gui.running then
        gui.running = false
        local ok, err = pcall(runQuest)
        if not ok then
            local em = tostring(err)
            if em:find("Stopped by user", 1, true) then
                gui.status = "Stopped by user."
            else
                gui.status = "Error: " .. em
                print("\ar[PPPoker Lua v2] " .. em .. "\ax")
                debugLog("ERROR: " .. em)
            end
        end
    end
    mq.delay(200)
end

haltNavigationForStop()
if mq.imgui and mq.imgui.destroy then
    pcall(function() mq.imgui.destroy("PPPokerGUIV2") end)
end
