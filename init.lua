-- pppoker.lua 23rd anniversary task
-- Created by: RedFrog
-- Original creation date: 03/18/2026
-- Quest: https://everquest.allakhazam.com/db/quest.html?quest=10723
-- Version: 1.27
-- Changelog:
-- 1.27: New quest brain — objective-driven (`mq.TLO.Task(...).Objective(i).Done()`), fixed-index resume; replaces skip-prone stage/pipeline logic; new debug lines for objective selection/travel/waits.
-- 1.26: t09 — restore `/travelto neriakb` + `zoning(41)` when not in Commons (before done-count snapshot); keep t08-style resume tail.
-- 1.25: t09 travel trial commented; t08-style tail added.
-- 1.24: t09 — Poker2.lua nav timing only for paintings.
-- 1.23: (reverted) t09 dismount / double Blind / extra settle.
-- 1.22: t09 `/travelto neriakb` — longer `zoning(41)` timeout (EasyFind can chain Nektulos → Foreign → Commons; default 120s hit false fail before arrival).
-- 1.21: t09 Neriak Commons — match Poker2.lua nav lines; longer post-`moving()` dwell at each painting (Blind Fish was crediting only after Toadstool when the run left too quickly).
-- 1.20: t08 — drop Bull Pit sweep; Bull + Slug `/nav locyx` like Poker2.lua.
-- 1.19: t08 — always nav Bull then Slug; removed conditional Slug gate; Bull single pocket before sweep attempt.
-- 1.18: Neriak Commons (t09) — **nav to pockets only** (like Tassel painting / Poker2); no Marenkor/Rista target or hail (task credits at location).
-- 1.17: Route stage per journal row — classify **Instruction before Zone** (`routeStageForObjectiveRow`). Fixes freeportwest + global done/total “finale” rule mis-tagging Neriak rows so `hasIncompleteWorkForRouteStage(3|4)` stayed false (Slug/Commons skipped). t08: short settle after zoning Foreign for Task TLO.
-- 1.16: Neriak — Slug nav + end-of-t08 hub hop use `hasIncompleteWorkForRouteStage(3|4)`; `leaveNeriakTowardHubIfNeeded` bails if any stage 3/4 work left.
-- 1.15: Post-Betty — Zueria: no convert/cast/~22s wait when slide not used; fix level TLO=0 wrongly allowing slide; Gate before mount in t06 + dismount before Gate AA (mounted Gate often does not fire).
-- 1.14: East FP — Bluffing Betty: post-pocket settle delay + wider hail distance + `/nav target` fallback (25u at nav end was failing on Live).
-- 1.13: FILE MAP (below) documents chunk order vs quest; `pppokerGateOrPotionToPok` dedupes Gate+potion exit in Neriak Commons / Highpass Tiger / South Qeynos.
-- 1.12: Comment — `Me.Invis(1)` / pppokerLivingInvisTLO = standard invis (not undead/IU); no logic change.
-- 1.11: Zueria — PP.ZUERIA config + snapshot; single `pppokerZueria` table (itemName, refreshReadiness, ensureTargetMode, runAfterMementoGrog). GUI reads PP.ZUERIA.readiness.
-- 1.10: PP.NPC — one table for all quest NPC name lists (targeting fallbacks); callers use PP.NPC.KEY.
-- 1.09: Preflight — drop separate Spiritual Vigor line (still not treated as run-speed in logic; comment on movement check remains).
-- 1.08: ImGui Info panel shows last Zueria Slide readiness line (synced from readiness snapshot / preflight / post-Betty).
-- 1.07: Zueria Slide — single readiness snapshot (item, level, Nektulos mode) for preflight + post-Betty.
-- 1.06: Requires grouped after mq (ImGui, mq.icons, ImAnim). PP waypoints: Slick / Tassel painting / Betty pocket as single {x,y,z} tables like PoK Soulbinder.
-- 1.05: Route blocks — run a stage if ANY journal row maps to that stage (not only first incomplete); pipeline no longer skips early blocks when startStage is high. PoK Soulbinder: one loc table {x,y,z}.
-- 1.04: Task pipeline — 15 named steps (need + run) wired to shared helpers; resume uses zone+TLO adjust (East FP + Tassel done no longer restarts at West Slick).
-- 1.03: East FP — require Bluffing Betty within range before hail (second NPC wait was ignored; task fail).
--       Neriak hub — Gate fallback warns now distinguish no AA / wrong bind / cooldown vs zoning timeout.
--       Zueria Slide — info line before ~22s wait (was a long silent pause).
-- 1.02: Tassel wait — define waitUntilTasselObjectiveCredited after setGuiStage (Lua local scope; was nil global crash at painting).
-- 1.01: Stage 2 — after Tassel nav, poll Task TLO until Tassel row credits (or timeout) before /travelto freeporteast; log when East travel is issued (was firing with no echo right after nav).
-- 1.00: Task zones — Live journal uses display names ("West Freeport", "East Freeport", "North Qeynos"); normalizeZoneShort now aliases to freeportwest/freeporteast/qeynos2/qeynos so resume/missTassel/stage mapping matches MQ Task TLO.
-- 0.99: ImGui — follow MQ convention (open=X close, show=collapsed body); if show=false but not collapsed, force gui.open=false (fixes blank shell X). Restored freeportwest match for missTassel so stage 2 still runs when journal omits "tassel" text.
-- 0.98: No auto /timed rerun on fail. Stage 2 — removed Tassel task hard-stop (Poker2 linear: nav painting then East). Collapsed ImGui title no longer stops script (only X closes).
-- 0.97: Fix Tassel settle crash (removed early shouldStop() call before declaration). UI status now switches to "Buffing..." after Slick before stage-2 city prep.
-- 0.96: Tassel check waits briefly for Task TLO to update at waypoint (prevents false "incomplete" immediately after nav). info/warn now auto-strip leading "PPPoker:" text to avoid duplicate prefixes.
-- 0.95: Fix Tassel lock crash (runQuest scope): removed invalid config refs in stage-2 block; intentional stop now uses coin-gain guard only.
-- 0.94: Close + repeat fixes — window X now hard-stops script/nav when Begin returns no-draw; Tassel stage-2 block suppresses auto-repeat to prevent immediate re-run.
-- 0.93: GUI close fix — normalize imgui.Begin return variants so X reliably closes window/script (prevents blank stuck shell window).
-- 0.92: Stage 2 lock — after Tassel waypoint, do not proceed to East Freeport while active task still shows Tassel incomplete.
-- 0.91: Tassel lock — with active Paintings task, treat incomplete freeportwest objective (non-return/non-Slick text) as Tassel-incomplete; always run Tassel waypoint in stage 2.
-- 0.90: Invis — MQ TLO strict booleans (Lua: 0 is truthy; was skipping Perf after Guise). Buff bar checked before Invis(1)/Invisible for "already invis".
-- 0.89: Invis — also use ${Me.Invis(1)} (living invis TLO; aligns with InvisDisplay) for present-check + AA success polling alongside Invisible/buff names.
-- 0.88: Invis — treat Me.Buff(self/group AA names) as present; AA success if buff or Me.Invisible (fixes Perf→Group→spell when TLO Invisible lags). Self AA order: strongest first.
-- 0.87: CLR invis — preflight/city warnings: clerics have no living invis spells (only IU); script tries invis AAs only, else pot/alt.
-- 0.86: Invis — removed Cleric "Invisibility to Undead" spell fallback (normal invis only via AA/items for CLR).
-- 0.85: Stage 2 — remove second invis prep before East Freeport (was re-triggering group/spell invis after Tassel).
-- 0.84: Debug toggle now uses AStone-style right-aligned label+icon block; invis AA activation waits for cast-start/cast-finish before fallback.
-- 0.83: GUI — short Status line; scrollable Info (quest + script tips); Debug toggle + log (resume/journal detail). Removed duplicate text under progress bar. Verbose console lines moved to Debug.
-- 0.82: Invis — try self Alt Ability names first, then group AA, then class spell (mem/cast). Names in PP.INVIS_SELF_AA_NAMES / INVIS_GROUP_AA_NAMES (match AA window). Me.Invisible() counts as invis present for casters.
-- 0.81: No stop after Big Slick if MQ task not visible yet; when no Paintings task in tracker, run stages 2+ anyway (classic Poker.lua linear flow — was skipping Tassel’s). taskNeedsStageBlockOrEarlier: only use skip logic when a task index exists.
-- 0.80: Big Slick nav — same as original Poker.lua: one `/nav locyxz` + `moving()` + delay; removed distance checks, retries, and fail(). PoK Soulbinder nav same simple pattern.
-- 0.78: CWTN — if ${CWTN.*} / TLO reports already paused, skip /CWTN pause on; on exit do not /CWTN pause off (leave user’s prior pause). Plugin load still via Plugin[name].IsLoaded().
-- 0.77: Invis only for dangerous city legs (Tassel's+ East FP, Neriak, Highpass, Qeynos) — not Slick quest/reward in West FP. Tassel's: invis even if already in West FP. ensureNearLocyxzForHail retries /nav or fails. Idle GUI: journal stage or "Ready to get Quest".
-- 0.76: Spiritual Vigor is HP/stamina — no longer treated as run-speed. City entry: refresh movement buffs first, then invis last (spell casts drop invis).
-- 0.75: Forward-declare `moving` + assign after nav helpers — Lua locals aren’t visible above declaration, so `moving()` in runTassels/ensureNear was a nil global. Run start: movement buff only; invis applied just before traveling into Freeport / Neriak (not in PoK).
-- 0.74: Pack quest/GUI constants + mutable state into single table `PP` — Lua chunk local limit (200) exceeded on VanillaMQ; fixes "main function has more than 200 local variables".
-- 0.73: moving() waits briefly for Navigation.Active=true after /nav (fixes instant return when already near Slick — no walk, hail out of range). ensureNearLocyxz before Slick hail if still too far. No Paintings task → only stage 1 runs; after stage 1 if still no task, stop (no Tassels bar run).
-- 0.72: moving() — if mq.TLO.Navigation exists, trust ONLY its Active (do not OR with legacy Nav.Active); stale Nav=true left scripts stuck for ~2m after nav finished. Unknown Active types treated as not navigating.
-- 0.71: Big Slick — only full name "Big Slick Jones" with plain /target after nav to loc (quest + final hail); removed spawn/id/npc targeting extras.
-- 0.70: Big Slick targeting — dismount before hail; longer timeout; spawn-filter + /target id + /target npc fallbacks (fixes at-Slick but no target on Live).
-- 0.69: moving() — fix Navigation.Active string values (TRUE/FALSE case); if Active stuck after destination + grace, /nav stop and continue instead of fail (MQ2Nav can leave Active set after "Reached destination").
-- 0.68: Commemorative count uses only Me.Commemoratives() (character sheet currency); removed invalid ${Me.Currency[]} parse that spammed "No such character member Currency".
-- 0.67: moving() uses Navigation.Active (AStone-style) with Nav fallback — fixes silent run stop after Tassel when Nav TLO missing; GUI "Getting quest" when run active but task not parsed yet; friendlier run error (full text to MQ print); Commemorative GUI line + A_DragItem icon.
-- 0.66: AStone-style movement buff check/apply (class SoW/Selo/etc. + Worn Totem / Spiritual Vigor) and invis check/apply (warportal-style class spells + ROG Sneak/Hide); preflight reports both; applied once after preflight/PoK bind at run start.
-- 0.65: Full EQ journal steps: GUI bar + ticks from getPokerTaskProgress() done/total; status "Step N/M (EQ) — …"; route block still internal 1–8; logEqQuestSnapshot once at run start; dynamic bar tick spacing from total.
-- 0.64: Tassel's: enter stage 2 if Tassel row still incomplete even when resume stage >2; shared runTasselsPaintingWaypoint; before final Slick hail — retry Tassel + block if journal still incomplete (done/total or Tassel scan).
-- 0.63: Stage 2: Tassel's Tavern is West Freeport (EQResource) — painting auto-updates at waypoint; no Darrisa NPC. West→nav→delay, then East for Grub/Betty (fixes bogus /target spam in East).
-- 0.62: Quest bar: ticks every 1/8 (8 PPPoker stages), shimmer on, gradient fill top→bottom, rounding 4 (PIC_TEST_BAR_OPTS).
-- 0.61: East Freeport: zone to 382 before Tassel nav; hail Darrisa; fix false “stage >2” skip (freeportwest→8 only when total≥6; use hasIncompleteStage2Objective for Betty/slide). Instruction hints: Darrisa, grub/grog.
-- 0.60: PPPOKER_IMAGE_NUDGE_X — extra pixels right for header atlas before drawHeaderImage (tune if binding ignores child padding fix).
-- 0.59: Image child uses WindowPadding (0,0) only around BeginChild/EndChild so atlas left aligns with “Paintings…” (no double pad). Subtitle: “Anniversary”.
-- 0.58: drawHeaderImage no longer pushes WindowPadding (0,0) (that overrode main pad and glued the atlas to the left). ItemSpacing (0,0) kept for tight image child.
-- 0.57: Main window WindowPadding (PPPOKER_WINDOW_PAD_*) so content isn’t flush against the left inner edge; tune X/Y as needed.
-- 0.56: Window: first frame uses SetNextWindowSize/Pos(..., Always) so each /lua run opens at 400×700 (FirstUseEver was not re-applying when ImGui context survives). Still NoSavedSettings — no ini persistence.
-- 0.55: Inlined quest progress bar (ex-statusbar.lua); default window 400×700, ImGui NoSavedSettings (resize OK, size not persisted). Backup: init_pppoker_v0_54.lua.
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
-- add run to pok if no gate/potion after last neriak stage
-- add currency status upon success
-- Gate Section fix (done: bounded gate code/potion retries + timeouts)

--[[ ========== FILE MAP (read top → bottom; quest spine in middle) ==========
  A. Requires + PP (constants, ZUERIA, NPC, waypoints, GUI opts)
  B. Task TLO — find Paintings task, progress, zone→stage, resume, objective scans
  C. Plugins — CWTN / RGMerc pause, fail(), logEqQuestSnapshot
  D. Preflight helpers — Nav, Gate pot/AA, items, coins
  E. pppokerZueria — slide item, readiness, convert, post-grog cast
  F. Movement + invis — SoW/totem, invis AA/spell, preflight travel report
  G. Mount, targeting, nav/moving, zoning, PoK bind, Gate→PoK, leave Neriak hub
  H. GUI core — gui table, refreshGuiQuestProgress, setGuiStage, Tassel wait
  I. QUEST SPINE — taskBlockNeededForPipeline, QuestSteps t01–t15, TASK_PIPELINE, runTaskPipeline, runQuest
  J. ImGui — StatusBar, atlas, pppokerDrawGUI, mq.imgui.init
  K. Tail — gatePotionCount, auto-repeat (small utilities)

  Future tidy-ups (low risk first): cluster remaining /nav xyz into PP.WAYPOINTS by stage;
  one iterator for Task objective rows to dedupe hasIncomplete* / getPokerTaskProgress loops.
]]

local mq = require('mq')
local imgui = require('ImGui')
local ImGui = imgui
local Icons = require('mq.icons')
local ImAnim = require('ImAnim')

--- Filled after `gui` exists; verbose messages for Debug panel (see `pppokerGuiDebug` below).
local pppokerGuiDebug

--- Set by the GUI Stop button. Used to abort long waits quickly.
local stopRequested = false

--- Single table keeps the Lua chunk under the ~200 local-variable limit (VanillaMQ / Lua 5.1).
local PP = {
    VERSION = "1.27",
    GATE_ZONE_ID = 202,
    --- EasyFind to Neriak Commons often zones through multiple hops; 120s default `zoning()` is too tight on Live.
    ZONING_TIMEOUT_NERIAK_COMMONS_MS = 360000,
    POK_TRAVEL_SHORTNAME = "poknowledge",
    --- Soulbinder Jera pocket in PoK (same order as `/nav locyxz x y z`).
    POK_SOULBINDER_LOC = { -131.6, -94.2, -159.0 },
    --- Big Slick corner (legacy Poker.lua `/nav locyxz 19 136 -54`).
    SLICK_QUEST_LOC = { 19, 136, -54 },
    --- Tassel's Tavern painting credit spot (West Freeport).
    TASSEL_PAINTING_LOC = { -177, -415, -85 },
    --- Crab & Grog / Bluffing Betty pocket (East Freeport).
    EAST_FP_BETTY_POCKET_LOC = { 153, -806, 7 },
    --- Live: Betty is often slightly past strict 25u from pocket after MQ2Nav "Reached destination"; match practical hail.
    EAST_FP_BETTY_HAIL_MAX_DIST = 45,
    GATE_ALT_ACT_ID = 1217,
    GATE_POTION_NAME = "Philter of Major Translocation",
    --- Zueria Slide (East FP → Nektulos). Code: `pppokerZueria` + `PP.pppokerZueria`; last snapshot in `ZUERIA.readiness`.
    ZUERIA = {
        SLIDE_ITEM_BASE = "Zueria Slide",
        TARGET_MODE = "Nektulos",
        ZONE_ID_NEKTULOS = 25,
        -- Level floor when ${FindItem...RequiredLevel} is missing (Live Nektulos conversion ~105).
        LEVEL_FLOOR = 105,
        readiness = nil,
    },
    MOUNT_KEYRING_SLOT = 1,
    MOVEMENT_CLASS_BUFFS = {
        BRD = { "Selo's Accelerando", "Selo's Song of Travel" },
        BST = { "Spirit of Wolf", "Spirit of the Shrew" },
        DRU = { "Spirit of Wolf", "Spirit of Cheetah" },
        RNG = { "Spirit of Wolf" },
        SHM = { "Spirit of Wolf", "Spirit of Cheetah" },
    },
    INVIS_CLASS_BUFFS = {
        -- CLR: EQ only offers Invisibility to Undead as a class spell line; we do not cast IU (need living invis in cities).
        -- Script tries invis AAs only; otherwise use pot, clickie, or another toon — see preflight / city-entry warns.
        CLR = {},
        DRU = { "Invisibility", "Camouflage" },
        ENC = { "Invisibility" },
        MAG = { "Invisibility" },
        NEC = { "Invisibility", "Shadow" },
        RNG = { "Camouflage" },
        SHM = { "Invisibility" },
        WIZ = { "Invisibility", "Improved Invisibility" },
    },
    --- Exact strings as in the AA window (and buff names on the bar). Strongest first — fewer wasted clicks / shared timers.
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
    WORN_TOTEM = "Worn Totem",
    COMMEMORATIVE_ITEM_ICON_ID = 5901,
    DRAGITEM_ICON_ATLAS_OFFSET = 500,
    --- Quest NPCs: full name first, then shorter keywords for ${Spawn} / targeting (see targetOrFail, waitForNPCToBeWithinDistance).
    NPC = {
        BIG_SLICK_JONES = { "Big Slick Jones" },
        BLUFFING_BETTY = { "Bluffing Betty", "Bluffing" },
        QUINN_OF_QUADS = { "Quinn of Quads", "Quads" },
        MHRAI_QUEEN_OF_TAILS = { "Mhrai, Queen of Tails", "Queen", "Mhrai" },
        SOULBINDER_JERA = { "Soulbinder Jera", "Jera" },
    },
    QUEST_TITLE = "Paintings Playing Poker",
    TASK_OBJECTIVE_EMPTY_STREAK_MAX = 5,
    TASK_SLOT_MAX = 48,
    NAMED_POKER_TASK_KEYS = {
        "Paintings Playing Poker",
        "23rd Anniversary: Paintings Playing Poker",
        "Playing Poker",
        "Paintings",
    },
    pokerResumeTaskSource = nil,
    cwtnState = { pausedApplied = false, alreadyPausedAtStart = false },
    restartState = { scheduled = false },
    -- GUI / atlas (was separate locals; merged for local limit)
    ATLAS_FILE = "pictest_triptych.png",
    USE_TRIPTYCH_ATLAS = true,
    ATLAS_W = 500,
    ATLAS_H = 900,
    SEGMENT_COUNT = 3,
    PANEL_W = 500,
    PANEL_H = 300,
    PANELS = {
        { name = "Roosters", file = "pictest_roosters.png", segment = 0 },
        { name = "Dogs",     file = "pictest_dogs.png",     segment = 1 },
        { name = "Fish",     file = "pictest_fish.png",     segment = 2 },
    },
    WINDOW_W = 400,
    WINDOW_H = 780,
    FRAME_OFFSET_Y = 72,
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
    WINDOW_ID_SUFFIX = "###PPPokerPic01",
    WINDOW_PAD_X = 10,
    WINDOW_PAD_Y = 6,
    IMAGE_NUDGE_X = 12,
    PIC_TEST_BAR_ENABLED = true,
    PIC_TEST_BAR_SHOW_OPTIONS_UI = false,
    PIC_TEST_BAR_OPTS = {
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
    },
    textures = {},
    loadedOk = {},
    selectedIndex = 1,
    texturesLoadedOnce = false,
    pppokerApplyInitialLayout = true,
    picTestBarLive = nil,
    barTextFmtStr = "Quest %.0f%%",
    picTestBarUseDemoPct = false,
    picTestBarDemoPct = 65.0,
}
PP.SEGMENT_H = math.floor(PP.ATLAS_H / PP.SEGMENT_COUNT)

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
    for i = 1, PP.TASK_SLOT_MAX do
        local id = safeParseNum(string.format("${Task[%d].ID}", i))
        if id and id > 0 then n = n + 1 end
    end
    if n > 0 then return n end
    for i = 1, PP.TASK_SLOT_MAX do
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
local function tryNamedPaintingsTaskRef()
    for _, key in ipairs(PP.NAMED_POKER_TASK_KEYS) do
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
    for i = 1, PP.TASK_SLOT_MAX do
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
                    if streak >= PP.TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
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
    PP.pokerResumeTaskSource = nil
    local named = tryNamedPaintingsTaskRef()
    if named then
        PP.pokerResumeTaskSource = "title"
        return named
    end
    for i = 1, PP.TASK_SLOT_MAX do
        if taskSlotAppearsOccupied(i) then
            local title = getTaskTitleForSlot(i)
            if taskTitleLooksLikePaintingsPoker(title) then
                PP.pokerResumeTaskSource = "title"
                return i
            end
        end
    end
    local byObj = findPokerTaskIndexByObjectives()
    if byObj then
        PP.pokerResumeTaskSource = "objectives"
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
            if streak >= PP.TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
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
    z = z:gsub("%-", "")
    --- Live ${Task[].Objective[].Zone} often uses journal display text, not zone shortnames.
    local canon = {
        westfreeport = "freeportwest",
        eastfreeport = "freeporteast",
        northqeynos = "qeynos2",
        southqeynos = "qeynos",
    }
    if canon[z] then
        return canon[z]
    end
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
        -- MQ often under-counts objectives; (done >= total-1) with small total wrongly maps to finale (8)
        -- and skips East Freeport (Betty). Only treat as stage 8 when enough steps exist.
        local minTotalForFinale = 6
        if total and total >= minTotalForFinale and done and done >= (total - 1) then
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
    -- Stage 2: East Freeport beats + Tassel’s (journal zone may be West; instruction often says Tassel)
    if t:find("bluffing betty", 1, true) or t:find("crab and grog", 1, true) then return 2 end
    if t:find("grub n grog", 1, true) or t:find("grub and grog", 1, true) then return 2 end
    if t:find("tassel", 1, true) then return 2 end
    if t:find("grub", 1, true) and (t:find("grog", 1, true) or t:find("tavern", 1, true) or t:find("memento", 1, true)) then return 2 end
    -- Stage 3 Neriak Foreign Quarter (wording varies: "The Bull Pit", typos, etc.)
    if t:find("bull", 1, true) and t:find("pit", 1, true) then return 3 end
    if t:find("svunsa", 1, true) then return 3 end
    if t:find("slug", 1, true) then return 3 end
    if t:find("grendon", 1, true) then return 3 end
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

--- Map one journal row to route block 1–8. **Instruction first** so freeportwest + global done/total finale
--- rule does not mis-classify Neriak / Highpass rows when MQ leaves Zone wrong or blank.
local function routeStageForObjectiveRow(zone, instr, done, total)
    local fi = stageFromObjectiveInstruction(instr, done, total)
    if fi then return fi end
    local s = stageFromObjectiveZone(zone, done, total)
    if s == 1 then s = stageFromObjectiveZoneFuzzy(zone, done, total) end
    return s
end

local function inferResumeStageFromProgress(progress)
    local done = progress.done or 0
    local total = progress.total or 0
    local zone = progress.activeZone
    local instr = progress.activeInstr
    return routeStageForObjectiveRow(zone, instr, done, total)
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
            if streak >= PP.TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
        else
            streak = 0
            local incomplete = false
            if req > 0 then
                incomplete = (cur < req)
            elseif instr and instr ~= "" then
                incomplete = (cur <= 0)
            end
            if incomplete then
                local s = routeStageForObjectiveRow(zone, instr, done, total)
                if s ~= 1 then return s end
            end
        end
    end
    return nil
end

--- Any incomplete task row that maps to script stage 2 (Tassel’s / Grub&Grog / Betty / East zone rows). Used so we don't skip Betty when resume stage wrongly jumps past 2.
local function hasIncompleteStage2Objective()
    local taskIndex = getActivePokerTaskIndex()
    if not taskIndex then return false end
    local progress = getPokerTaskProgress()
    local done = progress and progress.done or 0
    local total = progress and progress.total or 0
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
            if streak >= PP.TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
        else
            streak = 0
            local incomplete = false
            if req > 0 then
                incomplete = (cur < req)
            elseif instr and instr ~= "" then
                incomplete = (cur <= 0)
            end
            if incomplete then
                local s = routeStageForObjectiveRow(zone, instr, done, total)
                if s == 2 then return true end
            end
        end
    end
    return false
end

--- Incomplete journal row whose instruction mentions Tassel's Tavern (West painting step).
local function hasIncompleteTasselTavernObjective()
    local taskIndex = getActivePokerTaskIndex()
    if not taskIndex then return false end
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
            if streak >= PP.TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
        else
            streak = 0
            local incomplete = false
            if req > 0 then
                incomplete = (cur < req)
            elseif instr and instr ~= "" then
                incomplete = (cur <= 0)
            end
            if incomplete then
                local t = tostring(instr or ""):lower()
                local z = normalizeZoneShort(zone)
                if t:find("tassel", 1, true) then return true end
                -- Catch-up when journal zone is freeportwest but text omits "Tassel" (do not use this after nav to gate East — that was removed in 0.98).
                if z == "freeportwest" then
                    local looksFinalReturn = t:find("big slick", 1, true)
                        or (t:find("return", 1, true) and t:find("freeport", 1, true))
                    if not looksFinalReturn then return true end
                end
            end
        end
    end
    return false
end

--- Map one journal row to route block 1–8 (same rules as resume / stage-2 scan).
local function mapRowToRouteStage(zone, instr, done, total)
    return routeStageForObjectiveRow(zone, instr, done, total)
end

--- True if any incomplete objective row maps to this route block (journal order can list Qeynos before Neriak is credited — first-row-only resume used to skip whole blocks).
local function hasIncompleteWorkForRouteStage(routeStage)
    local taskIndex = getActivePokerTaskIndex()
    if not taskIndex then return false end
    local progress = getPokerTaskProgress()
    local done = progress and progress.done or 0
    local total = progress and progress.total or 0
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
            if streak >= PP.TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
        else
            streak = 0
            local incomplete = false
            if req > 0 then
                incomplete = (cur < req)
            elseif instr and instr ~= "" then
                incomplete = (cur <= 0)
            end
            if incomplete and mapRowToRouteStage(zone, instr, done, total) == routeStage then
                return true
            end
        end
    end
    return false
end

--- First incomplete row can lag as West while toon is in East with Tassel done — avoid resuming at stage 1 (West Slick).
local function adjustResumeStageForCurrentZone(stage)
    stage = tonumber(stage) or 1
    local z = mq.TLO.Zone.ID()
    if z == 382 and hasIncompleteStage2Objective() and not hasIncompleteTasselTavernObjective() then
        if stage < 2 and type(pppokerGuiDebug) == "function" then
            pppokerGuiDebug(string.format("Resume adjust: East FP + stage-2 work — bumping stage %d -> 2", stage))
        end
        return math.max(stage, 2)
    end
    if z == 383 and getActivePokerTaskIndex() and not hasIncompleteTasselTavernObjective() and hasIncompleteStage2Objective() and stage <= 1 then
        if type(pppokerGuiDebug) == "function" then
            pppokerGuiDebug("Resume adjust: West FP + Tassel done, East incomplete — stage 1 -> 2")
        end
        return 2
    end
    return stage
end

--- Forward declarations: Lua locals aren’t visible above their `local function` line; callers earlier in the file must share these bindings.
local moving
local pppokerEnsureInvisForCityEntry

--- West Freeport painting waypoint; task auto-updates at location (EQ journal).
local function runTasselsPaintingWaypoint()
    -- Keep Tassel's waypoint simple (Poker2-style): no invis recast here.
    -- Stage 2 applies bar-leg invis once before this; do not duplicate before East travel.
    if mq.TLO.Zone.ID() ~= 383 then
        mq.cmd('/squelch /travelto freeportwest')
        zoning(383)
        mq.delay(1000)
    end
    info("PPPoker: Tassel's Tavern (West Freeport) — moving to painting waypoint for task update.")
    mq.cmdf("/squelch /nav locyxz %.1f %.1f %.1f", unpack(PP.TASSEL_PAINTING_LOC))
    moving()
    mq.delay(4500)
end

local function computeStartStage()
    local progress = getPokerTaskProgress()
    if progress then
        if PP.pokerResumeTaskSource == "objectives" then
            pppokerGuiDebug("Poker task found by scanning objective text (task title was empty or did not match).")
        end
        pppokerGuiDebug(string.format("Task progress detected: %d/%d objectives done", progress.done or 0, progress.total or 0))
        if progress.total and progress.total > 0 and progress.done >= progress.total then
            return 8, true -- completed
        end
        pppokerGuiDebug(string.format("Resume: active zone=%s instr=%s", tostring(progress.activeZone), tostring(progress.activeInstr)))
        local stage = inferResumeStageFromProgress(progress)
        -- Always re-scan objectives when we still map to stage 1 (covers total==0 parse quirks and first-row blanks).
        if stage == 1 and progress.taskIndex then
            local alt = findStageByScanningObjectives(progress.taskIndex, progress.done, progress.total)
            if alt then
                pppokerGuiDebug(string.format("Resume: objective scan mapped to stage %d", alt))
                stage = alt
            elseif (progress.total or 0) > 0 and (progress.done or 0) < (progress.total or 0) then
                pppokerGuiDebug(
                    "Resume: could not map incomplete objective to a stage (zone/instr unrecognized); defaulting to stage 1."
                )
            end
        end
        return adjustResumeStageForCurrentZone(stage), false
    end
    local tcTlo = 0
    pcall(function()
        tcTlo = tonumber(mq.TLO.Task.Count() or 0) or 0
    end)
    local tcProbe = getTaskCount()
    pppokerGuiDebug(string.format(
        "Resume: Poker task not found (TLO Task.Count=%d, slots with parse data=%d). Open Quest Journal (active tasks) and try again; MQ uses ${Task[name]} not UI order. Using zone-based stage.",
        tcTlo,
        tcProbe
    ))
    -- fallback: infer from current zone
    return adjustResumeStageForCurrentZone(zoneIdToStage(mq.TLO.Zone.ID())), false
end

--- Re-read quest task for resume stage without log spam (call after hail/spawn updates).
local function computeResumeStageQuiet()
    local progress = getPokerTaskProgress()
    if not progress then
        return adjustResumeStageForCurrentZone(zoneIdToStage(mq.TLO.Zone.ID())), false
    end
    if progress.total and progress.total > 0 and progress.done >= progress.total then
        return 8, true
    end
    local stage = inferResumeStageFromProgress(progress)
    if stage == 1 and progress.taskIndex then
        local alt = findStageByScanningObjectives(progress.taskIndex, progress.done, progress.total)
        if alt then stage = alt end
    end
    return adjustResumeStageForCurrentZone(stage), false
end

--- Run a stage block only while the task's first incomplete objective maps to this stage or an earlier one.
--- Example: if task is already at Highpass (5), needNow=5 → skip stages 1–4 (needNow <= 4 is false).
--- When all objectives parse as done (qc), still allow stage 8 so return hail can run if the run reached it.
--- With **no** Paintings task visible to MQ yet: always run the block (classic Poker.lua linear run — do not skip Tassel’s / East FP while journal lags).
local function taskNeedsStageBlockOrEarlier(stageNum)
    local need, qc = computeResumeStageQuiet()
    if qc then
        if stageNum == 8 then return true, need, true end
        return false, need, true
    end
    local taskIdx = getActivePokerTaskIndex()
    if not taskIdx then
        return true, need, false
    end
    if hasIncompleteWorkForRouteStage(stageNum) then
        return true, need, false
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
            if streak >= PP.TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
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
    -- Intentionally no-op: auto /timed reruns were noisy and confused runs; re-launch from GUI when needed.
    if PP.restartState.scheduled then return end
    PP.restartState.scheduled = true
    if type(pppokerGuiDebug) == "function" then
        pppokerGuiDebug("scheduleRestart: no auto /lua run (disabled).")
    end
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

--- Best-effort: CWTN builds differ; if nil, caller may still issue /CWTN pause on.
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
    -- Only pause when this toon's expected CWTN class plugin is loaded.
    local loaded, pluginName = isExpectedCWTNPluginLoaded()
    PP.cwtnState.alreadyPausedAtStart = false
    if not loaded then
        pppokerGuiDebug(string.format("CWTN pause skipped: expected plugin not loaded (%s)", pluginName or "unknown"))
        return false
    end

    local pausedNow = cwtnAppearsPaused()
    if pausedNow == true then
        pppokerGuiDebug(string.format("CWTN already paused — skipping /CWTN pause on (%s)", pluginName))
        PP.cwtnState.pausedApplied = false
        PP.cwtnState.alreadyPausedAtStart = true
        return true
    end

    mq.cmd('/CWTN pause on')
    PP.cwtnState.pausedApplied = true
    if pausedNow == nil then
        pppokerGuiDebug(string.format(
            "CWTN: pause state not readable (${CWTN.Paused} etc.) — issued /CWTN pause on (%s)",
            pluginName
        ))
    else
        pppokerGuiDebug("CWTN paused via /CWTN pause on (plugin: " .. pluginName .. ")")
    end
    return true
end

local function unpauseCWTNPlugins()
    if PP.cwtnState.alreadyPausedAtStart then
        PP.cwtnState.alreadyPausedAtStart = false
        pppokerGuiDebug("CWTN was paused before this run — leaving paused (no /CWTN pause off).")
        return
    end
    if not PP.cwtnState.pausedApplied then return end
    local loaded = isExpectedCWTNPluginLoaded()
    if not loaded then
        PP.cwtnState.pausedApplied = false
        return
    end
    mq.cmd('/CWTN pause off')
    PP.cwtnState.pausedApplied = false
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
    -- If user hit Stop, abort cleanly without scheduling a restart.
    if stopRequested then
        unpauseCWTNPlugins()
        unpauseRGMercs()
        error("Stopped by user")
    end
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
    local s = tostring(msg or "")
    s = s:gsub("^%s*PPPoker:%s*", "")
    print(string.format("\ao[\agPPPoker\ao]\at %s", s))
end

warn = function(msg)
    local s = tostring(msg or "")
    s = s:gsub("^%s*PPPoker:%s*", "")
    print(string.format("\ao[\ayPPPoker\ao]\at %s", s))
end

--- Log EQ journal snapshot (done/total, active objective, each incomplete row). Call once per run to verify stable totals.
local function logEqQuestSnapshot(context)
    local ctx = context and tostring(context) or "snapshot"
    local ok, p = pcall(getPokerTaskProgress)
    if not ok or not p or not p.taskIndex then
        pppokerGuiDebug(string.format("EQ quest [%s]: could not read task (no Paintings task in tracker?)", ctx))
        return
    end
    pppokerGuiDebug(string.format(
        "EQ quest [%s]: %d/%d objectives done | active zone=%s",
        ctx,
        p.done or 0,
        p.total or 0,
        tostring(p.activeZone or "")
    ))
    if p.activeInstr and tostring(p.activeInstr) ~= "" then
        pppokerGuiDebug(string.format("EQ quest [%s]: active instruction: %s", ctx, tostring(p.activeInstr)))
    end
    local taskIndex = p.taskIndex
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
            if streak >= PP.TASK_OBJECTIVE_EMPTY_STREAK_MAX then break end
        else
            streak = 0
        end
        if zempty and iempty then
            -- skip
        else
            local incomplete = false
            if req > 0 then
                incomplete = (cur < req)
            elseif instr and instr ~= "" then
                incomplete = (cur <= 0)
            end
            if incomplete then
                pppokerGuiDebug(string.format(
                    "EQ quest [%s]: incomplete #%d zone=%s | %s",
                    ctx,
                    objIdx,
                    tostring(zone or ""),
                    tostring(instr or "")
                ))
            end
        end
    end
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
    return ok and tonumber(zid or 0) == PP.GATE_ZONE_ID
end

local function hasGatePotion()
    local ok, found = pcall(function() return mq.TLO.FindItem(PP.GATE_POTION_NAME)() end)
    return ok and found
end

local function hasItem(name)
    local ok, found = pcall(function() return mq.TLO.FindItem(name)() end)
    return ok and found
end

--- Commemorative Coins total (same as Character sheet → Currency tab). MQ has no Me.Currency[] TLO — use Commemoratives only.
local function getCommemorativeCount()
    local ok, n = pcall(function() return tonumber(mq.TLO.Me.Commemoratives() or 0) end)
    if ok and n then return math.floor(n) end
    return 0
end

--- Zueria Slide: all behavior lives here; `PP.ZUERIA` holds constants + last `readiness` snapshot (ImGui / `/lua`).
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
        R.summary = "Zueria Slide: not in inventory — after Betty, script uses Gate/PoK routing."
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
            -- TLO miss reads as 0; do not run convert/cast/slide wait (was wrongly treated as level-OK).
            R.levelOk = false
            R.reason = "level_unread"
            R.summary =
                "Zueria Slide: could not read character level — slide skipped (Gate/PoK route after grog)."
        elseif R.meLevel < R.effectiveRequired then
            R.levelOk = false
            R.reason = "under_level"
            R.summary = string.format(
                "Zueria Slide: level %d below required %d (TLO req %d, floor %d) — slide step skipped.",
                R.meLevel,
                R.effectiveRequired,
                R.requiredFromTLO,
                floor
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
            "Zueria Slide: %s | level %d OK (effective req %d) | %s mode — will use after Betty grog.",
            tostring(R.itemName or "?"),
            R.meLevel,
            R.effectiveRequired,
            target
        )
    elseif R.reason == "needs_convert" then
        R.summary = string.format(
            "Zueria Slide: %s | level %d OK — will /convertitem toward %s after Betty if needed.",
            tostring(R.itemName or "?"),
            R.meLevel,
            target
        )
    elseif R.reason ~= "under_level" and R.reason ~= "no_item" and R.reason ~= "level_unread" then
        R.summary = string.format(
            "Zueria Slide: %s | level %d | req %d",
            tostring(R.itemName or "?"),
            R.meLevel,
            R.effectiveRequired
        )
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

--- After Memento Grog (East FP): re-check readiness, convert if needed, cast and wait for Nektulos.
--- When `canAttemptSlide` is false, does not run convert loop, item click, or long cast wait — next step is Gate/PoK.
function pppokerZueria.runAfterMementoGrog()
    local c = PP.ZUERIA
    local zs = pppokerZueria.refreshReadiness()
    if type(pppokerGuiDebug) == "function" then
        pppokerGuiDebug(zs.summary)
    end
    if not zs.canAttemptSlide then
        info("Zueria Slide: " .. zs.summary)
        info("Skipping slide /convertitem, item click, and cast wait — continuing to hub route.")
        pcall(function()
            gui.zueriaSlideInfo = tostring(zs.summary or "")
        end)
        return
    end
    local slideReady = pppokerZueria.ensureTargetMode()
    if slideReady and slideReady:find(c.TARGET_MODE, 1, true) then
        local zid = c.ZONE_ID_NEKTULOS
        mq.cmdf('/useitem "%s"', slideReady)
        info("Zueria Slide: waiting for Nektulos zone (polling; long item cast if slide fires)…")
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
        if not zoned and type(pppokerGuiDebug) == "function" then
            pppokerGuiDebug("Zueria slide did not zone to Nektulos in time — continuing without slide (stage 3 will handle).")
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

-- ========== Movement + invis (AStone / Warportal patterns) ==========

local function waitUntilMs(maxMs, predicate)
    local t0 = mq.gettime()
    while mq.gettime() - t0 < maxMs do
        local ok, v = pcall(predicate)
        if ok and v then return true end
        mq.delay(100)
    end
    return false
end

local function findFreeGemSlotPpp()
    local maxGems = mq.TLO.Me.NumGems() or 8
    for i = 1, maxGems do
        if not mq.TLO.Me.Gem(i).ID() then return i end
    end
    local lastSlot = maxGems
    info(string.format("PPPoker: all gem slots full, clearing slot %d for buff spell.", lastSlot))
    mq.cmdf("/memspell %d clear", lastSlot)
    mq.delay(2000)
    return lastSlot
end

local function meditateToManaPpp(requiredMana)
    requiredMana = requiredMana or 40
    if (mq.TLO.Me.CurrentMana() or 0) >= requiredMana then return end
    info(string.format("PPPoker: meditating for mana (need %d)...", requiredMana))
    mq.cmd("/sit on")
    local t0 = mq.gettime()
    local timeoutMs = 120000
    while (mq.TLO.Me.CurrentMana() or 0) < requiredMana do
        if mq.gettime() - t0 >= timeoutMs then
            warn("PPPoker: meditate timeout; standing.")
            mq.cmd("/stand")
            return
        end
        mq.delay(500)
        if not mq.TLO.Me.Sitting() then mq.cmd("/sit on") end
    end
    mq.cmd("/stand")
end

--- True run-speed only: class SoW/Selo/etc. Spiritual Vigor (HP/stamina click) is not movement — do not count here.
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
    info('PPPoker: using Worn Totem for speed (AStone-style).')
    mq.cmdf('/useitem "%s"', PP.WORN_TOTEM)
    mq.delay(2000)
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
                info(string.format('PPPoker: memorizing "%s" in gem %d', spell, gemSlot))
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
                        info(string.format('PPPoker: movement buff applied: "%s"', spell))
                        return true
                    end
                    warn(string.format('PPPoker: "%s" cast did not stick (attempt %d/%d).', spell, attempt, maxRetries))
                else
                    mq.delay(2000)
                end
            end
        end
    end
    return false
end

local function pppokerEnsureMovementBuff()
    local has, which = pppokerMovementBuffPresent()
    if has then return true, which end
    if pppokerApplyMovementClassBuff() then return true, "class spell" end
    if pppokerUseWornTotemIfAvailable() then return true, PP.WORN_TOTEM end
    return false, nil
end

--- MQ often returns 0/1 or strings; in Lua \`if 0 then\` is **true** — must not treat as invis.
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

--- ${Me.Invis(1)} — MQ's **standard** invis state (normal invis vs guards / living NPCs on the client).
--- This is **not** "look for undead" and **not** Invisibility to Undead (IU/IVU); PPPoker never uses IU for city legs.
--- Name matches RedGuides/MQ docs ("Invis(1)" = primary invis slot); use with pppokerMqBool only.
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

--- True if named buff is on the short bar (AA invis often applies before ${Me.Invisible} flips true in MQ).
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
    -- Buff bar first (Guise / clicks can strip invis while TLO lags or returns numeric junk).
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
    -- Unknown value (or unexpected type): treat as unknown readiness.
    return nil
end

local function pppokerTryActivateInvisAA(aaName)
    local id = pppokerInvisAAId(aaName)
    if id <= 0 then return false end
    local ready = pppokerInvisAAReady(aaName)
    if ready == false then return false end
    pppokerGuiDebug(string.format('Invis AA candidate: "%s" id=%s ready=%s', aaName, tostring(id), tostring(ready)))
    mq.cmd("/target myself")
    mq.delay(200)
    mq.cmdf("/alt act %d", id)
    mq.delay(250)
    -- Some AAs begin casting a moment after /alt act; don't treat "not casting yet" as completion.
    local sawCasting = waitUntilMs(2000, function() return mq.TLO.Me.Casting() ~= nil end)
    if sawCasting then
        waitUntilMs(12000, function() return mq.TLO.Me.Casting() == nil end)
    else
        -- Instant/no-cast AA path.
        mq.delay(500)
    end
    -- AA can apply invis a moment after cast/activation; poll before deciding AA failed.
    -- Do not rely on Me.Invisible() alone — Live often lags; buff name matches AA string for these lines.
    local okInvis = waitUntilMs(6000, function()
        return pppokerLivingInvisTLO() or pppokerInvisibleTLO() or pppokerInvisBuffIdByName(aaName)
    end)
    if okInvis then
        pppokerGuiDebug(string.format('Invis AA activated: "%s"', aaName))
        return true
    end
    pppokerGuiDebug(string.format('Invis AA did not stick (no buff / Invis(1) / Me.Invisible) after "%s"', aaName))
    pppokerGuiDebug(string.format('Invis AA failed: "%s"', aaName))
    return false
end

--- Self AA → group AA (no spell mem) for classes that use spell invis when AA missing.
local function pppokerApplyInvisViaAA()
    local class = mq.TLO.Me.Class.ShortName()
    if class == "ROG" then return false end
    if not PP.INVIS_CLASS_BUFFS[class] then return false end

    -- Debug: show AA candidates (self first, then group) with ID+readiness from TLO.
    pppokerGuiDebug(string.format("Invis via AA: class=%s (self->group priority)", tostring(class)))
    for _, name in ipairs(PP.INVIS_SELF_AA_NAMES) do
        local id = pppokerInvisAAId(name)
        local ready = pppokerInvisAAReady(name)
        pppokerGuiDebug(string.format('Self AA candidate: "%s" id=%s ready=%s', tostring(name), tostring(id), tostring(ready)))
    end
    for _, name in ipairs(PP.INVIS_GROUP_AA_NAMES) do
        local id = pppokerInvisAAId(name)
        local ready = pppokerInvisAAReady(name)
        pppokerGuiDebug(string.format('Group AA candidate: "%s" id=%s ready=%s', tostring(name), tostring(id), tostring(ready)))
    end

    for _, name in ipairs(PP.INVIS_SELF_AA_NAMES) do
        if pppokerTryActivateInvisAA(name) then return true end
    end
    for _, name in ipairs(PP.INVIS_GROUP_AA_NAMES) do
        if pppokerTryActivateInvisAA(name) then return true end
    end
    return false
end

local function pppokerRogueSneakHide()
    info("PPPoker: ROG — Sneak, then Hide.")
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
                info(string.format('PPPoker: memorizing invis "%s" in gem %d', spell, gemSlot))
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
                        info(string.format('PPPoker: invis buff applied: "%s"', spell))
                        return true
                    end
                    warn(string.format('PPPoker: invis "%s" did not stick (attempt %d/%d).', spell, attempt, maxRetries))
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

--- Preflight: report movement + invis (no casting here).
local function reportTravelBuffsPreflight()
    local mov, mname = pppokerMovementBuffPresent()
    if mov then
        info("- Movement speed: OK (" .. tostring(mname or "?") .. ").")
    else
        warn("- Movement speed: not detected — script will try class buff / Worn Totem at run start.")
        if hasItem(PP.WORN_TOTEM) then
            info("  - Worn Totem: in inventory (fallback).")
        end
    end

    local class = mq.TLO.Me.Class.ShortName()
    if not PP.INVIS_CLASS_BUFFS[class] and class ~= "ROG" then
        info("- Invis: not required for class " .. tostring(class) .. " (cast manually if you want).")
    else
        local inv, iname = pppokerInvisBuffPresent()
        if inv then
            if iname then
                info("- Invis: OK (" .. tostring(iname) .. ").")
            else
                info("- Invis: OK (Invisible or ROG).")
            end
        else
            if class == "CLR" then
                warn("- Invis: not detected — Cleric has no living invis spells (only IU). Script will try invis AAs only; use a pot, clickie, or boxed buff before city legs if needed.")
            else
                warn("- Invis: not detected — script will try invis AA (self then group), then class spell / Sneak+Hide before city travel (not in PoK).")
            end
        end
    end
end

--- Before city zones: movement buffs first (may cast / click item), then invis last — casting drops invis.
pppokerEnsureInvisForCityEntry = function(whereLabel)
    whereLabel = whereLabel or "city zone"
    info("PPPoker: prep for " .. whereLabel .. " — movement speed first, then invis (spells strip invis).")
    local movOk, movDetail = pppokerEnsureMovementBuff()
    if movOk then
        info("PPPoker: movement speed OK (" .. tostring(movDetail or "?") .. ") — applying invis last.")
    else
        warn("PPPoker: movement speed still missing — apply SoW/Selo/totem manually; applying invis last anyway.")
    end
    local invOk, invDetail = pppokerEnsureInvisBuff()
    if invOk then
        info("PPPoker: invis OK (" .. tostring(invDetail or "n/a") .. ").")
    else
        local cls = mq.TLO.Me.Class.ShortName()
        if cls == "CLR" then
            warn("PPPoker: invis not applied — Cleric: no living invis spell for script to cast; use pot, clickie, or alt buff before " .. whereLabel .. " if KOS.")
        else
            warn("PPPoker: invis not applied — use pot/spell before entering " .. whereLabel .. " if your race is KOS.")
        end
    end
    -- Do not start movement while an AA/spell cast is still resolving.
    waitUntilMs(8000, function() return not mq.TLO.Me.Casting() end)
    mq.delay(300)
end

--- After preflight: movement speed only (SoW/Selo/totem). Invis is deferred to `pppokerEnsureInvisForCityEntry` on city entry.
local function ensureAStoneStyleTravelBuffs()
    info("PPPoker: ensuring movement speed (AStone-style)...")
    local movOk, movDetail = pppokerEnsureMovementBuff()
    if movOk then
        info("PPPoker: movement speed OK (" .. tostring(movDetail or "?") .. ").")
    else
        warn("PPPoker: could not apply movement buff — use SoW/Selo or Worn Totem manually.")
    end
end

local function preflight()
    info("Version " .. PP.VERSION .. " starting preflight checks...")

    if not isNavLoaded() then
        fail("Preflight failed: MQ2Nav plugin not loaded (required for /nav).")
    end

    info("Speed helpers (optional, but faster runs):")

    -- Mount: we prefer mount keyring slot 1, but can fall back to legacy Ammo mount.
    local mName = mountKeyringSlot1Name and mountKeyringSlot1Name() or nil
    if mName then
        info('- Mount keyring slot ' .. PP.MOUNT_KEYRING_SLOT .. ': ' .. mName .. ' (will use)')
    else
        warn('- Mount keyring slot ' .. PP.MOUNT_KEYRING_SLOT .. ': not found (mounting disabled until slot is set)')
    end

    if hasItem("Guise of the Deceiver") then
        info("- Guise of the Deceiver: found (used for shrink if you're tall)")
    else
        warn("- Guise of the Deceiver: not found (shrink step may be slower/harder)")
    end

    local zs = pppokerZueria.refreshReadiness()
    pcall(function()
        gui.zueriaSlideInfo = zs.summary or ""
    end)
    if not zs.hasItem or not zs.levelOk then
        warn("- " .. zs.summary)
    else
        info("- " .. zs.summary)
    end

    -- Gate sanity: not required, but warns if neither option is likely to work.
    if hasGateAA() then
        if boundToGateZone() then
            info("- Gate AA: detected and bound to zone " .. PP.GATE_ZONE_ID .. " (fast return)")
        else
            warn("- Gate AA: detected but NOT bound to zone " .. PP.GATE_ZONE_ID .. " (may not help these steps)")
        end
    else
        warn("- Gate AA: not detected (gate steps rely on potion/other travel)")
    end

    if hasGatePotion() then
        info('- Gate potion: found (' .. PP.GATE_POTION_NAME .. ')')
    else
        warn('- Gate potion: not found (' .. PP.GATE_POTION_NAME .. ')')
    end

    if boundToGateZone() then
        info("- PoK bind (zone " .. PP.GATE_ZONE_ID .. "): OK — Gate/potion can return to hub")
    else
        warn("- PoK bind: missing — will travel to Plane of Knowledge and bind at Soulbinder Jera before quest start")
    end

    info("Travel buffs (AStone / Warportal patterns):")
    reportTravelBuffsPreflight()

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
        return mq.parse(string.format('${Mount[%d].Name}', PP.MOUNT_KEYRING_SLOT))
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
        info('Mounting (keyring slot ' .. PP.MOUNT_KEYRING_SLOT .. '): ' .. mountName)
        -- Use macro-style expansion too (matches your working snippet).
        mq.cmd('/useitem ${Mount[' .. tostring(PP.MOUNT_KEYRING_SLOT) .. ']}')
        return true
    end

    warn('Mount keyring slot ' .. PP.MOUNT_KEYRING_SLOT .. ' not found; skipping mount (keyring-only mode)')
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
        if stopRequested then
            mq.cmd('/squelch /travelto stop')
            mq.cmd('/squelch /nav stop')
            mq.cmd('/popup "PPPoker stopped by user"')
            unpauseRGMercs()
            unpauseCWTNPlugins()
            error("Stopped by user")
        end
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
    timeout_ms = timeout_ms or 8000
    local start = os.time()
    while (os.time() - start) * 1000 <= timeout_ms do
        for _, name in ipairs(names) do
            if name and name ~= "" then
                mq.cmdf('/target "%s"', name)
                mq.delay(300)
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

--- Wait for an NPC to actually be in keyword / interaction range (prevents early target while nav is still “settling”).
local function waitForNPCToBeWithinDistance(names, maxDist, timeoutMs)
    maxDist = maxDist or 25
    timeoutMs = timeoutMs or 15000
    return waitUntilMs(timeoutMs, function()
        for _, name in ipairs(names or {}) do
            if name and name ~= "" then
                local spawn = mq.TLO.Spawn(name)
                if spawn and spawn() then
                    local dist = spawn.Distance() or 9999
                    if dist <= maxDist then return true end
                end
            end
        end
        return false
    end)
end

--- MQ2Nav exposes `Navigation.Active` on current builds; older samples used `Nav` — missing Nav throws and aborts pcall(runQuest).
--- Active may be bool, number, or string ("TRUE"/"FALSE"); Lua's v ~= "false" misses "FALSE" and wrongly keeps waiting forever.
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
            -- Unknown wording: do not block the run (treat as not navigating).
            return false
        end
        -- userdata/table from some builds: never treat as "still navigating" (avoids infinite moving()).
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
        -- Critical: when BOTH Navigation and Nav exist, ${Navigation.Active} can be false while Nav.Active
        -- stays true — old logic OR'd them and moving() never finished until timeout (no /target reached).
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

local function navStopQuiet()
    pcall(function() mq.cmd("/squelch /nav stop") end)
end

--- Legacy Poker.lua pattern: `/nav locyxz` then wait for Nav to finish — no distance math or retries.
local function navToBigSlickWaypoint()
    mq.cmdf("/squelch /nav locyxz %.1f %.1f %.1f", unpack(PP.SLICK_QUEST_LOC))
    moving()
    -- Nav.Active detection can be flaky; keep a short buffer so we're actually in keyword range.
    mq.delay(3000)
end

moving = function(timeout_ms)
    timeout_ms = timeout_ms or 120000
    -- MQ2Nav often reports Active=false for a few hundred ms after /nav; old code skipped the while-loop and never waited.
    mq.delay(400)
    local armUntil = os.time() + 3
    while not navigationIsActive() and os.time() < armUntil do
        mq.delay(50)
    end
    -- If Navigation reports "inactive" immediately (some builds), still wait a bit before we continue.
    if not navigationIsActive() then
        mq.delay(2500)
    end
    local start = os.time()
    while navigationIsActive() do
        mq.delay(100)
        if (os.time() - start) * 1000 > timeout_ms then
            -- Some routes complete a moment after timeout; give Nav a short grace window.
            warn("Navigation timeout threshold reached; waiting grace period...")
            mq.delay(5000)
            if navigationIsActive() then
                warn("Navigation.Active still set after grace (common after 'Reached destination'). Issuing /nav stop and continuing.")
                navStopQuiet()
                mq.delay(1200)
            end
            if navigationIsActive() then
                warn("Navigation still reports active after /nav stop — continuing run anyway.")
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
        info("PoK bind OK (zone " .. PP.GATE_ZONE_ID .. ").")
        return
    end

    warn("No PoK bind; travelling to Plane of Knowledge to bind with Soulbinder Jera...")
    if mq.TLO.Zone.ID() ~= PP.GATE_ZONE_ID then
        mq.cmd('/squelch /travelto ' .. PP.POK_TRAVEL_SHORTNAME)
        zoning(PP.GATE_ZONE_ID)
    end
    mq.delay(1000)
    mq.cmdf("/squelch /nav locyxz %.1f %.1f %.1f", unpack(PP.POK_SOULBINDER_LOC))
    moving()
    mq.delay(1000)
    targetOrFail(PP.NPC.SOULBINDER_JERA, "Could not target Soulbinder Jera for PoK bind")
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
        if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == PP.GATE_ZONE_ID then
            dismountIfMounted("Gate AA")
            mq.delay(400)
            mq.cmd('/alt act ' .. tostring(PP.GATE_ALT_ACT_ID))
            mq.delay(10000)
            if wait_for_zone_soft(PP.GATE_ZONE_ID, 40000) then
                zoning(PP.GATE_ZONE_ID)
                return true
            end
        end
    end
    return false
end

local function gateToPokIfAvailable()
    if not hasGateAA() then return false, "no_aa" end
    if not boundToGateZone() then return false, "not_bound" end
    if not mq.TLO.Me.AltAbilityReady('Gate')() then return false, "not_ready" end
    dismountIfMounted("Gate AA to PoK hub")
    mq.delay(500)
    warn("Fallback: using Gate AA to return to PoK hub for travel reset...")
    mq.cmd('/alt act ' .. tostring(PP.GATE_ALT_ACT_ID))
    mq.delay(10000)
    if waitForZoneOrFalse(PP.GATE_ZONE_ID, 60000) then
        return true
    end
    return false, "zoning_timeout"
end

local function try_gate_potion(max_attempts)
    if not mq.TLO.FindItem(PP.GATE_POTION_NAME)() then
        return false
    end
    for _ = 1, max_attempts do
        if mq.TLO.Me.ZoneBound.ID() == PP.GATE_ZONE_ID then
            mq.cmd('/useitem "' .. PP.GATE_POTION_NAME .. '"')
            mq.delay(12000)
            if wait_for_zone_soft(PP.GATE_ZONE_ID, 45000) then
                zoning(PP.GATE_ZONE_ID)
                return true
            end
        end
    end
    return false
end

--- When bound to PoK: try Gate AA then gate potion (quest legs: Neriak Commons end, Highpass Tiger, South Qeynos).
local function pppokerGateOrPotionToPok(maxAttempts)
    maxAttempts = maxAttempts or 3
    if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == PP.GATE_ZONE_ID then
        if not try_gate_code(maxAttempts) then
            fail("Gate code failed after " .. tostring(maxAttempts) .. " attempts")
        end
    end
    if mq.TLO.FindItem(PP.GATE_POTION_NAME)() and mq.TLO.Me.ZoneBound.ID() == PP.GATE_ZONE_ID then
        if not try_gate_potion(maxAttempts) then
            fail("Gate potion failed after " .. tostring(maxAttempts) .. " attempts")
        end
    end
    mq.delay(1000)
end

--- If task is past Commons (stage 5+) but character is still in Neriak (40/41), Gate or /travelto PoK. Used from any skipped stage — not only "Neriak resume."
local function leaveNeriakTowardHubIfNeeded()
    -- First incomplete row can point at Highpass while Slug/Commons rows are still open — do not hub-hop.
    if hasIncompleteWorkForRouteStage(3) or hasIncompleteWorkForRouteStage(4) then
        return
    end
    local need, qc = computeResumeStageQuiet()
    if qc or need < 5 then return end
    local z = mq.TLO.Zone.ID()
    if z ~= 40 and z ~= 41 then return end
    info("Task ahead of Neriak Commons — leaving Neriak (Gate or PoK) for next zone.")
    dismountIfMounted("Leaving Neriak for hub travel")
    if try_gate_code(2) then return end
    if try_gate_potion(2) then return end
    mq.cmd('/squelch /travelto poknowledge')
    if not waitForZoneOrFalse(PP.GATE_ZONE_ID, 180000) then
        warn("Could not reach PoK from Neriak; you may need to travel manually toward Highpass route.")
    end
end

stopRequested = false
local gui = {
    open = true,
    running = false,
    status = "Idle",
    stage = 1,
    --- True while a run is in progress and the Paintings task is not visible to MQ yet (no journal / not parsed).
    expectingQuestFromRun = false,
    --- Filled from getPokerTaskProgress() (EQ journal); refreshed each setGuiStage and each GUI frame.
    questDone = 0,
    questTotal = 0,
    questActiveInstr = nil,
    questActiveZone = nil,
    questVerified = false,
    --- Longer quest/script context for the Info panel (Status stays short).
    infoDynamic = "",
    --- Last Zueria Slide summary (`PP.ZUERIA.readiness.summary`; set after preflight / slide step).
    zueriaSlideInfo = "",
    debugOpen = false,
    --- Newest-first lines for the Debug panel (ring buffer).
    debugLines = {},
}

--- Append a timestamped line to the in-window Debug log (verbose resume / journal detail).
pppokerGuiDebug = function(msg)
    local line = string.format("%s  %s", os.date("%H:%M:%S"), tostring(msg))
    table.insert(gui.debugLines, 1, line)
    while #gui.debugLines > 80 do
        table.remove(gui.debugLines)
    end
end

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

local function refreshGuiQuestProgress()
    local ok, p = pcall(getPokerTaskProgress)
    if ok and p then
        gui.questDone = tonumber(p.done) or 0
        gui.questTotal = tonumber(p.total) or 0
        gui.questActiveInstr = p.activeInstr
        gui.questActiveZone = p.activeZone
        gui.questVerified = (gui.questTotal or 0) > 0
        if (gui.questTotal or 0) > 0 or p.taskIndex then
            gui.expectingQuestFromRun = false
        end
        local zs = PP.ZUERIA.readiness
        if zs and zs.summary and tostring(zs.summary) ~= "" then
            gui.zueriaSlideInfo = tostring(zs.summary)
        end
        return p
    end
    gui.questVerified = false
    local zs2 = PP.ZUERIA.readiness
    if zs2 and zs2.summary and tostring(zs2.summary) ~= "" then
        gui.zueriaSlideInfo = tostring(zs2.summary)
    end
    return nil
end

--- Current 1-based step index from EQ journal (next incomplete), or total when all complete.
local function eqJournalStepIndex(done, total)
    local d, t = tonumber(done) or 0, tonumber(total) or 0
    if t <= 0 then return nil, nil, false end
    if d >= t then
        return t, t, true
    end
    return math.min(d + 1, t), t, false
end

--- stage = internal route block 1–8 (skip logic). Status stays one short line; detail → gui.infoDynamic.
local function setGuiStage(stage, statusDetail)
    gui.stage = tonumber(stage) or 1
    refreshGuiQuestProgress()
    local cur, tot, complete = eqJournalStepIndex(gui.questDone, gui.questTotal)
    local detail = ""
    if statusDetail and statusDetail ~= "" then
        detail = tostring(statusDetail):gsub("^%s+", ""):gsub("%s+$", "")
    end
    local lines = {}
    if detail ~= "" then
        lines[#lines + 1] = detail
    end
    if gui.questActiveZone and tostring(gui.questActiveZone) ~= "" then
        lines[#lines + 1] = "Zone: " .. tostring(gui.questActiveZone)
    end
    if gui.questActiveInstr and tostring(gui.questActiveInstr) ~= "" then
        lines[#lines + 1] = "Instruction: " .. tostring(gui.questActiveInstr)
    end
    gui.infoDynamic = table.concat(lines, "\n")
    if tot and tot > 0 then
        if complete then
            gui.status = string.format("Complete %d/%d", gui.questDone, tot)
        else
            gui.status = string.format("Step %d/%d", cur, tot)
        end
    else
        if gui.expectingQuestFromRun then
            gui.status = "Getting quest…"
            if gui.infoDynamic == "" then
                gui.infoDynamic =
                    "West Freeport — hail Big Slick; accept the task. It may take a moment to show in MQ's task list."
            end
        else
            gui.status = string.format("Route %d/8", gui.stage)
            if gui.infoDynamic == "" then
                gui.infoDynamic = "No Paintings task visible to MQ yet — keep Active Tasks / Quest Journal open."
            end
        end
    end
end

--- After nav to Tassel loc, EQ may lag before ${Task[].Objective[1]} shows complete — do not /travelto east until TLO says Tassel row is done.
--- Must be defined after setGuiStage (Lua local is not visible above its declaration).
local function waitUntilTasselObjectiveCredited(timeoutMs)
    timeoutMs = timeoutMs or 120000
    if not getActivePokerTaskIndex() then
        info("No Paintings task in Task TLO — continuing without Tassel wait (same as classic linear run).")
        return true
    end
    if not hasIncompleteTasselTavernObjective() then
        pppokerGuiDebug("Tassel row already complete — no wait before East.")
        return true
    end
    setGuiStage(2, "Waiting: EQ journal to credit Tassel painting (Task TLO)")
    info("At Tassel waypoint — waiting for Task TLO to show Tassel objective complete before East Freeport.")
    local start = mq.gettime()
    local lastEcho = start
    while (mq.gettime() - start) < timeoutMs do
        if stopRequested then
            return false
        end
        if not hasIncompleteTasselTavernObjective() then
            info("Tassel objective credited in Task TLO — proceeding to East Freeport.")
            return true
        end
        if (mq.gettime() - lastEcho) >= 15000 then
            lastEcho = mq.gettime()
            info(string.format(
                "Still waiting on Tassel update (~%ds) — stay on/near the painting until the journal line completes.",
                math.floor((mq.gettime() - start) / 1000)
            ))
        end
        mq.delay(400)
    end
    warn("Tassel still incomplete in Task TLO after wait — not issuing /travelto freeporteast. Re-run or stand at painting until it credits.")
    mq.cmd('/popup "PPPoker: Tassel not credited — stay at painting, then Run again."')
    setGuiStage(2, "Blocked — Tassel not credited (Task TLO)")
    return false
end

--- 15-step Paintings Playing Poker stream (one table of functions keeps chunk locals down).
local QuestSteps = {}
local TASK_PIPELINE

local function taskBlockNeededForPipeline(stageNum)
    local needs, needAt, qc = taskNeedsStageBlockOrEarlier(stageNum)
    if stageNum == 2 then
        needs = needs or hasIncompleteTasselTavernObjective()
    end
    return needs, needAt, qc
end

function QuestSteps.t01_west_slick_quest()
    if mq.TLO.Zone.ID() ~= 383 then
        mq.cmd('/squelch /travelto freeportwest')
        zoning(383)
    end
    mq.delay(1000)
    navToBigSlickWaypoint()
    mq.delay(500)
    local slickOk = waitForNPCToBeWithinDistance(PP.NPC.BIG_SLICK_JONES, 25, 12000)
    if not slickOk then
        pppokerGuiDebug("Slick not in range yet — re-naving to keyword pocket.")
        navToBigSlickWaypoint()
        mq.delay(1000)
        slickOk = waitForNPCToBeWithinDistance(PP.NPC.BIG_SLICK_JONES, 25, 12000)
    end
    if not slickOk then
        fail("Big Slick Jones not within hail range after nav — move closer, then re-run.")
    end
    dismountIfMounted("Targeting Big Slick Jones (quest)")
    mq.delay(400)
    targetOrFail(PP.NPC.BIG_SLICK_JONES, "Could not target Big Slick Jones", 15000)
    mq.delay(1000)
    mq.cmd('/face fast')
    if not getActivePokerTaskIndex() then
        mq.cmd('/say paintings')
    else
        info("Poker task already active; skipping new task request phrase.")
    end
    mq.delay(2000)
    mq.cmd('/target ${Me.Name}')
    mq.delay(1000)
    if mq.TLO.Me.Height() > 2.50 then
        mq.cmd('/useitem Guise of the Deceiver')
        mq.delay(8500)
        mq.cmd('/popup You are a bit tall, lets shrink a little to make it easier')
    end
    mq.delay(500)
    if not getActivePokerTaskIndex() then
        info("PPPoker: MQ task not visible yet after Slick — continuing bar route (same as classic Poker.lua).")
    end
    gui.expectingQuestFromRun = false
end

function QuestSteps.t02_stage2_popup_and_invis()
    mq.cmd('/popup Lets start our Bar Run!')
    pppokerEnsureInvisForCityEntry("West Freeport to East Freeport bar leg")
end

function QuestSteps.t03_tassel_waypoint_and_wait()
    runTasselsPaintingWaypoint()
    if not waitUntilTasselObjectiveCredited(120000) then
        return false
    end
end

function QuestSteps.t04_travel_east_freeport()
    if mq.TLO.Zone.ID() ~= 382 then
        info("Issuing /travelto freeporteast (East Freeport — Grub & Grog / Betty).")
        mq.cmd('/squelch /travelto freeporteast')
        zoning(382)
        mq.delay(1000)
    end
end

function QuestSteps.t05_east_fp_betty_grog_slide()
    local bettyDist = PP.EAST_FP_BETTY_HAIL_MAX_DIST or 45
    local function navBettyPocketAndSettle()
        mq.cmdf("/squelch /nav locyxz %.1f %.1f %.1f", unpack(PP.EAST_FP_BETTY_POCKET_LOC))
        moving()
        -- Spawns / Distance TLO can lag right when Nav reports destination; same buffer idea as Slick pocket.
        mq.delay(3000)
    end
    navBettyPocketAndSettle()
    local bettyInRange = waitForNPCToBeWithinDistance(PP.NPC.BLUFFING_BETTY, bettyDist, 12000)
    if not bettyInRange then
        pppokerGuiDebug("Betty not in range yet — re-naving to tavern pocket.")
        navBettyPocketAndSettle()
        bettyInRange = waitForNPCToBeWithinDistance(PP.NPC.BLUFFING_BETTY, bettyDist, 20000)
    end
    if not bettyInRange and targetByNames(PP.NPC.BLUFFING_BETTY, 8000) then
        pppokerGuiDebug("Betty targetable but past pocket threshold — /nav target to close gap.")
        mq.cmd("/squelch /nav target")
        moving()
        mq.delay(2000)
        bettyInRange = waitForNPCToBeWithinDistance(PP.NPC.BLUFFING_BETTY, bettyDist, 15000)
    end
    if not bettyInRange then
        fail("Bluffing Betty not within hail range after nav — move closer or clear path, then re-run.")
    end
    info("Betty in range — target and hail.")
    targetOrFail(PP.NPC.BLUFFING_BETTY, "Could not target Bluffing Betty")
    mq.delay(1000)
    mq.cmd('/face fast')
    mq.cmd('/keypress hail')
    mq.delay(2000)
    mq.cmd('/autoinv')
    mq.delay(1000)
    mq.cmd('/autoinv')
    mq.cmd('/target ${Me.Name}')
    while mq.TLO.FindItem("Memento Grog")() do
        mq.cmd('/useitem Memento Grog')
        mq.delay(1000)
        mq.cmd('/useitem Memento Grog')
        mq.delay(1000)
    end
    pppokerZueria.runAfterMementoGrog()
    mq.delay(1000)
end

function QuestSteps.t06_neriak_mount_and_pok()
    mq.delay(1000)
    -- Gate AA often does not fire while mounted; try PoK hop dismounted first, then mount for hub run.
    if mq.TLO.Zone.ID() ~= PP.GATE_ZONE_ID then
        local gated, gateWhy = gateToPokIfAvailable()
        if gated then
            info("Neriak route: gated to PoK hub first.")
        else
            if gateWhy == "no_aa" then
                warn("Neriak route: no Gate AA — /travelto PoK.")
            elseif gateWhy == "not_bound" then
                warn(string.format(
                    "Neriak route: Gate not bound to PoK (ZoneBound ID %s, need %s) — /travelto PoK.",
                    tostring(mq.TLO.Me.ZoneBound.ID()),
                    tostring(PP.GATE_ZONE_ID)
                ))
            elseif gateWhy == "not_ready" then
                warn("Neriak route: Gate on cooldown or not ready — /travelto PoK.")
            else
                warn("Neriak route: Gate cast did not land in PoK in time — /travelto PoK.")
            end
            mq.cmd('/squelch /travelto poknowledge')
            if not waitForZoneOrFalse(PP.GATE_ZONE_ID, 180000) then
                fail("Failed to reach PoK hub before Neriak route.")
            end
        end
    end
    mountIfNeeded()
    mq.delay(2000)
end

function QuestSteps.t07_neriak_zone_from_pok()
    pppokerEnsureInvisForCityEntry("Neriak Foreign Quarter")
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
end

function QuestSteps.t08_neriak_foreign_bull_slug()
    mq.delay(1000)
    info("Neriak Foreign: brief settle so Task TLO matches journal after zoning.")
    mq.delay(2000)
    local doneBeforeNeriakA = getPokerDoneCount()
    -- Same sequence as Poker2.lua (no extra sweep tiles; no branching on done count between stops).
    info("Neriak Foreign: Bull Pit — /nav locyx -352 -207")
    mq.cmd('/squelch /nav locyx -352 -207')
    moving()
    mq.delay(1500)
    info("Neriak Foreign: Slug's Tavern — /nav locyx 204 -243 3")
    mq.cmd('/squelch /nav locyx 204 -243 3')
    moving()
    mq.delay(1500)
    local doneAfterNeriakA = getPokerDoneCount()
    if doneAfterNeriakA <= doneBeforeNeriakA then
        warn("Neriak Foreign: journal unchanged after Bull + Slug — stand on marks if needed, then re-run.")
    end
    local needResume = select(1, computeResumeStageQuiet())
    if needResume >= 5 and not hasIncompleteWorkForRouteStage(3) and not hasIncompleteWorkForRouteStage(4) then
        leaveNeriakTowardHubIfNeeded()
    end
end

function QuestSteps.t09_neriak_commons()
    -- Order: travel + wait for zone 41 **before** done snapshot / painting nav (Poker2 `travelto` then `delay(1000)` then navs).
    if mq.TLO.Zone.ID() ~= 41 then
        pppokerEnsureInvisForCityEntry("Neriak Commons")
        info("Travel to Neriak Commons (EasyFind may chain zones — up to ~6 min).")
        mq.cmd('/squelch /travelto neriakb')
        zoning(41, PP.ZONING_TIMEOUT_NERIAK_COMMONS_MS)
    end
    local doneBeforeCommons = getPokerDoneCount()
    mq.delay(1000)
    -- Poker2.lua (lines 122–131): nav / delays only.
    mq.cmd('/squelch /nav locyxz 12 -850 -52')
    moving()
    mq.delay(1500)
    mq.cmd('/squelch /nav locyxz -148 -994 -26')
    moving()
    mq.delay(1000)
    local doneAfterCommons = getPokerDoneCount()
    if doneAfterCommons <= doneBeforeCommons then
        warn("Neriak Commons: journal unchanged after painting waypoints — stand on marks if needed, then re-run.")
    end
    local needResume = select(1, computeResumeStageQuiet())
    if needResume >= 5 and not hasIncompleteWorkForRouteStage(3) and not hasIncompleteWorkForRouteStage(4) then
        leaveNeriakTowardHubIfNeeded()
    end
    mq.cmd('/face heading 315')
    mq.delay(1200)
    pppokerGateOrPotionToPok(3)
end

function QuestSteps.t10_highpass_quinn()
    pppokerEnsureInvisForCityEntry("Highpass Hold (travel via Rathe Moors)")
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
    mq.cmd('/squelch /nav locyxz 454 -620 22')
    moving()
    mq.delay(1000)
    dismountIfMounted("Hailing Quinn of Quads")
    mq.delay(1500)
    targetOrFail(PP.NPC.QUINN_OF_QUADS, "Could not target Quinn of Quads")
    mq.delay(1000)
    mq.cmd('/keypress hail')
    mq.delay(1500)
    mq.cmd('/target ${Me.Name}')
end

function QuestSteps.t11_highpass_mhrai_tiger_gate()
    mq.cmd('/squelch /nav locyxz -442 -215 -12')
    moving()
    mq.delay(1000)
    mq.cmd('/squelch /nav locyxz -426 -263 -12')
    moving()
    mq.delay(1000)
    mq.cmd('/nav locyxz -408 -267 -12')
    moving()
    mq.delay(1000)
    targetOrFail(PP.NPC.MHRAI_QUEEN_OF_TAILS, "Could not target Mhrai, Queen of Tails")
    mq.delay(1000)
    mq.cmd('/keypress hail')
    mq.delay(1500)
    mq.cmd('/target ${Me.Name}')
    mq.cmd('/nav locyxz -125 540 -13')
    moving()
    mq.delay(1000)
    pppokerGateOrPotionToPok(3)
end

function QuestSteps.t12_north_qeynos()
    pppokerEnsureInvisForCityEntry("North Qeynos")
    mq.delay(1000)
    if mq.TLO.Zone.ID() ~= 2 then
        mq.cmd('/travelto qeynos2')
        zoning(2)
    end
    mq.delay(1000)
    mq.cmd('/nav locyxz 118 335 1')
    moving()
    mq.delay(1500)
end

function QuestSteps.t13_south_qeynos()
    pppokerEnsureInvisForCityEntry("South Qeynos")
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
    pppokerGateOrPotionToPok(3)
end

function QuestSteps.t14_return_slick_verify()
    if mq.TLO.Zone.ID() ~= 383 then
        mq.cmd('/travelto freeportwest')
        zoning(383)
        mq.delay(1000)
    end
    navToBigSlickWaypoint()
    mq.delay(500)
    local slickOk = waitForNPCToBeWithinDistance(PP.NPC.BIG_SLICK_JONES, 25, 12000)
    if not slickOk then
        pppokerGuiDebug("Slick not in range yet — re-naving to keyword pocket (reward).")
        navToBigSlickWaypoint()
        mq.delay(1000)
        slickOk = waitForNPCToBeWithinDistance(PP.NPC.BIG_SLICK_JONES, 25, 12000)
    end
    if not slickOk then
        fail("Big Slick Jones not within hail range (reward) — move closer, then re-run.")
    end
    dismountIfMounted("Turning in / hailing Big Slick Jones")
    mq.delay(400)
    if hasIncompleteTasselTavernObjective() then
        warn("PPPoker: Task still shows Tassel's Tavern incomplete — visiting West painting before final hail.")
        runTasselsPaintingWaypoint()
        mq.delay(2000)
        if hasIncompleteTasselTavernObjective() then
            setGuiStage(8, "Blocked — finish Tassel's Tavern (West painting)")
            warn("PPPoker: Tassel's Tavern still incomplete after waypoint. Stand at painting or verify journal, then re-run.")
            mq.cmd('/popup "PPPoker: Complete Tassel\'s Tavern in West Freeport (painting), then run again."')
            unpauseRGMercs()
            unpauseCWTNPlugins()
            return false
        end
    end
    local okPre8, pre8 = pcall(function() return getPokerTaskProgress() end)
    if okPre8 and pre8 and pre8.total and pre8.total > 0 and pre8.done < pre8.total then
        local miss8 = firstIncompleteObjectiveText() or "unknown"
        setGuiStage(8, "Blocked — journal not complete before Slick")
        warn("PPPoker: Not all objectives complete before Slick hail (" .. tostring(pre8.done) .. "/" .. tostring(pre8.total) .. "): " .. miss8)
        mq.cmd('/popup "PPPoker: Task not complete — check journal before hailing Big Slick."')
        unpauseRGMercs()
        unpauseCWTNPlugins()
        return false
    end
end

function QuestSteps.t15_return_slick_hail()
    targetOrFail(PP.NPC.BIG_SLICK_JONES, "Could not target Big Slick Jones (reward)", 15000)
    mq.delay(1000)
    mq.cmd('/face fast')
    mq.cmd('/keypress hail')
    mq.delay(1000)
end

--- Order matters. `need` optional: nil = run whenever the route block runs. `onWhenBlockSkipped` only on first row of that stage.
TASK_PIPELINE = {
    { stage = 1, key = "t01", label = "West Freeport — Big Slick / accept task", run = QuestSteps.t01_west_slick_quest },
    { stage = 2, key = "t02", label = "Stage 2 — invis (West → East bar leg)", run = QuestSteps.t02_stage2_popup_and_invis },
    {
        stage = 2,
        key = "t03",
        label = "Stage 2 — Tassel's Tavern (painting + Task TLO wait)",
        need = hasIncompleteTasselTavernObjective,
        run = QuestSteps.t03_tassel_waypoint_and_wait,
    },
    {
        stage = 2,
        key = "t04",
        label = "Stage 2 — travel to East Freeport",
        need = function()
            if hasIncompleteTasselTavernObjective() then return false end
            if not hasIncompleteStage2Objective() then return false end
            return mq.TLO.Zone.ID() ~= 382
        end,
        run = QuestSteps.t04_travel_east_freeport,
    },
    {
        stage = 2,
        key = "t05",
        label = "Stage 2 — Crab & Grog / Betty / grog / Zueria Slide",
        need = function()
            if hasIncompleteTasselTavernObjective() then return false end
            if not hasIncompleteStage2Objective() then return false end
            local needMid2 = select(1, computeResumeStageQuiet())
            local stillEast = hasIncompleteStage2Objective()
            if needMid2 > 2 and not stillEast then
                info(string.format(
                    "Skipping Crab & Grog / Bluffing Betty / slide: resume stage %s and no incomplete East Freeport rows in tracker.",
                    tostring(needMid2)
                ))
                return false
            end
            return (needMid2 <= 2 or stillEast)
        end,
        run = QuestSteps.t05_east_fp_betty_grog_slide,
    },
    { stage = 3, key = "t06", label = "Stage 3 — mount + PoK hub (pre-Neriak)", run = QuestSteps.t06_neriak_mount_and_pok, onWhenBlockSkipped = leaveNeriakTowardHubIfNeeded },
    { stage = 3, key = "t07", label = "Stage 3 — invis + travel to Neriak Foreign", run = QuestSteps.t07_neriak_zone_from_pok },
    { stage = 3, key = "t08", label = "Stage 3 — Bull Pit / Slug / sweep", run = QuestSteps.t08_neriak_foreign_bull_slug },
    { stage = 4, key = "t09", label = "Stage 4 — Neriak Commons (Blind Fish / Toadstool)", run = QuestSteps.t09_neriak_commons, onWhenBlockSkipped = leaveNeriakTowardHubIfNeeded },
    { stage = 5, key = "t10", label = "Stage 5 — Highpass (travel + Quinn)", run = QuestSteps.t10_highpass_quinn },
    { stage = 5, key = "t11", label = "Stage 5 — Highpass (Mhrai / Tiger / gate)", run = QuestSteps.t11_highpass_mhrai_tiger_gate },
    { stage = 6, key = "t12", label = "Stage 6 — North Qeynos", run = QuestSteps.t12_north_qeynos },
    { stage = 7, key = "t13", label = "Stage 7 — South Qeynos", run = QuestSteps.t13_south_qeynos },
    { stage = 8, key = "t14", label = "Stage 8 — return West / verify journal", run = QuestSteps.t14_return_slick_verify },
    { stage = 8, key = "t15", label = "Stage 8 — hail Big Slick (reward)", run = QuestSteps.t15_return_slick_hail },
}

PP.QUEST_TASK_PIPELINE = TASK_PIPELINE
PP.QuestSteps = QuestSteps

--- Always iterate every pipeline row; block entry uses journal scan (any row for that stage), not startStage, so Neriak/Highpass are not skipped when the first incomplete line points at Qeynos.
local function runTaskPipeline(_startStage)
    local skipLogged = {}
    for _, step in ipairs(TASK_PIPELINE) do
        local needs, needAt, _qc = taskBlockNeededForPipeline(step.stage)
        if not needs then
            if not skipLogged[step.stage] then
                skipLogged[step.stage] = true
                setGuiStage(needAt or step.stage, string.format("Skipped — route ahead of block %d (~%s)", step.stage, tostring(needAt)))
                if step.onWhenBlockSkipped then step.onWhenBlockSkipped() end
                info(string.format("Skipping route block %d: task ahead (~stage %s).", step.stage, tostring(needAt)))
            end
        else
            local subOk = (step.need == nil) or step.need()
            if subOk then
                setGuiStage(step.stage, string.format("%s [%s]", step.label, step.key))
                shouldStop()
                if gui.debugOpen then
                    pppokerGuiDebug(string.format("Task step: %s", step.key))
                end
                local r = step.run()
                if r == false then
                    return false
                end
            end
        end
    end
    return true
end

local function runQuest()
--Start
mq.cmd('/beep')
-- Delay to stop/pause before repeat.
-- /lua stop poker or /lua pause poker
--mq.delay(30000)
mq.cmd('/popup Starting: Paintings Playing Poker 23rd Anniversary Quest')
local start_time = os.time()
local coinsBefore = getCommemorativeCount()
mq.cmd('/removelev')
--pause CWTN so plugins don't interfere with the quest run
pauseCWTNPlugins()
pauseRGMercs()
-- Keyring-only mount mode: uses ${Mount[1]} via mountIfNeeded().
-- mountIfNeeded() can be used here, but was intentionally left disabled.
preflight()
ensurePokBind()
ensureAStoneStyleTravelBuffs()

-- Brief delay: Task TLO can read 0 until the quest tracker is populated this session.
mq.delay(250)

-- ========== New quest brain (objective-driven, memory Task TLO) ==========
local function qbDbg(msg)
    local s = tostring(msg or "")
    -- Always print; also feed GUI debug panel when enabled.
    info(s)
    if type(pppokerGuiDebug) == "function" then
        pppokerGuiDebug(s)
    end
end

local function qbGetTask()
    local ok, t = pcall(function() return mq.TLO.Task(PP.QUEST_TITLE) end)
    if ok and t and t() then return t end
    return nil
end

local function qbGetObjective(task, idx)
    if not task or not task() then return nil end
    local ok, obj = pcall(function() return task.Objective(idx) end)
    if not ok or not obj or not obj() then return nil end
    return obj
end

local function qbIsDone(obj)
    if not obj or not obj() then return false end
    local ok, v = pcall(function() return obj.Done() end)
    return ok and v == true
end

local function qbObjectiveText(obj)
    if not obj or not obj() then return "" end
    local ok, s = pcall(function() return obj.Instruction() end)
    if not ok or not s then return "" end
    return tostring(s)
end

local function qbFindFirstIncomplete(task, maxObjectives)
    maxObjectives = maxObjectives or 30
    for i = 1, maxObjectives do
        local obj = qbGetObjective(task, i)
        if obj and not qbIsDone(obj) then
            return i, obj
        end
    end
    return nil, nil
end

local function qbWaitObjectiveDone(task, idx, timeoutMs)
    timeoutMs = timeoutMs or 90000
    local t0 = mq.gettime()
    local lastEchoAt = 0
    while mq.gettime() - t0 < timeoutMs do
        shouldStop()
        local obj = qbGetObjective(task, idx)
        if obj and qbIsDone(obj) then
            return true
        end
        if mq.gettime() - lastEchoAt > 8000 then
            lastEchoAt = mq.gettime()
            local instr = qbObjectiveText(obj)
            qbDbg(string.format("Waiting: Objective %d not Done yet — %s", idx, instr))
        end
        mq.delay(250)
    end
    return false
end

local function qbEnsureZone(zoneId, travelToArg, label, timeoutMs)
    if mq.TLO.Zone.ID() == zoneId then return true end
    label = label or travelToArg or tostring(zoneId)
    qbDbg(string.format("Travel decision: not in %s (zone %d). /travelto %s", label, zoneId, tostring(travelToArg)))
    mq.cmdf('/squelch /travelto %s', travelToArg)
    if not waitForZoneOrFalse(zoneId, timeoutMs or 240000) then
        fail("Travel failed: could not zone to " .. tostring(label) .. " (zone " .. tostring(zoneId) .. ")")
    end
    return true
end

local function qbLower(s)
    return tostring(s or ""):lower()
end

local function qbClassifyByInstruction(instr)
    local t = qbLower(instr)
    if t:find("big slick", 1, true) then return "slick_return" end
    if t:find("tassel", 1, true) then return "tassel_painting" end
    if t:find("bluffing betty", 1, true) or t:find("crab", 1, true) or t:find("grub", 1, true) or t:find("grog", 1, true) then
        return "east_betty_grog"
    end
    if t:find("bull", 1, true) or t:find("svunsa", 1, true) then return "neriak_bull" end
    if t:find("slug", 1, true) or t:find("grendon", 1, true) then return "neriak_slug" end
    if t:find("blind fish", 1, true) or t:find("marenkor", 1, true) then return "commons_blind" end
    if t:find("toadstool", 1, true) or t:find("rista", 1, true) then return "commons_toad" end
    if t:find("quinn", 1, true) or (t:find("quad", 1, true) and t:find("highpass", 1, true)) then return "highpass_quinn" end
    if t:find("mhrai", 1, true) or t:find("queen of tails", 1, true) then return "highpass_mhrai" end
    if t:find("tiger", 1, true) then return "highpass_tiger" end
    if t:find("north qeynos", 1, true) or t:find("crow", 1, true) or t:find("segran", 1, true) then return "north_qeynos" end
    if t:find("fish's ale", 1, true) or t:find("fishs ale", 1, true) or t:find("bruno", 1, true) then return "south_fish" end
    if t:find("lion", 1, true) or t:find("tomas", 1, true) then return "south_lion" end
    return nil
end

local function qbRunAction(actionKey)
    if actionKey == "tassel_painting" then
        qbEnsureZone(383, "freeportwest", "West Freeport", 240000)
        qbDbg("Action: Tassel's painting waypoint")
        runTasselsPaintingWaypoint()
        return
    end

    if actionKey == "east_betty_grog" then
        qbEnsureZone(382, "freeporteast", "East Freeport", 240000)
        qbDbg("Action: Betty / grog / slide (East Freeport pocket)")
        QuestSteps.t05_east_fp_betty_grog_slide()
        return
    end

    if actionKey == "neriak_bull" or actionKey == "neriak_slug" then
        qbEnsureZone(40, "neriaka", "Neriak Foreign Quarter", 240000)
        if actionKey == "neriak_bull" then
            qbDbg("Action: Bull Pit pocket")
            mq.cmd('/squelch /nav locyx -352 -207')
            moving()
            mq.delay(1500)
        else
            qbDbg("Action: Slug's Tavern pocket")
            mq.cmd('/squelch /nav locyx 204 -243 3')
            moving()
            mq.delay(1500)
        end
        return
    end

    if actionKey == "commons_blind" or actionKey == "commons_toad" then
        qbEnsureZone(41, "neriakb", "Neriak Commons", PP.ZONING_TIMEOUT_NERIAK_COMMONS_MS or 360000)
        if actionKey == "commons_blind" then
            qbDbg("Action: Blind Fish painting pocket")
            mq.cmd('/squelch /nav locyxz 12 -850 -52')
            moving()
            mq.delay(1500)
        else
            qbDbg("Action: Toadstool painting pocket")
            mq.cmd('/squelch /nav locyxz -148 -994 -26')
            moving()
            mq.delay(1000)
        end
        return
    end

    if actionKey == "highpass_quinn" then
        qbDbg("Action: Highpass — Quinn of Quads")
        QuestSteps.t10_highpass_quinn()
        return
    end

    if actionKey == "highpass_mhrai" or actionKey == "highpass_tiger" then
        qbDbg("Action: Highpass — Mhrai/Tiger segment")
        QuestSteps.t11_highpass_mhrai_tiger_gate()
        return
    end

    if actionKey == "north_qeynos" then
        qbDbg("Action: North Qeynos pocket")
        QuestSteps.t12_north_qeynos()
        return
    end

    if actionKey == "south_fish" or actionKey == "south_lion" then
        qbDbg("Action: South Qeynos pockets")
        QuestSteps.t13_south_qeynos()
        return
    end

    if actionKey == "slick_return" then
        qbDbg("Action: Return to Big Slick Jones (reward)")
        QuestSteps.t15_return_slick_hail()
        return
    end

    fail("Quest brain: unhandled actionKey=" .. tostring(actionKey))
end

-- Main objective loop: run the first incomplete objective until all are Done.
local task = qbGetTask()
if not task then
    setGuiStage(1, "No Paintings task found — go hail Big Slick Jones")
    warn("Could not find active task via mq.TLO.Task('" .. PP.QUEST_TITLE .. "'). Make sure the task is active.")
    unpauseRGMercs()
    unpauseCWTNPlugins()
    return
end

qbDbg("Quest brain: using Task.Objective(i).Done() fixed-index resume (1..16).")
logEqQuestSnapshot("run start")

local maxObjectives = 30
local loopSafety = 0
while true do
    shouldStop()
    loopSafety = loopSafety + 1
    if loopSafety > 200 then
        fail("Quest brain safety stop: too many objective loops (possible TLO update stall).")
    end

    local idx, obj = qbFindFirstIncomplete(task, maxObjectives)
    if not idx then
        qbDbg("All objectives appear Done in Task TLO.")
        break
    end

    local instr = qbObjectiveText(obj)
    setGuiStage(1, string.format("Objective %d — %s", idx, instr))
    qbDbg(string.format("Next objective: #%d | %s", idx, instr))

    local actionKey = qbClassifyByInstruction(instr)
    if not actionKey then
        fail(string.format("Quest brain: cannot classify objective #%d instruction: %s", idx, instr))
    end

    qbRunAction(actionKey)

    qbDbg(string.format("Post-action: waiting for Objective %d to become Done...", idx))
    if not qbWaitObjectiveDone(task, idx, 120000) then
        fail(string.format("Timeout waiting for Objective %d to become Done: %s", idx, instr))
    end

    qbDbg(string.format("Objective %d is Done.", idx))
    mq.delay(500)
end

-- Completion beeps.
mq.cmd('/beep')
mq.cmd('/beep')
local coinsAfter = getCommemorativeCount()
local gained = coinsAfter - coinsBefore
gui.lastRunGainedCoins = gained
gui.lastRunCoinsAfter = coinsAfter
print("You now have... " .. tostring(getCommemorativeCount()) .. " Commemorative Coins !")
local end_time = os.time()
print("Quest Run Time... " .. end_time - start_time .. " Seconds")

local okProg, progress = pcall(function() return getPokerTaskProgress() end)
if okProg and progress and progress.total and progress.total > 0 and progress.done < progress.total then
    local miss = firstIncompleteObjectiveText() or "unknown objective"
    setGuiStage(8, "Journal still incomplete — " .. tostring(miss))
    warn("Quest NOT complete yet. Remaining objective: " .. miss)
    mq.cmd('/popup "Poker task still incomplete. Check objective in task window."')
    unpauseRGMercs()
    unpauseCWTNPlugins()
    return
end
if gained <= 0 then
    warn("No commemorative coin gain detected this run; likely no completed turn-in reward.")
end

setGuiStage(8, "Run finished — verify reward / journal")
unpauseRGMercs()
unpauseCWTNPlugins()

end -- runQuest

-- GUI: PicTest-style triptych atlas + UV (see `pictest/init.lua`); assets beside this script.
--[[ ========== Inlined horizontal progress bar (was statusbar.lua; needs ImAnim) ========== ]]
local BarColors = {
    HPMax = ImVec4(0.992, 0.138, 0.138, 1.000),
    HPMin = ImVec4(0.551, 0.207, 0.962, 1.000),
    ManaMax = ImVec4(0.124, 0.592, 0.920, 1.000),
    ManaMin = ImVec4(0.258, 0.069, 0.502, 1.000),
    EndurMin = ImVec4(0.063, 0.389, 0.117, 1.000),
    EndurMax = ImVec4(0.825, 0.727, 0.004, 1.000),
    XPMin = ImVec4(0.293, 0.416, 0.791, 1.000),
    XPMax = ImVec4(0.782, 0.905, 0.009, 1.000),
    borders = ImVec4(0.8, 0.8, 0.8, 1.0),
}

local statusBarGlobalOpts = {
    height = 15.0,
    width = 0,
    padEnd = 10.0,
    rounding = 4.0,
    showText = true,
    textFmt = "%.1f%%",
    tickEvery = 0.2,
    tickAlpha = 50,
    tickThickness = 1.0,
    shimmer = false,
    shimmerFollows = true,
    shimmerSpeed = 0.5,
    shimmerWidth = 60.0,
    shimmerDeadzone = 0.001,
    glow = true,
    tweenSeconds = 0.35,
    fillGradient = true,
    fillGradientMode = "dynamic",
    fillGradientDir = "lr",
    border = false,
    borderThickness = 2.0,
    borderColor = BarColors.borders,
    borderConColor = false,
}

local StatusBar = {}
StatusBar._state = StatusBar._state or {}

local function sbClamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function sbGetBarState(id, now)
    local state = StatusBar._state[id]
    if not state then
        state = { lastP = 0.0, dir = 1, t0 = now, }
        StatusBar._state[id] = state
    end
    return state
end

local function sbTo01(percent)
    if percent > 1.0 then
        return sbClamp01(percent / 100.0)
    end
    return sbClamp01(percent)
end

local function sbShallowCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end

function StatusBar.DrawProgress(label, percent, lowCol, highCol, opts)
    if not ImAnim then
        return 0
    end
    opts = opts or {}

    local now = mq.gettime()
    local dl = ImGui.GetWindowDrawList()
    local borderOn = (opts.border == true)
    local borderTh = opts.borderThickness or 1.0
    local borderCol = opts.borderColor or BarColors.borders
    local height = opts.height or 24.0
    local width = opts.width or 0.0
    local padEnd = opts.padEnd or 20.0
    local rounding = opts.rounding or 6.0
    local showText = (opts.showText ~= false)
    local textFmt = opts.textFmt or "%.0f%%"
    local showTicks = (opts.showTicks ~= false)
    local tickEvery = opts.tickEvery or 0.05
    local tickAlpha = opts.tickAlpha or 80
    local shimmerOn = (opts.shimmer ~= false)
    local glowOn = (opts.glow ~= false)
    local bgU32 = opts.bgU32 or IM_COL32(30, 32, 40, 255)
    local tweenSec = opts.tweenSeconds or 0.35
    local gradOn = (opts.fillGradient == true)
    local gradMode = opts.fillGradientMode or "static"
    local gradDir = opts.fillGradientDir or "lr"
    local target = sbTo01(percent)
    local id = ImGui.GetID(label)

    local progress = ImAnim.TweenFloat(
        id,
        ImHashStr(label),
        target,
        tweenSec,
        ImAnim.EasePreset(IamEaseType.OutExpo),
        IamPolicy.Crossfade,
        0
    )

    progress = sbClamp01(progress)

    local bar_pos = ImGui.GetCursorScreenPosVec()
    local avail = ImGui.GetContentRegionAvailVec()
    local bar_size = width > 0 and ImVec2(width, height) or ImVec2(avail.x - padEnd, height)
    local bar_max = ImVec2(bar_pos.x + bar_size.x, bar_pos.y + bar_size.y)

    dl:AddRectFilled(bar_pos, bar_max, bgU32, rounding)

    local function DrawTicks()
        local tickW = opts.tickThickness or 1.0
        local insetY = 3.0
        local y1 = bar_pos.y + insetY
        local y2 = bar_pos.y + bar_size.y - insetY

        local steps = math.floor(1.0 / tickEvery + 0.5)
        for i = 0, steps do
            local t = i * tickEvery
            if t > 1.00001 then break end

            local x = bar_pos.x + (bar_size.x * t)
            dl:AddRectFilled(
                ImVec2(x - tickW * 0.5, y1),
                ImVec2(x + tickW * 0.5, y2),
                IM_COL32(255, 255, 255, tickAlpha),
                0.0
            )
        end
    end

    local filled_w = bar_size.x * progress
    if filled_w > 2.0 then
        local fill_max = ImVec2(bar_pos.x + filled_w, bar_pos.y + bar_size.y)

        if gradOn then
            local colorLeft, colorRight
            if gradMode == "dynamic" then
                colorLeft = lowCol
                colorRight = ImAnim.GetBlendedColor(lowCol, highCol, progress, IamColorSpace.OKLAB)
            else
                colorLeft = lowCol
                colorRight = highCol
            end

            local colorLow = ImGui.ColorConvertFloat4ToU32(colorLeft)
            local colorHigh = ImGui.ColorConvertFloat4ToU32(colorRight)

            if gradDir == "tb" then
                dl:AddRectFilledMultiColor(
                    bar_pos, fill_max,
                    colorHigh, colorHigh,
                    colorLow, colorLow
                )
            else
                dl:AddRectFilledMultiColor(
                    bar_pos, fill_max,
                    colorLow, colorHigh, colorHigh, colorLow
                )
            end

            dl:AddRect(bar_pos, fill_max, IM_COL32(255, 255, 255, 30), rounding, ImDrawFlags.RoundCornersLeft, 1.0)
        else
            local fill_col = ImAnim.GetBlendedColor(lowCol, highCol, progress, IamColorSpace.OKLAB)
            local fill_u32 = ImGui.ColorConvertFloat4ToU32(fill_col)
            dl:AddRectFilled(bar_pos, fill_max, fill_u32, rounding, ImDrawFlags.RoundCornersLeft)
        end

        if glowOn then
            local glow_x = bar_pos.x + filled_w - 4.0
            for i = 0, 3 do
                local alpha = 0.30 * (1.0 - i * 0.25)
                local offset = i * 4.0
                local a255 = math.floor(alpha * 255 * (1.0 - i * 0.2))
                dl:AddRectFilled(
                    ImVec2(glow_x - offset, bar_pos.y),
                    ImVec2(glow_x + 4.0, bar_pos.y + bar_size.y),
                    IM_COL32(255, 255, 255, a255),
                    4.0
                )
            end
        end

        if shimmerOn then
            local shimmerFollows = (opts.shimmerFollows ~= false)
            local shimmerSpeed = opts.shimmerSpeed or 0.5
            local shimmerWidth = opts.shimmerWidth or 60.0
            local deadzone = opts.shimmerDeadzone or 0.001
            local barState = sbGetBarState(id, now)

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
                local shimmer_alpha = 0.15 * math.sin((shimmer_pos / filled_w) * math.pi)
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

    if showTicks and tickEvery > 0 then DrawTicks() end

    if showText then
        local pctText = string.format(textFmt, progress * 100.0)
        local txtSize = ImGui.CalcTextSizeVec(pctText)
        local txtPos = ImVec2(
            bar_pos.x + (bar_size.x - txtSize.x) * 0.5,
            bar_pos.y + (bar_size.y - txtSize.y) * 0.5
        )
        dl:AddText(txtPos, IM_COL32(255, 255, 255, 200), pctText)
    end

    if borderOn then
        local colU32
        if borderCol == nil then
            colU32 = IM_COL32(255, 255, 255, 120)
        elseif type(borderCol) == "number" then
            colU32 = borderCol
        else
            colU32 = ImGui.ColorConvertFloat4ToU32(borderCol)
        end
        dl:AddRect(bar_pos, bar_max, colU32, rounding, 0, borderTh)
    end

    ImGui.Dummy(ImVec2(bar_size.x, bar_size.y + 6.0))
    return progress
end

local pppokerBarApi = {
    DrawProgress = StatusBar.DrawProgress,
    Colors = BarColors,
    globalOpts = statusBarGlobalOpts,
    shallowCopy = sbShallowCopy,
}

local config = {
    requestedRun = false,
    running = false,
    autoRepeat = true,
    autoRepeatDelaySec = 12,
    nextRunAllowedAt = 0,
}

--- While idle, refresh Status from EQ journal (~1.2s throttle) so the window shows stage without pressing Run.
local lastIdleJournalMs = 0
local function updateIdleGuiFromJournal()
    if config.running then return end
    local now = mq.gettime()
    if lastIdleJournalMs > 0 and (now - lastIdleJournalMs) < 1200 then return end
    lastIdleJournalMs = now

    refreshGuiQuestProgress()
    local routeSt, qc = computeResumeStageQuiet()
    gui.stage = tonumber(routeSt) or 1

    if qc then
        gui.status = string.format("Complete %d/%d (journal).", tonumber(gui.questDone) or 0, tonumber(gui.questTotal) or 0)
        gui.infoDynamic =
            "All objectives are done in the journal. If you still need the reward hail at Big Slick, run once more (script uses route block 8)."
        return
    end

    local taskIdx = getActivePokerTaskIndex()
    local qt = tonumber(gui.questTotal) or 0
    local qd = tonumber(gui.questDone) or 0

    if taskIdx and qt > 0 then
        local curStep, tot, complete = eqJournalStepIndex(qd, qt)
        local z = gui.questActiveZone and tostring(gui.questActiveZone) or ""
        local ins = gui.questActiveInstr and tostring(gui.questActiveInstr) or ""
        local lines = {}
        if z ~= "" then
            lines[#lines + 1] = "Zone: " .. z
        end
        if ins ~= "" then
            lines[#lines + 1] = "Instruction: " .. ins
        end
        lines[#lines + 1] = string.format("Resume stage ~%d/8 (from journal / zone mapping).", routeSt or 1)
        gui.infoDynamic = table.concat(lines, "\n")
        if complete then
            gui.status = string.format("Complete %d/%d", qd, qt)
        else
            gui.status = string.format("Ready — step %d/%d", curStep or 1, tot or qt)
        end
        return
    end

    if taskIdx then
        gui.status = "Ready — task in tracker."
        gui.infoDynamic = string.format(
            "Paintings task is in the tracker but objective counts are not readable yet. Resume ~route %d/8 — open Quest Journal (Active Tasks) if MQ looks wrong.",
            routeSt or 1
        )
        return
    end

    gui.status = "Ready to get quest — press Run."
    gui.infoDynamic =
        "West Freeport: hail Big Slick and accept Paintings Playing Poker (23rd anniversary). Keep Active Tasks visible so MQ can read objectives."
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
            pppokerGuiDebug("PPPoker: loaded atlas " .. PP.ATLAS_FILE .. " (" .. PP.ATLAS_W .. "x" .. PP.ATLAS_H .. ")")
        else
            for i = 1, #PP.PANELS do
                PP.textures[i] = nil
                PP.loadedOk[i] = false
            end
            warn("PPPoker: missing or bad atlas: " .. path)
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
                info("PPPoker: loaded " .. p.file)
            else
                PP.loadedOk[i] = false
                warn("PPPoker: missing or bad: " .. path)
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
        info("PPPoker FORCE_IMAGE: " .. PP.PANELS[PP.selectedIndex].name)
        return
    end
    PP.selectedIndex = choices[math.random(#choices)]
    pppokerGuiDebug("PPPoker header art: " .. PP.PANELS[PP.selectedIndex].name .. " (re-run script to re-roll).")
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

    -- ItemSpacing 0 for tight vertical layout in the child.
    -- WindowPadding 0 only while the child exists: child windows inherit parent pad by default, which
    -- double-insets the image vs same-window Text() on the line below (misaligned with “Paintings…”).
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
        imgui.BeginChild("##PPPokerPicPanel", getImVec2(frameW, frameH), false, flags)
    end)
    if not childOk then
        childOk = pcall(function()
            imgui.BeginChild("##PPPokerPicPanel", getImVec2(frameW, frameH), false)
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
    if stylePushCount > 0 then
        imgui.PopStyleVar(stylePushCount)
    end
end

local function ensurePicTestBarLive()
    if PP.picTestBarLive then
        return PP.picTestBarLive
    end
    local o = pppokerBarApi.shallowCopy(pppokerBarApi.globalOpts)
    for k, v in pairs(PP.PIC_TEST_BAR_OPTS) do
        o[k] = v
    end
    PP.picTestBarLive = o
    if o.textFmt then
        PP.barTextFmtStr = tostring(o.textFmt)
    end
    return PP.picTestBarLive
end

local function resetPicTestBarLive()
    PP.picTestBarLive = nil
    ensurePicTestBarLive()
    if PP.picTestBarLive and PP.picTestBarLive.textFmt then
        PP.barTextFmtStr = tostring(PP.picTestBarLive.textFmt)
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

        PP.picTestBarUseDemoPct = imgui.Checkbox("Use demo %% (ignore quest progress)", PP.picTestBarUseDemoPct)
        if PP.picTestBarUseDemoPct then
            PP.picTestBarDemoPct = imgui.SliderFloat("Demo %%", PP.picTestBarDemoPct, 0, 100, "%.1f")
        end

        bopts.height = imgui.SliderInt("Height", math.floor(bopts.height + 0.5), 6, 48)
        bopts.width = imgui.SliderInt("Width (0 = full)", math.floor(bopts.width + 0.5), 0, 480)
        bopts.padEnd = imgui.SliderInt("Pad end", math.floor(bopts.padEnd + 0.5), 0, 40)
        bopts.rounding = imgui.SliderInt("Rounding", math.floor(bopts.rounding + 0.5), 0, 16)

        bopts.showText = imgui.Checkbox("Show text", bopts.showText)
        if imgui.InputText then
            local ns = imgui.InputText("Text format", PP.barTextFmtStr, 96)
            if ns and ns ~= "" then
                PP.barTextFmtStr = ns
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
    imgui.TextColored(green, string.format("Commemoratives: %d", cnt))
end

--- Static help for the Info panel (short quest + how the script uses MQ).
local function pppokerStaticInfoText()
    return table.concat({
        "Paintings Playing Poker (23rd anniversary): a linear bar crawl. MacroQuest reads your Quest Journal — keep Active Tasks open when troubleshooting.",
        "First stop is West Freeport (Big Slick). Say what the quest window asks for when hailing / accepting.",
        "Stop cancels /travelto and /nav. Invis before risky city hops: AAs, then class spells where they exist (Clerics have no living invis spells — AAs or pots).",
        "",
    }, "\n")
end

--- Debug toggle: AStone-style right-aligned label + icon toggle.
local function pppokerDrawDebugToggle()
    local dbgAvailX = select(1, getContentRegionAvail2()) or 0
    local dbgBlockW = 90 -- "Debug" text + toggle icon
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + math.max(0, (dbgAvailX or 0) - dbgBlockW))
    ImGui.PushID("PPPokerDebug")
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

local function pppokerDrawGUI()
    if not PP.texturesLoadedOnce then
        if loadTextures() then
            pickRandomPanel()
        end
        PP.texturesLoadedOnce = true
    end

    if PP.pppokerApplyInitialLayout then
        local condAlways = nil
        if ImGuiCond then
            condAlways = ImGuiCond.Always
        end
        if condAlways == nil then
            condAlways = 1
        end
        pcall(function()
            local mv = imgui.GetMainViewport()
            if mv and mv.WorkPos then
                imgui.SetNextWindowPos(mv.WorkPos.x + 600, mv.WorkPos.y + 20, condAlways)
            end
        end)
        if imgui.SetNextWindowSize then
            pcall(function()
                imgui.SetNextWindowSize(getImVec2(PP.WINDOW_W, PP.WINDOW_H), condAlways)
            end)
        end
        PP.pppokerApplyInitialLayout = false
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

    local began = false
    -- VanillaMQ / ls.lua: Begin(title, open, flags) -> open, show
    --   open = false when user clicks X (persisted via gui.open)
    --   show = false when title bar is collapsed (skip body only; keep gui.open true)
    local function pppokerBeginWindow(title, openVal, flags)
        local okB, a, b = pcall(function()
            return imgui.Begin(title, openVal, flags)
        end)
        if not okB then
            local okB2, a2, b2 = pcall(function()
                return imgui.Begin(title, openVal)
            end)
            if not okB2 then
                return openVal, false
            end
            a, b = a2, b2
        end
        if type(a) == "boolean" and type(b) == "boolean" then
            return a, b
        end
        if type(a) == "boolean" and b == nil then
            -- Single-return variant: treat as draw; if false, also close window.
            if a == false then
                return false, false
            end
            return openVal, true
        end
        -- Unknown return shape; stay open and draw to avoid phantom blank states.
        return openVal, true
    end

    local ok, err = pcall(function()
        local open, show = pppokerBeginWindow(
            string.format("PPPoker v%s", PP.VERSION) .. PP.WINDOW_ID_SUFFIX,
            gui.open,
            winFlags
        )
        began = true
        gui.open = open
        if not open then
            return
        end
        if not show then
            -- Collapsed: show=false, open=true. Some builds leave open=true on X with show=false — detect via IsWindowCollapsed.
            local hasCollapsedFn, collapsed = false, false
            pcall(function()
                if imgui.IsWindowCollapsed then
                    hasCollapsedFn = true
                    collapsed = (imgui.IsWindowCollapsed() == true)
                end
            end)
            if hasCollapsedFn and not collapsed then
                gui.open = false
                config.running = false
                stopRequested = true
                haltNavigationForStop()
            end
            return
        end

        pcall(function()
            local cy = PP.FRAME_OFFSET_Y
            if PP.USE_TRIPTYCH_ATLAS and PP.PANELS[PP.selectedIndex] and PP.PANELS[PP.selectedIndex].segment == 2 then
                cy = math.max(4, PP.FRAME_OFFSET_Y - PP.FISH_CURSOR_Y_LIFT_PX)
            end
            imgui.SetCursorPos(0, cy)
            local nudge = tonumber(PP.IMAGE_NUDGE_X) or 0
            if nudge ~= 0 and imgui.SetCursorPosX and imgui.GetCursorPos then
                local a, b = imgui.GetCursorPos()
                local cx = 0
                if type(a) == "table" then
                    cx = tonumber(a.x or a["x"]) or 0
                else
                    cx = tonumber(a) or 0
                end
                imgui.SetCursorPosX(cx + nudge)
            end
        end)
        drawHeaderImage()

        if imgui.Spacing then
            imgui.Spacing()
        end

        imgui.Text("Paintings Playing Poker — 23rd Anniversary")
        imgui.Separator()

        if not config.running then
            updateIdleGuiFromJournal()
        end

        if config.running then
            if imgui.Button("Stop") then
                stopRequested = true
                config.running = false
                haltNavigationForStop()
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
        imgui.SameLine()
        pppokerDrawDebugToggle()

        imgui.Separator()
        drawCommemorativeCoinsRow()
        imgui.Separator()
        if gui.status and tostring(gui.status) ~= "" then
            imgui.Text("Status: " .. tostring(gui.status))
        end

        refreshGuiQuestProgress()
        local qd = tonumber(gui.questDone) or 0
        local qt = tonumber(gui.questTotal) or 0
        local questPct = 0.0
        if qt > 0 then
            questPct = math.min(100.0, math.max(0.0, (qd / qt) * 100.0))
        elseif gui.stage and gui.stage > 0 then
            questPct = math.min(100.0, math.max(0.0, (gui.stage - 1) / 7 * 100.0))
        end

        if PP.PIC_TEST_BAR_ENABLED and ImAnim then
            local mod = pppokerBarApi
            local bopts = ensurePicTestBarLive()
            if mod and bopts then
                pcall(function()
                    local pct = questPct
                    if PP.picTestBarUseDemoPct then
                        pct = PP.picTestBarDemoPct
                    end
                    local drawOpts = mod.shallowCopy(bopts)
                    if not PP.picTestBarUseDemoPct and qt > 0 then
                        drawOpts.tickEvery = 1.0 / qt
                    end
                    mod.DrawProgress("PPPokerQuest", pct, mod.Colors.XPMin, mod.Colors.XPMax, drawOpts)
                    if PP.PIC_TEST_BAR_SHOW_OPTIONS_UI then
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

        imgui.Separator()
        imgui.TextColored(ImVec4(0.85, 0.9, 1.0, 1.0), "Info")
        local infoPanelH = 148
        pcall(function()
            imgui.BeginChild("##pppokerinfo", getImVec2(0, infoPanelH), true)
            imgui.TextWrapped(pppokerStaticInfoText())
            if gui.infoDynamic and tostring(gui.infoDynamic) ~= "" then
                if imgui.Spacing then
                    imgui.Spacing()
                end
                imgui.TextColored(ImVec4(0.75, 0.95, 0.85, 1.0), "Current:")
                imgui.TextWrapped(tostring(gui.infoDynamic))
            end
            if gui.zueriaSlideInfo and tostring(gui.zueriaSlideInfo) ~= "" then
                if imgui.Spacing then
                    imgui.Spacing()
                end
                imgui.TextColored(ImVec4(0.82, 0.88, 1.0, 1.0), "Zueria Slide:")
                imgui.TextWrapped(tostring(gui.zueriaSlideInfo))
            end
            imgui.EndChild()
        end)

        if gui.debugOpen then
            if imgui.Spacing then
                imgui.Spacing()
            end
            imgui.TextColored(ImVec4(1.0, 0.85, 0.55, 1.0), "Debug")
            local dbgPanelH = 140
            pcall(function()
                imgui.BeginChild("##pppokerdebug", getImVec2(0, dbgPanelH), true)
                if not gui.debugLines or #gui.debugLines == 0 then
                    imgui.TextWrapped("(No debug lines yet — start a run to log resume / journal detail.)")
                else
                    for i = 1, #gui.debugLines do
                        imgui.TextWrapped(gui.debugLines[i])
                    end
                end
                imgui.EndChild()
            end)
        end
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
    local ok, count = pcall(function() return mq.TLO.FindItem(PP.GATE_POTION_NAME)() end)
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
        gui.expectingQuestFromRun = true

        local ok, err = pcall(runQuest)
        gui.expectingQuestFromRun = false
        if not ok then
            local em = tostring(err)
            if type(err) == "string" and err:find("Stopped by user", 1, true) then
                gui.status = "Stopped by user."
            else
                print("\ar[PPPoker Lua] " .. em .. "\ax")
                pppokerGuiDebug(em)
                gui.status = "Script error — see MQ Lua echo / console (full message printed there)."
            end
            config.running = false
        else
            -- runQuest already set gui.status via setGuiStage(...); keep EQ-verified message.
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

-- User closed the window (X) or script is exiting: stop movement immediately.
haltNavigationForStop()
config.running = false

if mq.imgui and mq.imgui.destroy then
    pcall(function()
        mq.imgui.destroy("PPPokerGUI")
    end)
end
for i = 1, #PP.PANELS do
    PP.textures[i] = nil
end
