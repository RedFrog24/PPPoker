-- pppoker.lua 23rd anniversary task (init2 prototype)
-- Created by: RedFrog
-- Original creation date: 03/18/2026
-- Quest: https://everquest.allakhazam.com/db/quest.html?quest=10723
-- Version: 2.65
-- Changelog:
-- 2.65: Debug — bordered scrollable frame + colored log lines restored (2.62-style ImGui.TextColored parsing of \\a codes). Ring buffer in gui.debugLog; info/warn mirror to panel without duplicate console line; standalone debugLog() still prints + appends.
-- 2.63: Debug — no in-window log/frame; Debug toggle removed. debugLog() and all script diagnostics go to EQ console only (info/warn unchanged).
-- 2.62: Debug panel — parse MQ \a color codes and draw with ImGui.TextColored (frames do not enable EQ colors; needs explicit mapping). Raw log lines from info/warn; optional bordered debug child. mqSpell/mqObjGreen use "\\a" in Lua so stored strings match console triplets.
-- 2.61: Console — objective completion (\ag) and spell names (\am) in log text; debug panel still plain until 2.62.
-- 2.60: Console/debug — drop redundant "PPPoker:" in message text; info/warn already print [\agPPPoker\ao] / [\ayPPPoker\ao].
-- 2.59: CWTN pause — use ${CWTN.Paused} / mq.TLO.CWTN.Paused() (init.lua parity); skip /CWTN pause on if already paused; unpause only when this run paused CWTN (not if user had paused before Run).
-- 2.58: Quest objective bar — restored animated shimmer overlay (init.lua parity; opts.shimmer was unused in drawObjectiveBar).
-- 2.57: Idle + run Status — show journal instruction text only (no "Next: objective N —" / "Objective N:" prefix).
-- 2.56: GUI — removed "Current Objective" line (Status + Progress + bar retain step info via Status when idle).
-- 2.55: PoK bind — popup/info "Please Start in PoK" when not bound; after nav to Soulbinder loc, wait until within POK_SOULBINDER_MAX_DIST of loc before target + /say Bind (avoid Jera too early).
-- 2.54: PoK bind parity with init.lua — if not bound to zone 202, /travelto poknowledge, nav to PP.POK_SOULBINDER_LOC, Soulbinder Jera, /say Bind; runs at Run start after pausing RGmerc/CWTN, before journal sync and Slick acquire. PP.ENSURE_POK_BIND_BEFORE_RUN (default true).
-- 2.53: GUI — version only in window title; removed duplicate (v#) from header line after "Anniversary".
-- 2.52: After full success — optional auto-repeat (PP.AUTO_REPEAT_DELAY_SEC, default 10s like Poker2 /timed); global _G.PPPokerV2.armRun() queues another Run without clicking (main loop). Set AUTO_REPEAT_DELAY_SEC to 0 to disable.
-- 2.51: North/South Qeynos — no keyring mount ever (mountIfNeeded hard-skips NQ/SQ; obj 13–15 use navLocNoMount). Removed PP.TRAVEL_NO_MOUNT_IN_QEYNOS. Dismount + speed/invis helpers unchanged.
-- 2.50: Objective 8 (PoK→Highpass) — optional Blightfire Moors hop (Poker2.lua): /travelto moors, zone 395, then poker2MountDelayInNekOrMoors + /travelto highpasshold. Fixes mount never running in Moors when script skipped 395 (poker2MountDelayInNekOrMoors no-op from PoK). PP.TRAVEL_HIGHPASS_VIA_MOORS (default true). Moors added to zoneWantsCityPrep for movement prep before /travelto moors.
-- 2.49: tryGateToPoK — faster polling after fizzle/interrupt/collapse (Gate AA/spell/potion ready waits, cast-clear probe, shorter backoff before next attempt). Tunables: PP.GATE_READY_POLL_MS, PP.GATE_CAST_CLEAR_POLL_MS, PP.GATE_POST_CAST_EXTRA_WAIT_MS, PP.GATE_RETRY_BACKOFF_MS.
-- 2.48: Objective 16 — if Paintings task vanishes from journal after final hail (EQ removes quest on turn-in), waitObjectiveDone treats that as complete; main loop breaks so nil task is not "Task became unavailable."
-- 2.47: On successful quest completion, log commemorative coin count and Quest Run Time (seconds), matching Poker2.lua end-of-run output.
-- 2.46: Blightfire (Moors) poker2MountDelayInNekOrMoors — speed buff + mountIfNeeded only (no extra Poker2 pause stack).
-- 2.45: Qeynos ensureSpeedAndInvisInQeynos — speed, shrink (TRAVEL_SHRINK_IN_QEYNOS), dismount if mounted, invis; then nav to POIs (2.51: navLocNoMount in NQ/SQ, no keyring mount).
-- 2.44: Highpass ensureSpeedShrinkInvisInHighpass — no dismount; speed, shrink, mount, invis (same toggles).
-- 2.42: Highpass ensureSpeedShrinkInvisInHighpass — mountIfNeeded after shrink, invis last; TRAVEL_NO_MOUNT_IN_HIGHPASS to walk only. mountIfNeeded skips Highpass when that toggle true.
-- 2.41: Guise shrink — at most one /useitem + one shrink popup per Run (resetGuiseShrinkSession); removed duplicate shrink from prepBeforeTasselLeg (preflight only, like zone helpers).
-- 2.40: Qeynos (NQ/SQ): ensureSpeedAndInvisInQeynos dismounts for speed/invis on foot, then nav (later 2.51: hard no keyring mount in NQ/SQ).
-- 2.39: ensureSpeedShrinkInvisInHighpass — on zone-in/resume in Highpass (obj 8–12): dismount, movement buff, Guise shrink (toggle), invis last via ensureInvisIfNeeded. Mount left to navLoc / navLocNoMount per leg.
-- 2.38: Blightfire/Nektulos Poker2 mount — waitMeNotCasting before keyring mount click and after mount; mountIfNeeded already waits Me.Casting + mounted after /useitem.
-- 2.37: tryGateToPoK — route by capability: AA waits AltAbilityReady; spell Gate waits SpellReady; potion waits FindItem.Timer (reuse). No AA/spell/potion → return false immediately (caller /travelto) with no long waits.
-- 2.36: tryGateToPoK — wait for Gate AA ready, retries after collapse/fail (AltAbilityReady + cast clear + longer zone wait); potion path retried. Avoids immediate /travelto pok when Gate was not ready long enough.
-- 2.35: Pause Nav uses MQ2Nav /nav pause and Unpause uses /nav pause off (path preserved). moving() waits while Navigation.Active or Navigation.Paused (or gui.navPaused fallback). Removed resumeNavAfterUnpause + /nav stop pause behavior.
-- 2.34: Objective 16 (final hail Big Slick): wait until Big Slick spawn within hail range (waitBigSlickWithinDist) after nav, optional re-nav — then target and hail (no interaction while too far).
-- 2.33: Pause Nav halts /nav but navLoc/navLocNoMount re-issue same locyxz after Unpause (resumeNavAfterUnpause). mountIfNeeded waits for cast to finish + mount before nav. Stop/Run clear resumeNavAfterUnpause.
-- 2.32: Pause Nav toggles gui.navPaused; moving() waits in waitWhileNavPaused (Run continues after unpause). Stop clears navPaused, halts nav/travelto, and sets stopRequested to end Run. Run clears navPaused on start.
-- 2.31: South Qeynos Lion's Mane (obj 15): no Gate at lion; after that objective done, obj 16 starts with Gate/potion to PoK if still in NQ/SQ, then West Freeport / Slick (same pattern as Tiger / Toadstool).
-- 2.30: Neriak Toadstool (obj 7): no Gate at painting; after Toadstool objective done, obj 8 starts with Gate/potion to PoK then Highpass (same pattern as Tiger → Qeynos).
-- 2.29: Qeynos (NQ/SQ): ensureSpeedAndInvisInQeynos — speed + invis on foot. Highpass (see 2.39 ensureSpeedShrinkInvisInHighpass): no dismount before hail Quinn/Mhrai; nav without mount on lumber+tiger (obj 10–12); Gate/potion removed from Tiger step — after Tiger objective done, obj 13 runs Gate/travel then NQ. TRAVEL_INVIS_AFTER_QEYNOS_ZONE gates invis inside Qeynos helper.
-- 2.28: Neriak (40/41): on entry/resume — dismount if needed, speed buff + invis (casts if needed); mount keyring never used in Neriak (PP.TRAVEL_NO_MOUNT_IN_NERIAK). Blightfire/Moors (395): on entry — speed buff + mount + Poker2 pause. Removed TRAVEL_NO_MOVEMENT_BUFF_CAST_IN_NERIAK (speed may cast in Neriak on foot).
-- 2.27: Neriak mount-cast fix via pppokerEnsureMovementBuff — skip class/totem movement buff *application* in Neriak Foreign/Commons (PP.TRAVEL_NO_MOVEMENT_BUFF_CAST_IN_NERIAK). Reverts 2.26 dismount-before-buffs in ensureSpeedAndInvisInNeriak (single rule in movement buff path).
-- 2.26: Neriak buff pass (ensureSpeedAndInvisInNeriak): dismount before movement/invis if PP.TRAVEL_DISMOUNT_BEFORE_BUFFS_IN_NERIAK (default true) — many spells/items do not cast on mount.
-- 2.25: In Neriak (Foreign or Commons): after zoning or when already in zone (resume), refresh movement speed + invis (ensureSpeedAndInvisInNeriak). PoK->Neriak travel applies buffs after landing, not only before /travelto.
-- 2.24: Preflight no longer casts invis — Guise shrink and other clicks/spells after invis drop it; invis only at leg-specific ensureInvisIfNeeded (e.g. after shrink in prepBeforeTasselLeg). Preflight = speed, mount, Zueria readiness, Guise shrink only.
-- 2.23: Run flow - journal quest/objective checks first, then preflight (speed, mount, Zueria readiness, Guise shrink, invis last; skip invis recast if already up). Before Tassel (obj 1): speed + shrink + invis-if-needed. City /travelto prep is movement-only (no invis spam in ensureZone). Betty obj 2: nav + in-range wait only; obj 3: hail + Memento Grog + Zueria slide or Gate/potion/travelto PoK then /travelto neriaka (avoids Hodstock). Obj 4: East FP uses PoK hub then Neriak; Nektulos/Moors keeps direct neriaka after mount pause.
-- 2.22: moving()/navigationIsActive aligned with init.lua — arm wait for Navigation.Active + post-nav grace (fixes navLoc returning before path finishes; Slick acquire was targeting/saying before [Nav] Reached destination). tryAcquire: wait until Big Slick spawn within range, Poker2-style post-nav buffer, journal sync after /say uses minimal fetch first then full only if getTask still nil. Run order: movement buff before TaskWnd sync (less journal flash before mount). GUI: Pause Nav button (/nav stop). Version 2.21 notes retained below.
-- 2.21: No quest on Run - travel to Big Slick loc, /say paintings (PP.SLICK_QUEST_KEYWORD), esc, full TaskWnd sync, then re-check journal (TRY_BIG_SLICK_QUEST_ACQUIRE). First journal tick uses TASK_JOURNAL_FIRST_SYNC minimal (fetch-only) to cut open/close spam; use "full" if Task TLO stays empty.
-- 2.20: Poker2.lua timing — mount+3s after Nektulos (25) or Moors/Blightfire (395) before next /travelto; invis before Tassel nav; invis after mount before Neriak; invis after zoning NQ/SQ. Final Slick (obj 16): /face fast, longer pre/post-hail delays, journal sync + 5m wait timeout + periodic TaskWnd sync while waiting (fixes hail-too-fast / journal lag timeouts).
-- 2.19: Travel tuning (init.lua patterns): mount keyring slot 1 before /nav, dismount before hail/target and Gate; movement buff (class SoW/Selo + Worn Totem) at run start; city prep (speed then invis) before /travelto city zones — toggles on PP (TRAVEL_*).
-- 2.18: taskobjective has no Done member on Live MQ — removed all .Done() and ${...Objective[..].Done} parse (stops "No such taskobjective member Done" spam). Completion = Status + RequiredCount/CurrentCount only (parse + userdata).
-- 2.17: Objective completion uses mq.parse (${Task[..].Objective[n].Status|RequiredCount|CurrentCount|Done}) first; matches /echo in game. Lua userdata alone was leaving Obj 1 "incomplete" forever. Slot index fallback if named parse empty. Console log lines use ASCII '-' (no em dash).
-- 2.16: objectiveIsComplete also uses Objective RequiredCount/CurrentCount (init.lua-style) when present — Live often credits via counts while Done/Status lag; fixes false resume at Obj 1 / Tassel when step is done.
-- 2.15: Define getObjectiveSlotRaw before getQuestProgress (Lua local forward-ref fix — GUI draw error calling nil).
-- 2.14: Central taskEvalExists() — mq.TLO.Task(name)() must be evaluated for journal memory (case-sensitive); all task gates use pcall’d () check per MQ docs. getTask tries named task first, then Task(1..N) by title.
-- 2.13: firstIncompleteObjective skips nil Objective(i) (MQ omits finished steps; old logic treated nil as incomplete → always resumed at 1). Bar still uses only rows that exist — may look pessimistic vs journal. shouldStop() honors GUI close (X) + stop flag; runQuest logs quest title then next incomplete index after journal checks.
-- 2.12: No Task/journal reads or status-bar fill until first Run: open shows placeholder only; Run syncs journal then checks quest-in-journal, then objective rows/progress. Removed automatic prime before ImGui and in main loop (was acting like objective 1 pending before quest check).
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
-- 2.01: Versioning — 0.01 bumps like init.lua; PP.VERSION in window title (header line is title text only).
-- 2.00: New clean objective-index runner (16 objectives), compact GUI, shared nav/plugin helpers.
--       Quest state via mq.TLO.Task (memory); TaskWnd/journal open not required for automation.
--       Status bar uses fixed 16 objective slots (ticks + X/16); dynamic scan under-counted when MQ leaves gaps.
--       On open (and while idle), Status refreshes from Task TLO — no Run required.

local mq = require('mq')
local imgui = require('ImGui')
local ImGui = imgui
local Icons = require('mq.icons')
local ImAnim = require('ImAnim')

local stopRequested = false

local PP = {
    VERSION = "2.65",
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
    --- Wizard/Druid spell (when no Gate AA); `/cast` uses this name.
    GATE_SPELL_NAME = "Gate",
    --- Gate AA: retries when "too unstable"/collapse — wait until AltAbilityReady again, then re-cast.
    GATE_MAX_ATTEMPTS = 12,
    GATE_WAIT_READY_MS = 240000,
    GATE_ZONE_WAIT_MS = 90000,
    GATE_POTION_ATTEMPTS = 4,
    --- After collapse/fizzle: poll AltAbilityReady / SpellReady / potion timer this often (ms).
    GATE_READY_POLL_MS = 250,
    --- While Gate cast bar clears or zone updates (waitCastClearOrZoned).
    GATE_CAST_CLEAR_POLL_MS = 100,
    --- After /alt act or /cast Gate, extra wait before long zone wait (was 2500).
    GATE_POST_CAST_EXTRA_WAIT_MS = 2000,
    --- After failed Gate attempt, pause before waitUntil* / next attempt (was 2000).
    GATE_RETRY_BACKOFF_MS = 1200,
    --- Potion path: extra wait after cast clear before long zone wait (was 3000).
    GATE_POST_POTION_EXTRA_WAIT_MS = 2200,
    POK_TRAVEL_SHORTNAME = "poknowledge",
    --- Soulbinder Jera in Plane of Knowledge (same order as `/nav locyxz` — init.lua parity).
    POK_SOULBINDER_LOC = { -131.6, -94.2, -159.0 },
    --- After /nav to POK_SOULBINDER_LOC, wait until Me is this close (3D) before target + /say Bind.
    POK_SOULBINDER_MAX_DIST = 20,
    --- Max wait (ms) to reach Soulbinder loc after moving() completes.
    POK_SOULBINDER_LOC_WAIT_MS = 90000,
    --- If true (default), each Run: ensure bind is PoK (202) before TaskWnd sync and any travel to Big Slick for acquire.
    ENSURE_POK_BIND_BEFORE_RUN = true,
    MEMENTO_GROG_NAME = "Memento Grog",
    GUISE_SHRINK_ITEM = "Guise of the Deceiver",
    GUISE_SHRINK_HEIGHT_MIN = 2.5,
    --- Betty pocket hail radius (Live nav often stops slightly past strict 25).
    EAST_FP_BETTY_HAIL_MAX_DIST = 45,
    --- Zueria Slide (East FP -> Nektulos); `PP.pppokerZueria` + readiness snapshot.
    ZUERIA = {
        SLIDE_ITEM_BASE = "Zueria Slide",
        TARGET_MODE = "Nektulos",
        ZONE_ID_NEKTULOS = 25,
        LEVEL_FLOOR = 105,
        readiness = nil,
    },

    --- Travel (see init.lua AStone / warportal patterns)
    --- ensureZone: only refresh movement before /travelto (invis at leg-specific ensureInvisIfNeeded calls).
    MOUNT_KEYRING_SLOT = 1,
    TRAVEL_MOUNT_BEFORE_NAV = true,
    TRAVEL_DISMOUNT_BEFORE_HAIL = true,
    TRAVEL_DISMOUNT_BEFORE_GATE = true,
    TRAVEL_CITY_PREP_BEFORE_ZONE = true,
    WORN_TOTEM = "Worn Totem",
    MOVEMENT_CLASS_BUFFS = {
        BRD = { "Selo's Accelerando", "Selo's Song of Travel" },
        BST = { "Spirit of Wolf", "Spirit of the Shrew" },
        DRU = { "Spirit of Wolf", "Spirit of Cheetah" },
        RNG = { "Spirit of Wolf" },
        SHM = { "Spirit of Wolf", "Spirit of Cheetah" },
    },
    INVIS_CLASS_BUFFS = {
        CLR = {},
        DRU = { "Invisibility", "Camouflage" },
        ENC = { "Invisibility" },
        MAG = { "Invisibility" },
        NEC = { "Invisibility", "Shadow" },
        RNG = { "Camouflage" },
        SHM = { "Invisibility" },
        WIZ = { "Invisibility", "Improved Invisibility" },
    },
    INVIS_SELF_AA_NAMES = {
        "Perfected Invisibility",
        "Improved Invisibility",
        "Invisibility",
    },
    INVIS_GROUP_AA_NAMES = {
        "Group Invisibility",
        "Mass Invisibility",
        "Group Perfected Invisibility",
        "Mass Group Invisibility",
    },

    --- Moors (395): speed + mountIfNeeded. Nektulos (25): mount + 3s pause before next /travelto. Toggle off to skip both.
    TRAVEL_POKER2_MOUNT_IN_NEK_MOORS = true,
    --- Obj 8: from PoK, /travelto moors first (zone 395), then mount pause, then Highpass — matches Poker2.lua (direct PoK→Highpass skips Moors; poker2MountDelayInNekOrMoors was a no-op). Set false for direct PoK→highpasshold only.
    TRAVEL_HIGHPASS_VIA_MOORS = true,
    --- Invis before painting nav (Tassel) and similar (init.lua: city danger legs).
    TRAVEL_INVIS_BEFORE_TASSEL = true,
    --- After Nek mount, invis before /travelto neriaka (user request; Poker2 had no invis).
    TRAVEL_INVIS_BEFORE_NERIAK = true,
    --- mountIfNeeded: never use keyring mount in Neriak Foreign/Commons (walk /nav); speed+invis applied on foot in ensureSpeedAndInvisInNeriak.
    TRAVEL_NO_MOUNT_IN_NERIAK = true,
    --- After /travelto into North or South Qeynos, refresh invis before nav to POIs.
    TRAVEL_INVIS_AFTER_QEYNOS_ZONE = true,
    --- North/South Qeynos: maybeGuiseShrink in ensureSpeedAndInvisInQeynos after speed. Set false to skip.
    TRAVEL_SHRINK_IN_QEYNOS = true,
    --- Highpass Hold: Guise shrink on entry/resume (before invis). Set false to skip shrink here.
    TRAVEL_SHRINK_IN_HIGHPASS = true,
    --- Highpass: invis last via ensureInvisIfNeeded (skips if already up). Set false to skip invis in this helper.
    TRAVEL_INVIS_AFTER_HIGHPASS_ZONE = true,
    --- true = walk Highpass Hold (no keyring mount). false = mount after shrink, before invis (default).
    TRAVEL_NO_MOUNT_IN_HIGHPASS = false,
    --- Final hail Big Slick (obj 16): match Poker2 delays + journal time to credit.
    SLICK_FINAL_POST_NAV_MS = 1200,
    SLICK_FINAL_PRE_HAIL_MS = 1200,
    SLICK_FINAL_POST_HAIL_MS = 4500,
    --- Extra dwell after moving() to Slick on quest-acquire path (init.lua Poker2 buffer before range check).
    SLICK_ACQUIRE_POST_NAV_BUFFER_MS = 3000,
    WAIT_OBJECTIVE_TIMEOUT_MS = 120000,
    WAIT_OBJECTIVE_TIMEOUT_FINAL_MS = 300000,
    --- 0 = off. While waiting for objective update, re-sync TaskWnd this often (helps journal lag after hail).
    WAIT_JOURNAL_SYNC_MS = 15000,
    --- First journal refresh on Run: "minimal" = /windowstate TaskWnd fetch only (no open/close); "full" = open+fetch+close. Use full if getTask stays empty with minimal.
    TASK_JOURNAL_FIRST_SYNC = "minimal",
    --- If no Paintings task in journal, go to Slick at PP.LOC.SLICK, /say keyword, then full sync and re-check.
    TRY_BIG_SLICK_QUEST_ACQUIRE = true,
    --- After 16/16 + run time: wait this many seconds then start another Run (0 = off). Poker2.lua used `/timed 10 /lua run poker2`; here the same script stays loaded and re-enters runQuest (tryAcquire picks up quest again).
    AUTO_REPEAT_DELAY_SEC = 10,
    --- Poker2.lua uses /say paintings at Big Slick for the quest offer.
    SLICK_QUEST_KEYWORD = "paintings",

    ZONE = {
        WEST_FP = 383,
        EAST_FP = 382,
        --- Nektulos Forest (after Zueria slide); Poker2 mounts here before Neriak.
        NEKTULOS = 25,
        NERIAK_A = 40,
        NERIAK_B = 41,
        HIGHPASS = 407,
        --- Rathe / Moors (often called Blightfire); Poker2 mounts here before Highpass.
        MOORS = 395,
        NQ = 2,
        SQ = 1,
        POK = 202,
    },

    NPC = {
        SOULBINDER_JERA = { "Soulbinder Jera", "Jera" },
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
    status = "Press Run to scan journal — quest check first, then objectives.",
    step = 0,
    --- Set by refreshIdleQuestSnapshot when all objectives read complete (Status/Done).
    questComplete = false,
    --- No task in journal, or task has zero objective rows (not started / not loaded).
    needBigSlickQuest = false,
    --- After first Run: syncTaskJournalWindowFull completed; safe to call getTask / getQuestProgress in drawGUI.
    journalScannedOnce = false,
    --- Last Zueria Slide readiness summary (optional; init.lua parity).
    zueriaSlideInfo = "",
    --- Pause Nav button mirrors /nav pause (UI label); moving() uses plugin Active/Paused TLOs.
    navPaused = false,
    --- Debug toggle — show bordered in-window log (ring buffer).
    debugOpen = false,
    --- Newest lines for the Debug panel (ring buffer, max 120).
    debugLog = {},
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

-- Debug toggle: right-aligned label + green/red icon (init.lua style).
local function pppokerDrawDebugToggle()
    local dbgAvailX = select(1, getContentRegionAvail2()) or 0
    local dbgBlockW = 90
    pcall(function()
        if imgui.GetCursorPosX and imgui.SetCursorPosX then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + math.max(0, dbgAvailX - dbgBlockW))
        end
    end)
    pcall(function()
        imgui.PushID("PPPokerDebugV2")
    end)
    imgui.Text("Debug")
    imgui.SameLine()
    local onCol = getImVec4(0.0, 1.0, 0.0, 1.0)
    local offCol = getImVec4(1.0, 0.0, 0.0, 1.0)
    if gui.debugOpen then
        if Icons and Icons.FA_TOGGLE_ON then
            pcall(function()
                imgui.TextColored(onCol or getImVec4(0, 1, 0, 1), Icons.FA_TOGGLE_ON)
            end)
        else
            pcall(function()
                imgui.TextColored(onCol or getImVec4(0, 1, 0, 1), "ON")
            end)
        end
    else
        if Icons and Icons.FA_TOGGLE_OFF then
            pcall(function()
                imgui.TextColored(offCol or getImVec4(1, 0, 0, 1), Icons.FA_TOGGLE_OFF)
            end)
        else
            pcall(function()
                imgui.TextColored(offCol or getImVec4(1, 0, 0, 1), "OFF")
            end)
        end
    end
    pcall(function()
        if imgui.IsItemHovered and imgui.SetTooltip and imgui.IsMouseClicked then
            if imgui.IsItemHovered() then
                imgui.SetTooltip(gui.debugOpen and "On (click to turn off)" or "Off (click to turn on)")
                if imgui.IsMouseClicked(0) then
                    gui.debugOpen = not gui.debugOpen
                end
            end
        end
    end)
    pcall(function()
        imgui.PopID()
    end)
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

--- Per-bar shimmer phase (follows fill direction); keyed by ImGui bar id string.
local objectiveBarShimmerState = {}

local function sbGetObjectiveBarState(label, now)
    local state = objectiveBarShimmerState[label]
    if not state then
        state = { lastP = 0.0, dir = 1, t0 = now }
        objectiveBarShimmerState[label] = state
    end
    return state
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

        local shimmerOn = (opts.shimmer ~= false)
        if shimmerOn then
            local now = mq.gettime()
            local shimmerFollows = (opts.shimmerFollows ~= false)
            local shimmerSpeed = opts.shimmerSpeed or 0.5
            if shimmerSpeed <= 0 then shimmerSpeed = 0.5 end
            local shimmerWidth = opts.shimmerWidth or 60.0
            local deadzone = opts.shimmerDeadzone or 0.001
            local barState = sbGetObjectiveBarState(label, now)

            local phase = (((now - (barState.t0 or now)) * 0.001) * shimmerSpeed) % 1.0

            if shimmerFollows then
                local delta = progress - (barState.lastP or progress)
                local newDir = barState.dir or 1
                if delta > deadzone then newDir = 1 end
                if delta < -deadzone then newDir = -1 end
                if newDir ~= (barState.dir or 1) then
                    barState.t0 = now - (phase / shimmerSpeed) * 1000.0
                    barState.dir = newDir
                end
            else
                barState.dir = 1
            end

            phase = (((now - (barState.t0 or now)) * 0.001) * shimmerSpeed) % 1.0

            local pos01 = phase
            if shimmerFollows and (barState.dir or 1) < 0 then
                pos01 = 1.0 - phase
            end

            local shimmer_pos = pos01 * filled_w
            if shimmer_pos < filled_w then
                local denom = math.max(filled_w, 0.001)
                local shimmer_alpha = 0.15 * math.sin((shimmer_pos / denom) * math.pi)
                local a_sh = math.floor(shimmer_alpha * 255)

                dl:AddRectFilledMultiColor(
                    ImVec2(bar_pos.x + shimmer_pos, bar_pos.y),
                    ImVec2(bar_pos.x + shimmer_pos + shimmerWidth, bar_pos.y + bar_size.y),
                    IM_COL32(255, 255, 255, 0),
                    IM_COL32(255, 255, 255, a_sh),
                    IM_COL32(255, 255, 255, a_sh),
                    IM_COL32(255, 255, 255, 0)
                )
            end

            barState.lastP = progress
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

local function pushDebugLine(msg, alsoPrint)
    local line = os.date("%H:%M:%S") .. " " .. tostring(msg or "")
    gui.debugLog[#gui.debugLog + 1] = line
    if #gui.debugLog > 120 then
        table.remove(gui.debugLog, 1)
    end
    if alsoPrint then
        print(line)
    end
end

--- Append to Debug panel; also prints timestamped line to EQ console (CWTN / atlas / wait loops).
debugLog = function(msg)
    pushDebugLine(msg, true)
end

-- Message body often started with "PPPoker:"; print already prefixes [\agPPPoker\ao].
local function stripPppokerPrefix(msg)
    local s = tostring(msg or "")
    return (s:gsub("^PPPoker:%s*", ""))
end

--- Wrap spell name for console (purple/magenta); reset after. Use "\\a" so strings contain \a + letter (MQ triplet).
local function mqSpell(name)
    return "\\am" .. tostring(name or "") .. "\\at"
end

--- Objective completion / "all done" lines (green).
local function mqObjGreen(msg)
    return "\\ag" .. tostring(msg or "") .. "\\at"
end

local function info(msg)
    local s = stripPppokerPrefix(msg)
    print(string.format("\ao[\agPPPoker\ao]\at %s\ax", s))
    pushDebugLine(s, false)
end

local function warn(msg)
    local s = stripPppokerPrefix(msg)
    print(string.format("\ao[\ayPPPoker\ao]\at %s\ax", s))
    pushDebugLine("\\ayWARN:\\at " .. s, false)
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

--- MQ taskobjective: intRequiredCount / intCurrentCount (see datatype-taskobjective); Lua bindings may expose RequiredCount/CurrentCount. Matches init.lua progress via cur vs req.
local function objectiveReqCur(obj)
    if not obj then
        return nil, nil
    end
    local req, cur
    pcall(function()
        if obj.RequiredCount and type(obj.RequiredCount) == "function" then
            req = tonumber(obj.RequiredCount())
        end
    end)
    pcall(function()
        if obj.CurrentCount and type(obj.CurrentCount) == "function" then
            cur = tonumber(obj.CurrentCount())
        end
    end)
    if req == nil then
        pcall(function()
            if obj.intRequiredCount and type(obj.intRequiredCount) == "function" then
                req = tonumber(obj.intRequiredCount())
            end
        end)
    end
    if cur == nil then
        pcall(function()
            if obj.intCurrentCount and type(obj.intCurrentCount) == "function" then
                cur = tonumber(obj.intCurrentCount())
            end
        end)
    end
    return req, cur
end

--- Journal completion: Required/Current counts, then Status() text. MQ datatype taskobjective has no Done member (do not reference .Done() — spams console).
local function objectiveIsComplete(obj)
    if not obj then
        return false
    end
    primeObjectiveSlot(obj)

    local req, cur = objectiveReqCur(obj)
    if req and req > 0 and cur and cur >= req then
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
        if s == "done" or s == "complete" or s == "completed" then
            return true
        end
        local cStr, tStr = raw:match("^%s*(%d+)%s*/%s*(%d+)%s*$")
        if cStr and tStr then
            local c, t = tonumber(cStr), tonumber(tStr)
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

--- Auto-repeat delay after success; returns false if Stop pressed or ImGui window closed.
local function delayMsWithStopCheck(ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then
        return true
    end
    local t0 = mq.gettime()
    while mq.gettime() - t0 < ms do
        if stopRequested or not gui.open then
            return false
        end
        mq.delay(200)
    end
    return true
end

local function shouldStop()
    if stopRequested then
        haltNavigationForStop()
        error("Stopped by user")
    end
    -- Closing the ImGui window does not set stopRequested; main thread must abort when X is pressed.
    if not gui.open then
        haltNavigationForStop()
        error("Stopped by user")
    end
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

--- MQ2Nav: prefer ${Navigation.Active} when present (do not OR with Nav — stale Nav.Active can stuck moving()).
local function navigationIsActive()
    local function truthyActive(v)
        if v == nil then return false end
        if type(v) == "boolean" then return v end
        if type(v) == "number" then return v ~= 0 end
        if type(v) == "string" then
            local s = tostring(v):lower():gsub("^%s+", ""):gsub("%s+$", "")
            if s == "" or s == "false" or s == "0" or s == "off" or s == "no" or s == "inactive" or s == "idle" or s == "stopped" or s == "done" or s == "nil" or s == "null" then
                return false
            end
            if s == "true" or s == "1" or s == "on" or s == "yes" or s == "active" or s == "running" then
                return true
            end
            return false
        end
        return false
    end
    local function readActive(tlo)
        if not tlo or not tlo.Active then return false end
        local a = tlo.Active
        local ok, v = pcall(function()
            if type(a) == "function" then return a() end
            return a
        end)
        if not ok then return false end
        return truthyActive(v)
    end
    local ok, active = pcall(function()
        if mq.TLO.Navigation then
            return readActive(mq.TLO.Navigation)
        end
        if mq.TLO.Nav then
            return readActive(mq.TLO.Nav)
        end
        return false
    end)
    return ok and active == true
end

--- MQ2Nav: true while path is paused (/nav pause) — path kept; Active may be false while Paused is true.
local function navigationIsPaused()
    local function truthyPaused(v)
        if v == nil then return false end
        if type(v) == "boolean" then return v end
        if type(v) == "number" then return v ~= 0 end
        if type(v) == "string" then
            local s = tostring(v):lower():gsub("^%s+", ""):gsub("%s+$", "")
            if s == "" or s == "false" or s == "0" or s == "off" or s == "no" or s == "nil" or s == "null" then
                return false
            end
            if s == "true" or s == "1" or s == "on" or s == "yes" or s == "paused" or s:find("pause", 1, true) then
                return true
            end
            return false
        end
        return false
    end
    local function readPaused(tlo)
        if not tlo or not tlo.Paused then return false end
        local p = tlo.Paused
        local ok, v = pcall(function()
            if type(p) == "function" then return p() end
            return p
        end)
        if not ok then return false end
        return truthyPaused(v)
    end
    local ok, paused = pcall(function()
        if mq.TLO.Navigation then
            return readPaused(mq.TLO.Navigation)
        end
        if mq.TLO.Nav then
            return readPaused(mq.TLO.Nav)
        end
        return false
    end)
    return ok and paused == true
end

local function navPluginPause()
    pcall(function() mq.cmd("/squelch /nav pause") end)
end

local function navPluginUnpause()
    pcall(function() mq.cmd("/squelch /nav pause off") end)
end

local function navStopQuiet()
    pcall(function() mq.cmd("/squelch /nav stop") end)
end

--- Wait for /nav to arm, then until Navigation.Active and Paused both clear (pause keeps path; use Paused TLO + gui.navPaused fallback).
local function moving(timeoutMs)
    timeoutMs = timeoutMs or 120000
    mq.delay(400)
    local armUntil = os.time() + 3
    while not navigationIsActive() and not navigationIsPaused() and os.time() < armUntil do
        shouldStop()
        mq.delay(50)
    end
    if not navigationIsActive() and not navigationIsPaused() then
        mq.delay(2500)
    end
    local start = os.time()
    while navigationIsActive() or navigationIsPaused() or gui.navPaused do
        shouldStop()
        mq.delay(100)
        if (os.time() - start) * 1000 > timeoutMs then
            warn("Navigation timeout threshold reached; waiting grace period...")
            mq.delay(5000)
            if navigationIsActive() or navigationIsPaused() then
                warn("Navigation still active/paused after grace. Issuing /nav stop and continuing.")
                navStopQuiet()
                mq.delay(1200)
            end
            if navigationIsActive() or navigationIsPaused() then
                warn("Navigation still reports active/paused after /nav stop — continuing run anyway.")
            end
            gui.navPaused = false
            return true
        end
    end
    gui.navPaused = false
    return true
end

-- ========== Travel: mount, movement, invis (init.lua-aligned) ==========

local function waitUntilMs(maxMs, predicate)
    local t0 = mq.gettime()
    while mq.gettime() - t0 < maxMs do
        local ok, v = pcall(predicate)
        if ok and v then return true end
        mq.delay(100)
    end
    return false
end

--- Wait until ${Me.Casting} clears (speed buffs / items before mount, etc.).
local function waitMeNotCasting(timeoutMs)
    timeoutMs = timeoutMs or 30000
    local t0 = mq.gettime()
    while mq.gettime() - t0 < timeoutMs do
        shouldStop()
        local ok, c = pcall(function() return mq.TLO.Me.Casting() end)
        if ok and not c then
            return true
        end
        mq.delay(100)
    end
    local ok, c = pcall(function() return mq.TLO.Me.Casting() end)
    return ok and not c
end

local function hasItem(name)
    local ok, found = pcall(function() return mq.TLO.FindItem(name)() end)
    return ok and found
end

--- Zueria Slide (init.lua-aligned); `PP.ZUERIA` holds constants + readiness.
local pppokerZueria = {}

function pppokerZueria.itemName()
    local c = PP.ZUERIA
    local ok, name = pcall(function() return mq.TLO.FindItem(c.SLIDE_ITEM_BASE).Name() end)
    if not ok or not name or name == "" then return nil end
    return tostring(name)
end

function pppokerZueria.refreshReadiness()
    local c = PP.ZUERIA
    local target = c.TARGET_MODE
    local R = {
        hasItem = false,
        itemName = nil,
        meLevel = 0,
        requiredFromTLO = 0,
        effectiveRequired = 0,
        levelOk = true,
        modeMatches = false,
        canAttemptSlide = false,
        reason = "no_item",
        summary = "",
    }
    pcall(function()
        R.meLevel = tonumber(mq.TLO.Me.Level() or 0) or 0
    end)
    local ok, item = pcall(function() return mq.TLO.FindItem(c.SLIDE_ITEM_BASE) end)
    if not ok or not item or not item() then
        R.summary = "Zueria Slide: not in inventory - after Betty, script uses Gate/PoK routing."
        c.readiness = R
        return R
    end
    R.hasItem = true
    R.itemName = pppokerZueria.itemName()
    pcall(function()
        if item.RequiredLevel then
            R.requiredFromTLO = tonumber(item.RequiredLevel() or 0) or 0
        end
    end)
    local floor = tonumber(c.LEVEL_FLOOR) or 0
    R.effectiveRequired = (R.requiredFromTLO > 0) and R.requiredFromTLO or floor
    if R.effectiveRequired > 0 then
        if R.meLevel <= 0 then
            R.levelOk = false
            R.reason = "level_unread"
            R.summary = "Zueria Slide: could not read character level - slide skipped (Gate/PoK route after grog)."
        elseif R.meLevel < R.effectiveRequired then
            R.levelOk = false
            R.reason = "under_level"
            R.summary = string.format(
                "Zueria Slide: level %d below required %d - slide step skipped.",
                R.meLevel,
                R.effectiveRequired
            )
        else
            R.levelOk = true
            R.reason = "ok_level"
        end
    else
        R.levelOk = true
        R.reason = "ok_level"
    end
    if R.itemName and R.itemName:find(target, 1, true) then
        R.modeMatches = true
    end
    if R.levelOk and R.modeMatches then
        R.reason = "ready"
    elseif R.levelOk and R.hasItem then
        R.reason = "needs_convert"
    end
    R.canAttemptSlide = R.hasItem and R.levelOk
    if R.reason == "ready" then
        R.summary = string.format(
            "Zueria Slide: %s | level %d OK | %s mode - will use after Betty grog.",
            tostring(R.itemName or "?"),
            R.meLevel,
            target
        )
    elseif R.reason == "needs_convert" then
        R.summary = string.format(
            "Zueria Slide: %s | level %d OK - will /convertitem toward %s after Betty if needed.",
            tostring(R.itemName or "?"),
            R.meLevel,
            target
        )
    elseif R.summary == "" then
        R.summary = string.format("Zueria Slide: %s | level %d", tostring(R.itemName or "?"), R.meLevel)
    end
    c.readiness = R
    return R
end

function pppokerZueria.ensureTargetMode(mode)
    mode = mode or PP.ZUERIA.TARGET_MODE
    local current = pppokerZueria.itemName()
    if not current then return nil end
    if current:find(mode, 1, true) then
        return current
    end
    for attempt = 1, 8 do
        info(string.format("Converting %s (attempt %d/8) toward mode: %s", current, attempt, mode))
        mq.cmdf('/convertitem "%s"', current)
        mq.delay(1500)
        current = pppokerZueria.itemName()
        if not current then return nil end
        if current:find(mode, 1, true) then
            info("Zueria Slide mode ready: " .. current)
            return current
        end
    end
    warn("Could not convert Zueria Slide to mode: " .. mode)
    return current
end

function pppokerZueria.runAfterMementoGrog()
    local c = PP.ZUERIA
    local zs = pppokerZueria.refreshReadiness()
    if zs.summary then
        info(zs.summary)
    end
    pcall(function()
        gui.zueriaSlideInfo = tostring(zs.summary or "")
    end)
    if not zs.canAttemptSlide then
        info("Skipping Zueria slide - using Gate/PoK routing toward Neriak.")
        return
    end
    local slideReady = pppokerZueria.ensureTargetMode()
    if slideReady and slideReady:find(c.TARGET_MODE, 1, true) then
        local zid = c.ZONE_ID_NEKTULOS
        mq.cmdf('/useitem "%s"', slideReady)
        info("Zueria Slide: waiting for Nektulos zone…")
        local t0 = mq.gettime()
        while mq.gettime() - t0 < 30000 do
            if mq.TLO.Zone.ID() == zid then
                info("Zueria Slide: arrived in Nektulos.")
                break
            end
            mq.delay(250)
        end
        local zoned = (mq.TLO.Zone.ID() == zid)
        for attempt = 1, 2 do
            if zoned then break end
            if mq.TLO.Me.Casting() then break end
            mq.cmdf('/useitem "%s"', slideReady)
            zoned = waitForZoneOrFalse(zid, 30000)
            if zoned then break end
        end
        if not zoned then
            warn("Zueria slide did not zone to Nektulos in time - continuing with Gate/PoK route.")
        end
    end
    local r = c.readiness
    if r and r.summary then
        pcall(function()
            gui.zueriaSlideInfo = tostring(r.summary)
        end)
    end
end

PP.pppokerZueria = pppokerZueria

local function findFreeGemSlotPpp()
    local maxGems = mq.TLO.Me.NumGems() or 8
    for i = 1, maxGems do
        if not mq.TLO.Me.Gem(i).ID() then return i end
    end
    local lastSlot = maxGems
    info(string.format("all gem slots full, clearing slot %d for buff spell.", lastSlot))
    mq.cmdf("/memspell %d clear", lastSlot)
    mq.delay(2000)
    return lastSlot
end

local function meditateToManaPpp(requiredMana)
    requiredMana = requiredMana or 40
    if (mq.TLO.Me.CurrentMana() or 0) >= requiredMana then return end
    info(string.format("meditating for mana (need %d)...", requiredMana))
    mq.cmd("/sit on")
    local t0 = mq.gettime()
    local timeoutMs = 120000
    while (mq.TLO.Me.CurrentMana() or 0) < requiredMana do
        if mq.gettime() - t0 >= timeoutMs then
            warn("meditate timeout; standing.")
            mq.cmd("/stand")
            return
        end
        mq.delay(500)
        if not mq.TLO.Me.Sitting() then mq.cmd("/sit on") end
    end
    mq.cmd("/stand")
end

local function pppokerMovementBuffPresent()
    local class = mq.TLO.Me.Class.ShortName()
    local list = PP.MOVEMENT_CLASS_BUFFS[class]
    if list then
        for _, spell in ipairs(list) do
            local ok, id = pcall(function() return mq.TLO.Me.Buff(spell).ID() end)
            if ok and id and tonumber(id or 0) > 0 then return true, spell end
        end
    end
    return false, nil
end

local function pppokerUseWornTotemIfAvailable()
    if not hasItem(PP.WORN_TOTEM) then return false end
    info("using Worn Totem for speed.")
    mq.cmdf('/useitem "%s"', PP.WORN_TOTEM)
    waitMeNotCasting(12000)
    mq.delay(400)
    return true
end

local function pppokerApplyMovementClassBuff()
    local class = mq.TLO.Me.Class.ShortName()
    local list = PP.MOVEMENT_CLASS_BUFFS[class]
    if not list then return false end
    for _, spell in ipairs(list) do
        local spellData = mq.TLO.Spell(spell)
        if spellData and spellData.ID() and tonumber(spellData.ID() or 0) > 0 then
            local gemSlot
            local maxGems = mq.TLO.Me.NumGems() or 8
            for i = 1, maxGems do
                local n = mq.TLO.Me.Gem(i).Name()
                if n and n:lower() == spell:lower() then
                    gemSlot = i
                    break
                end
            end
            if not gemSlot then
                gemSlot = findFreeGemSlotPpp()
                info(string.format("memorizing %s in gem %d", mqSpell(spell), gemSlot))
                mq.cmdf('/memspell %d "%s"', gemSlot, spell)
                mq.delay(8000)
            end
            local maxRetries = 8
            for attempt = 1, maxRetries do
                meditateToManaPpp(40)
                if mq.TLO.Me.SpellReady(spell)() then
                    mq.cmd("/target myself")
                    mq.delay(400)
                    mq.cmdf('/cast "%s"', spell)
                    local castTime = spellData.CastTime() or 5000
                    waitUntilMs(castTime + 3500, function() return not mq.TLO.Me.Casting() end)
                    mq.delay(1500)
                    local ok, bid = pcall(function() return mq.TLO.Me.Buff(spell).ID() end)
                    if ok and bid and tonumber(bid or 0) > 0 then
                        info(string.format("movement buff applied: %s", mqSpell(spell)))
                        return true
                    end
                    warn(string.format("%s cast did not stick (attempt %d/%d).", mqSpell(spell), attempt, maxRetries))
                else
                    mq.delay(2000)
                end
            end
        end
    end
    return false
end

local function pppokerEnsureMovementBuff()
    local hasM, which = pppokerMovementBuffPresent()
    if hasM then return true, which end
    if pppokerApplyMovementClassBuff() then return true, "class spell" end
    if pppokerUseWornTotemIfAvailable() then return true, PP.WORN_TOTEM end
    return false, nil
end

local function pppokerMqBool(v)
    if v == true then return true end
    if v == false or v == nil then return false end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local u = v:upper()
        if u == "TRUE" or u == "ON" or u == "1" then return true end
        return false
    end
    return false
end

local function pppokerInvisibleTLO()
    local ok, inv = pcall(function() return mq.TLO.Me.Invisible() end)
    if ok and pppokerMqBool(inv) then return true end
    return false
end

local function pppokerLivingInvisTLO()
    local ok, v = pcall(function()
        local t = mq.TLO.Me.Invis(1)
        if t == nil then return false end
        if type(t) == "function" then
            return t()
        end
        return t
    end)
    if ok and pppokerMqBool(v) then return true end
    return false
end

local function pppokerInvisBuffIdByName(buffName)
    if not buffName or buffName == "" then return false end
    local ok, bid = pcall(function() return mq.TLO.Me.Buff(buffName).ID() end)
    if ok and bid and tonumber(bid or 0) > 0 then return true end
    return false
end

local function pppokerInvisKnownAaBuffPresent()
    for _, name in ipairs(PP.INVIS_SELF_AA_NAMES) do
        if pppokerInvisBuffIdByName(name) then return true, name end
    end
    for _, name in ipairs(PP.INVIS_GROUP_AA_NAMES) do
        if pppokerInvisBuffIdByName(name) then return true, name end
    end
    return false, nil
end

local function pppokerInvisBuffPresent()
    local class = mq.TLO.Me.Class.ShortName()
    if class == "ROG" then
        if pppokerInvisibleTLO() then return true, "Hide/Sneak" end
        return false, nil
    end
    local list = PP.INVIS_CLASS_BUFFS[class]
    if not list then return true, nil end
    local aaOk, aaWhich = pppokerInvisKnownAaBuffPresent()
    if aaOk then return true, aaWhich end
    for _, spell in ipairs(list) do
        local ok, id = pcall(function() return mq.TLO.Me.Buff(spell).ID() end)
        if ok and id and tonumber(id or 0) > 0 then return true, spell end
    end
    if pppokerLivingInvisTLO() then return true, "Invis(1)" end
    if pppokerInvisibleTLO() then return true, "Invisible" end
    return false, nil
end

local function pppokerInvisAAId(aaName)
    local ok, id = pcall(function()
        local a = mq.TLO.Me.AltAbility(aaName)
        if a == nil then return 0 end
        if type(a) == "function" then
            a = a()
        end
        if not a then return 0 end
        return tonumber(a.ID() or 0) or 0
    end)
    if ok and id and tonumber(id) and tonumber(id) > 0 then return tonumber(id) end
    return 0
end

local function pppokerInvisAAReady(aaName)
    local ok, r = pcall(function()
        local v = mq.TLO.Me.AltAbilityReady(aaName)
        if type(v) == "function" then
            v = v()
        end
        return v
    end)
    if not ok or r == nil then return nil end
    if r == true then return true end
    if r == false then return false end
    return nil
end

local function pppokerTryActivateInvisAA(aaName)
    local id = pppokerInvisAAId(aaName)
    if id <= 0 then return false end
    local ready = pppokerInvisAAReady(aaName)
    if ready == false then return false end
    mq.cmd("/target myself")
    mq.delay(200)
    mq.cmdf("/alt act %d", id)
    mq.delay(250)
    local sawCasting = waitUntilMs(2000, function() return mq.TLO.Me.Casting() ~= nil end)
    if sawCasting then
        waitUntilMs(12000, function() return mq.TLO.Me.Casting() == nil end)
    else
        mq.delay(500)
    end
    return waitUntilMs(6000, function()
        return pppokerLivingInvisTLO() or pppokerInvisibleTLO() or pppokerInvisBuffIdByName(aaName)
    end)
end

local function pppokerApplyInvisViaAA()
    local class = mq.TLO.Me.Class.ShortName()
    if class == "ROG" then return false end
    if not PP.INVIS_CLASS_BUFFS[class] then return false end
    for _, name in ipairs(PP.INVIS_SELF_AA_NAMES) do
        if pppokerTryActivateInvisAA(name) then return true end
    end
    for _, name in ipairs(PP.INVIS_GROUP_AA_NAMES) do
        if pppokerTryActivateInvisAA(name) then return true end
    end
    return false
end

local function pppokerRogueSneakHide()
    info("ROG - Sneak, then Hide.")
    mq.cmd("/doability Sneak")
    mq.delay(800)
    mq.cmd("/doability Hide")
    mq.delay(1500)
    return true
end

local function pppokerApplyInvisClassBuff()
    local class = mq.TLO.Me.Class.ShortName()
    if class == "ROG" then
        if pppokerInvisibleTLO() then return true end
        return pppokerRogueSneakHide()
    end
    if pppokerInvisKnownAaBuffPresent() then return true end
    local list = PP.INVIS_CLASS_BUFFS[class]
    if not list then return true end
    for _, spell in ipairs(list) do
        if pppokerInvisBuffIdByName(spell) then return true end
    end
    if pppokerLivingInvisTLO() then return true end
    if pppokerInvisibleTLO() then return true end
    for _, spell in ipairs(list) do
        local spellData = mq.TLO.Spell(spell)
        if spellData and spellData.ID() and tonumber(spellData.ID() or 0) > 0 then
            local gemSlot
            local maxGems = mq.TLO.Me.NumGems() or 8
            for i = 1, maxGems do
                local n = mq.TLO.Me.Gem(i).Name()
                if n and n:lower() == spell:lower() then
                    gemSlot = i
                    break
                end
            end
            if not gemSlot then
                gemSlot = findFreeGemSlotPpp()
                info(string.format("memorizing invis %s in gem %d", mqSpell(spell), gemSlot))
                mq.cmdf('/memspell %d "%s"', gemSlot, spell)
                mq.delay(8000)
            end
            local maxRetries = 8
            for attempt = 1, maxRetries do
                meditateToManaPpp(40)
                if mq.TLO.Me.SpellReady(spell)() then
                    mq.cmd("/target myself")
                    mq.delay(400)
                    mq.cmdf('/cast "%s"', spell)
                    local castTime = spellData.CastTime() or 5000
                    waitUntilMs(castTime + 3500, function() return not mq.TLO.Me.Casting() end)
                    mq.delay(1500)
                    local ok, bid = pcall(function() return mq.TLO.Me.Buff(spell).ID() end)
                    if ok and bid and tonumber(bid or 0) > 0 then
                        info(string.format("invis buff applied: %s", mqSpell(spell)))
                        return true
                    end
                    warn(string.format("invis %s did not stick (attempt %d/%d).", mqSpell(spell), attempt, maxRetries))
                else
                    mq.delay(2000)
                end
            end
        end
    end
    return false
end

local function pppokerEnsureInvisBuff()
    local ok, which = pppokerInvisBuffPresent()
    if ok then return true, which end
    if pppokerApplyInvisViaAA() then return true, "AA" end
    if pppokerApplyInvisClassBuff() then return true, "spell" end
    if pppokerLivingInvisTLO() then return true, "Invis(1) TLO" end
    if pppokerInvisibleTLO() then return true, "Invisible TLO" end
    return false, nil
end

--- Apply invis only if not already present (avoids duplicate casts after preflight / Tassel prep).
local function ensureInvisIfNeeded(label)
    local invOk, invWhich = pppokerInvisBuffPresent()
    if invOk then
        info(string.format("invis already up (%s) - skip recast (%s).", mqSpell(tostring(invWhich or "?")), tostring(label)))
        return true
    end
    info("invis - " .. tostring(label))
    pppokerEnsureInvisBuff()
    waitUntilMs(8000, function()
        return not mq.TLO.Me.Casting()
    end)
    mq.delay(300)
    return true
end

--- One Guise click per Run; one shrink /popup per Run (reset at runQuest start).
local guiseShrinkUsedThisRun = false
local guiseShrinkPopupShownThisRun = false

local function resetGuiseShrinkSession()
    guiseShrinkUsedThisRun = false
    guiseShrinkPopupShownThisRun = false
end

local function maybeGuiseShrink(contextLabel)
    if guiseShrinkUsedThisRun then
        return
    end
    local item = PP.GUISE_SHRINK_ITEM or "Guise of the Deceiver"
    if not hasItem(item) then return end
    local ok, h = pcall(function() return mq.TLO.Me.Height() end)
    h = (ok and tonumber(h or 0)) or 0
    local minH = tonumber(PP.GUISE_SHRINK_HEIGHT_MIN) or 2.5
    if h <= minH then return end
    guiseShrinkUsedThisRun = true
    info("shrink (" .. tostring(contextLabel) .. ") - " .. item)
    mq.cmdf('/useitem "%s"', item)
    mq.delay(8500)
    if not guiseShrinkPopupShownThisRun then
        guiseShrinkPopupShownThisRun = true
        pcall(function()
            mq.cmd("/popup You are a bit tall, lets shrink a little to make it easier")
        end)
    end
end

local function prepBeforeTasselLeg()
    pppokerEnsureMovementBuff()
    if PP.TRAVEL_INVIS_BEFORE_TASSEL then
        ensureInvisIfNeeded("Tassel painting (before /nav)")
    end
end

local function prepCityTravel(whereLabel)
    if not PP.TRAVEL_CITY_PREP_BEFORE_ZONE then return end
    whereLabel = whereLabel or "city zone"
    info("prep for " .. whereLabel .. " - movement speed only (invis at leg-specific points).")
    local movOk, movDetail = pppokerEnsureMovementBuff()
    if movOk then
        info("movement OK (" .. tostring(movDetail or "?") .. ").")
    else
        warn("movement buff missing - use SoW/Selo/totem manually.")
    end
    waitUntilMs(8000, function() return not mq.TLO.Me.Casting() end)
    mq.delay(300)
end

local function zoneWantsCityPrep(zoneId)
    local z = tonumber(zoneId)
    return z == PP.ZONE.WEST_FP
        or z == PP.ZONE.EAST_FP
        or z == PP.ZONE.NERIAK_A
        or z == PP.ZONE.NERIAK_B
        or z == PP.ZONE.HIGHPASS
        or z == PP.ZONE.NQ
        or z == PP.ZONE.SQ
        or z == PP.ZONE.MOORS
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

local function mountKeyringSlot1Name()
    local ok, name = pcall(function()
        return mq.parse(string.format("${Mount[%d].Name}", PP.MOUNT_KEYRING_SLOT))
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
    if not PP.TRAVEL_MOUNT_BEFORE_NAV then return false end
    local zid = mq.TLO.Zone.ID()
    if PP.TRAVEL_NO_MOUNT_IN_NERIAK ~= false then
        if zid == PP.ZONE.NERIAK_A or zid == PP.ZONE.NERIAK_B then
            return false
        end
    end
    if zid == PP.ZONE.NQ or zid == PP.ZONE.SQ then
        return false
    end
    if PP.TRAVEL_NO_MOUNT_IN_HIGHPASS ~= false then
        if zid == PP.ZONE.HIGHPASS then
            return false
        end
    end
    if isMounted() then return true end
    if classIsBard() then
        return false
    end
    local mountName = mountKeyringSlot1Name()
    if mountName then
        info("Mounting (keyring " .. tostring(PP.MOUNT_KEYRING_SLOT) .. "): " .. mountName)
        waitMeNotCasting(45000)
        mq.cmd("/useitem ${Mount[" .. tostring(PP.MOUNT_KEYRING_SLOT) .. "]}")
        local tCast = mq.gettime()
        while mq.gettime() - tCast < 18000 do
            shouldStop()
            local ok, casting = pcall(function() return mq.TLO.Me.Casting() end)
            if ok and not casting then break end
            mq.delay(100)
        end
        mq.delay(200)
        local tMount = mq.gettime()
        while mq.gettime() - tMount < 18000 do
            shouldStop()
            if isMounted() then return true end
            mq.delay(100)
        end
        if not isMounted() then
            warn("Mount: still not mounted after wait — continuing (may move before mount completes).")
        end
        return true
    end
    return false
end

local function dismountIfMounted(reason)
    if not isMounted() then return false end
    if reason and reason ~= "" then
        info("Dismount: " .. tostring(reason))
    end
    mq.cmd("/dismount")
    mq.delay(500)
    return true
end

local function ensureZone(zoneId, travelToArg, label, timeoutMs)
    if mq.TLO.Zone.ID() == zoneId then
        info(string.format("Already in %s (%d), skipping /travelto.", tostring(label), zoneId))
        return
    end
    if PP.TRAVEL_CITY_PREP_BEFORE_ZONE and zoneWantsCityPrep(zoneId) then
        prepCityTravel(tostring(label))
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

--- skipDismount: set true for Highpass Quinn/Mhrai (avoid dismount while moving between paintings).
local function targetOrFail(names, failMsg, timeoutMs, skipDismount)
    if PP.TRAVEL_DISMOUNT_BEFORE_HAIL and not skipDismount then
        dismountIfMounted("hail/target")
    end
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
    mountIfNeeded()
    settleMs = settleMs or 1000
    mq.cmdf('/squelch /nav locyxz %.1f %.1f %.1f', loc[1], loc[2], loc[3])
    moving()
    mq.delay(settleMs)
end

local function navLocNoMount(loc, settleMs)
    settleMs = settleMs or 1000
    mq.cmdf('/squelch /nav locyxz %.1f %.1f %.1f', loc[1], loc[2], loc[3])
    moving()
    mq.delay(settleMs)
end

local function boundToGateZone()
    local ok, zid = pcall(function() return mq.TLO.Me.ZoneBound.ID() end)
    return ok and tonumber(zid or 0) == PP.GATE_ZONE_ID
end

--- `loc` matches `/nav locyxz` argument order (y, x, z).
local function distanceMeToLocYXZ(loc)
    if not loc or not loc[1] then
        return 99999
    end
    local okY, my = pcall(function() return mq.TLO.Me.Y() end)
    local okX, mx = pcall(function() return mq.TLO.Me.X() end)
    local okZ, mz = pcall(function() return mq.TLO.Me.Z() end)
    if not (okY and okX and okZ) then
        return 99999
    end
    local dy = (my or 0) - loc[1]
    local dx = (mx or 0) - loc[2]
    local dz = (mz or 0) - loc[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function waitNearLocYXZ(loc, maxDist, timeoutMs)
    maxDist = tonumber(maxDist) or 20
    timeoutMs = tonumber(timeoutMs) or 90000
    local t0 = mq.gettime()
    while mq.gettime() - t0 < timeoutMs do
        shouldStop()
        if distanceMeToLocYXZ(loc) <= maxDist then
            return true
        end
        mq.delay(200)
    end
    return false
end

--- Gate AA / philter returns need bind to PoK (202). init.lua: ensure before quest steps; here before journal + Slick acquire.
local function ensurePokBind()
    if PP.ENSURE_POK_BIND_BEFORE_RUN == false then
        return
    end
    if boundToGateZone() then
        info("PoK bind OK (zone " .. tostring(PP.GATE_ZONE_ID) .. ").")
        return
    end
    pcall(function()
        mq.cmd("/popup Please Start in PoK")
    end)
    info("Please Start in PoK — not bound to Plane of Knowledge; travelling to Soulbinder Jera to bind.")
    warn("No PoK bind; travelling to Plane of Knowledge to bind with Soulbinder Jera...")
    if mq.TLO.Zone.ID() ~= PP.GATE_ZONE_ID then
        mq.cmdf("/squelch /travelto %s", PP.POK_TRAVEL_SHORTNAME or "poknowledge")
        zoning(PP.GATE_ZONE_ID)
    end
    mq.delay(1000)
    local loc = PP.POK_SOULBINDER_LOC
    if not loc or not loc[1] then
        warn("POK_SOULBINDER_LOC missing — skip Soulbinder nav.")
        return
    end
    mq.cmdf("/squelch /nav locyxz %.1f %.1f %.1f", loc[1], loc[2], loc[3])
    moving()
    local maxD = tonumber(PP.POK_SOULBINDER_MAX_DIST) or 20
    local waitMs = tonumber(PP.POK_SOULBINDER_LOC_WAIT_MS) or 90000
    info(string.format("waiting at Soulbinder loc (within %d) before target...", maxD))
    if not waitNearLocYXZ(loc, maxD, waitMs) then
        warn("did not reach Soulbinder loc within distance — attempting target anyway.")
    else
        mq.delay(400)
    end
    targetOrFail(PP.NPC.SOULBINDER_JERA, "Could not target Soulbinder Jera for PoK bind")
    mq.delay(500)
    pcall(function() mq.cmd("/face fast") end)
    mq.cmd("/say Bind")
    mq.delay(5000)
    if boundToGateZone() then
        info("PoK bind acquired.")
    else
        warn("PoK bind may not have completed; verify in-game. Continuing quest.")
    end
end

local function hasGateAA()
    local ok, id = pcall(function() return mq.TLO.Me.AltAbility("Gate").ID() end)
    return ok and tonumber(id or 0) > 0
end

local function hasGateSpell()
    local name = PP.GATE_SPELL_NAME or "Gate"
    local ok, has = pcall(function()
        local s = mq.TLO.Me.Spell(name)
        return s and s()
    end)
    return ok and has
end

local function hasGatePotion()
    local n = PP.GATE_POTION_NAME or "Philter of Major Translocation"
    local ok, found = pcall(function() return mq.TLO.FindItem(n)() end)
    return ok and found
end

local function gateAltAbilityReady()
    local ok, r = pcall(function() return mq.TLO.Me.AltAbilityReady("Gate")() end)
    return ok and r
end

local function gateSpellReady()
    local name = PP.GATE_SPELL_NAME or "Gate"
    local ok, r = pcall(function()
        local sr = mq.TLO.Me.SpellReady(name)
        return sr and sr()
    end)
    return ok and r
end

--- FindItem.Timer tick-based: 0/1 = ready to click (see MQ docs / community notes).
local function gatePotionReady(potionName)
    local okItem, item = pcall(function() return mq.TLO.FindItem(potionName) end)
    if not okItem or not item or not item() then
        return false
    end
    local okT, t = pcall(function() return item.Timer() end)
    if not okT or t == nil then
        return true
    end
    local tn = tonumber(t)
    if tn == nil then
        return true
    end
    return tn <= 1
end

--- After collapse or failed zone, Gate AA is on cooldown — poll until ready or timeout.
local function waitUntilGateAltReady(maxMs)
    maxMs = maxMs or (PP.GATE_WAIT_READY_MS or 240000)
    local poll = PP.GATE_READY_POLL_MS or 250
    local t0 = mq.gettime()
    if gateAltAbilityReady() then
        return true
    end
    info("waiting for Gate AA to become ready again (collapse/cooldown)...")
    while mq.gettime() - t0 < maxMs do
        shouldStop()
        if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
            return true
        end
        if gateAltAbilityReady() then
            return true
        end
        mq.delay(poll)
    end
    return gateAltAbilityReady()
end

local function waitUntilGateSpellReady(maxMs)
    maxMs = maxMs or (PP.GATE_WAIT_READY_MS or 240000)
    local poll = PP.GATE_READY_POLL_MS or 250
    local t0 = mq.gettime()
    if gateSpellReady() then
        return true
    end
    info("waiting for Gate spell to be ready (gem/recast)...")
    while mq.gettime() - t0 < maxMs do
        shouldStop()
        if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
            return true
        end
        if gateSpellReady() then
            return true
        end
        mq.delay(poll)
    end
    return gateSpellReady()
end

local function waitUntilGatePotionReady(potionName, maxMs)
    maxMs = maxMs or (PP.GATE_WAIT_READY_MS or 240000)
    local poll = PP.GATE_READY_POLL_MS or 250
    local t0 = mq.gettime()
    if gatePotionReady(potionName) then
        return true
    end
    info("waiting for gate potion item timer (reuse)...")
    while mq.gettime() - t0 < maxMs do
        shouldStop()
        if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
            return true
        end
        if not mq.TLO.FindItem(potionName)() then
            return false
        end
        if gatePotionReady(potionName) then
            return true
        end
        mq.delay(poll)
    end
    return gatePotionReady(potionName)
end

local function waitCastClearOrZoned(targetZoneId, maxMs)
    maxMs = maxMs or 60000
    local poll = PP.GATE_CAST_CLEAR_POLL_MS or 100
    local t0 = mq.gettime()
    while mq.gettime() - t0 < maxMs do
        shouldStop()
        if mq.TLO.Zone.ID() == targetZoneId then
            return true
        end
        local ok, c = pcall(function() return mq.TLO.Me.Casting() end)
        if ok and not c then
            return false
        end
        mq.delay(poll)
    end
    return mq.TLO.Zone.ID() == targetZoneId
end

local function tryGateToPoK()
    if PP.TRAVEL_DISMOUNT_BEFORE_GATE then
        dismountIfMounted("Gate")
    end
    if mq.TLO.Me.ZoneBound.ID() ~= PP.GATE_ZONE_ID then
        return false
    end
    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end

    local canAA = hasGateAA()
    local canSpell = hasGateSpell()
    local canPot = hasGatePotion()
    if not canAA and not canSpell and not canPot then
        info("no Gate AA, no Gate spell, no gate potion — skipping Gate waits (use /travelto or manual).")
        return false
    end

    local maxAttempts = PP.GATE_MAX_ATTEMPTS or 12
    local waitReadyMs = PP.GATE_WAIT_READY_MS or 240000
    local zoneWaitMs = PP.GATE_ZONE_WAIT_MS or 90000
    local postCastWait = PP.GATE_POST_CAST_EXTRA_WAIT_MS or 2000
    local postPotionWait = PP.GATE_POST_POTION_EXTRA_WAIT_MS or 2200
    local retryBackoff = PP.GATE_RETRY_BACKOFF_MS or 1200
    local spellName = PP.GATE_SPELL_NAME or "Gate"
    local potionName = PP.GATE_POTION_NAME or "Philter of Major Translocation"

    if canAA then
        for attempt = 1, maxAttempts do
            shouldStop()
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if not gateAltAbilityReady() then
                if not waitUntilGateAltReady(waitReadyMs) then
                    warn("Gate AA did not become ready in time — trying spell or potion if available.")
                    break
                end
            end
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if PP.TRAVEL_DISMOUNT_BEFORE_GATE then
                dismountIfMounted("Gate")
            end
            info(string.format("Gate AA to Plane of Knowledge (attempt %d/%d).", attempt, maxAttempts))
            mq.cmd("/alt act " .. tostring(PP.GATE_ALT_ACT_ID))
            mq.delay(600)
            if waitCastClearOrZoned(PP.GATE_ZONE_ID, 60000) then
                return true
            end
            mq.delay(postCastWait)
            if waitForZoneOrFalse(PP.GATE_ZONE_ID, zoneWaitMs) then
                return true
            end
            warn(string.format(
                "Gate AA did not reach PoK (attempt %d/%d) — collapse/interrupt; waiting for AA again.",
                attempt,
                maxAttempts
            ))
            mq.delay(retryBackoff)
        end
    end

    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end

    if canSpell then
        for attempt = 1, maxAttempts do
            shouldStop()
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if not gateSpellReady() then
                if not waitUntilGateSpellReady(waitReadyMs) then
                    warn("Gate spell did not become ready in time — trying potion if available.")
                    break
                end
            end
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if PP.TRAVEL_DISMOUNT_BEFORE_GATE then
                dismountIfMounted("Gate spell")
            end
            info(string.format("Gate spell %s to PoK (attempt %d/%d).", mqSpell(spellName), attempt, maxAttempts))
            mq.cmdf('/cast "%s"', spellName)
            mq.delay(600)
            if waitCastClearOrZoned(PP.GATE_ZONE_ID, 60000) then
                return true
            end
            mq.delay(postCastWait)
            if waitForZoneOrFalse(PP.GATE_ZONE_ID, zoneWaitMs) then
                return true
            end
            warn(string.format(
                "Gate spell did not reach PoK (attempt %d/%d) — will wait for gem/recast.",
                attempt,
                maxAttempts
            ))
            mq.delay(retryBackoff)
        end
    end

    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end

    local potionAttempts = PP.GATE_POTION_ATTEMPTS or 4
    if canPot then
        for p = 1, potionAttempts do
            shouldStop()
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if not mq.TLO.FindItem(potionName)() then
                break
            end
            if not gatePotionReady(potionName) then
                if not waitUntilGatePotionReady(potionName, waitReadyMs) then
                    warn("Gate potion still on reuse timer — giving up on potion.")
                    break
                end
            end
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if PP.TRAVEL_DISMOUNT_BEFORE_GATE then
                dismountIfMounted("Gate potion")
            end
            info(string.format("%s to PoK (attempt %d/%d).", potionName, p, potionAttempts))
            mq.cmd('/useitem "' .. potionName .. '"')
            mq.delay(600)
            if waitCastClearOrZoned(PP.GATE_ZONE_ID, 60000) then
                return true
            end
            mq.delay(postPotionWait)
            if waitForZoneOrFalse(PP.GATE_ZONE_ID, zoneWaitMs) then
                return true
            end
            warn(string.format("%s did not reach PoK (fail/collapse) — waiting for item timer.", potionName))
            mq.delay(retryBackoff)
            if not waitUntilGatePotionReady(potionName, waitReadyMs) then
                break
            end
        end
    end

    return mq.TLO.Zone.ID() == PP.GATE_ZONE_ID
end

--- After Run passes journal checks: speed, mount, Zueria snapshot, Guise shrink (once per Run). No invis here — apply invis in prepBeforeTasselLeg / zone helpers.
local function runPreflightAfterQuestChecks()
    info("preflight - speed, mount, Zueria Slide check, Guise shrink (no invis; invis last per leg).")
    pppokerEnsureMovementBuff()
    mountIfNeeded()
    if PP.pppokerZueria and PP.pppokerZueria.refreshReadiness then
        local zs = PP.pppokerZueria.refreshReadiness()
        if zs and zs.summary then
            info(zs.summary)
        end
    end
    maybeGuiseShrink("preflight")
end

--- Movement + invis once we are in Neriak Foreign or Commons (zoned in or resumed already there). Dismount first so speed/invis cast on foot; mount keyring not used in Neriak (see mountIfNeeded).
local function ensureSpeedAndInvisInNeriak(contextLabel)
    local z = mq.TLO.Zone.ID()
    if z ~= PP.ZONE.NERIAK_A and z ~= PP.ZONE.NERIAK_B then
        return
    end
    contextLabel = contextLabel or "Neriak"
    info(string.format("%s - speed + invis on foot (Neriak zone %d).", contextLabel, z))
    dismountIfMounted("Neriak buffs (no mount)")
    mq.delay(400)
    pppokerEnsureMovementBuff()
    if PP.TRAVEL_INVIS_BEFORE_NERIAK then
        ensureInvisIfNeeded(contextLabel)
    end
end

--- North / South Qeynos: speed buff, shrink (toggle), dismount if mounted, invis last. Navigation: navLocNoMount only (no keyring mount in NQ/SQ).
local function ensureSpeedAndInvisInQeynos(contextLabel)
    local z = mq.TLO.Zone.ID()
    if z ~= PP.ZONE.NQ and z ~= PP.ZONE.SQ then
        return
    end
    contextLabel = contextLabel or "Qeynos"
    info(string.format("%s - speed, shrink, dismount if needed, invis (Qeynos zone %d).", contextLabel, z))
    mq.delay(400)
    waitMeNotCasting(30000)
    pppokerEnsureMovementBuff()
    waitMeNotCasting(30000)
    if PP.TRAVEL_SHRINK_IN_QEYNOS ~= false then
        maybeGuiseShrink(contextLabel)
        waitMeNotCasting(30000)
    end
    dismountIfMounted("Qeynos invis (on foot)")
    mq.delay(400)
    waitMeNotCasting(30000)
    if PP.TRAVEL_INVIS_AFTER_QEYNOS_ZONE then
        ensureInvisIfNeeded(contextLabel)
    end
end

--- Highpass Hold: speed buff, shrink, mount (if enabled), invis last — no dismount in this helper.
--- navLoc / navLocNoMount still run after; navLocNoMount skips mount for lumber/tiger legs.
local function ensureSpeedShrinkInvisInHighpass(contextLabel)
    local z = mq.TLO.Zone.ID()
    if z ~= PP.ZONE.HIGHPASS then
        return
    end
    contextLabel = contextLabel or "Highpass"
    info(string.format("%s - speed, shrink, mount, invis (Highpass zone %d).", contextLabel, z))
    mq.delay(400)
    waitMeNotCasting(30000)
    pppokerEnsureMovementBuff()
    waitMeNotCasting(30000)
    if PP.TRAVEL_SHRINK_IN_HIGHPASS ~= false then
        maybeGuiseShrink(contextLabel)
        waitMeNotCasting(30000)
    end
    if PP.TRAVEL_NO_MOUNT_IN_HIGHPASS ~= true then
        mountIfNeeded()
        waitMeNotCasting(30000)
    end
    if PP.TRAVEL_INVIS_AFTER_HIGHPASS_ZONE then
        ensureInvisIfNeeded(contextLabel)
    end
end

--- East FP without slide: PoK hub first, then Neriak Foreign (avoids Hodstock routing issues).
local function travelNeriakForeignFromPokHub()
    if mq.TLO.Zone.ID() == PP.ZONE.NERIAK_A then
        ensureSpeedAndInvisInNeriak("Neriak Foreign (already in zone)")
        return
    end
    local zoned = false
    for attempt = 1, 3 do
        info(string.format("/travelto neriaka from PoK (attempt %d/3).", attempt))
        mq.cmd("/squelch /travelto neriaka")
        if waitForZoneOrFalse(PP.ZONE.NERIAK_A, 180000) then
            zoned = true
            break
        end
        mq.cmd("/squelch /travelto stop")
        navStopQuiet()
        mq.delay(1500)
    end
    if not zoned then
        fail("Could not reach Neriak Foreign Quarter from Plane of Knowledge.")
    end
    ensureSpeedAndInvisInNeriak("Neriak Foreign (zoned from PoK)")
end

local function travelToPokHubThenNeriakFromEastFp()
    if mq.TLO.Zone.ID() == PP.ZONE.NERIAK_A then
        ensureSpeedAndInvisInNeriak("Neriak Foreign (resume before PoK hop)")
        return
    end
    info("East FP route - Plane of Knowledge hub, then Neriak Foreign (Hodstock bypass).")
    if mq.TLO.Zone.ID() ~= PP.ZONE.POK then
        if not tryGateToPoK() then
            warn("Gate/potion to PoK unavailable or failed - /travelto " .. tostring(PP.POK_TRAVEL_SHORTNAME) .. ".")
            mq.cmdf("/squelch /travelto %s", PP.POK_TRAVEL_SHORTNAME or "poknowledge")
            if not waitForZoneOrFalse(PP.GATE_ZONE_ID, 180000) then
                fail("Could not reach Plane of Knowledge before Neriak travel.")
            end
        end
    end
    mountIfNeeded()
    mq.delay(2000)
    travelNeriakForeignFromPokHub()
end

local function waitBettyWithinHailRange(maxDist, timeoutMs)
    maxDist = maxDist or PP.EAST_FP_BETTY_HAIL_MAX_DIST or 45
    timeoutMs = timeoutMs or 90000
    local t0 = mq.gettime()
    while mq.gettime() - t0 < timeoutMs do
        shouldStop()
        for _, name in ipairs(PP.NPC.BETTY or {}) do
            if name and name ~= "" then
                local spawn = mq.TLO.Spawn(name)
                if spawn and spawn() then
                    local dist = spawn.Distance() or 9999
                    if dist <= maxDist then return true end
                end
            end
        end
        mq.delay(200)
    end
    return false
end

--- Big Slick (West Freeport): distance to spawn by name — use before target/hail (quest acquire + final objective).
local function waitBigSlickWithinDist(maxDist, timeoutMs)
    maxDist = maxDist or 25
    timeoutMs = timeoutMs or 90000
    local t0 = mq.gettime()
    while mq.gettime() - t0 < timeoutMs do
        shouldStop()
        for _, name in ipairs(PP.NPC.BIG_SLICK or {}) do
            if name and name ~= "" then
                local spawn = mq.TLO.Spawn(name)
                if spawn and spawn() then
                    local dist = spawn.Distance() or 9999
                    if dist <= maxDist then return true end
                end
            end
        end
        mq.delay(200)
    end
    return false
end

local function doBettyPocketInteraction()
    targetOrFail(PP.NPC.BETTY, "Could not target Bluffing Betty", 15000)
    mq.delay(500)
    pcall(function()
        mq.cmd("/face fast")
    end)
    mq.delay(300)
    mq.cmd("/keypress hail")
    mq.delay(2000)
    mq.cmd("/autoinv")
    mq.delay(500)
    mq.cmd("/autoinv")
    mq.cmd("/target ${Me.Name}")
    local grog = PP.MEMENTO_GROG_NAME or "Memento Grog"
    while mq.TLO.FindItem(grog)() do
        mq.cmdf('/useitem "%s"', grog)
        mq.delay(1000)
    end
    if PP.pppokerZueria and PP.pppokerZueria.runAfterMementoGrog then
        PP.pppokerZueria.runAfterMementoGrog()
    end
    mq.delay(1000)
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

--- Parse ${CWTN...} for paused/on/off; returns true/false/nil if unknown or parse error.
local function cwtnParsePausedTriState(expr)
    local ok, v = pcall(function() return mq.parse(expr) end)
    if not ok or v == nil then return nil end
    local s = tostring(v):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "null" then return nil end
    if s:find("no such", 1, true) or s:find("could not", 1, true) or s:find("not found", 1, true) then
        return nil
    end
    if s == "true" or s == "on" or s == "1" or s == "yes" or s == "paused" then return true end
    if s == "false" or s == "off" or s == "0" or s == "no" then return false end
    local n = tonumber(s)
    if n then return n ~= 0 end
    return nil
end

--- Prefer mq.parse; then mq.TLO.CWTN.Paused() when CWTN datatype is present.
local function cwtnAppearsPaused()
    for _, expr in ipairs({
        "${CWTN.Paused}",
        "${CWTN.Pause}",
        "${CWTN.IsPaused}",
    }) do
        local t = cwtnParsePausedTriState(expr)
        if t ~= nil then return t end
    end
    local ok, r = pcall(function()
        local c = mq.TLO.CWTN
        if not c or not c() then return nil end
        if not c.Paused then return nil end
        local v = c.Paused()
        if type(v) == "boolean" then return v end
        if type(v) == "number" then return v ~= 0 end
        if type(v) == "string" then
            local sl = v:lower():gsub("^%s+", ""):gsub("%s+$", "")
            if sl == "true" or sl == "on" or sl == "1" or sl == "yes" then return true end
            if sl == "false" or sl == "off" or sl == "0" or sl == "no" then return false end
        end
        return nil
    end)
    if ok and r ~= nil then return r end
    return nil
end

local function pauseCWTNPlugins()
    local loaded, pluginName = isExpectedCWTNPluginLoaded()
    PP.cwtnState.alreadyPausedAtStart = false
    if not loaded then
        debugLog(string.format("CWTN pause skipped: expected plugin not loaded (%s)", tostring(pluginName or "unknown")))
        return false
    end

    local pausedNow = cwtnAppearsPaused()
    if pausedNow == true then
        debugLog(string.format("CWTN already paused — skipping /CWTN pause on (%s)", tostring(pluginName)))
        PP.cwtnState.pausedApplied = false
        PP.cwtnState.alreadyPausedAtStart = true
        return true
    end

    mq.cmd("/CWTN pause on")
    PP.cwtnState.pausedApplied = true
    if pausedNow == nil then
        debugLog(string.format(
            "CWTN: pause state not readable (${CWTN.Paused} / TLO.CWTN.Paused) — issued /CWTN pause on (%s)",
            tostring(pluginName)
        ))
    else
        debugLog("CWTN paused via /CWTN pause on (plugin: " .. tostring(pluginName) .. ")")
    end
    return true
end

local function unpauseCWTNPlugins()
    if PP.cwtnState.alreadyPausedAtStart then
        PP.cwtnState.alreadyPausedAtStart = false
        debugLog("CWTN was paused before this run — leaving paused (no /CWTN pause off).")
        return
    end
    if not PP.cwtnState.pausedApplied then return end
    local loaded = select(1, isExpectedCWTNPluginLoaded())
    if not loaded then
        PP.cwtnState.pausedApplied = false
        return
    end
    mq.cmd("/CWTN pause off")
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

--- Same as init.lua: journal fields via mq.parse match /echo; Lua Task.Objective userdata can disagree.
local function safeParseNum(expr)
    local ok, val = pcall(function()
        return mq.parse(expr)
    end)
    if not ok or val == nil then
        return nil
    end
    local s = tostring(val):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "NULL" then
        return nil
    end
    return tonumber(s)
end

local function safeParseStr(expr)
    local ok, val = pcall(function()
        return mq.parse(expr)
    end)
    if not ok or val == nil then
        return nil
    end
    local s = tostring(val):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "NULL" then
        return nil
    end
    return s
end

-- Quest progress: mq.TLO.Task. Journal prime uses mq.delay — ONLY call from script main thread (while gui.open), never from ImGui draw.
-- Completion signal: objectiveIsComplete (Done() then Status()). Indices: /lua parse mq.TLO.Task("Paintings Playing Poker").Objective(N).Status()

--- Every Run: full sync so resume sees current journal (repeatable).
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

--- Update Task TLO without flashing the journal window (many Live builds). If getTask() still empty, set PP.TASK_JOURNAL_FIRST_SYNC = "full".
local function syncTaskJournalMinimal()
    pcall(function()
        mq.cmd("/windowstate TaskWnd fetch")
    end)
    mq.delay(300)
end

--- mq.TLO.Task("Exact Name")() — evaluate the TLO: truthy if that task exists in journal memory; falsy if not (name is case-sensitive). Use after TaskWnd sync if stale.
local function taskEvalExists(task)
    if not task then
        return false
    end
    local ok, v = pcall(function()
        return task()
    end)
    return ok and v ~= nil and v ~= false
end

local function taskIsPaintingsPlayingPoker(task)
    if not taskEvalExists(task) then
        return false
    end
    local ok, title = pcall(function()
        return task.Title()
    end)
    return ok and title and tostring(title) == PP.QUEST_TITLE
end

local function getTask()
    local t = mq.TLO.Task(PP.QUEST_TITLE)
    if taskEvalExists(t) and taskIsPaintingsPlayingPoker(t) then
        return t
    end
    for i = 1, PP.MAX_OBJECTIVES do
        local ti = mq.TLO.Task(i)
        if taskEvalExists(ti) and taskIsPaintingsPlayingPoker(ti) then
            return ti
        end
    end
    return nil
end

--- Raw Task.Objective(idx) (may be nil if MQ omits that row after the step is done).
local function getObjectiveSlotRaw(task, idx)
    if not task then
        return nil
    end
    local ok, obj = pcall(function()
        return task.Objective(idx)
    end)
    if not ok or not obj then
        return nil
    end
    return obj
end

--- Numeric journal slot 1..N for Paintings (for ${Task[i].Objective[j].*} when named key parse is empty).
local function getPaintingsTaskSlotNumber()
    for i = 1, PP.MAX_OBJECTIVES do
        local ti = mq.TLO.Task(i)
        if taskEvalExists(ti) and taskIsPaintingsPlayingPoker(ti) then
            return i
        end
    end
    return nil
end

--- Completion from mq.parse only; nil = no usable parse (fall back to userdata). Aligns with /echo ${Task[...].Objective[n].*} (init.lua taskObjectiveExpr).
local function objectiveCompleteFromParse(objIdx)
    local function evalOne(ref, useSlotIndex)
        local st, req, cur
        if useSlotIndex then
            st = safeParseStr(string.format("${Task[%d].Objective[%d].Status}", ref, objIdx))
            req = safeParseNum(string.format("${Task[%d].Objective[%d].RequiredCount}", ref, objIdx))
            cur = safeParseNum(string.format("${Task[%d].Objective[%d].CurrentCount}", ref, objIdx))
        else
            st = safeParseStr(string.format("${Task[%s].Objective[%d].Status}", ref, objIdx))
            req = safeParseNum(string.format("${Task[%s].Objective[%d].RequiredCount}", ref, objIdx))
            cur = safeParseNum(string.format("${Task[%s].Objective[%d].CurrentCount}", ref, objIdx))
        end
        local hasData = (st and st ~= "")
            or (req ~= nil)
            or (cur ~= nil)
        if not hasData then
            return nil
        end
        if st and st ~= "" then
            local raw = tostring(st)
            local s = raw:lower():match("^%s*(.-)%s*$")
            if s then
                s = s:gsub("%p+$", "")
                if s == "done" or s == "complete" or s == "completed" then
                    return true
                end
            end
            local cStr, tStr = raw:match("^%s*(%d+)%s*/%s*(%d+)%s*$")
            if cStr and tStr then
                local c, t = tonumber(cStr), tonumber(tStr)
                if t and t > 0 and c and c >= t then
                    return true
                end
                if t and t > 0 and c and c < t then
                    return false
                end
            end
        end
        if req and req > 0 and cur and cur >= req then
            return true
        end
        if req and req > 0 and cur and cur < req then
            return false
        end
        return false
    end

    local a = evalOne(PP.QUEST_TITLE, false)
    if a ~= nil then
        return a
    end
    local slot = getPaintingsTaskSlotNumber()
    if slot then
        local b = evalOne(slot, true)
        if b ~= nil then
            return b
        end
    end
    return nil
end

--- Parse says complete if true; else Lua userdata (Task.Objective) for same checks as before.
local function objectiveSlotComplete(task, idx)
    local p = objectiveCompleteFromParse(idx)
    if p == true then
        return true
    end
    local obj = getObjectiveSlotRaw(task, idx)
    local ud = obj and objectiveIsComplete(obj) or false
    if p == false then
        return ud
    end
    return ud
end

--- Progress: percent01, stepStatus[1..N], completedCount, hasQuest. Title must match PP.QUEST_TITLE. Per-slot: mq.parse first, then userdata.
local function getQuestProgress(task)
    local stepStatus = {}
    for i = 1, PP.QUEST_OBJECTIVE_COUNT do
        stepStatus[i] = false
    end
    if not taskEvalExists(task) then
        return 0, stepStatus, 0, false
    end
    if not taskIsPaintingsPlayingPoker(task) then
        return 0, stepStatus, 0, false
    end
    local completedCount = 0
    for i = 1, PP.QUEST_OBJECTIVE_COUNT do
        local ok = objectiveSlotComplete(task, i)
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
    if not taskEvalExists(task) then
        return false
    end
    for i = 1, PP.QUEST_OBJECTIVE_COUNT do
        if task.Objective(i) then
            return true
        end
    end
    return false
end

--- Objective TLO ref; do not gate on obj() — see objectiveIsComplete / MQ docs (() can be false briefly).
local function getObjective(task, idx)
    return getObjectiveSlotRaw(task, idx)
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

--- First index not complete by parse+userdata. Does not skip nil rows only: parse can mark done without userdata (init.lua-style).
local function firstIncompleteObjective(task)
    if not taskEvalExists(task) or not taskHasAnyObjectiveRow(task) then
        return nil, nil
    end
    for i = 1, PP.QUEST_OBJECTIVE_COUNT do
        if not objectiveSlotComplete(task, i) then
            return i, getObjectiveSlotRaw(task, i)
        end
    end
    return nil, nil
end

local function waitObjectiveDone(taskName, idx, timeoutMs)
    timeoutMs = timeoutMs or PP.WAIT_OBJECTIVE_TIMEOUT_MS or 120000
    local t0 = mq.gettime()
    local nextLog = t0
    local nextSync = t0
    while mq.gettime() - t0 < timeoutMs do
        shouldStop()
        if PP.WAIT_JOURNAL_SYNC_MS and PP.WAIT_JOURNAL_SYNC_MS > 0 and mq.gettime() >= nextSync then
            syncTaskJournalWindowFull()
            nextSync = mq.gettime() + PP.WAIT_JOURNAL_SYNC_MS
        end
        local t = getTask()
        -- Final objective: journal entry often disappears on reward; there is no Objective(16) left to read as Done.
        if idx == PP.QUEST_OBJECTIVE_COUNT and not t then
            mq.delay(400)
            syncTaskJournalWindowFull()
            mq.delay(200)
            t = getTask()
            if not t then
                info(mqObjGreen("Paintings task no longer in journal — objective 16 complete (final turn-in)."))
                return true
            end
        end
        if t and objectiveSlotComplete(t, idx) then
            return true
        end
        local obj = (t and t()) and t.Objective(idx) or nil
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
            local stStr = "?"
            pcall(function()
                if obj.Status and type(obj.Status) == "function" then
                    stStr = tostring(obj.Status() or "")
                end
            end)
            debugLog(string.format(
                "Waiting objective %d... %s | Status=%s",
                idx,
                instr,
                stStr
            ))
            nextLog = mq.gettime() + 8000
        end
        mq.delay(250)
    end
    return false
end

--- While not running Run, keep Status (and gui.step for logic) in sync with mq.TLO.Task (after first Run scan).
--- Call only when gui.journalScannedOnce (Run has synced journal at least once).
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
    if instr and instr ~= "" then
        gui.status = instr
    else
        gui.status = string.format("Objective %d", idx)
    end
end

--- Blightfire (Moors): speed buff + mount if needed. Nektulos: mount + pause (Poker2.lua before next /travelto).
local function poker2MountDelayInNekOrMoors()
    if not PP.TRAVEL_POKER2_MOUNT_IN_NEK_MOORS then
        return
    end
    local z = mq.TLO.Zone.ID()
    if z == PP.ZONE.MOORS then
        info("Blightfire (Moors) - speed buff, mount if needed.")
        mq.delay(400)
        waitMeNotCasting(30000)
        pppokerEnsureMovementBuff()
        waitMeNotCasting(30000)
        mountIfNeeded()
        waitMeNotCasting(15000)
        return
    end
    if z ~= PP.ZONE.NEKTULOS then
        return
    end
    info(string.format("Poker2 mount pause (Nektulos zone %d) before next travel.", z))
    mq.delay(1000)
    mountIfNeeded()
    waitMeNotCasting(15000)
    mq.delay(3000)
end

local function runObjectiveStep(idx, task)
    local instr = objInstruction(task, idx)
    gui.step = idx
    if instr and instr ~= "" then
        gui.status = instr
    else
        gui.status = string.format("Objective %d", idx)
    end
    info(string.format("Objective %d: %s", idx, instr))

    if idx == 1 then
        ensureZone(PP.ZONE.WEST_FP, "freeportwest", "West Freeport")
        prepBeforeTasselLeg()
        navLoc(PP.LOC.TASSEL, 1500)
    elseif idx == 2 then
        ensureZone(PP.ZONE.EAST_FP, "freeporteast", "East Freeport")
        navLoc(PP.LOC.BETTY, 1500)
        mq.delay(3000)
        if not waitBettyWithinHailRange(nil, 90000) then
            warn("Betty not in hail range; re-nav once.")
            navLoc(PP.LOC.BETTY, 1500)
            mq.delay(3000)
            if not waitBettyWithinHailRange(nil, 60000) then
                fail("Bluffing Betty not within hail range after nav (objective 2).")
            end
        end
    elseif idx == 3 then
        ensureZone(PP.ZONE.EAST_FP, "freeporteast", "East Freeport")
        if not waitBettyWithinHailRange(nil, 12000) then
            navLoc(PP.LOC.BETTY, 1500)
            mq.delay(2000)
            if not waitBettyWithinHailRange(nil, 45000) then
                fail("Bluffing Betty not in range for hail (objective 3).")
            end
        end
        doBettyPocketInteraction()
    elseif idx == 4 then
        local z = mq.TLO.Zone.ID()
        if z == PP.ZONE.EAST_FP then
            travelToPokHubThenNeriakFromEastFp()
        elseif z == PP.ZONE.POK then
            mountIfNeeded()
            mq.delay(2000)
            travelNeriakForeignFromPokHub()
        elseif z == PP.ZONE.NEKTULOS or z == PP.ZONE.MOORS then
            poker2MountDelayInNekOrMoors()
            ensureZone(PP.ZONE.NERIAK_A, "neriaka", "Neriak Foreign Quarter")
        else
            poker2MountDelayInNekOrMoors()
            ensureZone(PP.ZONE.NERIAK_A, "neriaka", "Neriak Foreign Quarter")
        end
        ensureSpeedAndInvisInNeriak("objective 4 (Bull Pit)")
        navLoc(PP.LOC.BULL, 1500)
    elseif idx == 5 then
        ensureZone(PP.ZONE.NERIAK_A, "neriaka", "Neriak Foreign Quarter")
        ensureSpeedAndInvisInNeriak("objective 5 (Slug's Tavern)")
        mq.cmd('/squelch /nav locyx 204 -243 3')
        moving()
        mq.delay(1500)
    elseif idx == 6 then
        ensureZone(PP.ZONE.NERIAK_B, "neriakb", "Neriak Commons", 360000)
        ensureSpeedAndInvisInNeriak("objective 6 (Blind Fish)")
        navLoc(PP.LOC.BLIND_FISH, 1500)
    elseif idx == 7 then
        ensureZone(PP.ZONE.NERIAK_B, "neriakb", "Neriak Commons", 360000)
        ensureSpeedAndInvisInNeriak("objective 7 (Toadstool)")
        navLoc(PP.LOC.TOADSTOOL, 1000)
        mq.cmd('/face heading 315')
        mq.delay(1200)
    elseif idx == 8 then
        if mq.TLO.Zone.ID() == PP.ZONE.NERIAK_B or mq.TLO.Zone.ID() == PP.ZONE.NERIAK_A then
            info("Toadstool done - Gate/potion to PoK hub, then Highpass.")
            tryGateToPoK()
            mq.delay(2000)
        end
        if (PP.TRAVEL_HIGHPASS_VIA_MOORS ~= false)
            and mq.TLO.Zone.ID() == PP.GATE_ZONE_ID
            and mq.TLO.Zone.ID() ~= PP.ZONE.HIGHPASS
        then
            ensureZone(PP.ZONE.MOORS, "moors", "Blightfire Moors")
        end
        poker2MountDelayInNekOrMoors()
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(500)
        ensureSpeedShrinkInvisInHighpass("objective 8 (Highpass)")
        navLoc(PP.LOC.QUINN, 1000)
    elseif idx == 9 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(500)
        ensureSpeedShrinkInvisInHighpass("objective 9 (Highpass - Quinn)")
        navLoc(PP.LOC.QUINN, 800)
        targetOrFail(PP.NPC.QUINN, "Could not target Quinn", 12000, true)
        mq.cmd('/keypress hail')
        mq.delay(1500)
        mq.cmd('/target ${Me.Name}')
    elseif idx == 10 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(500)
        ensureSpeedShrinkInvisInHighpass("objective 10 (Highpass - lumber)")
        navLocNoMount(PP.LOC.LUMBER_1, 900)
        navLocNoMount(PP.LOC.LUMBER_2, 900)
        navLocNoMount(PP.LOC.LUMBER_3, 1000)
    elseif idx == 11 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(500)
        ensureSpeedShrinkInvisInHighpass("objective 11 (Highpass - Mhrai)")
        navLocNoMount(PP.LOC.LUMBER_3, 900)
        targetOrFail(PP.NPC.MHRAI, "Could not target Mhrai", 12000, true)
        mq.cmd('/keypress hail')
        mq.delay(1500)
        mq.cmd('/target ${Me.Name}')
    elseif idx == 12 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(500)
        ensureSpeedShrinkInvisInHighpass("objective 12 (Highpass - tiger)")
        navLocNoMount(PP.LOC.TIGER, 1000)
    elseif idx == 13 then
        if mq.TLO.Zone.ID() == PP.ZONE.HIGHPASS then
            info("Tiger Roar done - Gate/potion to PoK hub, then North Qeynos.")
            tryGateToPoK()
            mq.delay(2000)
        end
        ensureZone(PP.ZONE.NQ, "qeynos2", "North Qeynos")
        mq.delay(500)
        ensureSpeedAndInvisInQeynos("objective 13 (North Qeynos)")
        navLocNoMount(PP.LOC.NQ, 1500)
    elseif idx == 14 then
        ensureZone(PP.ZONE.SQ, "qeynos", "South Qeynos")
        mq.delay(500)
        ensureSpeedAndInvisInQeynos("objective 14 (South Qeynos - fish)")
        navLocNoMount(PP.LOC.SQ_FISH, 1500)
    elseif idx == 15 then
        ensureZone(PP.ZONE.SQ, "qeynos", "South Qeynos")
        mq.delay(500)
        ensureSpeedAndInvisInQeynos("objective 15 (South Qeynos - lion)")
        navLocNoMount(PP.LOC.SQ_LION, 1500)
    elseif idx == 16 then
        if mq.TLO.Zone.ID() == PP.ZONE.NQ or mq.TLO.Zone.ID() == PP.ZONE.SQ then
            info("Lion's Mane done - Gate/potion to PoK hub, then West Freeport / Slick.")
            tryGateToPoK()
            mq.delay(2000)
        end
        ensureZone(PP.ZONE.WEST_FP, "freeportwest", "West Freeport")
        gui.status = "Objective 16: navigating to Big Slick..."
        navLoc(PP.LOC.SLICK, 1000)
        mq.delay(PP.SLICK_FINAL_POST_NAV_MS)
        gui.status = "Objective 16: waiting in hail range of Big Slick..."
        if not waitBigSlickWithinDist(25, 90000) then
            warn("Big Slick not within hail range after nav (objective 16); retrying /nav once.")
            navLoc(PP.LOC.SLICK, 1000)
            mq.delay(PP.SLICK_FINAL_POST_NAV_MS)
            if not waitBigSlickWithinDist(25, 60000) then
                fail("Could not reach Big Slick Jones within hail range for final objective.")
            end
        end
        gui.status = "Objective 16: hailing Big Slick..."
        targetOrFail(PP.NPC.BIG_SLICK, "Could not target Big Slick Jones")
        mq.delay(PP.SLICK_FINAL_PRE_HAIL_MS)
        pcall(function()
            mq.cmd("/face fast")
        end)
        mq.delay(400)
        mq.cmd("/keypress hail")
        mq.delay(PP.SLICK_FINAL_POST_HAIL_MS)
        syncTaskJournalWindowFull()
    else
        fail("Unhandled objective index " .. tostring(idx))
    end
end

--- After /say at Slick: fetch-only first (fewer TaskWnd flashes); full open/fetch/close only if getTask still nil.
local function syncJournalAfterKeywordTry()
    syncTaskJournalMinimal()
    mq.delay(400)
    if getTask() then return end
    syncTaskJournalWindowFull()
    mq.delay(500)
end

--- No Paintings task: zone, nav to Slick, wait in range, /say PP.SLICK_QUEST_KEYWORD, esc, journal sync. Caller re-calls getTask().
local function tryAcquireQuestFromBigSlick()
    if not PP.TRY_BIG_SLICK_QUEST_ACQUIRE then return end
    shouldStop()
    info("No Paintings task in journal - traveling to Big Slick to acquire quest.")
    gui.status = "Acquiring quest - traveling to Big Slick (West Freeport)..."
    ensureZone(PP.ZONE.WEST_FP, "freeportwest", "West Freeport")
    shouldStop()
    navLoc(PP.LOC.SLICK, 1000)
    mq.delay(PP.SLICK_ACQUIRE_POST_NAV_BUFFER_MS or 3000)
    if not waitBigSlickWithinDist(25, 90000) then
        warn("Big Slick not within 25 after nav; retrying /nav once.")
        navLoc(PP.LOC.SLICK, 1000)
        mq.delay(PP.SLICK_ACQUIRE_POST_NAV_BUFFER_MS or 3000)
        if not waitBigSlickWithinDist(25, 60000) then
            fail("Could not reach Big Slick Jones within hail range after navigation.")
        end
    end
    mq.delay(PP.SLICK_FINAL_POST_NAV_MS or 1200)
    gui.status = "Acquiring quest - hailing Big Slick..."
    targetOrFail(PP.NPC.BIG_SLICK, "Could not target Big Slick Jones", 15000)
    mq.delay(PP.SLICK_FINAL_PRE_HAIL_MS or 1200)
    pcall(function()
        mq.cmd("/face fast")
    end)
    mq.delay(400)
    local kw = tostring(PP.SLICK_QUEST_KEYWORD or "paintings"):match("^%s*(.-)%s*$") or "paintings"
    if kw == "" then kw = "paintings" end
    info(string.format("/say %s (quest offer)", kw))
    mq.cmd("/say " .. kw)
    mq.delay(800)
    pcall(function()
        mq.cmd("/keypress esc")
    end)
    mq.delay(400)
    syncJournalAfterKeywordTry()
end

--- Main automation: first incomplete objective → runObjectiveStep → waitObjectiveDone (objectiveIsComplete). Same data as getQuestProgress / GUI bar.
local function runQuest()
    resetGuiseShrinkSession()
    local questRunStartTime = os.time()
    mq.cmd(string.format('/popup Starting: Paintings Playing Poker v%s (init2)', PP.VERSION))
    pauseCWTNPlugins()
    pauseRGMercs()

    ensurePokBind()

    local firstMode = (PP.TASK_JOURNAL_FIRST_SYNC or "full"):lower()
    if firstMode == "minimal" then
        syncTaskJournalMinimal()
    else
        syncTaskJournalWindowFull()
    end
    gui.journalScannedOnce = true

    local task = getTask()
    if not task and firstMode == "minimal" then
        syncTaskJournalWindowFull()
        task = getTask()
    end
    if not task and PP.TRY_BIG_SLICK_QUEST_ACQUIRE then
        tryAcquireQuestFromBigSlick()
        task = getTask()
    end
    if not task then
        unpauseRGMercs()
        unpauseCWTNPlugins()
        gui.status = "Get Quest from Big Slick - no Paintings Playing Poker task in journal."
        warn(gui.status)
        return
    end
    do
        local okTit, journalTitle = pcall(function()
            return task.Title()
        end)
        info(string.format("Quest check: journal title=%q (expected %q).", tostring(okTit and journalTitle), PP.QUEST_TITLE))
    end
    if not taskHasAnyObjectiveRow(task) then
        unpauseRGMercs()
        unpauseCWTNPlugins()
        gui.status = "Get Quest from Big Slick - journal has no objectives for this task yet (open journal or hail Big Slick in West Freeport)."
        warn(gui.status)
        return
    end

    do
        local _, _, _, hasQuest = getQuestProgress(task)
        if not hasQuest then
            unpauseRGMercs()
            unpauseCWTNPlugins()
            gui.status = "Get Quest from Big Slick - task title mismatch or journal not synced."
            warn(gui.status)
            return
        end
        local resumeIdx = select(1, firstIncompleteObjective(task))
        if resumeIdx then
            info(string.format(
                "Paintings Playing Poker - next incomplete objective index %d (parse+userdata).",
                resumeIdx
            ))
        else
            info(mqObjGreen("Paintings Playing Poker - no incomplete objectives (all done)."))
        end
    end

    runPreflightAfterQuestChecks()

    while true do
        shouldStop()
        task = getTask()
        if not task then
            unpauseRGMercs()
            unpauseCWTNPlugins()
            gui.status = "Task became unavailable - stopping."
            warn(gui.status)
            return
        end
        if not taskHasAnyObjectiveRow(task) then
            unpauseRGMercs()
            unpauseCWTNPlugins()
            gui.status = "Get Quest from Big Slick - objectives not visible; open journal or re-hail."
            warn(gui.status)
            return
        end

        local idx, obj = firstIncompleteObjective(task)
        if not idx then
            gui.status = "Quest complete."
            info(mqObjGreen("All objectives are Done."))
            break
        end

        local instr = objInstruction(task, idx)
        info(string.format("Resume: first incomplete objective %d: %s", idx, instr))
        runObjectiveStep(idx, task)
        local waitMs = (idx == 16) and (PP.WAIT_OBJECTIVE_TIMEOUT_FINAL_MS or 300000)
            or (PP.WAIT_OBJECTIVE_TIMEOUT_MS or 120000)
        if not waitObjectiveDone(PP.QUEST_TITLE, idx, waitMs) then
            fail(string.format("Timeout waiting objective %d to complete: %s", idx, instr))
        end
        info(mqObjGreen(string.format("Objective %d completed.", idx)))
        mq.delay(500)
        if idx == PP.QUEST_OBJECTIVE_COUNT then
            gui.status = "Quest complete."
            gui.questComplete = true
            info(mqObjGreen("All objectives are Done."))
            break
        end
    end

    do
        local n = getCommemorativeCount()
        info(string.format("You now have... %d Commemorative Coins !", n))
        info(string.format("Quest Run Time... %d Seconds", os.time() - questRunStartTime))
    end

    unpauseRGMercs()
    unpauseCWTNPlugins()

    local ar = tonumber(PP.AUTO_REPEAT_DELAY_SEC)
    if ar and ar > 0 then
        info(string.format("auto-repeat — next Run in %d s (Stop / close window cancels).", ar))
        if delayMsWithStopCheck(ar * 1000) then
            gui.running = true
            stopRequested = false
            gui.navPaused = false
            navPluginUnpause()
            gui.status = "Auto-repeat — starting Run..."
        else
            info("auto-repeat cancelled.")
        end
    end
end

-- EQ \a codes in stored lines — map to ImVec4 for ImGui.TextColored (see changelog 2.62).
local function mqColorLetterToImVec4(ch)
    local c1 = (tostring(ch or "")):sub(1, 1):lower()
    local r, g, b, a = 0.88, 0.88, 0.92, 1.0
    if c1 == "g" then
        r, g, b = 0.32, 0.92, 0.42
    elseif c1 == "m" or c1 == "p" then
        r, g, b = 0.72, 0.48, 1.0
    elseif c1 == "y" then
        r, g, b = 0.98, 0.95, 0.35
    elseif c1 == "r" then
        r, g, b = 0.98, 0.35, 0.35
    elseif c1 == "o" then
        r, g, b = 1.0, 0.62, 0.2
    elseif c1 == "t" or c1 == "x" then
        r, g, b = 0.9, 0.9, 0.93
    elseif c1 == "w" then
        r, g, b = 1.0, 1.0, 1.0
    elseif c1 == "u" then
        r, g, b = 0.45, 0.68, 1.0
    elseif c1 == "b" then
        r, g, b = 0.35, 0.38, 0.45
    end
    return getImVec4(r, g, b, a)
end

local function parseMqColoredSegments(s)
    s = tostring(s or "")
    local defaultCol = getImVec4(0.88, 0.88, 0.92, 1)
    local parts = {}
    local buf = ""
    local cur = defaultCol
    local i = 1
    while i <= #s do
        if i + 2 <= #s and s:byte(i) == 92 and s:byte(i + 1) == 97 then
            if #buf > 0 then
                parts[#parts + 1] = { text = buf, color = cur }
                buf = ""
            end
            cur = mqColorLetterToImVec4(s:sub(i + 2, i + 2)) or cur
            i = i + 3
        else
            buf = buf .. s:sub(i, i)
            i = i + 1
        end
    end
    parts[#parts + 1] = { text = buf, color = cur }
    return parts
end

local function drawMqColoredDebugLine(line)
    local segs = parseMqColoredSegments(line)
    local wrapW = select(1, getContentRegionAvail2())
    if wrapW < 80 then
        wrapW = 360
    end
    pcall(function()
        if imgui.GetCursorPosX and imgui.PushTextWrapPos then
            imgui.PushTextWrapPos(imgui.GetCursorPosX() + wrapW)
        elseif imgui.PushTextWrapPos then
            imgui.PushTextWrapPos(0)
        end
    end)
    local first = true
    local any = false
    for _, seg in ipairs(segs) do
        local t = seg.text or ""
        if t ~= "" then
            any = true
            if not first and imgui.SameLine then
                pcall(function()
                    imgui.SameLine(0, 0)
                end)
            end
            first = false
            if seg.color and imgui.TextColored then
                pcall(function()
                    imgui.TextColored(seg.color, t)
                end)
            else
                imgui.Text(t)
            end
        end
    end
    if not any then
        if imgui.TextWrapped then
            imgui.TextWrapped(line)
        else
            imgui.Text(line)
        end
    end
    pcall(function()
        if imgui.PopTextWrapPos then
            imgui.PopTextWrapPos()
        end
    end)
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
    if not open then
        stopRequested = true
    end
    if draw then
        local okDraw, errDraw = pcall(function()
            local activeTask, doneObjectives, totalObjectives, percent01, stepStatus
            local hasQuest = false
            if gui.journalScannedOnce then
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
                hasQuest = false
            end
            local percent = (percent01 or 0) * 100.0
            local barOpts = ensureObjectiveBarLive()
            barOpts.tickEvery = 1.0 / PP.QUEST_OBJECTIVE_COUNT
            if gui.journalScannedOnce and stepStatus then
                barOpts.perStepDone = stepStatus
            else
                barOpts.perStepDone = nil
            end

            drawHeaderImage()
            imgui.Text("Paintings Playing Poker - 23rd Anniversary")
            imgui.Separator()
            imgui.Text(string.format("Status: %s", gui.status))
            if gui.journalScannedOnce then
                imgui.Text(string.format("Progress: %d / %d objectives", doneObjectives or 0, totalObjectives or PP.QUEST_OBJECTIVE_COUNT))
            else
                imgui.Text(string.format("Progress: — / %d objectives (press Run to scan)", totalObjectives or PP.QUEST_OBJECTIVE_COUNT))
            end
            drawObjectiveBar("PPPokerV2ObjectiveBar", percent, BarColors.XPMin, BarColors.XPMax, barOpts)

            if imgui.Button((gui.running and Icons.FA_STOP or Icons.FA_PLAY) .. " " .. (gui.running and "Running" or "Run")) then
                if not gui.running then
                    gui.running = true
                    stopRequested = false
                    gui.navPaused = false
                    navPluginUnpause()
                end
            end
            imgui.SameLine()
            if imgui.Button(gui.navPaused and "Unpause Nav" or "Pause Nav") then
                gui.navPaused = not gui.navPaused
                if gui.navPaused then
                    navPluginPause()
                    gui.status = "Nav paused (/nav pause) — click Unpause Nav or /nav pause off to continue."
                else
                    navPluginUnpause()
                    gui.status = "Nav resumed (/nav pause off)."
                end
            end
            imgui.SameLine()
            if imgui.Button(Icons.FA_BAN .. " Stop") then
                stopRequested = true
                gui.running = false
                gui.navPaused = false
                navPluginUnpause()
                haltNavigationForStop()
                gui.status = "Stopped — nav and script run halted."
            end
            imgui.SameLine()
            pppokerDrawDebugToggle()

            imgui.Separator()
            drawCommemorativeCoinsRow()
            imgui.Separator()

            if gui.debugOpen then
                local began = pcall(function()
                    imgui.BeginChild("PPPokerV2Debug", getImVec2(0, 220), true, 0)
                end)
                if not began then
                    began = pcall(function()
                        imgui.BeginChild("PPPokerV2Debug", 0, 220)
                    end)
                end
                if began then
                    for j = math.max(1, #gui.debugLog - 60), #gui.debugLog do
                        drawMqColoredDebugLine(gui.debugLog[j])
                    end
                    pcall(function()
                        imgui.SetScrollHereY(1.0)
                    end)
                    pcall(function()
                        imgui.EndChild()
                    end)
                end
            end
        end)
        if not okDraw then
            local em = tostring(errDraw)
            warn("GUI draw error: " .. em)
        end
    end
    imgui.End()
    if mainPadPushed and imgui.PopStyleVar then
        pcall(function() imgui.PopStyleVar(1) end)
    end
end

mq.imgui.init("PPPokerGUIV2", drawGUI)

_G.PPPokerV2 = _G.PPPokerV2 or {}
function _G.PPPokerV2.armRun()
    _G.PPPokerV2._armRunPending = true
end

while gui.open do
    if _G.PPPokerV2 and _G.PPPokerV2._armRunPending then
        _G.PPPokerV2._armRunPending = false
        if not gui.running then
            gui.running = true
            stopRequested = false
            gui.navPaused = false
            navPluginUnpause()
            gui.status = "Run (PPPokerV2.armRun) — starting..."
        end
    end
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
                pushDebugLine("ERROR: " .. em, false)
            end
        end
    end
    mq.delay(200)
end

haltNavigationForStop()
if mq.imgui and mq.imgui.destroy then
    pcall(function() mq.imgui.destroy("PPPokerGUIV2") end)
end
