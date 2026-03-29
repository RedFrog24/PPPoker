--[[
    mq_task_diag.lua — probe MQ Task TLO + optional TaskWnd for PPPoker quest logic.
    Run: /lua run pppoker/mq_task_diag   (path relative to your MQ lua folder)

    Compare memory slot order vs journal UI; see which objective fields parse on your build.
--]]

local mq = require("mq")

local TASK_SLOT_MAX = 48
local OBJ_MAX = 24
local EMPTY_STREAK_MAX = 5

local NAMED_KEYS = {
    "Paintings Playing Poker",
    "23rd Anniversary: Paintings Playing Poker",
    "Playing Poker",
    "Paintings",
}

local function parse(s)
    local ok, v = pcall(mq.parse, s)
    if not ok or v == nil then return nil end
    local t = tostring(v):gsub("^%s+", ""):gsub("%s+$", "")
    if t == "" or t == "NULL" then return nil end
    return t
end

local function parseNum(s)
    local t = parse(s)
    if not t then return nil end
    return tonumber(t)
end

local function line(msg)
    print("[mq_task_diag] " .. tostring(msg))
end

local function sep()
    line("------------------------------------------------------------")
end

--- Try a list of ${Task[...].Objective[n].Field} names; print only hits.
-- Only fields that exist on taskobjective in VanillaMQ Live (avoids MQ console spam).
local OBJECTIVE_FIELDS = {
    "Instruction",
    "Zone",
    "CurrentCount",
    "RequiredCount",
    "Status",
    "Index",
    "Optional",
}

local function taskRefExpr(ref, isStringKey)
    if isStringKey then
        return string.format("Task[%s]", ref)
    end
    return string.format("Task[%d]", ref)
end

local function dumpObjectivesForTask(refLabel, ref, isStringKey)
    line(string.format("Objectives for %s (ref=%s)", refLabel, tostring(ref)))
    local streak = 0
    for o = 1, OBJ_MAX do
        local base = taskRefExpr(ref, isStringKey) .. string.format(".Objective[%d]", o)
        local any = false
        local parts = {}
        for _, field in ipairs(OBJECTIVE_FIELDS) do
            local expr = "${" .. base .. "." .. field .. "}"
            local val = parse(expr)
            if val then
                any = true
                parts[#parts + 1] = field .. "=" .. val
            end
        end
        if not any then
            streak = streak + 1
            if streak >= EMPTY_STREAK_MAX then
                line(string.format("  (stopped after %d empty objective rows)", EMPTY_STREAK_MAX))
                break
            end
        else
            streak = 0
            line(string.format("  [%d] %s", o, table.concat(parts, " | ")))
        end
    end
end

local function sectionTaskMemory()
    sep()
    line("A) Task TLO — memory (numeric slots 1.." .. TASK_SLOT_MAX .. ")")
    sep()

    local tc = parseNum("${Task.Count}")
    line(string.format("${Task.Count} => %s", tostring(tc)))

    local occupied = 0
    for i = 1, TASK_SLOT_MAX do
        local t = mq.TLO.Task(i)
        local exists = (t and t() and true) or false
        local id = parseNum(string.format("${Task[%d].ID}", i))
        local title = parse(string.format("${Task[%d].Title}", i))
        if exists or (id and id > 0) or (title and title ~= "") then
            occupied = occupied + 1
            local step = parse(string.format("${Task[%d].Step}", i))
            local timer = parse(string.format("${Task[%d].Timer}", i))
            line(string.format(
                "Slot %2d | ID=%s | Title=%s",
                i,
                tostring(id or "?"),
                tostring(title or "(no title)")
            ))
            if step then line("        Step: " .. step) end
            if timer then line("        Timer: " .. timer) end

            -- Highlight Paintings-ish tasks
            local low = tostring(title or ""):lower()
            if low:find("painting", 1, true) and low:find("poker", 1, true) then
                line("        >>> matches Paintings Playing Poker fingerprint <<<")
                dumpObjectivesForTask("numeric slot " .. i, i, false)
            end
        end
    end
    line(string.format("Occupied slots (heuristic): %d", occupied))
end

local function sectionStringKeys()
    sep()
    line("B) Task TLO — string keys (mq.TLO.Task(\"name\") / ${Task[key]...})")
    sep()

    for _, key in ipairs(NAMED_KEYS) do
        local title = parse(string.format("${Task[%s].Title}", key))
        local id = parseNum(string.format("${Task[%s].ID}", key))
        if title or id then
            line(string.format('Key "%s" => ID=%s Title=%s', key, tostring(id or "?"), tostring(title or "?")))
            local t = mq.TLO.Task(key)
            local okT = t and t()
            line(string.format("  Task(%q)() => %s", key, tostring(okT)))
            if title and title ~= "" then
                dumpObjectivesForTask('string key "' .. key .. '"', key, true)
            end
        else
            line(string.format('Key "%s" => (no parse data)', key))
        end
    end
end

local function sectionTaskWnd()
    sep()
    line("C) Window('TaskWnd') — UI (open Quest Journal / Tasks for best results)")
    sep()

    local w = mq.TLO.Window("TaskWnd")
    if not w then
        line("Window('TaskWnd') is nil")
        return
    end

    local exists = false
    pcall(function()
        exists = w() and true or false
    end)
    line(string.format("TaskWnd() => %s", tostring(exists)))

    local openW = false
    pcall(function()
        if w.Open then openW = w.Open() end
    end)
    line(string.format("TaskWnd.Open() => %s", tostring(openW)))

    pcall(function()
        local list = w.Child("TASK_TaskList")
        if not list or not list() then
            line("Child TASK_TaskList missing or false")
            return
        end
        line("Child TASK_TaskList OK")
        if list.SelectedIndex then
            local si = list.SelectedIndex()
            line(string.format("  TASK_TaskList.SelectedIndex() => %s", tostring(si)))
            if list.List and si ~= nil then
                local c2 = list.List(si, 2)
                local c3 = list.List(si, 3)
                line(string.format("  List(sel,2) title-ish => %s", tostring(c2)))
                line(string.format("  List(sel,3) time-ish => %s", tostring(c3)))
            end
        end
    end)

    pcall(function()
        local el = w.Child("TASK_TaskElementList")
        if el and el() then
            line("Child TASK_TaskElementList OK (row text varies by build)")
        else
            line("Child TASK_TaskElementList missing or false")
        end
    end)
end

local function main()
    line("MQ Task diagnostic — " .. tostring(mq.TLO.Me.Name() or "?") .. " zone " .. tostring(mq.TLO.Zone.Name() or "?"))
    sectionTaskMemory()
    sectionStringKeys()
    sectionTaskWnd()
    sep()
    line("Done. Use this output to decide: numeric slot vs string key vs UI scrape.")
end

main()
