-- pppoker.lua 23rd anniversary task
-- Created by: RedFrog
-- Original creation date: 03/18/2026
-- Quest: https://everquest.allakhazam.com/db/quest.html?quest=10723
-- Version: 0.54
-- Changelog:
-- 0.54: GUI replaced with PicTest-style atlas (`pictest_triptych.png` UV + scaling) + optional ImAnim status bar; `statusbar.lua` copied beside script. Quest logic unchanged.
-- 0.53: Banner size: max(width from content min/max, GetContentRegionAvail, GetWindowContentRegionWidth, GetWindowWidth-padding). Height: min(16:9, ~45% of content, content-70) floor 120px. Default window 480x400.
-- 0.52: Rooster banner via draw-list AddImage (full content width, fixed band height). Dedicated pppoker_popen for Begin (fixes X if gui.open was not reliable). Window taller.
-- 0.51: GUI v2 from scratch: minimal window only (no PNG, Child, draw-list, MageGear). New ID ###PPPokerV2. Backup with full old GUI: init_pppoker_v0_50.lua.
-- 0.50: ImGui.Begin second arg must be persistent gui.open (not literal true) — MQ passes p_open by value each frame; true every call ignored X and kept window open.
-- 0.49: PPPOKER_BACKDROP_MODE default "image" again so rooster shows; "none" intentionally hides PNG. Drawlist falls back to Image if AddImage errors.
-- 0.48: PPPOKER_BACKDROP_MODE: "none" | "image" | "drawlist". CreateTexture+Image often ignores size on some MQ builds.
-- 0.47: Note: require('ImGui') is MacroQuest's one binding — copying MageGear Lua layout is not a different ImGui DLL. Added AB_TEST load of magegear/water.png + optional one-shot size print for diagnosis.
-- 0.46: GUI rewritten MageGear-style (imgui.Begin open/draw, Indent+Image+SetCursorPos backdrop, BeginChild+FrameBg/ChildBg). Prior GUI in init_pppoker_v0_45.lua backup.
-- 0.45: Backdrop size from GetWindowContentRegionMin/Max (full client); cursor pinned to content min before Image — GetContentRegionAvail alone can be ~2/3 if cursor not at origin.
-- 0.44: Backdrop uses ImGui.Image(texId, width, height) with scalar sizes — MQ Lua often ignores ImVec2/AddImage stretch for CreateTexture IDs.
-- 0.43: GUI backdrop uses pppoker_test_420x260.png (matches window size) for scaling/debug; swap PPPOKER_BG_FILENAME for rooster art when done.
-- 0.40: Backdrop uses draw-list AddImageQuad explicit corners/UV to ensure stretching across width.
-- 0.35: Backdrop now expands by ImGui window padding so image fills window sides.
-- 0.34: GUI backdrop updated to roosters poker painting frame.
-- 0.33: GUI backdrop: handle GetWindowPos/GetWindowSize as (x,y) numbers or table (MQ ImGui binding).
-- 0.32: Optional GUI backdrop: pppoker_bg_dogs_playing_poker.png (AI-generated art) via mq.CreateTexture + ImGui draw list.
-- 0.31: Unified task-driven skips: every stage block runs only if tracker still needs this stage or earlier; Neriak hub escape kept as shared helper (not Neriak-only resume logic).
-- 0.30: Mid-run task refresh: skip Neriak Foreign/Commons taverns when already complete; Gate/PoK hop toward Highpass when task is ahead.
-- 0.29: GUI Stop halts /travelto and /nav (plus same when shouldStop() fires).
-- 0.28: Task resume without Task.Count: named ${Task[Paintings...]} lookup (MQ index != UI order); probe slots 1–48; short delay before resume so tracker data is visible.
-- 0.27: Resume: find Poker task by objective text + ${Task[n].Title} parse fallbacks; objective scan tolerates empty leading rows; stage scan runs whenever task index exists but stage maps to 1.
-- 0.26: Quest resume fix: flexible task title match; infer stage from objective Instruction + fuzzy Zone when MQ omits neriaka/neriakb shortnames.
-- 0.25: Stage 3 verification added: Bull Pit/Slug objective progress check with Bull Pit upstairs fallback sweep.
-- 0.24: CWTN pause now checks expected class plugin load first; skip pause/unpause when plugin is not loaded.
-- 0.23: GUI fix: robust cursor position handling + protected draw block to prevent ImGui missing End.
-- 0.22: GUI scaffold added (Run/Stop + animated status/tween bar).
-- 0.21: Quest progress awareness: resume from current task objective zone; task check restart schedules relaunch on fail.
-- 0.18: Pause CWTN via generic `/CWTN pause on|off` (not MQ2Mage-only) so any CWTN plugin is halted.
-- 0.20: RGmerc pause/restore added (pause at start, restore on fail/success).
-- 0.17: Pause CWTN (MQ2Mage) during quest run; restore on fail/success.
-- 0.16: Replaced /casting item clicks with /useitem for compatibility.
-- 0.15: Zueria Slide mode handling: detect any slide, convert to Nektulos with /convertitem, then cast.
-- 0.14: Nav timeout tuning: longer wait + grace recheck to avoid false-fail on near-complete pathing.
-- 0.13: Force PoK reset route before Neriak travel after grog (avoid Hodstock-only path failures).
-- 0.12: Neriak fallback adds Gate-to-PoK route (if AA+PoK bind), with clearer retry logging.
-- 0.11: Mount keyring slot check now uses mq.parse("${Mount[1].Name}") to match in-game /echo behavior.
-- 0.10: Mount logic is now keyring slot 1 only (removed Ammo-slot fallback).
-- 0.09: Neriak travel hardening after grog: no-slide run fallback via Nektulos with retries.
-- 0.08: PoK bind check: preflight status; if unbound, travel to PoK, nav to Soulbinder Jera, /say Bind.
-- 0.07: Preflight: show speed-helper items checklist + detected status.
-- 0.06: Preflight + item/spell checks (Nav plugin, mount keyring slot 1, Gate AA/bind, gate potion).
-- 0.05: Mount pre-check: prefer mount keyring slot 1, fallback to Ammo slot; skip mounting bards.
-- 0.04: Header: "Created by" corrected to match workspace standard.
-- 0.03: Header formatting aligned with Warportal style (quest above changelog).
-- 0.02: NPC targeting robustness (quest-accurate name targeting + fail-fast).
-- 0.01: init.lua entrypoint; bounded gate retries/timeouts; navigation/zone wait timeouts.

-- To-Do (working):
-- targeting hardening (avoid unnecessary retarget spam)
-- use relocate
-- add Onlyloot or looly off
-- add invis for lower level
-- add speed buff checks
-- add run to pok if no gate/potion after last neriak stage
-- add currency status upon success
-- Gate Section fix (done: bounded gate code/potion retries + timeouts)

local mq = require('mq')

local VERSION = "0.54"

local GATE_ZONE_ID = 202
local POK_TRAVEL_SHORTNAME = "poknowledge"
local POK_SOULBINDER_LOC_X = -131.6
local POK_SOULBINDER_LOC_Y = -94.2
local POK_SOULBINDER_LOC_Z = -159.0
local GATE_ALT_ACT_ID = 1217
local GATE_POTION_NAME = "Philter of Major Translocation"
local ZUERIA_SLIDE_BASE = "Zueria Slide"
local ZUERIA_TARGET_MODE = "Nektulos"

local MOUNT_KEYRING_SLOT = 1

-- NPCs (quest naming is exact; keep fallbacks for older/partial spawns)
local NPC_BIG_SLICK_JONES = { "Big Slick Jones", "Slick" }
local NPC_BLUFFING_BETTY = { "Bluffing Betty", "Bluffing" }
local NPC_QUINN_OF_QUADS = { "Quinn of Quads", "Quads" }
local NPC_MHRAI_QUEEN_OF_TAILS = { "Mhrai, Queen of Tails", "Queen", "Mhrai" }
local NPC_SOULBINDER_JERA = { "Soulbinder Jera", "Jera" }

local cwtnState = { pausedApplied = false }

local QUEST_TITLE = "Paintings Playing Poker"

local restartState = { scheduled = false }

--- MQ sometimes leaves blank objective rows before real data; stop after this many consecutive empties.
local TASK_OBJECTIVE_EMPTY_STREAK_MAX = 5

--- Set in getActivePokerTaskIndex so computeStartStage can log how the task was found.
local pokerResumeTaskSource = nil

--- MQ docs: task list order in memory != quest window order; Task.Count is often 0 on Live. Probe this many slots.
local TASK_SLOT_MAX = 48

local function normalizeTaskTitle(s)
    s = tostring(s or ""):lower()
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

--- True if this task slot looks like Paintings Playing Poker (Live title may include anniversary prefix).
local function taskTitleLooksLikePaintingsPoker(titleRaw)
    local t = normalizeTaskTitle(titleRaw)
    if t == "" then return false end
    if t:find("paintings playing poker", 1, true) then return true end
    if t:find("paintings", 1, true) and t:find("poker", 1, true) then return true end
    return false
end

local function safeParseNum(expr)
    local ok, val = pcall(function() return mq.parse(expr) end)
    if not ok or val == nil then return nil end
    local s = tostring(val)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "NULL" then return nil end
    local n = tonumber(s)
    return n
end

local function safeParseStr(expr)
    local ok, val = pcall(function() return mq.parse(expr) end)
    if not ok or val == nil then return nil end
    local s = tostring(val)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "NULL" then return nil end
    return s
end

local function getTaskCount()
    local ok, count = pcall(function() return mq.TLO.Task.Count() end)
    local c = (ok and tonumber(count)) or 0
    if c > 0 then return c end
    local n = 0
    for i = 1, TASK_SLOT_MAX do
        local id = safeParseNum(string.format("${Task[%d].ID}", i))
        if id and id > 0 then n = n + 1 end
    end
    if n > 0 then return n end
    for i = 1, TASK_SLOT_MAX do
        local tit = safeParseStr(string.format("${Task[%d].Title}", i))
        if tit and tit ~= "" then n = n + 1 end
    end
    return n
end

--- Build ${Task[ref].Objective[n].Field} — ref may be numeric slot or string key (partial name match per MQ docs).
local function taskObjectiveExpr(taskRef, objIdx, field)
    local mid
    if type(taskRef) == "number" then
        mid = string.format("Task[%d].Objective[%d].%s", taskRef, objIdx, field)
    else
        mid = string.format("Task[%s].Objective[%d].%s", taskRef, objIdx, field)
    end
    return "${" .. mid .. "}"
end

--- TLO Title() can be empty while ${Task[n].Title} (or similar) still works on some builds.
local function getTaskTitleForSlot(i)
    local t = mq.TLO.Task(i)
    if not t or not t() then return "" end
    local title = ""
    pcall(function()
        -- MQ Task datatype docs expose `.Title`. Don't query other members here.
        title = t.Title() or title
    end)
    title = tostring(title or "")
    if title ~= "" and title ~= "NULL" then return title end
    local s = safeParseStr(string.format("${Task[%d].Title}", i))
    if s and s ~= "" then return s end
    return ""
end

--- Resolve via ${Task[key]} substring match (see MQ datatype-task docs). Order: most specific first.
local NAMED_POKER_TASK_KEYS = {
    "Paintings Playing Poker",
    "23rd Anniversary: Paintings Playing Poker",
    "Playing Poker",
    "Paintings",
}

local function tryNamedPaintingsTaskRef()
    for _, key in ipairs(NAMED_POKER_TASK_KEYS) do
        local title = safeParseStr(string.format("${Task[%s].Title}", key))
        if title and taskTitleLooksLikePaintingsPoker(title) then
            return key
        end
    end
    return nil
end

local function taskSlotAppearsOccupied(i)
    local t = mq.TLO.Task(i)
    if t and t() then return true end
    local id = safeParseNum(string.format("${Task[%d].ID}", i))
    if id and id > 0 then return true end
    local tit = safeParseStr(string.format("${Task[%d].Title}", i))
    return tit and tit ~= ""
end

--- If title matching fails, fingerprint this anniversary task from objective Instruction/Zone text across the tracker slot.
local function findPokerTaskIndexByObjectives()
    for i = 1, TASK_SLOT_MAX do
        local id = safeParseNum(string.format("${Task[%d].ID}", i))
        local tit = safeParseStr(string.format("${Task[%d].Title}", i))
        local o1 = safeParseStr(taskObjectiveExpr(i, 1, "Instruction")) or ""
        if (not id or id <= 0) and (not tit or tit == "") and o1 == "" then
            -- empty slot; skip heavy objective walk
        else
            local streak = 0
            local parts = {}
            for o = 1, 24 do
                local instr = safeParseStr(taskObjectiveExpr(i, o, "Instruction")) or ""
                local zone = safeParseStr(taskObjectiveExpr(i, o, "Zone")) or ""
                if instr == "" and zone == "" then
                    streak = streak + 1
                    if streak >= TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
                else
                    streak = 0
                    parts[#parts + 1] = instr
                    parts[#parts + 1] = zone
                end
            end
            local blob = table.concat(parts, " "):lower()
            if blob == "" then
                -- skip
            elseif blob:find("paintings", 1, true) and blob:find("poker", 1, true) then
                return i
            elseif blob:find("bull", 1, true) and blob:find("pit", 1, true) then
                return i
            elseif blob:find("bluffing betty", 1, true) then
                return i
            elseif blob:find("quin", 1, true) and blob:find("quad", 1, true) then
                return i
            elseif blob:find("blind fish", 1, true) then
                return i
            elseif blob:find("toadstool", 1, true) then
                return i
            elseif blob:find("big slick", 1, true) and blob:find("paint", 1, true) then
                return i
            elseif blob:find("memento grog", 1, true) and blob:find("paint", 1, true) then
                return i
            elseif blob:find("svunsa", 1, true) then
                return i
            elseif blob:find("slug", 1, true) and (blob:find("tavern", 1, true) or blob:find("neriak", 1, true)) then
                return i
            end
        end
    end
    return nil
end

local function getActivePokerTaskIndex()
    pokerResumeTaskSource = nil
    local named = tryNamedPaintingsTaskRef()
    if named then
        pokerResumeTaskSource = "title"
        return named
    end
    for i = 1, TASK_SLOT_MAX do
        if taskSlotAppearsOccupied(i) then
            local title = getTaskTitleForSlot(i)
            if taskTitleLooksLikePaintingsPoker(title) then
                pokerResumeTaskSource = "title"
                return i
            end
        end
    end
    local byObj = findPokerTaskIndexByObjectives()
    if byObj then
        pokerResumeTaskSource = "objectives"
        return byObj
    end
    return nil
end

-- Returns: totalObjectives, doneObjectives, activeObjectiveZoneShort, activeObjectiveInstruction
local function getPokerTaskProgress()
    local taskIndex = getActivePokerTaskIndex()
    if not taskIndex then return nil end

    local total = 0
    local done = 0
    local activeZone = nil
    local activeInstr = nil
    local streak = 0

    for objIdx = 1, 30 do
        local req = safeParseNum(taskObjectiveExpr(taskIndex, objIdx, "RequiredCount")) or 0
        local cur = safeParseNum(taskObjectiveExpr(taskIndex, objIdx, "CurrentCount")) or 0
        local zone = safeParseStr(taskObjectiveExpr(taskIndex, objIdx, "Zone"))
        local instr = safeParseStr(taskObjectiveExpr(taskIndex, objIdx, "Instruction"))
        local zempty = (not zone or zone == "")
        local iempty = (not instr or instr == "")

        if zempty and iempty then
            streak = streak + 1
            if streak >= TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
        else
            streak = 0
        end

        if zempty and iempty then
            -- skip blank row
        elseif req > 0 then
            total = total + 1
            if cur >= req then
                done = done + 1
            elseif not activeZone then
                activeZone = zone
                activeInstr = instr
            end
        elseif instr and instr ~= "" then
            -- Some objectives may not expose RequiredCount in the same way; count by instruction presence.
            total = total + 1
            if cur > 0 then done = done + 1 end
            if not activeZone then
                activeZone = zone
                activeInstr = instr
            end
        end
    end

    return {
        taskIndex = taskIndex,
        total = total,
        done = done,
        activeZone = activeZone,
        activeInstr = activeInstr,
    }
end

local function zoneIdToStage(zoneId)
    if zoneId == 383 then return 1 end -- West Freeport
    if zoneId == 382 then return 2 end -- East Freeport
    if zoneId == 40 then return 3 end  -- Neriak Foreign Quarter
    if zoneId == 41 then return 4 end  -- Neriak Commons
    if zoneId == 407 then return 5 end -- Highpass Hold
    if zoneId == 2 then return 6 end   -- North Qeynos
    if zoneId == 1 then return 7 end   -- South Qeynos
    return 1
end

-- Forward declarations so helpers defined earlier can safely call info/warn.
local info, warn

local function normalizeZoneShort(z)
    z = tostring(z or ""):lower()
    z = z:gsub("%s+", "")
    return z
end

local function stageFromObjectiveZone(zoneShort, done, total)
    local z = normalizeZoneShort(zoneShort)
    if z == "freeporteast" then return 2 end
    if z == "neriaka" then return 3 end
    if z == "neriakb" then return 4 end
    if z == "highpasshold" then return 5 end
    if z == "qeynos2" then return 6 end
    if z == "qeynos" then return 7 end
    if z == "freeportwest" then
        if total and total > 0 and done and done >= (total - 1) then
            return 8
        end
        return 1
    end
    -- default for unknown/empty zones
    return 1
end

--- When Objective.Zone is empty or a non-standard string, map from Instruction text (Live wording varies).
local function stageFromObjectiveInstruction(instr, _done, _total)
    local t = tostring(instr or ""):lower()
    if t == "" then return nil end
    -- Stage 2 East Freeport
    if t:find("bluffing betty", 1, true) or t:find("crab and grog", 1, true) then return 2 end
    if t:find("tassel", 1, true) and t:find("tavern", 1, true) then return 2 end
    -- Stage 3 Neriak Foreign Quarter (wording varies: "The Bull Pit", typos, etc.)
    if t:find("bull", 1, true) and t:find("pit", 1, true) then return 3 end
    if t:find("svunsa", 1, true) then return 3 end
    if t:find("slug", 1, true) then return 3 end
    -- Stage 4 Neriak Commons
    if t:find("blind fish", 1, true) or t:find("marenkor", 1, true) then return 4 end
    if t:find("toadstool", 1, true) or t:find("rista", 1, true) then return 4 end
    -- Stage 5 Highpass
    if t:find("highpass", 1, true) then return 5 end
    if t:find("quin", 1, true) and t:find("quad", 1, true) then return 5 end
    -- Stage 6 / 7 Qeynos
    if t:find("north qeynos", 1, true) then return 6 end
    if t:find("south qeynos", 1, true) then return 7 end
    -- Stage 8 return to Slick
    if t:find("big slick", 1, true) then return 8 end
    if t:find("return", 1, true) and t:find("freeport", 1, true) then return 8 end
    return nil
end

--- Extra zone-string variants (spaces stripped) when ${Task[].Objective[].Zone} is not exactly neriaka/neriakb.
local function stageFromObjectiveZoneFuzzy(zoneShort, done, total)
    local z = normalizeZoneShort(zoneShort)
    if z == "" then return 1 end
    if z:find("freeporte", 1, true) and not z:find("west", 1, true) then return 2 end
    if z:find("neriak", 1, true) then
        if z == "neriakb" or z:find("common", 1, true) then return 4 end
        if z == "neriaka" or z:find("foreign", 1, true) then return 3 end
    end
    if z:find("highpass", 1, true) then return 5 end
    if z == "qeynos2" then return 6 end
    if z == "qeynos" then return 7 end
    if z:find("freeportwest", 1, true) then
        return stageFromObjectiveZone("freeportwest", done, total)
    end
    return 1
end

local function inferResumeStageFromProgress(progress)
    local done = progress.done or 0
    local total = progress.total or 0
    local zone = progress.activeZone
    local instr = progress.activeInstr

    local s = stageFromObjectiveZone(zone, done, total)
    if s ~= 1 then return s end
    s = stageFromObjectiveZoneFuzzy(zone, done, total)
    if s ~= 1 then return s end
    local fromInstr = stageFromObjectiveInstruction(instr, done, total)
    if fromInstr then return fromInstr end
    return 1
end

--- If first incomplete row still maps to stage 1, scan rows and use any row that maps to 2–8.
local function findStageByScanningObjectives(taskIndex, done, total)
    if not taskIndex then return nil end
    local streak = 0
    for objIdx = 1, 30 do
        local req = safeParseNum(taskObjectiveExpr(taskIndex, objIdx, "RequiredCount")) or 0
        local cur = safeParseNum(taskObjectiveExpr(taskIndex, objIdx, "CurrentCount")) or 0
        local zone = safeParseStr(taskObjectiveExpr(taskIndex, objIdx, "Zone"))
        local instr = safeParseStr(taskObjectiveExpr(taskIndex, objIdx, "Instruction"))
        local zempty = (not zone or zone == "")
        local iempty = (not instr or instr == "")
        if zempty and iempty then
            streak = streak + 1
            if streak >= TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
        else
            streak = 0
            local incomplete = false
            if req > 0 then
                incomplete = (cur < req)
            elseif instr and instr ~= "" then
                incomplete = (cur <= 0)
            end
            if incomplete then
                local s = stageFromObjectiveZone(zone, done, total)
                if s == 1 then s = stageFromObjectiveZoneFuzzy(zone, done, total) end
                if s == 1 then s = stageFromObjectiveInstruction(instr, done, total) or 1 end
                if s ~= 1 then return s end
            end
        end
    end
    return nil
end

local function computeStartStage()
    local progress = getPokerTaskProgress()
    if progress then
        if pokerResumeTaskSource == "objectives" then
            info("Poker task found by scanning objective text (task title was empty or did not match).")
        end
        info(string.format("Task progress detected: %d/%d objectives done", progress.done or 0, progress.total or 0))
        if progress.total and progress.total > 0 and progress.done >= progress.total then
            return 8, true -- completed
        end
        info(string.format("Resume: active zone=%s instr=%s", tostring(progress.activeZone), tostring(progress.activeInstr)))
        local stage = inferResumeStageFromProgress(progress)
        -- Always re-scan objectives when we still map to stage 1 (covers total==0 parse quirks and first-row blanks).
        if stage == 1 and progress.taskIndex then
            local alt = findStageByScanningObjectives(progress.taskIndex, progress.done, progress.total)
            if alt then
                info(string.format("Resume: objective scan mapped to stage %d", alt))
                stage = alt
            elseif (progress.total or 0) > 0 and (progress.done or 0) < (progress.total or 0) then
                warn("Resume: could not map incomplete objective to a stage (zone/instr unrecognized); defaulting to stage 1.")
            end
        end
        return stage, false
    end
    local tcTlo = 0
    pcall(function()
        tcTlo = tonumber(mq.TLO.Task.Count() or 0) or 0
    end)
    local tcProbe = getTaskCount()
    warn(string.format(
        "Resume: Poker task not found (TLO Task.Count=%d, slots with parse data=%d). Open Quest Journal (active tasks) and try again; MQ uses ${Task[name]} not UI order. Using zone-based stage.",
        tcTlo,
        tcProbe
    ))
    -- fallback: infer from current zone
    return zoneIdToStage(mq.TLO.Zone.ID()), false
end

--- Re-read quest task for resume stage without log spam (call after hail/spawn updates).
local function computeResumeStageQuiet()
    local progress = getPokerTaskProgress()
    if not progress then
        return zoneIdToStage(mq.TLO.Zone.ID()), false
    end
    if progress.total and progress.total > 0 and progress.done >= progress.total then
        return 8, true
    end
    local stage = inferResumeStageFromProgress(progress)
    if stage == 1 and progress.taskIndex then
        local alt = findStageByScanningObjectives(progress.taskIndex, progress.done, progress.total)
        if alt then stage = alt end
    end
    return stage, false
end

--- Run a stage block only while the task's first incomplete objective maps to this stage or an earlier one.
--- Example: if task is already at Highpass (5), needNow=5 → skip stages 1–4 (needNow <= 4 is false).
--- When all objectives parse as done (qc), still allow stage 8 so return hail can run if the run reached it.
local function taskNeedsStageBlockOrEarlier(stageNum)
    local need, qc = computeResumeStageQuiet()
    if qc then
        if stageNum == 8 then return true, need, true end
        return false, need, true
    end
    return need <= stageNum, need, false
end

local function getPokerDoneCount()
    local p = getPokerTaskProgress()
    if not p then return 0 end
    return tonumber(p.done) or 0
end

local function firstIncompleteObjectiveText()
    local progress = getPokerTaskProgress()
    if not progress or not progress.taskIndex then return nil end
    local taskIndex = progress.taskIndex
    local streak = 0
    for objIdx = 1, 30 do
        local req = safeParseNum(taskObjectiveExpr(taskIndex, objIdx, "RequiredCount")) or 0
        local cur = safeParseNum(taskObjectiveExpr(taskIndex, objIdx, "CurrentCount")) or 0
        local instr = safeParseStr(taskObjectiveExpr(taskIndex, objIdx, "Instruction"))
        local zone = safeParseStr(taskObjectiveExpr(taskIndex, objIdx, "Zone"))
        local zempty = (not zone or zone == "")
        local iempty = (not instr or instr == "")
        if zempty and iempty then
            streak = streak + 1
            if streak >= TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
        else
            streak = 0
            if req > 0 and cur < req then
                return string.format("%s (%d/%d) in %s", instr or "Objective", cur, req, zone or "unknown zone")
            end
        end
    end
    return nil
end

local function scheduleRestart()
    if restartState.scheduled then return end
    restartState.scheduled = true
    mq.cmd('/timed 10 /lua run pppoker')
end

local function expectedCWTNPluginName()
    local short = (mq.TLO.Me.Class.ShortName() or ""):upper()
    local map = {
        BER = "MQ2BerZerker",
        BST = "MQ2Bst",
        BRD = "MQ2Bard",
        CLR = "MQ2Cleric",
        DRU = "MQ2Druid",
        ENC = "MQ2Enchanter",
        MAG = "MQ2Mage",
        MNK = "MQ2Monk",
        NEC = "MQ2Necro",
        PAL = "MQ2Paladin",
        RNG = "MQ2Ranger",
        ROG = "MQ2Rogue",
        SHD = "MQ2Eskay",
        SHM = "MQ2Shaman",
        WAR = "MQ2War",
        WIZ = "MQ2Wizard",
    }
    return map[short]
end

local function isExpectedCWTNPluginLoaded()
    local pluginName = expectedCWTNPluginName()
    if not pluginName then return false, nil end
    local ok, loaded = pcall(function()
        local p = mq.TLO.Plugin(pluginName)
        return p and p.IsLoaded and p.IsLoaded()
    end)
    return (ok and loaded == true), pluginName
end

local function pauseCWTNPlugins()
    -- Only pause when this toon's expected CWTN class plugin is loaded.
    local loaded, pluginName = isExpectedCWTNPluginLoaded()
    if not loaded then
        warn(string.format("CWTN pause skipped: expected plugin not loaded (%s)", pluginName or "unknown"))
        return false
    end

    -- Generic CWTN pause should stop any active CWTN plugin for this character.
    mq.cmd('/CWTN pause on')
    cwtnState.pausedApplied = true
    info("CWTN paused via /CWTN pause on (plugin: " .. pluginName .. ")")
    return true
end

local function unpauseCWTNPlugins()
    if not cwtnState.pausedApplied then return end
    local loaded = isExpectedCWTNPluginLoaded()
    if not loaded then
        cwtnState.pausedApplied = false
        return
    end
    mq.cmd('/CWTN pause off')
    cwtnState.pausedApplied = false
end

local rgmercState = { pausedApplied = false }

local function pauseRGMercs()
    -- RGMercs Lua: pause so quest handoffs/binds aren't interrupted.
    local ok, status = pcall(function() return mq.TLO.Lua.Script('rgmercs').Status() end)
    if ok and status == 'RUNNING' then
        mq.cmd('/rgm pauseall')
        rgmercState.pausedApplied = true
    end
end

local function unpauseRGMercs()
    if not rgmercState.pausedApplied then return end
    mq.cmd('/rgm unpauseall')
    rgmercState.pausedApplied = false
end

local function fail(msg)
    mq.cmd('/popup "' .. msg .. '"')
    print(msg)
    unpauseCWTNPlugins() -- ensure CWTN resumes on failure when applicable
    unpauseRGMercs()
    scheduleRestart()
    error(msg)
end

-- Forward declarations (Lua locals must exist before first use)
local mountKeyringSlot1Name

info = function(msg)
    print(string.format("\ao[\agPPPoker\ao]\at %s", msg))
end

warn = function(msg)
    print(string.format("\ao[\ayPPPoker\ao]\at %s", msg))
end

local function isNavLoaded()
    local ok, loaded = pcall(function() return mq.TLO.Plugin('MQ2Nav').IsLoaded() end)
    return ok and loaded
end

local function hasGateAA()
    local ok, id = pcall(function() return mq.TLO.Me.AltAbility('Gate').ID() end)
    return ok and tonumber(id or 0) > 0
end

local function boundToGateZone()
    local ok, zid = pcall(function() return mq.TLO.Me.ZoneBound.ID() end)
    return ok and tonumber(zid or 0) == GATE_ZONE_ID
end

local function hasGatePotion()
    local ok, found = pcall(function() return mq.TLO.FindItem(GATE_POTION_NAME)() end)
    return ok and found
end

local function hasItem(name)
    local ok, found = pcall(function() return mq.TLO.FindItem(name)() end)
    return ok and found
end

local function getZueriaSlideName()
    local ok, name = pcall(function() return mq.TLO.FindItem(ZUERIA_SLIDE_BASE).Name() end)
    if not ok or not name or name == "" then return nil end
    return tostring(name)
end

local function ensureZueriaMode(targetMode)
    targetMode = targetMode or ZUERIA_TARGET_MODE
    local current = getZueriaSlideName()
    if not current then return nil end
    if current:find(targetMode, 1, true) then
        return current
    end

    for attempt = 1, 8 do
        info(string.format("Converting %s (attempt %d/8) toward mode: %s", current, attempt, targetMode))
        mq.cmdf('/convertitem "%s"', current)
        mq.delay(1500)
        current = getZueriaSlideName()
        if not current then return nil end
        if current:find(targetMode, 1, true) then
            info("Zueria Slide mode ready: " .. current)
            return current
        end
    end

    warn("Could not convert Zueria Slide to mode: " .. targetMode)
    return current
end

local function preflight()
    info("Version " .. VERSION .. " starting preflight checks...")

    if not isNavLoaded() then
        fail("Preflight failed: MQ2Nav plugin not loaded (required for /nav).")
    end

    info("Speed helpers (optional, but faster runs):")

    -- Mount: we prefer mount keyring slot 1, but can fall back to legacy Ammo mount.
    local mName = mountKeyringSlot1Name and mountKeyringSlot1Name() or nil
    if mName then
        info('- Mount keyring slot ' .. MOUNT_KEYRING_SLOT .. ': ' .. mName .. ' (will use)')
    else
        warn('- Mount keyring slot ' .. MOUNT_KEYRING_SLOT .. ': not found (mounting disabled until slot is set)')
    end

    if hasItem("Guise of the Deceiver") then
        info("- Guise of the Deceiver: found (used for shrink if you're tall)")
    else
        warn("- Guise of the Deceiver: not found (shrink step may be slower/harder)")
    end

    local slideName = getZueriaSlideName()
    if slideName and slideName:find(ZUERIA_TARGET_MODE, 1, true) then
        info('- Zueria Slide: ' .. slideName .. ' (ready)')
    elseif slideName then
        warn('- Zueria Slide: ' .. slideName .. ' (will convert to ' .. ZUERIA_TARGET_MODE .. ' when needed)')
    else
        warn('- Zueria Slide: not found (will rely on /travelto pathing)')
    end

    -- Gate sanity: not required, but warns if neither option is likely to work.
    if hasGateAA() then
        if boundToGateZone() then
            info("- Gate AA: detected and bound to zone " .. GATE_ZONE_ID .. " (fast return)")
        else
            warn("- Gate AA: detected but NOT bound to zone " .. GATE_ZONE_ID .. " (may not help these steps)")
        end
    else
        warn("- Gate AA: not detected (gate steps rely on potion/other travel)")
    end

    if hasGatePotion() then
        info('- Gate potion: found (' .. GATE_POTION_NAME .. ')')
    else
        warn('- Gate potion: not found (' .. GATE_POTION_NAME .. ')')
    end

    if boundToGateZone() then
        info("- PoK bind (zone " .. GATE_ZONE_ID .. "): OK — Gate/potion can return to hub")
    else
        warn("- PoK bind: missing — will travel to Plane of Knowledge and bind at Soulbinder Jera before quest start")
    end

    info("Preflight OK.")
end

local function isMounted()
    local ok, mountID = pcall(function() return mq.TLO.Me.Mount.ID() end)
    return ok and tonumber(mountID or 0) > 0
end

local function classIsBard()
    local ok, short = pcall(function() return mq.TLO.Me.Class.ShortName() end)
    if not ok or not short then return false end
    return tostring(short):upper() == "BRD"
end

mountKeyringSlot1Name = function()
    -- Match your known-good in-game check exactly: /echo ${Mount[1].Name}
    local ok, name = pcall(function()
        return mq.parse(string.format('${Mount[%d].Name}', MOUNT_KEYRING_SLOT))
    end)
    if ok and name then
        name = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" and name ~= "NULL" then
            return name
        end
    end
    return nil
end

local function mountIfNeeded()
    if isMounted() then return true end
    if classIsBard() then
        -- Bards tend to run faster via songs; mounting can be slower/interruptive.
        return false
    end

    local mountName = mountKeyringSlot1Name()
    if mountName then
        info('Mounting (keyring slot ' .. MOUNT_KEYRING_SLOT .. '): ' .. mountName)
        -- Use macro-style expansion too (matches your working snippet).
        mq.cmd('/useitem ${Mount[' .. tostring(MOUNT_KEYRING_SLOT) .. ']}')
        return true
    end

    warn('Mount keyring slot ' .. MOUNT_KEYRING_SLOT .. ' not found; skipping mount (keyring-only mode)')
    return false
end

local function dismountIfMounted(reason)
    if not isMounted() then return false end
    if reason and reason ~= "" then
        info("Dismounting: " .. tostring(reason))
    else
        info("Dismounting")
    end
    mq.cmd('/dismount')
    mq.delay(500)
    return true
end

local function waitForZoneOrFalse(zoneId, timeoutMs)
    local start = os.time()
    timeoutMs = timeoutMs or 120000
    while mq.TLO.Zone.ID() ~= zoneId do
        mq.delay(1000)
        if (os.time() - start) * 1000 > timeoutMs then
            return false
        end
    end
    return true
end

local function travelToOrFail(travelToArg, zoneId, label, attempts, timeoutMs)
    attempts = attempts or 2
    timeoutMs = timeoutMs or 120000
    label = label or travelToArg

    for attempt = 1, attempts do
        info(string.format("Travel: %s (attempt %d/%d)", label, attempt, attempts))
        mq.cmdf('/squelch /travelto %s', travelToArg)
        if waitForZoneOrFalse(zoneId, timeoutMs) then
            return true
        end
        warn("Travel did not zone in time; stopping travel/nav and retrying...")
        mq.cmd('/squelch /travelto stop')
        mq.cmd('/squelch /nav stop')
        mq.delay(1000)
    end

    fail("Travel failed: could not zone to " .. label .. " (zone " .. tostring(zoneId) .. ")")
end

local function normName(s)
    if not s then return "" end
    s = tostring(s)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end

local function targetMatchesNames(names)
    if not (mq.TLO.Target and mq.TLO.Target()) then return false end

    local targetName = nil
    do
        local ok, clean = pcall(function() return mq.TLO.Target.CleanName() end)
        if ok and clean and clean ~= "" then
            targetName = clean
        else
            ok, targetName = pcall(function() return mq.TLO.Target.Name() end)
            if not ok then targetName = nil end
        end
    end

    if not targetName or targetName == "" then return false end

    local tn = normName(targetName)
    for _, name in ipairs(names) do
        local nn = normName(name)
        if nn ~= "" and (tn == nn or tn:find(nn, 1, true) or nn:find(tn, 1, true)) then
            return true
        end
    end
    return false
end

local function targetByNames(names, timeout_ms)
    timeout_ms = timeout_ms or 4000
    local start = os.time()
    while (os.time() - start) * 1000 <= timeout_ms do
        for _, name in ipairs(names) do
            if name and name ~= "" then
                mq.cmdf('/target "%s"', name)
                mq.delay(250)
                if targetMatchesNames(names) then
                    return true
                end
            end
        end
        mq.delay(250)
    end
    return false
end

local function targetOrFail(names, failMsg, timeout_ms)
    if not targetByNames(names, timeout_ms) then
        fail(failMsg or "Failed to acquire expected NPC target")
    end
end

local function moving(timeout_ms)
    timeout_ms = timeout_ms or 120000
    local start = os.time()
    while mq.TLO.Nav.Active() do
        mq.delay(100)
        if (os.time() - start) * 1000 > timeout_ms then
            -- Some routes complete a moment after timeout; give Nav a short grace window.
            warn('Navigation timeout threshold reached; waiting grace period...')
            mq.delay(5000)
            if mq.TLO.Nav.Active() then
                fail('Navigation timeout waiting for Nav.Active() to clear')
            end
            return true
        end
    end
    return true
end

local function zoning(z_id, timeout_ms)
    timeout_ms = timeout_ms or 120000
    local start = os.time()
    while mq.TLO.Zone.ID() ~= z_id do
        mq.delay(1000)
        if (os.time() - start) * 1000 > timeout_ms then
            fail('Zoning timeout waiting for zone ' .. tostring(z_id))
        end
    end
    return true
end

-- Ensures character is bound in Plane of Knowledge (zone 202) for Gate AA / gate potion hub returns.
local function ensurePokBind()
    if boundToGateZone() then
        info("PoK bind OK (zone " .. GATE_ZONE_ID .. ").")
        return
    end

    warn("No PoK bind; travelling to Plane of Knowledge to bind with Soulbinder Jera...")
    if mq.TLO.Zone.ID() ~= GATE_ZONE_ID then
        mq.cmd('/squelch /travelto ' .. POK_TRAVEL_SHORTNAME)
        zoning(GATE_ZONE_ID)
    end
    mq.delay(1000)
    mq.cmdf('/squelch /nav locyxz %.1f %.1f %.1f', POK_SOULBINDER_LOC_X, POK_SOULBINDER_LOC_Y, POK_SOULBINDER_LOC_Z)
    moving()
    mq.delay(1000)
    targetOrFail(NPC_SOULBINDER_JERA, "Could not target Soulbinder Jera for PoK bind")
    mq.delay(500)
    mq.cmd('/face fast')
    mq.cmd('/say Bind')
    mq.delay(5000)
    if boundToGateZone() then
        info("PoK bind acquired.")
    else
        warn("PoK bind may not have completed; verify in-game. Continuing quest.")
    end
end

-- Returns false on timeout instead of hard-failing (for retry loops).
local function wait_for_zone_soft(z_id, timeout_ms)
    timeout_ms = timeout_ms or 45000
    local start = os.time()
    while mq.TLO.Zone.ID() ~= z_id do
        mq.delay(1000)
        if (os.time() - start) * 1000 > timeout_ms then
            return false
        end
    end
    return true
end

local function try_gate_code(max_attempts)
    for _ = 1, max_attempts do
        if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == GATE_ZONE_ID then
            mq.cmd('/alt act ' .. tostring(GATE_ALT_ACT_ID))
            mq.delay(10000)
            if wait_for_zone_soft(GATE_ZONE_ID, 40000) then
                zoning(GATE_ZONE_ID)
                return true
            end
        end
    end
    return false
end

local function gateToPokIfAvailable()
    if not hasGateAA() then return false end
    if not boundToGateZone() then return false end
    if mq.TLO.Me.AltAbilityReady('Gate')() then
        warn("Fallback: using Gate AA to return to PoK hub for travel reset...")
        mq.cmd('/alt act ' .. tostring(GATE_ALT_ACT_ID))
        mq.delay(10000)
        return waitForZoneOrFalse(GATE_ZONE_ID, 60000)
    end
    return false
end

local function try_gate_potion(max_attempts)
    if not mq.TLO.FindItem(GATE_POTION_NAME)() then
        return false
    end
    for _ = 1, max_attempts do
        if mq.TLO.Me.ZoneBound.ID() == GATE_ZONE_ID then
            mq.cmd('/useitem "' .. GATE_POTION_NAME .. '"')
            mq.delay(12000)
            if wait_for_zone_soft(GATE_ZONE_ID, 45000) then
                zoning(GATE_ZONE_ID)
                return true
            end
        end
    end
    return false
end

--- If task is past Commons (stage 5+) but character is still in Neriak (40/41), Gate or /travelto PoK. Used from any skipped stage — not only "Neriak resume."
local function leaveNeriakTowardHubIfNeeded()
    local need, qc = computeResumeStageQuiet()
    if qc or need < 5 then return end
    local z = mq.TLO.Zone.ID()
    if z ~= 40 and z ~= 41 then return end
    info("Task ahead of Neriak Commons — leaving Neriak (Gate or PoK) for next zone.")
    dismountIfMounted("Leaving Neriak for hub travel")
    if try_gate_code(2) then return end
    if try_gate_potion(2) then return end
    mq.cmd('/squelch /travelto poknowledge')
    if not waitForZoneOrFalse(GATE_ZONE_ID, 180000) then
        warn("Could not reach PoK from Neriak; you may need to travel manually toward Highpass route.")
    end
end

local stopRequested = false
local gui = {
    open = true,
    running = false,
    status = "Idle",
    stage = 1,
}

--- Stop EasyFind /travelto and MQ2Nav so the character quits moving when user hits Stop.
local function haltNavigationForStop()
    mq.cmd('/squelch /travelto stop')
    mq.cmd('/squelch /nav stop')
end

local function shouldStop()
    if stopRequested then
        gui.status = "Stopped."
        haltNavigationForStop()
        mq.cmd('/popup "PPPoker stopped by user"')
        unpauseRGMercs()
        unpauseCWTNPlugins()
        error("Stopped by user")
    end
    return false
end

local function setGuiStage(stage, status)
    gui.stage = stage
    if status and status ~= "" then
        gui.status = status
    end
end

local function runQuest()
--Start
mq.cmd('/beep')
-- Delay to stop/pause before repeat.
-- /lua stop poker or /lua pause poker
--mq.delay(30000)
mq.cmd('/popup Starting: Paintings Playing Poker 23rd Anniversary Quest')
local start_time = os.time()
local coinsBefore = tonumber(mq.TLO.Me.Commemoratives() or 0) or 0
mq.cmd('/removelev')
--pause CWTN so plugins don't interfere with the quest run
pauseCWTNPlugins()
pauseRGMercs()
-- Keyring-only mount mode: uses ${Mount[1]} via mountIfNeeded().
-- mountIfNeeded() can be used here, but was intentionally left disabled.
preflight()
ensurePokBind()

-- Brief delay: Task TLO can read 0 until the quest tracker is populated this session.
mq.delay(250)

-- Quest progress awareness: resume near the current objective zone.
local startStage, questComplete = computeStartStage()
info(string.format("Quest resume: startStage=%d (questComplete=%s)", startStage or 1, tostring(questComplete)))
setGuiStage(startStage or 1, string.format("Resuming from stage %d", startStage or 1))
if questComplete then
    mq.cmd('/popup Quest already completed; stopping run.')
    unpauseRGMercs()
    unpauseCWTNPlugins()
    return
end
 
-- West Freeport. Talk to Big Slick for quest.
if startStage <= 1 then
    local needs1, needAt1 = taskNeedsStageBlockOrEarlier(1)
    if needs1 then
        setGuiStage(1, "Stage 1/8: West Freeport start")
        shouldStop()
        if mq.TLO.Zone.ID() ~= 383 then
           mq.cmd('/squelch /travelto freeportwest')
           zoning(383)
        end
        mq.delay(1000)
        mq.cmd('/squelch /nav locyxz 19 136 -54')
        moving()
        mq.delay(1000)
        targetOrFail(NPC_BIG_SLICK_JONES, "Could not target Big Slick Jones")
        mq.delay(1000)
        mq.cmd('/face fast')
        if not getActivePokerTaskIndex() then
            mq.cmd('/say paintings')
        else
            info("Poker task already active; skipping new task request phrase.")
        end
        mq.delay(2000)
        mq.cmd('/keypress esc')
        mq.delay(1000)
        if mq.TLO.Me.Height() > 2.50 then mq.cmd('/useitem Guise of the Deceiver') mq.delay(8500) mq.cmd('/popup You are a bit tall, lets shrink a little to make it easier')
        end
    else
        info(string.format("Skipping stage 1/8 (West Freeport): task already past this step (at stage %s).", tostring(needAt1)))
        setGuiStage(needAt1 or 1, string.format("Task ahead: stage %s", tostring(needAt1)))
    end
end

if startStage <= 2 then
    local needs2, needAt2 = taskNeedsStageBlockOrEarlier(2)
    if needs2 then
        setGuiStage(2, "Stage 2/8: East Freeport")
        shouldStop()
        mq.cmd('/popup Lets start our Bar Run!')

        -- Tassel's Tavern for update. Spawn Darrisa.
        mq.cmd('/squelch /nav locyxz -177 -415 -85')
        moving()
        mq.delay(1500)

        local needMid2 = computeResumeStageQuiet()
        if needMid2 > 2 then
            info(string.format("Skipping rest of stage 2 (East Freeport): task at stage %s — Tassel line done or ahead.", tostring(needMid2)))
        else
            -- East Freeport. Crab and Grog Tavern. Spawn Bluffing Betty.
            mq.cmd('/travelto freeporteast')
            zoning(382)
            mq.delay(1000)
            mq.cmd('/squelch /nav locyxz 153 -806 7')
            moving()
            mq.delay(1000)
            targetOrFail(NPC_BLUFFING_BETTY, "Could not target Bluffing Betty")
            mq.delay(1000)
            mq.cmd('/face fast')
            mq.cmd('/keypress hail')
            mq.delay(2000)
            mq.cmd('/autoinv')
            mq.delay(1000)
            mq.cmd('/autoinv')
            mq.cmd('/keypress esc')
            -- One for the road...
            while mq.TLO.FindItem("Memento Grog")() do
               mq.cmd('/useitem Memento Grog')
               mq.delay(1000)
               mq.cmd('/useitem Memento Grog')
               mq.delay(1000)
            end
            -- Charm item gate.
            local slideReady = ensureZueriaMode(ZUERIA_TARGET_MODE)
            if slideReady and slideReady:find(ZUERIA_TARGET_MODE, 1, true) then
                mq.cmdf('/useitem "%s"', slideReady)
                mq.delay(22000)
                while mq.TLO.Zone.ID() ~= 25 and not mq.TLO.Me.Casting() do
                    mq.cmdf('/useitem "%s"', slideReady)
                    zoning(25)
                end
                zoning(25)
            end
            mq.delay(1000)
        end
    else
        info(string.format("Skipping stage 2/8 (East Freeport): task already past this step (at stage %s).", tostring(needAt2)))
        setGuiStage(needAt2 or 2, string.format("Task ahead: stage %s", tostring(needAt2)))
    end
end

-- Neriak Foreign Quarter.
if startStage <= 3 then
    local needs3, needAt3 = taskNeedsStageBlockOrEarlier(3)
    if needs3 then
        setGuiStage(3, "Stage 3/8: Neriak Foreign Quarter")
        shouldStop()
        mq.delay(1000)
        mountIfNeeded()
        mq.delay(3000)

        local doneBeforeNeriakA = getPokerDoneCount()
        -- Force PoK reset route first to avoid EasyFind choosing Hodstock-only paths.
        if mq.TLO.Zone.ID() ~= GATE_ZONE_ID then
            if gateToPokIfAvailable() then
                info("Neriak route: gated to PoK hub first.")
            else
                warn("Neriak route: Gate unavailable; traveling to PoK hub first.")
                mq.cmd('/squelch /travelto poknowledge')
                if not waitForZoneOrFalse(GATE_ZONE_ID, 180000) then
                    fail("Failed to reach PoK hub before Neriak route.")
                end
            end
        end

        local zoned = false
        for attempt = 1, 3 do
            info(string.format("Neriak travel from PoK: attempt %d/3", attempt))
            mq.cmd('/squelch /travelto neriaka')
            if waitForZoneOrFalse(40, 180000) then
                zoned = true
                break
            end
            mq.cmd('/squelch /travelto stop')
            mq.cmd('/squelch /nav stop')
            mq.delay(1500)
        end

        if not zoned then
            fail("Failed to reach Neriak Foreign Quarter (zone 40) even after forcing PoK hub route.")
        end

        mq.delay(1000)
        -- The Bull Pit. Spawn Svunsa.
        mq.cmd('/squelch /nav locyxz -352 -207')
        moving()
        mq.delay(1500)
        -- Bull Pit objective is upstairs; do a second upstairs-adjacent point for reliability.
        mq.cmd('/squelch /nav locyxz -352 -207 22')
        moving()
        mq.delay(1000)

        local needForeign = select(1, computeResumeStageQuiet())
        if needForeign <= 3 then
            -- Slug's Tavern. Spawn Slug.
            mq.cmd('/squelch /nav locyxz 204 -243 3')
            moving()
            mq.delay(1500)
        else
            info("Task: Slug's Tavern already complete — skipping nav to Slug.")
        end

        local doneAfterNeriakA = getPokerDoneCount()
        if doneAfterNeriakA <= doneBeforeNeriakA then
            warn("No task progress detected in Neriak Foreign Quarter; retrying Bull Pit upstairs sweep...")
            local bullPitSweep = {
                { y = -352, x = -207, z = 22 },
                { y = -360, x = -214, z = 24 },
                { y = -344, x = -199, z = 24 },
                { y = -350, x = -206, z = 26 },
            }
            for _, p in ipairs(bullPitSweep) do
                mq.cmdf('/squelch /nav locyxz %d %d %d', p.y, p.x, p.z)
                moving()
                mq.delay(900)
                if getPokerDoneCount() > doneBeforeNeriakA then
                    break
                end
            end
        end

        needForeign = select(1, computeResumeStageQuiet())
        if needForeign >= 5 then
            leaveNeriakTowardHubIfNeeded()
        end
    else
        info(string.format("Skipping stage 3/8 (Neriak Foreign): task already past this step (at stage %s).", tostring(needAt3)))
        setGuiStage(needAt3 or 3, string.format("Task ahead: stage %s", tostring(needAt3)))
        leaveNeriakTowardHubIfNeeded()
    end
end

-- Neriak Commons
if startStage <= 4 then
    local needs4, needAt4 = taskNeedsStageBlockOrEarlier(4)
    if needs4 then
        setGuiStage(4, "Stage 4/8: Neriak Commons")
        shouldStop()
        if mq.TLO.Zone.ID() ~= 41 then
            mq.cmd('/travelto neriakb')
            zoning(41)
        end
        mq.delay(1000)
        -- The Blind Fish. Spawn  Marenkor
        mq.cmd('/squelch /nav locyxz 12 -850 -52')
        moving()
        mq.delay(1500)
        -- Toadstool Tavern. Spawn Rista
        mq.cmd('/squelch /nav locyxz -148 -994 -26')
        moving()
        mq.delay(1000)
        mq.cmd('/face heading 315')
        mq.delay(1200)
        -- Gate code. Try three times for collapses...
        if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == GATE_ZONE_ID then
            if not try_gate_code(3) then
                fail('Gate code failed after 3 attempts')
            end
        end
        if mq.TLO.FindItem(GATE_POTION_NAME)() and mq.TLO.Me.ZoneBound.ID() == GATE_ZONE_ID then
            if not try_gate_potion(3) then
                fail('Gate potion failed after 3 attempts')
            end
        end
        mq.delay(1000)
    else
        info(string.format("Skipping stage 4/8 (Neriak Commons): task already past this step (at stage %s).", tostring(needAt4)))
        setGuiStage(needAt4 or 4, string.format("Task ahead: stage %s", tostring(needAt4)))
        leaveNeriakTowardHubIfNeeded()
    end
end

-- Highpass Hold
if startStage <= 5 then
    local needs5, needAt5 = taskNeedsStageBlockOrEarlier(5)
    if needs5 then
        setGuiStage(5, "Stage 5/8: Highpass Hold")
        shouldStop()
        if mq.TLO.Zone.ID() ~= 407 then
            mq.cmd('/travelto moors')
            zoning(395)
            mq.delay(1000)
            mountIfNeeded()
            mq.delay(3000)
            mq.cmd('/travelto highpasshold')
            mq.delay(1500)
            zoning(407)
        else
            mountIfNeeded()
            mq.delay(1000)
        end
        -- Golden Roosters. Spawn Quinn of Quads
        mq.cmd('/squelch /nav locyxz 454 -620 22')
        moving()
        mq.delay(1000)
        dismountIfMounted("Hailing Quinn of Quads")
        mq.delay(1500)
        targetOrFail(NPC_QUINN_OF_QUADS, "Could not target Quinn of Quads")
        mq.delay(1000)
        mq.cmd('/keypress hail')
        mq.delay(1500)
        mq.cmd('/keypress esc')
        -- The Lumberyard. Spawn Gubli
        mq.cmd('/squelch /nav locyxz -442 -215 -12')
        moving()
        mq.delay(1000)
        mq.cmd('/squelch /nav locyxz -426 -263 -12')
        moving()
        mq.delay(1000)
        mq.cmd('/nav locyxz -408 -267 -12')
        moving()
        mq.delay(1000)
        targetOrFail(NPC_MHRAI_QUEEN_OF_TAILS, "Could not target Mhrai, Queen of Tails")
        mq.delay(1000)
        mq.cmd('/keypress hail')
        mq.delay(1500)
        mq.cmd('/keypress esc')
        -- The Tiger's Roar. Spawn Poker.
        mq.cmd('/nav locyxz -125 540 -13')
        moving()
        mq.delay(1000)
        if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == GATE_ZONE_ID then
            if not try_gate_code(3) then
                fail('Gate code failed after 3 attempts')
            end
        end
        if mq.TLO.FindItem(GATE_POTION_NAME)() and mq.TLO.Me.ZoneBound.ID() == GATE_ZONE_ID then
            if not try_gate_potion(3) then
                fail('Gate potion failed after 3 attempts')
            end
        end
        mq.delay(1000)
    else
        info(string.format("Skipping stage 5/8 (Highpass): task already past this step (at stage %s).", tostring(needAt5)))
        setGuiStage(needAt5 or 5, string.format("Task ahead: stage %s", tostring(needAt5)))
    end
end

-- North Qeynos
if startStage <= 6 then
    local needs6, needAt6 = taskNeedsStageBlockOrEarlier(6)
    if needs6 then
        setGuiStage(6, "Stage 6/8: North Qeynos")
        shouldStop()
        mq.delay(1000)
        if mq.TLO.Zone.ID() ~= 2 then
            mq.cmd('/travelto qeynos2')
            zoning(2)
        end
        mq.delay(1000)
        mq.cmd('/nav locyxz 118 335 1')
        moving()
        mq.delay(1500)
    else
        info(string.format("Skipping stage 6/8 (North Qeynos): task already past this step (at stage %s).", tostring(needAt6)))
        setGuiStage(needAt6 or 6, string.format("Task ahead: stage %s", tostring(needAt6)))
    end
end

-- South Qeynos
if startStage <= 7 then
    local needs7, needAt7 = taskNeedsStageBlockOrEarlier(7)
    if needs7 then
        setGuiStage(7, "Stage 7/8: South Qeynos")
        shouldStop()
        mq.cmd('/travelto qeynos')
        if mq.TLO.Zone.ID() ~= 1 then
            zoning(1)
        end
        mq.delay(1000)
        mq.cmd('/squelch /nav locyxz -282 -230 2')
        moving()
        mq.delay(1500)
        mq.cmd('/squelch /nav locyxz 311 -173 4')
        moving()
        mq.delay(1500)
        if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == GATE_ZONE_ID then
            if not try_gate_code(3) then
                fail('Gate code failed after 3 attempts')
            end
        end
        if mq.TLO.FindItem(GATE_POTION_NAME)() and mq.TLO.Me.ZoneBound.ID() == GATE_ZONE_ID then
            if not try_gate_potion(3) then
                fail('Gate potion failed after 3 attempts')
            end
        end
        mq.delay(1000)
    else
        info(string.format("Skipping stage 7/8 (South Qeynos): task already past this step (at stage %s).", tostring(needAt7)))
        setGuiStage(needAt7 or 7, string.format("Task ahead: stage %s", tostring(needAt7)))
    end
end

-- West Freeport -- Big Slick Jones for Reward.
if startStage <= 8 then
    local needs8, needAt8 = taskNeedsStageBlockOrEarlier(8)
    if needs8 then
        setGuiStage(8, "Stage 8/8: Return to Big Slick")
        shouldStop()
        mq.delay(1000)
        if mq.TLO.Zone.ID() ~= 383 then
            mq.cmd('/travelto freeportwest')
            zoning(383)
            mq.delay(1000)
        end
        mq.cmd('/squelch /nav locyxz 19 136 -54')
        moving()
        mq.delay(1000)
        dismountIfMounted("Turning in / hailing Big Slick Jones")
        targetOrFail(NPC_BIG_SLICK_JONES, "Could not target Big Slick Jones (reward)")
        mq.delay(1000)
        mq.cmd('/face fast')
        mq.cmd('/keypress hail')
        mq.delay(1000)
    else
        info(string.format("Skipping stage 8/8 (return to Slick): task already past this step (at stage %s).", tostring(needAt8)))
        setGuiStage(needAt8 or 8, string.format("Task ahead: stage %s", tostring(needAt8)))
    end
end
-- Completion beeps.
mq.cmd('/beep')
mq.cmd('/beep')
local coinsAfter = tonumber(mq.TLO.Me.Commemoratives() or 0) or 0
local gained = coinsAfter - coinsBefore
gui.lastRunGainedCoins = gained
gui.lastRunCoinsAfter = coinsAfter
print("You now have... " .. mq.TLO.Me.Commemoratives() .. " Commemorative Coins !")
local end_time = os.time()
print("Quest Run Time... " .. end_time - start_time .. " Seconds")

local okProg, progress = pcall(function() return getPokerTaskProgress() end)
if okProg and progress and progress.total and progress.total > 0 and progress.done < progress.total then
    local miss = firstIncompleteObjectiveText() or "unknown objective"
    warn("Quest NOT complete yet. Remaining objective: " .. miss)
    mq.cmd('/popup "Poker task still incomplete. Check objective in task window."')
    unpauseRGMercs()
    unpauseCWTNPlugins()
    return
end
if gained <= 0 then
    warn("No commemorative coin gain detected this run; likely no completed turn-in reward.")
end

setGuiStage(8, "Completed.")
unpauseRGMercs()
unpauseCWTNPlugins()

end -- runQuest

-- GUI: PicTest-style triptych atlas + UV (see `pictest/init.lua`); assets beside this script.
local imgui = require('ImGui')

local config = {
    requestedRun = false,
    running = false,
    autoRepeat = true,
    autoRepeatDelaySec = 12,
    nextRunAllowedAt = 0,
}

math.randomseed(os.time())
for _ = 1, 3 do
    math.random()
end

local PPPOKER_ATLAS_FILE = "pictest_triptych.png"
local USE_TRIPTYCH_ATLAS = true
local ATLAS_W = 500
local ATLAS_H = 900
local SEGMENT_COUNT = 3
local SEGMENT_H = math.floor(ATLAS_H / SEGMENT_COUNT)
local PANEL_W = 500
local PANEL_H = 300
local PANELS = {
    { name = "Roosters", file = "pictest_roosters.png", segment = 0 },
    { name = "Dogs",     file = "pictest_dogs.png",     segment = 1 },
    { name = "Fish",     file = "pictest_fish.png",     segment = 2 },
}
local WINDOW_W = 500
local WINDOW_H = 720
local FRAME_OFFSET_Y = 72
local CHILD_MAX_HEIGHT = 1000
local ATLAS_CROP_X0_PX = 8
local ATLAS_CROP_X1_PX = 490
local FISH_TOP_PAD_PX = 0
local FISH_CURSOR_Y_LIFT_PX = 0
local FISH_LAYOUT_EXTRA_BOTTOM_PX = 10
local FISH_UV_BOTTOM_TRIM_PX = 8
local ATLAS_CROP_TOP_IN_SEG = { 0, -44, -92 }
local ATLAS_CROP_BOTTOM_IN_SEG = { 248, 204, 193 }
local FORCE_IMAGE = nil
local WINDOW_ID_SUFFIX = "###PPPokerPic01"

local PIC_TEST_BAR_ENABLED = true
local PIC_TEST_BAR_SHOW_OPTIONS_UI = false
local PIC_TEST_BAR_OPTS = {
    height = 22,
    padEnd = 12,
    textFmt = "Quest %.0f%%",
    shimmer = false,
    border = true,
    borderThickness = 1,
}

local textures = {}
local loadedOk = {}
local selectedIndex = 1
local texturesLoadedOnce = false
local picTestBarModule = nil
local picTestBarLive = nil
local barTextFmtStr = "Quest %.0f%%"
local picTestBarUseDemoPct = false
local picTestBarDemoPct = 65.0

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

    if USE_TRIPTYCH_ATLAS then
        local path = dir .. "/" .. PPPOKER_ATLAS_FILE
        local ok, result = pcall(function()
            return mq.CreateTexture(path)
        end)
        if ok and result and result.GetTextureID and result:GetTextureID() then
            for i = 1, #PANELS do
                textures[i] = result
                loadedOk[i] = true
            end
            any = true
            info("PPPoker: loaded atlas " .. PPPOKER_ATLAS_FILE .. " (" .. ATLAS_W .. "x" .. ATLAS_H .. ")")
        else
            for i = 1, #PANELS do
                textures[i] = nil
                loadedOk[i] = false
            end
            warn("PPPoker: missing or bad atlas: " .. path)
        end
    else
        for i, p in ipairs(PANELS) do
            local path = dir .. "/" .. p.file
            local ok, result = pcall(function()
                return mq.CreateTexture(path)
            end)
            if ok and result and result.GetTextureID and result:GetTextureID() then
                textures[i] = result
                loadedOk[i] = true
                any = true
                info("PPPoker: loaded " .. p.file)
            else
                loadedOk[i] = false
                warn("PPPoker: missing or bad: " .. path)
            end
        end
    end
    return any
end

local function pickRandomPanel()
    local choices = {}
    for i = 1, #PANELS do
        if loadedOk[i] then
            choices[#choices + 1] = i
        end
    end
    if #choices == 0 then
        selectedIndex = 1
        return
    end
    if FORCE_IMAGE and FORCE_IMAGE >= 1 and FORCE_IMAGE <= #PANELS and loadedOk[FORCE_IMAGE] then
        selectedIndex = FORCE_IMAGE
        info("PPPoker FORCE_IMAGE: " .. PANELS[selectedIndex].name)
        return
    end
    selectedIndex = choices[math.random(#choices)]
    info("PPPoker header art: " .. PANELS[selectedIndex].name .. " (re-run script to re-roll).")
end

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

local function drawHeaderImage()
    local tex = textures[selectedIndex]
    if not tex or not loadedOk[selectedIndex] then
        return
    end

    local availW, availH = getContentRegionAvail2()
    if availW < 4 or availH < 4 then
        return
    end

    local frameW = math.floor(availW + 0.5)
    local srcW = PANEL_W
    local seg = PANELS[selectedIndex].segment
    local topIn = 0
    local botIn = PANEL_H - 1
    local uvSrcH = PANEL_H
    local layoutSrcH = PANEL_H
    if USE_TRIPTYCH_ATLAS then
        srcW = math.max(1, ATLAS_CROP_X1_PX - ATLAS_CROP_X0_PX)
        topIn = ATLAS_CROP_TOP_IN_SEG[seg + 1] or 0
        botIn = ATLAS_CROP_BOTTOM_IN_SEG[seg + 1] or (SEGMENT_H - 1)
        uvSrcH = math.max(1, botIn - topIn)
        layoutSrcH = uvSrcH
        if seg == 1 or seg == 2 then
            local rTop = ATLAS_CROP_TOP_IN_SEG[1] or 0
            local rBot = ATLAS_CROP_BOTTOM_IN_SEG[1] or (SEGMENT_H - 1)
            layoutSrcH = math.max(1, rBot - rTop)
            if seg == 2 then
                layoutSrcH = layoutSrcH + FISH_LAYOUT_EXTRA_BOTTOM_PX
            end
        end
    end
    local naturalH = math.max(1, math.floor(frameW * (layoutSrcH / srcW)))
    local frameH = naturalH
    if frameH > availH - 4 then
        frameH = math.max(1, math.floor(availH - 4))
    end
    if frameH > CHILD_MAX_HEIGHT then
        frameH = CHILD_MAX_HEIGHT
    end

    local u0, u1 = nil, nil
    if USE_TRIPTYCH_ATLAS then
        local nudge = 0.5
        local x0 = math.max(0, math.min(ATLAS_W, ATLAS_CROP_X0_PX))
        local x1 = math.max(0, math.min(ATLAS_W, ATLAS_CROP_X1_PX))
        topIn = ATLAS_CROP_TOP_IN_SEG[seg + 1] or 0
        botIn = ATLAS_CROP_BOTTOM_IN_SEG[seg + 1] or (SEGMENT_H - 1)
        local y0 = seg * SEGMENT_H + topIn
        local y1 = seg * SEGMENT_H + botIn
        if seg == 2 and FISH_UV_BOTTOM_TRIM_PX > 0 then
            y1 = y1 - FISH_UV_BOTTOM_TRIM_PX
            if y1 <= y0 + 4 then
                y1 = y0 + 4
            end
        end
        u0 = getImVec2((x0 + nudge) / ATLAS_W, (y0 + nudge) / ATLAS_H)
        u1 = getImVec2((x1 - nudge) / ATLAS_W, (y1 - nudge) / ATLAS_H)
    else
        u0 = getImVec2(0, 0)
        u1 = getImVec2(1, 1)
    end

    local didPush = false
    if ImGuiStyleVar and ImGuiStyleVar.WindowPadding and ImGuiStyleVar.ItemSpacing and imgui.PushStyleVar then
        pcall(function()
            imgui.PushStyleVar(ImGuiStyleVar.WindowPadding, getImVec2(0, 0))
            imgui.PushStyleVar(ImGuiStyleVar.ItemSpacing, getImVec2(0, 0))
            didPush = true
        end)
    end

    local flags = childNoScrollFlags()
    local childOk = pcall(function()
        imgui.BeginChild("##PPPokerPicPanel", getImVec2(frameW, frameH), false, flags)
    end)
    if not childOk then
        childOk = pcall(function()
            imgui.BeginChild("##PPPokerPicPanel", getImVec2(frameW, frameH), false)
        end)
    end
    if not childOk then
        if didPush then
            imgui.PopStyleVar(2)
        end
        return
    end

    local innerW, innerH = getContentRegionAvail2()
    if innerW < 1 or innerH < 1 then
        imgui.EndChild()
        if didPush then
            imgui.PopStyleVar(2)
        end
        return
    end

    local texId = tex:GetTextureID()
    local dl = getWindowDrawList()
    local colW = imCol32White()
    local laidOut = false

    local imgW, imgH = innerW, innerH
    local padTop = 0
    if USE_TRIPTYCH_ATLAS and seg == 1 then
        local scaledH = math.max(1, math.floor(innerW * (uvSrcH / srcW) + 0.5))
        if scaledH < innerH then
            padTop = innerH - scaledH
            imgH = scaledH
        elseif scaledH > innerH then
            imgH = innerH
        end
    end

    local fishTopPad = 0
    if USE_TRIPTYCH_ATLAS and seg == 2 and FISH_TOP_PAD_PX > 0 then
        fishTopPad = FISH_TOP_PAD_PX
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
        local okDl = pcall(function()
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
        if okDl then
            laidOut = true
        end
    end
    if not laidOut and texId then
        local ok3 = pcall(function()
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
        if ok3 then
            laidOut = true
        end
    end
    if not laidOut then
        imgui.Dummy(getImVec2(innerW, innerH))
    end

    imgui.EndChild()
    if didPush then
        imgui.PopStyleVar(2)
    end
end

local function getPicTestBarModule()
    if picTestBarModule ~= nil then
        return picTestBarModule ~= false and picTestBarModule or nil
    end
    local dir = getScriptDir():gsub("/+$", "")
    local path = dir .. "/statusbar.lua"
    local chunk, err = loadfile(path)
    if not chunk then
        picTestBarModule = false
        return nil
    end
    local ok, mod = pcall(chunk)
    if not ok or type(mod) ~= "table" or not mod.DrawProgress then
        picTestBarModule = false
        return nil
    end
    picTestBarModule = mod
    return mod
end

local function ensurePicTestBarLive()
    if picTestBarLive then
        return picTestBarLive
    end
    local mod = getPicTestBarModule()
    if not mod then
        return nil
    end
    local o = mod.shallowCopy(mod.globalOpts)
    for k, v in pairs(PIC_TEST_BAR_OPTS) do
        o[k] = v
    end
    picTestBarLive = o
    if o.textFmt then
        barTextFmtStr = tostring(o.textFmt)
    end
    return picTestBarLive
end

local function resetPicTestBarLive()
    picTestBarLive = nil
    ensurePicTestBarLive()
    if picTestBarLive and picTestBarLive.textFmt then
        barTextFmtStr = tostring(picTestBarLive.textFmt)
    end
end

local function drawPicTestBarOptionsUI(bopts, mod)
    if not bopts or not mod then
        return
    end
    pcall(function()
        if imgui.Separator then
            imgui.Separator()
        end
        local childH = 320
        pcall(function()
            imgui.BeginChild("##PPPokerBarOpts", getImVec2(0, childH), true)
        end)

        if imgui.CollapsingHeader then
            imgui.CollapsingHeader("Bar options (live)")
        elseif imgui.Text then
            imgui.Text("Bar options (live)")
        end

        picTestBarUseDemoPct = imgui.Checkbox("Use demo %% (ignore quest progress)", picTestBarUseDemoPct)
        if picTestBarUseDemoPct then
            picTestBarDemoPct = imgui.SliderFloat("Demo %%", picTestBarDemoPct, 0, 100, "%.1f")
        end

        bopts.height = imgui.SliderInt("Height", math.floor(bopts.height + 0.5), 6, 48)
        bopts.width = imgui.SliderInt("Width (0 = full)", math.floor(bopts.width + 0.5), 0, 480)
        bopts.padEnd = imgui.SliderInt("Pad end", math.floor(bopts.padEnd + 0.5), 0, 40)
        bopts.rounding = imgui.SliderInt("Rounding", math.floor(bopts.rounding + 0.5), 0, 16)

        bopts.showText = imgui.Checkbox("Show text", bopts.showText)
        if imgui.InputText then
            local ns = imgui.InputText("Text format", barTextFmtStr, 96)
            if ns and ns ~= "" then
                barTextFmtStr = ns
                bopts.textFmt = ns
            end
        end

        bopts.showTicks = imgui.Checkbox("Show ticks", bopts.showTicks ~= false)
        if bopts.showTicks then
            bopts.tickEvery = imgui.SliderFloat("Tick every", bopts.tickEvery or 0.2, 0.02, 1.0, "%.2f")
            bopts.tickAlpha = imgui.SliderFloat("Tick alpha", bopts.tickAlpha or 50, 0, 255, "%.0f")
            bopts.tickThickness = imgui.SliderFloat("Tick thickness", bopts.tickThickness or 1, 0.5, 5, "%.1f")
        end

        bopts.shimmer = imgui.Checkbox("Shimmer", bopts.shimmer)
        if bopts.shimmer then
            bopts.shimmerFollows = imgui.Checkbox("Shimmer follows fill", bopts.shimmerFollows ~= false)
            bopts.shimmerSpeed = imgui.SliderFloat("Shimmer speed", bopts.shimmerSpeed or 0.5, 0.05, 3, "%.2f")
            bopts.shimmerWidth = imgui.SliderFloat("Shimmer width", bopts.shimmerWidth or 60, 10, 200, "%.0f")
            bopts.shimmerDeadzone = imgui.SliderFloat("Shimmer deadzone", bopts.shimmerDeadzone or 0.001, 0, 0.05, "%.4f")
        end

        bopts.glow = imgui.Checkbox("Glow", bopts.glow ~= false)
        bopts.tweenSeconds = imgui.SliderFloat("Tween (sec)", bopts.tweenSeconds or 0.35, 0, 2, "%.2f")

        bopts.fillGradient = imgui.Checkbox("Gradient fill", bopts.fillGradient ~= false)
        if bopts.fillGradient and imgui.BeginCombo then
            local mode = bopts.fillGradientMode or "dynamic"
            if imgui.BeginCombo("Gradient mode##pppokerbar", mode) then
                for _, opt in ipairs({ "static", "dynamic" }) do
                    if imgui.Selectable(opt, mode == opt) then
                        bopts.fillGradientMode = opt
                    end
                end
                imgui.EndCombo()
            end
            local gdir = bopts.fillGradientDir or "lr"
            if imgui.BeginCombo("Gradient dir##pppokerbar", gdir) then
                for _, opt in ipairs({ "lr", "tb" }) do
                    if imgui.Selectable(opt, gdir == opt) then
                        bopts.fillGradientDir = opt
                    end
                end
                imgui.EndCombo()
            end
        end

        bopts.border = imgui.Checkbox("Border", bopts.border)
        if bopts.border then
            bopts.borderThickness = imgui.SliderFloat("Border thickness", bopts.borderThickness or 2, 0.5, 6, "%.1f")
            if imgui.ColorEdit4 then
                bopts.borderColor = imgui.ColorEdit4("Border color##pppokerbar", bopts.borderColor or mod.Colors.borders)
            end
        end

        if imgui.ColorEdit4 and imgui.Text then
            imgui.Text("Fill colors (quest bar)")
            mod.Colors.XPMin = imgui.ColorEdit4("Low##pppokerbar", mod.Colors.XPMin)
            mod.Colors.XPMax = imgui.ColorEdit4("High##pppokerbar", mod.Colors.XPMax)
        end

        if imgui.Button("Reset bar to PIC_TEST_BAR_OPTS") then
            resetPicTestBarLive()
        end

        imgui.EndChild()
    end)
end

local function pppokerDrawGUI()
    if not texturesLoadedOnce then
        if loadTextures() then
            pickRandomPanel()
        end
        texturesLoadedOnce = true
    end

    pcall(function()
        local mv = imgui.GetMainViewport()
        if mv and mv.WorkPos then
            imgui.SetNextWindowPos(mv.WorkPos.x + 600, mv.WorkPos.y + 20, ImGuiCond.FirstUseEver)
        end
    end)
    if imgui.SetNextWindowSize then
        local cond = 1
        if ImGuiCond then
            cond = ImGuiCond.FirstUseEver or cond
        end
        pcall(function()
            imgui.SetNextWindowSize(getImVec2(WINDOW_W, WINDOW_H), cond)
        end)
    end

    local mainPadPushed = false
    if ImGuiStyleVar and ImGuiStyleVar.WindowPadding and imgui.PushStyleVar then
        pcall(function()
            imgui.PushStyleVar(ImGuiStyleVar.WindowPadding, getImVec2(0, 0))
            mainPadPushed = true
        end)
    end

    local began = false
    local ok, err = pcall(function()
        local open, draw = imgui.Begin(string.format("PPPoker v%s", VERSION) .. WINDOW_ID_SUFFIX, gui.open)
        began = true
        gui.open = open
        if not draw then
            return
        end
        if not gui.open then
            return
        end

        pcall(function()
            local cy = FRAME_OFFSET_Y
            if USE_TRIPTYCH_ATLAS and PANELS[selectedIndex] and PANELS[selectedIndex].segment == 2 then
                cy = math.max(4, FRAME_OFFSET_Y - FISH_CURSOR_Y_LIFT_PX)
            end
            imgui.SetCursorPos(0, cy)
        end)
        drawHeaderImage()

        if imgui.Spacing then
            imgui.Spacing()
        end

        imgui.Text("Paintings Playing Poker — 23rd anniversary")
        imgui.Separator()

        if config.running then
            if imgui.Button("Stop") then
                stopRequested = true
                config.running = false
            end
            imgui.SameLine()
            imgui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), "Running")
        else
            if imgui.Button("Run") then
                stopRequested = false
                config.requestedRun = true
                config.running = true
            end
            imgui.SameLine()
            imgui.Text("Idle")
        end

        imgui.Separator()
        if gui.status and tostring(gui.status) ~= "" then
            imgui.Text("Status: " .. tostring(gui.status))
        end

        local questPct = 0.0
        if gui.stage and gui.stage > 0 then
            questPct = math.min(100.0, math.max(0.0, (gui.stage - 1) / 7 * 100.0))
        end

        if PIC_TEST_BAR_ENABLED then
            local mod = getPicTestBarModule()
            local bopts = ensurePicTestBarLive()
            if mod and bopts then
                pcall(function()
                    local pct = questPct
                    if picTestBarUseDemoPct then
                        pct = picTestBarDemoPct
                    end
                    mod.DrawProgress("PPPokerQuest", pct, mod.Colors.XPMin, mod.Colors.XPMax, bopts)
                    if PIC_TEST_BAR_SHOW_OPTIONS_UI then
                        drawPicTestBarOptionsUI(bopts, mod)
                    end
                end)
            else
                local progress = questPct / 100.0
                imgui.ProgressBar(progress, ImVec2(-1, 16), "")
            end
        else
            local progress = questPct / 100.0
            imgui.ProgressBar(progress, ImVec2(-1, 16), "")
        end

        imgui.Text(string.format("Stage %d / 8", gui.stage or 1))
    end)

    if began then
        imgui.End()
    end
    if mainPadPushed and imgui.PopStyleVar then
        imgui.PopStyleVar(1)
    end
    if not ok then
        gui.status = "GUI error: " .. tostring(err)
        print("PPPoker GUI error: " .. tostring(err))
    end
end

mq.imgui.init("PPPokerGUI", pppokerDrawGUI)

local function gatePotionCount()
    local ok, count = pcall(function() return mq.TLO.FindItem(GATE_POTION_NAME)() end)
    if not ok then return 0 end
    return tonumber(count or 0) or 0
end

local function canAutoRepeatAfterQuest()
    if stopRequested then return false end
    if not config.autoRepeat then return false end

    -- Stop when the last run no longer increases coins (prevents infinite reruns after completion).
    if gui.lastRunGainedCoins ~= nil and tonumber(gui.lastRunGainedCoins or 0) <= 0 then
        return false
    end

    -- If we have Gate AA, we can repeat without spending Gate potions.
    if hasGateAA() then
        return true
    end

    -- Otherwise, only repeat if we still have at least one gate potion.
    return gatePotionCount() > 0
end

while gui.open do
    -- Arm the next run after a cooldown, without using /timed restarts.
    if (not config.requestedRun) and config.nextRunAllowedAt and config.nextRunAllowedAt > 0 and os.time() >= config.nextRunAllowedAt then
        if canAutoRepeatAfterQuest() then
            config.requestedRun = true
        else
            config.nextRunAllowedAt = 0
        end
    end

    if config.requestedRun then
        config.requestedRun = false
        stopRequested = false
        gui.status = "Starting..."
        gui.stage = 1

        local ok, err = pcall(runQuest)
        if not ok then
            gui.status = "Error: " .. tostring(err)
            config.running = false
        else
            gui.status = "Completed."
            config.running = false
            if canAutoRepeatAfterQuest() then
                config.nextRunAllowedAt = os.time() + config.autoRepeatDelaySec
            else
                config.nextRunAllowedAt = 0
            end
        end
    end
    mq.delay(200)
end

if mq.imgui and mq.imgui.destroy then
    pcall(function()
        mq.imgui.destroy("PPPokerGUI")
    end)
end
for i = 1, #PANELS do
    textures[i] = nil
end
