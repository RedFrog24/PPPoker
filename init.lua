-- pppoker.lua 23rd anniversary task (main MQ Lua entry: init.lua)
-- Created by: RedFrog
-- Original creation date: 03/18/2026
-- Quest: https://everquest.allakhazam.com/db/quest.html?quest=10723
-- Version controlled by PP.VERSION (single source of truth - drives window title and run popup).
-- Changelog:
-- 3.38: Nav stuck detection in moving(). Samples Me.X/Y every 500ms while nav is active and not paused. If position unchanged more than 3 units over 3 seconds, strafes left for 500ms (/keypress strafe_left hold + release pattern from astone02) to clear geometry clip - matches the manual Ctrl+Left Arrow fix AL uses for the PoK anniversary tent area. Resets position and timer after each strafe attempt. Only fires when navigationIsActive() and not paused for buff upkeep (no false triggers during nav pause block).
-- 3.37: Mount counts as movement buff. pppokerMovementBuffPresent() now checks Me.Mount.ID() first - keyring mounts provide speed without placing a SPA 3 spell in the buff bar, so the HasSPA[3] scan missed them entirely. Result was false "movement buff missing" warn and Worn Totem attempt every time the character was already mounted. isMounted() is defined later in the file so the check is inlined directly using the same TLO.
-- 3.36: Apply invis before zoning into Neriak (not just after). prepCityTravel now accepts the destination zoneId and applies ensureInvisIfNeeded before /travelto when destination is NERIAK_A or NERIAK_B and TRAVEL_INVIS_BEFORE_NERIAK is true. Previously invis was only applied inside ensureSpeedAndInvisInNeriak after zone-in - guards at the Neriak zone line killed low-level characters before invis could land. ensureZone passes zoneId to prepCityTravel. Invis still reconfirmed after zone-in by ensureSpeedAndInvisInNeriak as before.
-- 3.35: Mount picker dropdown. Always-visible combo in the UI (below Commemoratives, above Debug panel) listing all keyring mounts. Levitating mounts (HasSPA[57] on item clicky spell, SPA 57 = SE_Levitation confirmed in game) shown in orange with "(levitates)" label and tooltip warning. Non-levitating mounts show green tooltip. Choice saved to pppoker_settings.lua (mq.pickle) by mount name - survives restarts. If saved mount removed from keyring, picker resets and prompts again. Single mount auto-selected silently with no UI prompt. Yellow "Choose Mount" + advisory text when multiple mounts and none yet selected. State vars (ppSettings, mountList, mountPickerIndex) stored in gui table to stay under LuaJIT 200-local limit; ppSettingsFile path inlined.
-- 3.34: Universal movement buff detection via SPA 3 (SE_MovementSpeed). pppokerMovementBuffPresent() previously checked only named class spells and AA buff names - missed any item clicky buff (e.g. Worn Totem gives "Blessing of Swiftness", unknown to the script). Fix: scan all 42 buff slots and check Spell(buffName).HasSPA(3)() - SPA 3 is the EQ movement speed effect code, confirmed TRUE for both "Blessing of Swiftness" and "Spirit of Wolf" in game. Works for any class spell, AA, or item clicky with zero config. BRD Selo songs remain a separate check via bardSeloActive() since songs live in Me.Song not Me.Buff. Removed MOVEMENT_ITEM_BUFF_NAMES config added in 3.33 - no longer needed.
-- 3.33: Movement item buff detection. pppokerMovementBuffPresent() only checked class spell names and AA names - had no knowledge of what buff effect a movement item grants. Worn Totem gives "Blessing of Swiftness" which was not in any checked list, so the script always reported movement buff missing even when the totem buff was active, causing the "movement buff missing - use SoW/Selo/totem manually" warn every tick. Fix: new config MOVEMENT_ITEM_BUFF_NAMES (default: "Blessing of Swiftness") - exact buff names granted by movement items. pppokerMovementBuffPresent() now checks these via Me.Buff().ID() after the class spell and AA checks.
-- 3.32: Replace all em dashes (U+2014) with plain hyphens throughout init.lua. MQ's default font renders em dashes as ??? (three question marks, one per UTF-8 byte) in EQ console output. Affected all info() and warn() calls that used — as a separator. 205 instances replaced globally.
-- 3.31: CWTN pause skipped message demoted from debugLog to debugLogQuiet - was printing a raw timestamped orange line to EQ console on every run when no CWTN plugin loaded (normal/expected state for many characters). Now goes to debug panel only.
-- 3.30: Fix level check crash (v3.27 regression). Spell.ClassLevel is not exposed in MQ Lua bindings - accessing it returned nil, then calling it with (class) threw "attempt to call field 'ClassLevel' (a nil value)" on every objective loop. Fix: replace ClassLevel(class)() with MinCasterLevel() in both movement and invis spell pipelines. MinCasterLevel returns the lowest level any class needs to cast the spell - sufficient gate for low-level characters. Both locations fixed (pppokerApplyMovementClassBuff line ~1893, pppokerApplyInvisClassBuff line ~2356).
-- 3.29: Remove pppokerUseWornTotemIfAvailable and PP.WORN_TOTEM config key. Worn Totem was handled by both a dedicated function (hardcoded legacy) and the MOVEMENT_ITEM_NAMES list - two code paths with different wait times (12s vs 6s). Now handled exclusively by pppokerUseMovementItemList like any other movement item. All movement items use the same reuse check and wait time.
-- 3.28: Movement item reuse check. pppokerUseWornTotemIfAvailable and pppokerUseMovementItemList now check itemClickReuseReady before clicking, matching the existing invis item behavior. New config MOVEMENT_SKIP_ITEM_IF_NOT_READY (default true) mirrors INVIS_SKIP_ITEM_IF_NOT_READY - when item is on cooldown, skip it this tick instead of clicking a dead item. Prevents Worn Totem from dropping invis for a failed/no-op click.
-- 3.27: Level check before memspell in both pppokerApplyMovementClassBuff and pppokerApplyInvisClassBuff. Previously only checked Spell.ID() > 0 (valid game spell) with no level gate - a level 12 NEC would attempt to memorize "Skin of the Shadow" (level 55) instead of skipping to "Gather Shadows" (level 7). Fix: read Spell.ClassLevel(class) and compare to Me.Level() before attempting memspell; log skip at debugLogQuiet level. Applies to both movement and invis spell pipelines.
-- 3.26: Unified buff application block in runBuffUpkeepTick. Worn Totem and invis are now both fixed for navigation: compute needMovement + needInvis upfront, then one combined nav-pause block (/nav pause + 200ms) when either is needed, apply movement first then invis (both with allowSpellCast=true since nav is paused), single /nav pause off afterward. invisApplyingNow renamed buffsApplyingNow to reflect it guards both. INVIS_REFRESH_MIN_TICKS_REMAINING default changed from 0 to 8 (48s proactive refresh) - script now proactively recasts invis before it expires rather than only reacting after it drops.
-- 3.25: Fix invis-not-recast and no-50%-med during navigation. Root cause: allowSpellCast=false during navMoving blocked pppokerApplyInvisClassBuff entirely - so pppokerEnsureInvisBuff returned without casting, and meditateToManaPpp (inside the spell path) was never reached. Fix: upkeep invis section now pauses nav (/nav pause + 200ms), applies invis with allowSpellCast=true so spell+med path is reachable, then resumes nav (/nav pause off). invisApplyingNow guard prevents upkeep re-entry while the cast is in progress (cast can take several seconds). meditateToManaPpp MaxMana read wrapped in pcall for safety. removeLevitationBuffsIfPresent() called in both needInvis and !needInvis paths.
-- 3.24: Med safety buffer + death respawn. meditateToManaPpp now meds to max(requiredMana, 50% of MaxMana) instead of just requiredMana - avoids repeated sit/stand for each subsequent cast (invis refresh, re-gate) during a run leg; log shows need/have/target. handleDeathIfNeeded(): detects Me.State=="DEAD", waits for RespawnWnd, clicks RSPB_STANDARD (bind point), waits until no longer dead + 2s settle, returns true. Wired into runBuffUpkeepTick (fires every 300ms during navigation and objective waits); returns early after respawn so buff checks run clean on the next tick. shouldStop() honored inside all wait loops.
-- 3.23: Upkeep invis-before-movement guard. runBuffUpkeepTick now reads invis state before the movement buff check. If invis is currently up and movement buff expired, movement re-application is skipped - clicking a movement item (Worn Totem, etc.) or casting a movement spell always drops invis in EQ. Character stays hidden; movement is re-applied on the next tick after invis naturally drops (which then fires the normal movement-first, invis-last sequence). Zone-entry helpers (ensureSpeedAndInvisInNeriak, Qeynos, Highpass) are unaffected - they explicitly apply movement before invis and are not in the upkeep path.
-- 3.22: Two latent fixes from code review. (1) warn forward decl - loadTextures referenced warn before its local definition; added local warn to forward-decl block and changed local function warn to assignment so it shares the same upvalue. Without this, any atlas/texture load failure would call nil and crash (never triggered because textures load cleanly, but the bug was real). (2) paintingsTaskSlot cache - getPaintingsTaskSlotNumber scanned up to 30 tasks on every objectiveCompleteFromParse call, which is called 16x per progress refresh (up to 480 TLO reads). Cache set on first successful scan, reset at runQuest start in case task was dropped/re-acquired between runs.
-- 3.21: Gate spell mana check - meditateToManaPpp(gateSpellMana) added before each /cast attempt in both tryGateToPoK_AAorSpellOnly() and tryGateToPoK(). Mana cost read once via mq.TLO.Spell(spellName).Mana() before the loop (math.max 40 floor, same pattern as movement/invis buff functions). Gate AA path unchanged - AAs do not use mana. Fixes low-level casters silently failing Gate casts after spending mana on invis.
-- 3.20: Gate retry - gem-ready polling. Added waitZonedOrGateReady(checkReadyFn, zoneId, maxMs): polls every GATE_READY_POLL_MS (250ms) and exits early when the gate ability/gem/item becomes ready again (fizzle/collapse resolved) instead of sitting out the full GATE_ZONE_WAIT_MS (90s cap). Applied to all four gate-cast paths: AA and spell in tryGateToPoK_AAorSpellOnly(), AA and spell in tryGateToPoK(), Drunkard's Stein in tryGateSteinToPoK(), and philters/potions in tryGatePotionsClickiesToPoK(). Typical collapse/fizzle wait drops from ~90s to ~3-5s. Updated warn messages in tryGateToPoK() AA/spell loops (was "waiting for AA again" - now "collapse/fizzle; retrying"). GATE_ZONE_WAIT_MS (90s) remains as safety cap; no config changes needed.
-- 3.19: Low-level Highpass safe gate (Option A). HIGHPASS_SAFE_GATE_LEVEL (default 40) - if Me.Level < threshold, nav to LOC.HIGHPASS_SAFE_GATE (outside Tiger room, no NPC clusters) before gate ladder runs in leaveHighpassTowardNorthQeynos. Character is still invis during nav; gate drops invis away from guards. Set HIGHPASS_SAFE_GATE_LEVEL=0 to disable. LOC.HIGHPASS_SAFE_GATE = { -78.13, 625.50, -18.68 } (verified in-game, heading WSW from Tiger room).
-- 3.18: Objective timeout no longer kills the run. waitObjectiveDone timeout replaced fail() with warn() - loop retries the same objective automatically on next iteration. runObjectiveStep wrapped in pcall - travel/gate fail() errors (e.g. "Could not reach PoK") warn and retry instead of crashing; stop requests re-thrown so Stop/close still works.
-- 3.17: Fix mana med threshold - meditateToManaPpp was hardcoded to 40 in both pppokerApplyMovementClassBuff and pppokerApplyInvisClassBuff. Low-level casters with >40 mana but less than spell cost would skip sitting entirely and fail the cast. Now passes math.max(40, spellData.Mana()) so the script sits until actually able to cast the spell. Added shouldStop() inside the med loop so Stop request exits immediately instead of waiting up to 2 min for timeout. Med log now shows have/need values.
-- 3.16: Shutdown cleanup - add cleanupAfterRun(): unpause RGMercs, unpause CWTN, unload MQ2AutoSize only if PPPoker loaded it (autosizePreloaded checked at script start via IIFE). cleanupAfterRun() now called on: normal quest completion, mid-run early exits (task unavailable / objectives gone), user stop, and any Lua error (pcall handler in main loop). Pre-preflight early exits (no task, no objectives, title mismatch) keep plain unpause pairs - AutoSize not yet loaded at those points.
-- 3.15: Fix RGMercs pause - solo script, no group: /rgl pauseall -> /rgl pause, /rgl unpauseall -> /rgl unpause. AutoSize: load plugin then /autosize self 3 (consistent run size; mount size left to user's AutoSize config). Clean stale prepBeforeTasselLeg doc comment (was still referencing removed Guise shrink).
-- 3.14: DRU/RNG camouflage fixes. DRU INVIS_CLASS_BUFFS: remove bogus "Invisibility" (DRU can't mem it - was triggering failed /memspell + 8s wait), add full camo ladder best→worst: "Improved Superior Camouflage" (Lv 48, Improved Invis), "Superior Camouflage" (Lv 18), "Camouflage" (Lv 4). RNG: add "Superior Camouflage" (Lv 47) before base "Camouflage" (Lv 14). INVIS_SELF_AA_NAMES: add "Innate Camouflage" (DRU/RNG AA, Alt Act ID 80 per EQResource). INVIS_GROUP_AA_NAMES: add "Shared Camouflage" (DRU/RNG group camo AA, Alt Act ID 518). Both AA names exit cleanly for non-DRU/RNG (AltAbility returns 0 → skipped).
-- 3.13: Remove Guise of the Deceiver shrink system entirely (maybeGuiseShrink, resetGuiseShrinkSession, GUISE_SHRINK_ITEM, GUISE_SHRINK_HEIGHT_MIN, TRAVEL_SHRINK_IN_QEYNOS, TRAVEL_SHRINK_IN_HIGHPASS, gui.shrinkUsed, gui.shrinkPopupShown). Add MQ2AutoSize plugin check/load in runPreflightAfterQuestChecks. Rename ensureSpeedShrinkInvisInHighpass -> ensureSpeedInvisInHighpass (all 5 call sites). Hoist bardSeloActive to module scope (safe now: 14 free slots); remove inner copies from pppokerMovementBuffPresent + pppokerApplyMovementClassBuff. Make syncJournalAfterKeywordTry + tryAcquireQuestFromBigSlick local (previously blocked by 200-local limit). Local count: 187.
-- 3.12: Phase 1 - move 8 state vars into gui table (shrinkUsed, shrinkPopupShown, lastBuffUpkeepTick, rgmercPaused, journalOpenedOnce, barLiveOpts, shimmerState, commIconTex); freed 8 locals. Phase 2 - merge waitUntilGateAltReady+waitUntilGateSpellReady into waitUntilGateReady(checkFn,label,maxMs); inline gatePotionReady alias into waitUntilGatePotionReady; freed 2 locals. Phase 3 - collapse navigationIsActive+navigationIsPaused from ~80 lines to ~36 by removing duplicate inner helper functions (no locals changed). Phase 4 - waitForZoneOrFalse uses mq.gettime() consistently; hasAnyGateItemPath collapsed to single return. Total: 196 -> 186 module locals (14 slots freed).
-- 3.11: Revert local on syncJournalAfterKeywordTry / tryAcquireQuestFromBigSlick - script was at the 200-local LuaJIT limit; these two additions pushed it over. Restored as globals.
-- 3.10: Revert bardSeloActive hoist - LuaJIT hard limit of 200 locals per scope; module-level local pushed main chunk over limit. Restored as inner function in both call sites (inner locals do not count against main chunk).
-- 3.09: syncJournalAfterKeywordTry / tryAcquireQuestFromBigSlick - add missing local; both were inadvertent globals leaking into _G.
-- 3.08: drawGUI - pass winFlags to imgui.Begin fallback path; was missing NoSavedSettings flag if primary pcall ever failed.
-- 3.07: Objective 5 - replace hardcoded /nav locyx 204 -243 3 with navLoc(PP.LOC.SLUG, 1500); PP.LOC.SLUG was already defined with the same coords but never used here.
-- 3.06: waitObjectiveDone - remove dead outer local obj assignment (was immediately shadowed by inner local obj in the log block; never read).
-- 3.05: getScriptDir() - replace fragile last-PID approach with debug.getinfo(1,"S").source directly; PID grab could silently return wrong folder when multiple Lua scripts running.
-- 3.04: Fix /rgm -> /rgl in pauseRGMercs/unpauseRGMercs (defunct macro prefix). Add 500ms settle after second /autoinv in doBettyPocketInteraction. Hoist bardSeloActive to module scope (was duplicated inside pppokerMovementBuffPresent and pppokerApplyMovementClassBuff).
-- 3.03: Invis - removed bogus **Veil of Midnight** (not an EQ spell); BRD songs **Shauri's Sonorous Clouding**, **Selo's Song of Travel** (verify ranks in spellbook). ENC/MAG/WIZ: **Superior Invisibility** where listed. `INVIS_REFRESH_MIN_TICKS_REMAINING` + `INVIS_DURATION_TRACK_EXTRA_NAMES` - refresh before fade (MQ `Me.Buff(name).Duration.Ticks`). Changelog 2.83 note: Veil of Midnight was never valid.
-- 3.02: Default `INVIS_ITEM_NAMES` - **Cloudy Potion** last (add other clickies above it for earlier tries).
-- 3.01: Gate **item ladder** - `GATE_ITEM_LADDER` ordered steps (`stein` → `zueria_slide` → `potions`); **skip** stein/philter when on reuse timer (no long wait blocking Slide). Invis **item** ladder: `INVIS_ITEM_LADDER` or `INVIS_ITEM_NAMES` order; skip clicky if not `FindItem` / reuse-ready (`INVIS_SKIP_ITEM_IF_NOT_READY`). Shared `itemClickReuseReady()` for timer checks.
-- 3.00: Rogue Sneak/Hide - skip `/doability` when `Me.Sneaking` / `Me.Hidden` already true; optional `Me.AbilityReady("Sneak"|"Hide")` guard (matches `${Me.Sneaking}`, `${Me.Hidden}`, `${Me.AbilityReady[x]}` in macros).
-- 2.99: Gate **item** order: **Drunkard's Stein** (PoK clicky, timer like philters) → **Zueria Slide** (level/mode checks unchanged) → **GATE_POTION_NAMES**; after Slide to Nektulos, AA/spell/stein/philter then `/travelto` PoK (no nested Slide). Obj 16 Lion routing delay **2000→1000** ms; final Slick hail timings **POST_HAIL 4500→3500**, **PRE_HAIL / POST_NAV 1200→600** ms.
-- 2.98: Highpass - tunable `HIGHPASS_ENTRY_DELAY_MS` / `HIGHPASS_POST_HAIL_DELAY_MS` (slightly shorter defaults); Tiger `LOC.TIGER` + face east (`TIGER_FACE_HEADING` 128), re-nav if still beyond `TIGER_NAV_RETRY_IF_DIST_GT`. See `WAIT_OBJECTIVE_TIMEOUT_MS` - wait loop after obj 12 until journal credits Tiger Roar.
-- 2.97: Obj 13 (after Tiger Roar → North Qeynos) - use same **Gate AA → spell → Zueria Slide → potion → run** ladder as obj 8/16; was still calling `tryGateDirectOrPokFallback` (monolithic Gate) so Slide never ran. `PP.TRAVEL_TIGER_ZUERIA_SLIDE_TO_NEK`.
-- 2.96: Bard invis AA - verified **Alt Act ID 231** = Shauri's Sonorous Clouding on EQ Resource master alt-act list (`articles.eqresource.com/altactlist.php`, Bard table; page spells it "Sonorious"). Name + rank effects cross-checked vs ZAM (`everquest.allakhazam.com/db/spell.html?spell=51343` Shauri's Sonorous Clouding III). `PP.INVIS_BRD_AA_IDS` / `PP.INVIS_BRD_AA_NAMES` populated from those sources (not guessed).
-- 2.95: Removed mistaken default `"Veil of Notes"` (not a verified Live AA string). Bard invis: set `PP.INVIS_BRD_AA_NAMES` and/or `PP.INVIS_SELF_AA_IDS` from your character.
-- 2.94: Bard invis - `INVIS_BRD_AA_NAMES` tried before caster-style `AltAbility` names; invis songs use `SongReady` not `SpellReady`. Explains caster vs BRD AA name resolution difference.
-- 2.93: AA activation now supports ID-first lists (movement/invis) with name fallback; upkeep uses /alt act by id path where configured. Added levitation cleanup list (`REMOVE_LEVITATION_BUFFS`) and `/removebuff` pass (default: "Shauri's Levitation") after invis/upkeep.
-- 2.92: Buff streamlining - movement/invis now support AA-first ladders with faster fall-through and optional continuous upkeep tick (low-delay checks during Run). Added configurable movement/invis AA + item lists and reduced cast retry stall.
-- 2.91: Travel refactor - linear “capability ladder” routing: **Gate AA → Gate spell → Zueria Slide item → Gate potions (list) → Run (zone-to-zone chain)**. Obj 8 (Toadstool) and obj 16 (Lion) now follow this order to reduce unnecessary waits and fix direct-zone edge cases.
-- 2.90: Toadstool→obj 8 - **runners** (no Gate AA/spell): nav to `PP.LOC.TOADSTOOL_RUNNER_PRE_NERIAKA` (default 3.53, -464.07, -10.81 in Commons), then `/travelto neriaka` before Gate/moors; `PP.TRAVEL_TOADSTOOL_RUNNER_PRE_NERIAKA_NAV`.
-- 2.89: Toadstool→obj 8 - optional **Zueria Slide** to Nektulos (fast), then Moors→Highpass; **no Gate AA/spell** → `/travelto moors` before PoK hub fallback. Lion's Mane→obj 16 - optional **Slide→Nek** then PoK→West FP for non-gaters. `PP.TRAVEL_TOADSTOOL_ZUERIA_SLIDE_TO_NEK`, `PP.TRAVEL_LION_ZUERIA_SLIDE_TO_NEK`, `PP.TRAVEL_TOADSTOOL_NO_GATE_USE_MOORS_FIRST`. EasyFind to Foreign Quarter **default off** (`TRAVEL_TOADSTOOL_LEAVE_EASYFIND_NERIAKA`); navmesh issues were client-side - re-enable if needed. `pppokerZueria.attemptSlideToNektulos()` shared with Betty grog path.
-- 2.88: Toadstool→obj 8 - from **Neriak Commons**, optional `/easyfind neriaka` (MQ2EasyFind) to zone line **Neriak Foreign Quarter** before Gate/`/travelto` (avoids broken EQ zone-path for some clients). `PP.TRAVEL_TOADSTOOL_LEAVE_EASYFIND_NERIAKA` / `PP.EASYFIND_NERIAKA_SHORTNAME`. Gate potions: `GATE_POTION_NAMES` list - added **Vial of Swirling Smoke** (PoK vendor; Lore); legacy `GATE_POTION_NAME` still honored if `GATE_POTION_NAMES` omitted.
-- 2.87: Gate-fail routing - try **direct** `/travelto` to the next leg first (restores 2.85 speed: Neriak→Highpass, Highpass→NQ, Qeynos→West FP); **PoK hub fallback** only if direct travel does not zone in time (keeps 2.86 fix for characters that need the hub).
-- 2.86: Obj 8 / 13 / 16 (and East FP→Neriak hub) - if Gate AA/spell/potion unavailable, `/travelto poknowledge` to PoK before next `/travelto` (matches prior analysis; fixes Neriak→Highpass with no gate means).
-- 2.85: NEC invis - add **Skin of the Shadow** (self, Improved Invis; ~Lv 55) before **Gather Shadows**; script skips unknown spells via Spell.ID.
-- 2.84: NEC invis spells - only **Gather Shadows** (Lv 7 self, Invisibility Unstable) per class lists; removed Gather Umbra (item/group click, not spellbook), Shadow, Invisibility (wrong / not NEC for living invis). ITU lines (e.g. Invisibility Versus Undead) intentionally omitted.
-- 2.83: CWTN - NEC expects MQ2Necro (fallback MQ2Necromancer); BRD still MQ2Bard. Invis - BRD songs (Shauri's Sonorous Clouding, Veil of Midnight); NEC spell list + optional PP.SPELLGEM_MEM_CAP.
-- 2.82: Version re-alignment - working copy had been ~2.65 when renamed init2→init (2.66); restored 2.67–2.81 behavior in one pass (see below). Git had never contained those intermediate versions.
-- 2.81: Task journal - PP.TASK_JOURNAL_SYNC_MODE `open_once_no_fetch` (default): open TaskWnd once per Run, no periodic fetch/open-close spam; PP.WAIT_OBJECTIVE_TIMEOUT_OBJ1_MS for Tassel.
-- 2.80: Highpass tiger - PP.LOC.TIGER trial coords (wall-stuck / Gate); may revert.
-- 2.79: Quest Run Time - `formatQuestRunDuration` (e.g. "2 min 30 seconds").
-- 2.78: ensureInvisIfNeeded `invis - <label>` - debug panel only (debugLogQuiet).
-- 2.77: CWTN already paused - debugLogQuiet.
-- 2.76: Travel prep chatter (prepCityTravel, preflight header, ensureSpeed*, Moors/Nek) - debugLogQuiet.
-- 2.75: ensureZone "Already in … skipping /travelto" - debugLogQuiet.
-- 2.74: PoK→Neriak retry line - "Traveling to" + mqItem("Neriak Foreign Quarter") + attempt.
-- 2.73: Atlas load - debugLogQuiet only; no "(WxH)" in message.
-- 2.72: ensureZone travel - mqItem destination; drop "via /travelto …".
-- 2.66: Entry file rename - former init2.lua is now init.lua; Run popup no longer tags "init2".
-- 2.65: Debug - bordered scrollable frame + colored log lines restored (2.62-style ImGui.TextColored parsing of \\a codes). Ring buffer in gui.debugLog; info/warn mirror to panel without duplicate console line; standalone debugLog() still prints + appends.
-- 2.63: Debug - no in-window log/frame; Debug toggle removed. debugLog() and all script diagnostics go to EQ console only (info/warn unchanged).
-- 2.62: Debug panel - parse MQ \a color codes and draw with ImGui.TextColored (frames do not enable EQ colors; needs explicit mapping). Raw log lines from info/warn; optional bordered debug child. mqSpell/mqObjGreen use "\\a" in Lua so stored strings match console triplets.
-- 2.61: Console - objective completion (\ag) and spell names (\am) in log text; debug panel still plain until 2.62.
-- 2.60: Console/debug - drop redundant "PPPoker:" in message text; info/warn already print [\agPPPoker\ao] / [\ayPPPoker\ao].
-- 2.59: CWTN pause - use ${CWTN.Paused} / mq.TLO.CWTN.Paused() (init.lua parity); skip /CWTN pause on if already paused; unpause only when this run paused CWTN (not if user had paused before Run).
-- 2.58: Quest objective bar - restored animated shimmer overlay (init.lua parity; opts.shimmer was unused in drawObjectiveBar).
-- 2.57: Idle + run Status - show journal instruction text only (no "Next: objective N -" / "Objective N:" prefix).
-- 2.56: GUI - removed "Current Objective" line (Status + Progress + bar retain step info via Status when idle).
-- 2.55: PoK bind - popup/info "Please Start in PoK" when not bound; after nav to Soulbinder loc, wait until within POK_SOULBINDER_MAX_DIST of loc before target + /say Bind (avoid Jera too early).
-- 2.54: PoK bind parity with init.lua - if not bound to zone 202, /travelto poknowledge, nav to PP.POK_SOULBINDER_LOC, Soulbinder Jera, /say Bind; runs at Run start after pausing RGmerc/CWTN, before journal sync and Slick acquire. PP.ENSURE_POK_BIND_BEFORE_RUN (default true).
-- 2.53: GUI - version only in window title; removed duplicate (v#) from header line after "Anniversary".
-- 2.52: After full success - optional auto-repeat (PP.AUTO_REPEAT_DELAY_SEC, default 10s like Poker2 /timed); global _G.PPPokerV2.armRun() queues another Run without clicking (main loop). Set AUTO_REPEAT_DELAY_SEC to 0 to disable.
-- 2.51: North/South Qeynos - no keyring mount ever (mountIfNeeded hard-skips NQ/SQ; obj 13–15 use navLocNoMount). Removed PP.TRAVEL_NO_MOUNT_IN_QEYNOS. Dismount + speed/invis helpers unchanged.
-- 2.50: Objective 8 (PoK→Highpass) - optional Blightfire Moors hop (Poker2.lua): /travelto moors, zone 395, then poker2MountDelayInNekOrMoors + /travelto highpasshold. Fixes mount never running in Moors when script skipped 395 (poker2MountDelayInNekOrMoors no-op from PoK). PP.TRAVEL_HIGHPASS_VIA_MOORS (default true). Moors added to zoneWantsCityPrep for movement prep before /travelto moors.
-- 2.49: tryGateToPoK - faster polling after fizzle/interrupt/collapse (Gate AA/spell/potion ready waits, cast-clear probe, shorter backoff before next attempt). Tunables: PP.GATE_READY_POLL_MS, PP.GATE_CAST_CLEAR_POLL_MS, PP.GATE_POST_CAST_EXTRA_WAIT_MS, PP.GATE_RETRY_BACKOFF_MS.
-- 2.48: Objective 16 - if Paintings task vanishes from journal after final hail (EQ removes quest on turn-in), waitObjectiveDone treats that as complete; main loop breaks so nil task is not "Task became unavailable."
-- 2.47: On successful quest completion, log commemorative coin count and Quest Run Time (seconds), matching Poker2.lua end-of-run output.
-- 2.46: Blightfire (Moors) poker2MountDelayInNekOrMoors - speed buff + mountIfNeeded only (no extra Poker2 pause stack).
-- 2.45: Qeynos ensureSpeedAndInvisInQeynos - speed, shrink (TRAVEL_SHRINK_IN_QEYNOS), dismount if mounted, invis; then nav to POIs (2.51: navLocNoMount in NQ/SQ, no keyring mount).
-- 2.44: Highpass ensureSpeedInvisInHighpass - no dismount; speed, shrink, mount, invis (same toggles).
-- 2.42: Highpass ensureSpeedInvisInHighpass - mountIfNeeded after shrink, invis last; TRAVEL_NO_MOUNT_IN_HIGHPASS to walk only. mountIfNeeded skips Highpass when that toggle true.
-- 2.41: Guise shrink - at most one /useitem + one shrink popup per Run (resetGuiseShrinkSession); removed duplicate shrink from prepBeforeTasselLeg (preflight only, like zone helpers).
-- 2.40: Qeynos (NQ/SQ): ensureSpeedAndInvisInQeynos dismounts for speed/invis on foot, then nav (later 2.51: hard no keyring mount in NQ/SQ).
-- 2.39: ensureSpeedInvisInHighpass - on zone-in/resume in Highpass (obj 8–12): dismount, movement buff, Guise shrink (toggle), invis last via ensureInvisIfNeeded. Mount left to navLoc / navLocNoMount per leg.
-- 2.38: Blightfire/Nektulos Poker2 mount - waitMeNotCasting before keyring mount click and after mount; mountIfNeeded already waits Me.Casting + mounted after /useitem.
-- 2.37: tryGateToPoK - route by capability: AA waits AltAbilityReady; spell Gate waits SpellReady; potion waits FindItem.Timer (reuse). No AA/spell/potion → return false immediately (caller /travelto) with no long waits.
-- 2.36: tryGateToPoK - wait for Gate AA ready, retries after collapse/fail (AltAbilityReady + cast clear + longer zone wait); potion path retried. Avoids immediate /travelto pok when Gate was not ready long enough.
-- 2.35: Pause Nav uses MQ2Nav /nav pause and Unpause uses /nav pause off (path preserved). moving() waits while Navigation.Active or Navigation.Paused (or gui.navPaused fallback). Removed resumeNavAfterUnpause + /nav stop pause behavior.
-- 2.34: Objective 16 (final hail Big Slick): wait until Big Slick spawn within hail range (waitBigSlickWithinDist) after nav, optional re-nav - then target and hail (no interaction while too far).
-- 2.33: Pause Nav halts /nav but navLoc/navLocNoMount re-issue same locyxz after Unpause (resumeNavAfterUnpause). mountIfNeeded waits for cast to finish + mount before nav. Stop/Run clear resumeNavAfterUnpause.
-- 2.32: Pause Nav toggles gui.navPaused; moving() waits in waitWhileNavPaused (Run continues after unpause). Stop clears navPaused, halts nav/travelto, and sets stopRequested to end Run. Run clears navPaused on start.
-- 2.31: South Qeynos Lion's Mane (obj 15): no Gate at lion; after that objective done, obj 16 starts with Gate/potion to PoK if still in NQ/SQ, then West Freeport / Slick (same pattern as Tiger / Toadstool).
-- 2.30: Neriak Toadstool (obj 7): no Gate at painting; after Toadstool objective done, obj 8 starts with Gate/potion to PoK then Highpass (same pattern as Tiger → Qeynos).
-- 2.29: Qeynos (NQ/SQ): ensureSpeedAndInvisInQeynos - speed + invis on foot. Highpass (see 2.39 ensureSpeedInvisInHighpass): no dismount before hail Quinn/Mhrai; nav without mount on lumber+tiger (obj 10–12); Gate/potion removed from Tiger step - after Tiger objective done, obj 13 runs Gate/travel then NQ. TRAVEL_INVIS_AFTER_QEYNOS_ZONE gates invis inside Qeynos helper.
-- 2.28: Neriak (40/41): on entry/resume - dismount if needed, speed buff + invis (casts if needed); mount keyring never used in Neriak (PP.TRAVEL_NO_MOUNT_IN_NERIAK). Blightfire/Moors (395): on entry - speed buff + mount + Poker2 pause. Removed TRAVEL_NO_MOVEMENT_BUFF_CAST_IN_NERIAK (speed may cast in Neriak on foot).
-- 2.27: Neriak mount-cast fix via pppokerEnsureMovementBuff - skip class/totem movement buff *application* in Neriak Foreign/Commons (PP.TRAVEL_NO_MOVEMENT_BUFF_CAST_IN_NERIAK). Reverts 2.26 dismount-before-buffs in ensureSpeedAndInvisInNeriak (single rule in movement buff path).
-- 2.26: Neriak buff pass (ensureSpeedAndInvisInNeriak): dismount before movement/invis if PP.TRAVEL_DISMOUNT_BEFORE_BUFFS_IN_NERIAK (default true) - many spells/items do not cast on mount.
-- 2.25: In Neriak (Foreign or Commons): after zoning or when already in zone (resume), refresh movement speed + invis (ensureSpeedAndInvisInNeriak). PoK->Neriak travel applies buffs after landing, not only before /travelto.
-- 2.24: Preflight no longer casts invis - Guise shrink and other clicks/spells after invis drop it; invis only at leg-specific ensureInvisIfNeeded (e.g. after shrink in prepBeforeTasselLeg). Preflight = speed, mount, Zueria readiness, Guise shrink only.
-- 2.23: Run flow - journal quest/objective checks first, then preflight (speed, mount, Zueria readiness, Guise shrink, invis last; skip invis recast if already up). Before Tassel (obj 1): speed + shrink + invis-if-needed. City /travelto prep is movement-only (no invis spam in ensureZone). Betty obj 2: nav + in-range wait only; obj 3: hail + Memento Grog + Zueria slide or Gate/potion/travelto PoK then /travelto neriaka (avoids Hodstock). Obj 4: East FP uses PoK hub then Neriak; Nektulos/Moors keeps direct neriaka after mount pause.
-- 2.22: moving()/navigationIsActive aligned with init.lua - arm wait for Navigation.Active + post-nav grace (fixes navLoc returning before path finishes; Slick acquire was targeting/saying before [Nav] Reached destination). tryAcquire: wait until Big Slick spawn within range, Poker2-style post-nav buffer, journal sync after /say uses minimal fetch first then full only if getTask still nil. Run order: movement buff before TaskWnd sync (less journal flash before mount). GUI: Pause Nav button (/nav stop). Version 2.21 notes retained below.
-- 2.21: No quest on Run - travel to Big Slick loc, /say paintings (PP.SLICK_QUEST_KEYWORD), esc, full TaskWnd sync, then re-check journal (TRY_BIG_SLICK_QUEST_ACQUIRE). First journal tick uses TASK_JOURNAL_FIRST_SYNC minimal (fetch-only) to cut open/close spam; use "full" if Task TLO stays empty.
-- 2.20: Poker2.lua timing - mount+3s after Nektulos (25) or Moors/Blightfire (395) before next /travelto; invis before Tassel nav; invis after mount before Neriak; invis after zoning NQ/SQ. Final Slick (obj 16): /face fast, longer pre/post-hail delays, journal sync + 5m wait timeout + periodic TaskWnd sync while waiting (fixes hail-too-fast / journal lag timeouts).
-- 2.19: Travel tuning (init.lua patterns): mount keyring slot 1 before /nav, dismount before hail/target and Gate; movement buff (class SoW/Selo + Worn Totem) at run start; city prep (speed then invis) before /travelto city zones - toggles on PP (TRAVEL_*).
-- 2.18: taskobjective has no Done member on Live MQ - removed all .Done() and ${...Objective[..].Done} parse (stops "No such taskobjective member Done" spam). Completion = Status + RequiredCount/CurrentCount only (parse + userdata).
-- 2.17: Objective completion uses mq.parse (${Task[..].Objective[n].Status|RequiredCount|CurrentCount|Done}) first; matches /echo in game. Lua userdata alone was leaving Obj 1 "incomplete" forever. Slot index fallback if named parse empty. Console log lines use ASCII '-' (no em dash).
-- 2.16: objectiveIsComplete also uses Objective RequiredCount/CurrentCount (init.lua-style) when present - Live often credits via counts while Done/Status lag; fixes false resume at Obj 1 / Tassel when step is done.
-- 2.15: Define getObjectiveSlotRaw before getQuestProgress (Lua local forward-ref fix - GUI draw error calling nil).
-- 2.14: Central taskEvalExists() - mq.TLO.Task(name)() must be evaluated for journal memory (case-sensitive); all task gates use pcall’d () check per MQ docs. getTask tries named task first, then Task(1..N) by title.
-- 2.13: firstIncompleteObjective skips nil Objective(i) (MQ omits finished steps; old logic treated nil as incomplete → always resumed at 1). Bar still uses only rows that exist - may look pessimistic vs journal. shouldStop() honors GUI close (X) + stop flag; runQuest logs quest title then next incomplete index after journal checks.
-- 2.12: No Task/journal reads or status-bar fill until first Run: open shows placeholder only; Run syncs journal then checks quest-in-journal, then objective rows/progress. Removed automatic prime before ImGui and in main loop (was acting like objective 1 pending before quest check).
-- 2.11: Journal prime runs once BEFORE mq.imgui.init so first ImGui frame never reads stale TLO (chicken/egg with main-loop-only prime). getQuestProgress returns hasQuest + Title() match; Run logs resume index from step table. Completion still objectiveIsComplete (not obj()-only).
-- 2.10: getQuestProgress() - percent + per-objective done table (16) via objectiveIsComplete; status bar ticks green/gray per step. getObjectiveProgress wraps same data. Automation remains runQuest + waitObjectiveDone (no raw Done-only wait in ImGui).
-- 2.09: Journal prime CANNOT use mq.delay inside ImGui (non-yieldable thread). Prime only from main while-loop; GUI shows "Syncing task journal…" until primed. Fixes spam/crash "Cannot delay from non-yieldable thread".
-- 2.08: Task journal prime runs in ImGui path BEFORE getTask (open→delay→fetch→delay→close); main loop no longer primed first (GUI was reading stale TLO). Run still does full sync. Matches RedGuides TaskWnd fetch pattern.
-- 2.07: One-time TaskWnd open/close at script start + every Run so Task TLO matches journal; getTask() requires Title() match; prime Objective slot (obj()) before Done/Status. Fixes idle snapshot + resume thinking obj 1 is open when MQ data was stale.
-- 2.06: objectiveIsComplete - check Done() BEFORE Status(). Status "0/1" was returning false and skipping Done() (journal could show complete while Status lagged). Widen Status text ("done"/"complete", trailing punctuation). Wait loop debug logs Status+Done.
-- 2.05: taskHasAnyObjectiveRow - any non-nil Objective(i) counts again (Status/Instruction can be empty briefly on Live). Run preflight uses warn+return instead of fail() so script/GUI keep running.
-- 2.04: Objective completion uses Status() first ("Done" or cur/tot like 0/1); Done() as fallback. Row detection requires non-empty Status or Instruction so empty TLO slots don't count as "has quest".
-- 2.03: Require at least one Task.Objective(i) row before resuming (fixes false step 1 / Tassel when journal had no objectives). Idle + Run: no task or no rows → "Get Quest from Big Slick"; distinguish quest complete vs not started.
-- 2.02: Task/objective reads no longer require Objective(i)() truthy (fixes idle snapshot + progress when MQ leaves () false). getTask() falls back to scanning Task(1..30) by Title().
-- 2.01: Versioning - 0.01 bumps like init.lua; PP.VERSION in window title (header line is title text only).
-- 2.00: New clean objective-index runner (16 objectives), compact GUI, shared nav/plugin helpers.
--       Quest state via mq.TLO.Task (memory); TaskWnd/journal open not required for automation.
--       Status bar uses fixed 16 objective slots (ticks + X/16); dynamic scan under-counted when MQ leaves gaps.
--       On open (and while idle), Status refreshes from Task TLO - no Run required.

local mq = require('mq')
local imgui = require('ImGui')
local ImGui = imgui
local Icons = require('mq.icons')
local ImAnim = require('ImAnim')

local stopRequested = false


local PP = {
    VERSION = "3.38",
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
    --- Straight-to-PoK clicky (Plane of Knowledge gate); ~30 min reuse; not level-gated. Used when `GATE_ITEM_LADDER` contains `"stein"`. Set nil/"" to skip stein step.
    GATE_STEIN_NAME = "Drunkard's Stein",
    --- Ordered steps after Gate AA/spell: each step skipped if unusable (missing, **reuse timer**, level/mode for Slide). Reorder or omit keys to change priority. `"potions"` = `GATE_POTION_NAMES` in list order.
    GATE_ITEM_LADDER = { "stein", "zueria_slide", "potions" },
    --- Full `tryGateToPoK` item phase: allow Zueria Slide when ladder includes `zueria_slide` and mode permits (tiger/lion/gate_full). Set false to never Slide in monolithic Gate (stein + philters only).
    GATE_ITEM_PHASE_ZUERIA_SLIDE = true,
    --- Gate clickies (any match enables potion path). First **ready** item is used in order. Lore - carry one. Vial: PoK Mirao Frostpuch ~1049pp; Philter: higher-level option.
    GATE_POTION_NAMES = {
        "Philter of Major Translocation",
        "Vial of Swirling Smoke",
    },
    --- Deprecated: use GATE_POTION_NAMES. If set and GATE_POTION_NAMES is empty, treated as a one-element list.
    GATE_POTION_NAME = nil,
    --- Wizard/Druid spell (when no Gate AA); `/cast` uses this name.
    GATE_SPELL_NAME = "Gate",
    --- Gate AA: retries when "too unstable"/collapse - wait until AltAbilityReady again, then re-cast.
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
    --- Soulbinder Jera in Plane of Knowledge (same order as `/nav locyxz` - init.lua parity).
    POK_SOULBINDER_LOC = { -131.6, -94.2, -159.0 },
    --- After /nav to POK_SOULBINDER_LOC, wait until Me is this close (3D) before target + /say Bind.
    POK_SOULBINDER_MAX_DIST = 20,
    --- Max wait (ms) to reach Soulbinder loc after moving() completes.
    POK_SOULBINDER_LOC_WAIT_MS = 90000,
    --- If true (default), each Run: ensure bind is PoK (202) before TaskWnd sync and any travel to Big Slick for acquire.
    ENSURE_POK_BIND_BEFORE_RUN = true,
    MEMENTO_GROG_NAME = "Memento Grog",
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
    --- Memorize buff/invis spells only in gem slots 1..this cap (inclusive). Default 8 avoids clearing high gem indexes when NumGems() reports extra slots.
    SPELLGEM_MEM_CAP = 8,
    --- After Gate fails: wait this long for direct `/travelto` to next zone before falling back to PoK hub (ms).
    TRAVEL_DIRECT_ZONE_WAIT_MS = 120000,
    --- Objective 8 from **Neriak Commons** (Toadstool): `/easyfind <shortname>` to Foreign Quarter zone line before Gate/`/travelto` (requires MQ2EasyFind + MQ2Nav). Default false - set true if your client needs the zone-line path.
    TRAVEL_TOADSTOOL_LEAVE_EASYFIND_NERIAKA = false,
    --- Obj 8: after Toadstool, if Zueria Slide item + level - **Nektulos** port (faster than running out of Neriak), then Moors→Highpass when `TRAVEL_HIGHPASS_VIA_MOORS`.
    TRAVEL_TOADSTOOL_ZUERIA_SLIDE_TO_NEK = true,
    --- Obj 8: if Gate to PoK fails and character has **no** Gate AA and **no** Gate spell, try `/travelto moors` (Blightfire) then Highpass before PoK-hub fallback (melee / rare caster path).
    TRAVEL_TOADSTOOL_NO_GATE_USE_MOORS_FIRST = true,
    --- Obj 8 - **runners** (no Gate AA/spell), still in Neriak Commons: `/nav` to `TOADSTOOL_RUNNER_PRE_NERIAKA`, then `/travelto neriaka` (Foreign) before Gate/potion/moors. Set false to skip.
    TRAVEL_TOADSTOOL_RUNNER_PRE_NERIAKA_NAV = true,
    --- Obj 16 from NQ/SQ: if Gate to PoK fails, try **Zueria Slide** to Nektulos then `/travelto poknowledge` (faster than running through Qeynos for Slide users).
    TRAVEL_LION_ZUERIA_SLIDE_TO_NEK = true,
    --- Obj 13 from Highpass (after Tiger Roar): same Slide→Nek option before potion/direct `/travelto qeynos2` (was missing; used old monolithic Gate path only).
    TRAVEL_TIGER_ZUERIA_SLIDE_TO_NEK = true,
    --- Zone shortname for `/easyfind` (RedGuides: matches zone connection to Neriak Foreign Quarter).
    EASYFIND_NERIAKA_SHORTNAME = "neriaka",
    MOVEMENT_CLASS_BUFFS = {
        BRD = { "Selo's Accelerando", "Selo's Song of Travel" },
        BST = { "Spirit of Wolf", "Spirit of the Shrew" },
        DRU = { "Spirit of Wolf", "Spirit of Cheetah" },
        RNG = { "Spirit of Wolf" },
        SHM = { "Spirit of Wolf", "Spirit of Cheetah" },
    },
    --- Movement AA priority (AA > spell > item). Add/remove names for your class packs.
    MOVEMENT_SELF_AA_NAMES = {
        "Selo's Sonata",
        "Spirit of the White Wolf",
    },
    --- Preferred movement AA ids (Live-first). ID path is more reliable than AA name text.
    MOVEMENT_SELF_AA_IDS = {},
    --- Movement items fallback after AA/spell checks.
    MOVEMENT_ITEM_NAMES = {
        "Worn Totem",
    },
    --- Per-class spell/song **gem** invis (Live names - verify in your spellbook; script skips unknown IDs). BRD: songs (not Veil of Midnight - that name does not exist). PAL: no standard gem invis - use `INVIS_ITEM_NAMES` (e.g. Cloudy Potion).
    INVIS_CLASS_BUFFS = {
        CLR = {},
        --- Level 19 song then 51 travel song (group invis + utilities). Ranks may read as "Shauri's Sonorous Clouding II" in book - add rank-specific names if MQ buff name differs.
        BRD = {
            "Shauri's Sonorous Clouding",
            "Selo's Song of Travel",
        },
        --- Druids have no standard Invisibility spell. Camouflage line only. Best→fallback: Improved Superior Camo (Lv 48, Improved Invis - won't break on movement), Superior Camo (Lv 18), base Camo (Lv 4). Script uses first one found in spellbook.
        DRU = { "Improved Superior Camouflage", "Superior Camouflage", "Camouflage" },
        --- Superior Invisibility (verify in spellbook - typically ENC; MAG often base Invisibility only).
        ENC = { "Superior Invisibility", "Invisibility" },
        MAG = { "Invisibility" },
        --- Living invis only (not ITU). Skin of the Shadow (improved invis, ~55+) then Gather Shadows (Lv 7 unstable). Cloak of Shadows AA via INVIS_SELF_AA_NAMES when trained.
        NEC = { "Skin of the Shadow", "Gather Shadows" },
        --- Rangers: Superior Camouflage (Lv 47) preferred; base Camouflage (Lv 14) fallback.
        RNG = { "Superior Camouflage", "Camouflage" },
        SHM = { "Invisibility" },
        WIZ = { "Superior Invisibility", "Improved Invisibility", "Invisibility" },
    },
    INVIS_SELF_AA_NAMES = {
        "Perfected Invisibility",
        "Improved Invisibility",
        "Invisibility",
        --- Necro (and similar): rank 1+ gives living invis; skipped on other classes (no AA id).
        "Cloak of Shadows",
        --- DRU/RNG: Alt Act ID 80 per EQ Resource. AltAbility lookup returns 0 for classes without it - exits cleanly.
        "Innate Camouflage",
    },
    --- Preferred invis AA ids (Live-first). Used before AA-name fallback.
    INVIS_SELF_AA_IDS = {},
    INVIS_GROUP_AA_IDS = {},
    INVIS_GROUP_AA_NAMES = {
        "Group Invisibility",
        "Mass Invisibility",
        "Group Perfected Invisibility",
        "Mass Group Invisibility",
        --- DRU/RNG group camo AA: Alt Act ID 518 per EQ Resource.
        "Shared Camouflage",
    },
    --- Bard group invis AA: **Alt Act ID 231** per EQ Resource `articles.eqresource.com/altactlist.php` (Bard section lists it as "Shauri's Sonorious Clouding" - site typo; in-game name below).
    INVIS_BRD_AA_IDS = { 231 },
    --- ZAM spell/AA line name (e.g. Allakhazam `spell=51343` Shauri's Sonorous Clouding III). Used if ID path fails.
    INVIS_BRD_AA_NAMES = { "Shauri's Sonorous Clouding" },
    --- Optional item fallback after invis AA/spell checks - **order = preference** (first = tried first). **Cloudy Potion** is last; add other clicky names above it if you want them first. Skipped if not in bags, on reuse timer, or unusable. `INVIS_ITEM_LADDER` overrides this when set.
    INVIS_ITEM_NAMES = {
        "Cloudy Potion",
    },
    --- If set (non-empty table), used **instead of** `INVIS_ITEM_NAMES` for order (easier to experiment without clearing defaults).
    INVIS_ITEM_LADDER = nil,
    --- If true (default): skip invis clicky when `FindItem.Timer` not ready - try next name in list.
    INVIS_SKIP_ITEM_IF_NOT_READY = true,
    --- If true (default): skip movement item (e.g. Worn Totem) when `FindItem.Timer` not ready - avoids dropping invis for a failed click.
    MOVEMENT_SKIP_ITEM_IF_NOT_READY = true,
    --- If true, and invis is up from non-AA source, try invis AA first when ready (upgrade behavior).
    INVIS_PREFER_AA_OVER_EXISTING = true,
    --- If > 0: when invis is up, re-apply if any **tracked** buff has `Me.Buff(name).Duration.Ticks` at or below this (EQ tick ≈ 6s). 0 = never refresh by duration (only when fully dropped). PAL potion users: try 8–15 ticks (~48–90s warning).
    INVIS_REFRESH_MIN_TICKS_REMAINING = 8,
    --- Extra buff **names** to read ticks on (exact `/echo ${Me.Buff[x].Name}`). Potion effects may differ from item name - add what your client shows. Merged with class spells + `INVIS_ITEM_NAMES` for tick checks.
    INVIS_DURATION_TRACK_EXTRA_NAMES = {
        "Cloudy Potion",
    },
    --- Remove troublesome lev buffs after invis/speed upkeep.
    REMOVE_LEVITATION_BUFFS = {
        "Shauri's Levitation",
    },
    --- Highpass obj 8–12: brief pause after `ensureZone` before buffs/nav (journal/zoning rhythm). Lower = snappier NPC steps.
    HIGHPASS_ENTRY_DELAY_MS = 350,
    --- After `/keypress hail` on Quinn / Mhrai - lets journal + target clear before next loop (was 1500).
    HIGHPASS_POST_HAIL_DELAY_MS = 1200,
    --- If Me.Level < this, nav to LOC.HIGHPASS_SAFE_GATE before gating out of Highpass (low-level / KOS protection). Set 0 to disable.
    HIGHPASS_SAFE_GATE_LEVEL = 40,
    --- Tiger painting (obj 12): extra settle after `/nav`; face heading (EQ 0–512, 128 ≈ east) toward update.
    TIGER_NAV_SETTLE_MS = 1200,
    TIGER_FACE_HEADING = 128,
    TIGER_POST_FACE_DELAY_MS = 350,
    --- If still farther than this after nav, one re-/nav to reduce “stopped short” missed updates.
    TIGER_NAV_RETRY_IF_DIST_GT = 22,
    TIGER_NAV_RETRY_SETTLE_MS = 800,
    --- Buff cast retries (short to avoid long stalls).
    BUFF_CAST_MAX_RETRIES = 3,
    --- Continuous upkeep: quick periodic checks while running objectives.
    BUFF_UPKEEP_ENABLED = true,
    BUFF_UPKEEP_CHECK_MS = 300,
    BUFF_UPKEEP_AUTO_INVIS = true,

    --- Moors (395): speed + mountIfNeeded. Nektulos (25): mount + 3s pause before next /travelto. Toggle off to skip both.
    TRAVEL_POKER2_MOUNT_IN_NEK_MOORS = true,
    --- Obj 8: from PoK, /travelto moors first (zone 395), then mount pause, then Highpass - matches Poker2.lua (direct PoK→Highpass skips Moors; poker2MountDelayInNekOrMoors was a no-op). Set false for direct PoK→highpasshold only.
    TRAVEL_HIGHPASS_VIA_MOORS = true,
    --- Invis before painting nav (Tassel) and similar (init.lua: city danger legs).
    TRAVEL_INVIS_BEFORE_TASSEL = true,
    --- After Nek mount, invis before /travelto neriaka (user request; Poker2 had no invis).
    TRAVEL_INVIS_BEFORE_NERIAK = true,
    --- mountIfNeeded: never use keyring mount in Neriak Foreign/Commons (walk /nav); speed+invis applied on foot in ensureSpeedAndInvisInNeriak.
    TRAVEL_NO_MOUNT_IN_NERIAK = true,
    --- After /travelto into North or South Qeynos, refresh invis before nav to POIs.
    TRAVEL_INVIS_AFTER_QEYNOS_ZONE = true,
    --- Highpass: invis last via ensureInvisIfNeeded (skips if already up). Set false to skip invis in this helper.
    TRAVEL_INVIS_AFTER_HIGHPASS_ZONE = true,
    --- true = walk Highpass Hold (no keyring mount). false = mount before invis (default).
    TRAVEL_NO_MOUNT_IN_HIGHPASS = false,
    --- Final hail Big Slick (obj 16): match Poker2 delays + journal time to credit.
    SLICK_FINAL_POST_NAV_MS = 600,
    SLICK_FINAL_PRE_HAIL_MS = 600,
    SLICK_FINAL_POST_HAIL_MS = 3500,
    --- Extra dwell after moving() to Slick on quest-acquire path (init.lua Poker2 buffer before range check).
    SLICK_ACQUIRE_POST_NAV_BUFFER_MS = 3000,
    WAIT_OBJECTIVE_TIMEOUT_MS = 120000,
    --- Objective 1 (Tassel) - longer wait before timeout (journal lag).
    WAIT_OBJECTIVE_TIMEOUT_OBJ1_MS = 180000,
    WAIT_OBJECTIVE_TIMEOUT_FINAL_MS = 300000,
    --- 0 = off. While waiting for objective update, re-sync TaskWnd this often (helps journal lag after hail). Ignored when TASK_JOURNAL_SYNC_MODE is open_once_no_fetch.
    WAIT_JOURNAL_SYNC_MS = 15000,
    --- "open_once_no_fetch" (default): open TaskWnd once per Run; no fetch/close loop. "legacy_full": open+fetch+close each sync.
    TASK_JOURNAL_SYNC_MODE = "open_once_no_fetch",
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
        --- Neriak Commons: prep point for `/travelto neriaka` after Toadstool (runners / reliable navmesh to Foreign).
        TOADSTOOL_RUNNER_PRE_NERIAKA = { 3.53, -464.07, -10.81 },
        QUINN = { 454, -620, 22 },
        LUMBER_1 = { -442, -215, -12 },
        LUMBER_2 = { -426, -263, -12 },
        LUMBER_3 = { -408, -267, -12 },
        --- Tiger painting (obj 12): locyxz; face east (`TIGER_FACE_HEADING` 128) after nav for journal update.
        TIGER = { -126.49, 570.88, -14.46 },
        --- Safe gate spot outside Tiger room - no NPC clusters; used when Me.Level < HIGHPASS_SAFE_GATE_LEVEL. EQ /loc: -78.13, 625.50, -18.68.
        HIGHPASS_SAFE_GATE = { -78.13, 625.50, -18.68 },
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
    status = "Press Run to scan journal - quest check first, then objectives.",
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
    --- Debug toggle - show bordered in-window log (ring buffer).
    debugOpen = false,
    --- Newest lines for the Debug panel (ring buffer, max 120).
    debugLog = {},
    --- Last buff upkeep tick timestamp (mq.gettime()).
    lastBuffUpkeepTick = 0,
    --- RGMercs pause state - true if pause was sent this Run.
    rgmercPaused = false,
    --- TaskWnd open_once_no_fetch mode - opened this session.
    journalOpenedOnce = false,
    --- Progress bar live options (built once from statusBarGlobalOpts + PP overrides).
    barLiveOpts = nil,
    --- Objective bar shimmer state keyed by label.
    shimmerState = {},
    --- Commemorative coin icon texture (loaded once).
    commIconTex = nil,
    --- Mount picker: saved settings table (loaded from pickle on startup).
    ppSettings = {},
    --- Mount picker: keyring entries { name, slot, levitates } populated at startup.
    mountList = {},
    --- Mount picker: index into mountList (0 = not yet chosen).
    mountPickerIndex = 0,
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
local warn
local runBuffUpkeepTick

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
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return (source:match("^(.*)[/\\].-$") or "."):gsub("\\", "/")
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
            debugLogQuiet("Loaded atlas " .. PP.ATLAS_FILE)
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

local function sbGetObjectiveBarState(label, now)
    local state = gui.shimmerState[label]
    if not state then
        state = { lastP = 0.0, dir = 1, t0 = now }
        gui.shimmerState[label] = state
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

local function ensureObjectiveBarLive()
    if gui.barLiveOpts then return gui.barLiveOpts end
    gui.barLiveOpts = sbShallowCopy(statusBarGlobalOpts)
    for k, v in pairs(PP.PIC_TEST_BAR_OPTS) do
        gui.barLiveOpts[k] = v
    end
    return gui.barLiveOpts
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

--- Append to Debug panel only (no EQ console print).
debugLogQuiet = function(msg)
    pushDebugLine(msg, false)
end

-- Message body often started with "PPPoker:"; print already prefixes [\agPPPoker\ao].
local function stripPppokerPrefix(msg)
    local s = tostring(msg or "")
    return (s:gsub("^PPPoker:%s*", ""))
end

--- Spell names: \\ap (purple). Reset with \\ax.
local function mqSpell(name)
    return "\ap" .. tostring(name or "") .. "\ax"
end

--- Objective completion / "all done" lines (green).
local function mqObjGreen(msg)
    return "\ag" .. tostring(msg or "") .. "\ax"
end

--- Item / destination highlight: \\am (magenta). Reset with \\ax.
local function mqItem(name)
    return "\am" .. tostring(name or "") .. "\ax"
end

local function info(msg)
    local s = stripPppokerPrefix(msg)
    print(string.format("\ao[\agPPPoker\ao]\at %s\ax", s))
    pushDebugLine(s, false)
end

warn = function(msg)
    local s = stripPppokerPrefix(msg)
    print(string.format("\ao[\ayPPPoker\ao]\at %s\ax", s))
    pushDebugLine("\\ayWARN:\\at " .. s, false)
end

local function getCommemorativeCount()
    local ok, n = pcall(function() return tonumber(mq.TLO.Me.Commemoratives() or 0) end)
    if ok and n then return math.floor(n) end
    return 0
end

-- Settings Persistence

local function loadPPSettings()
    local f = loadfile(mq.configDir .. "pppoker_settings.lua")
    if not f then return end
    local ok, data = pcall(f)
    if ok and type(data) == "table" then gui.ppSettings = data end
end

local function savePPSettings()
    mq.pickle(mq.configDir .. "pppoker_settings.lua", gui.ppSettings)
end

-- Mount Picker

local function initMountList()
    local count = tonumber(mq.TLO.Mount.Count() or 0) or 0
    gui.mountList = {}
    gui.mountPickerIndex = 0
    for i = 1, count do
        local okN, name = pcall(function()
            return mq.parse(string.format("${Mount[%d].Name}", i))
        end)
        name = tostring(okN and name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" and name ~= "NULL" then
            local okL, lev = pcall(function()
                return mq.TLO.Mount(i).Item.Clicky.Spell.HasSPA(57)()
            end)
            gui.mountList[#gui.mountList + 1] = { name = name, slot = i, levitates = (okL and lev == true) }
        end
    end
    -- Restore saved choice if still in keyring
    local saved = gui.ppSettings.mountName
    if saved then
        for i, m in ipairs(gui.mountList) do
            if m.name == saved then
                gui.mountPickerIndex = i
                PP.MOUNT_KEYRING_SLOT = m.slot
                return
            end
        end
        -- Saved mount no longer in keyring - clear it
        gui.ppSettings.mountName = nil
        savePPSettings()
    end
    -- Auto-select silently when only one mount (no choice to make)
    if #gui.mountList == 1 then
        gui.mountPickerIndex = 1
        PP.MOUNT_KEYRING_SLOT = 1
    end
end

local function drawMountPicker()
    if #gui.mountList == 0 then return end
    local needsChoice = #gui.mountList > 1 and gui.mountPickerIndex == 0
    local preview = gui.mountPickerIndex > 0 and gui.mountList[gui.mountPickerIndex].name or "-- Choose Mount --"
    local yellow = getImVec4(1.0, 0.85, 0.0, 1.0)
    local orange = getImVec4(1.0, 0.45, 0.15, 1.0)
    imgui.Text("Mount:")
    imgui.SameLine()
    local previewColorPushed = false
    if needsChoice and yellow then
        pcall(function()
            imgui.PushStyleColor(ImGuiCol.Text, yellow)
            previewColorPushed = true
        end)
    end
    imgui.SetNextItemWidth(-1)
    local opened = imgui.BeginCombo("##ppMountPicker", preview)
    if previewColorPushed then
        pcall(function() imgui.PopStyleColor() end)
    end
    if opened then
        for i, m in ipairs(gui.mountList) do
            local isSelected = (gui.mountPickerIndex == i)
            local colorPushed = false
            if m.levitates and orange then
                pcall(function()
                    imgui.PushStyleColor(ImGuiCol.Text, orange)
                    colorPushed = true
                end)
            end
            local label = m.name .. (m.levitates and "  (levitates)" or "") .. "##mnt" .. i
            if imgui.Selectable(label, isSelected) then
                gui.mountPickerIndex = i
                PP.MOUNT_KEYRING_SLOT = m.slot
                gui.ppSettings.mountName = m.name
                savePPSettings()
            end
            if colorPushed then
                pcall(function() imgui.PopStyleColor() end)
            end
            if isSelected then
                pcall(function() imgui.SetItemDefaultFocus() end)
            end
            if imgui.IsItemHovered() then
                if m.levitates then
                    imgui.SetTooltip("This mount applies levitation.\nCan cause issues in some areas - choose a non-levitating mount if possible.")
                else
                    imgui.SetTooltip("No levitation - recommended for this script.")
                end
            end
        end
        imgui.EndCombo()
    end
    if needsChoice and yellow then
        pcall(function()
            imgui.TextColored(yellow, "Select a mount above before running.")
        end)
    end
end

local function drawCommemorativeCoinsRow()
    local cnt = getCommemorativeCount()
    local green = getImVec4(0.15, 0.92, 0.38, 1.0)
    pcall(function()
        if gui.commIconTex == nil and mq.FindTextureAnimation then
            local okT, tex = pcall(mq.FindTextureAnimation, "A_DragItem")
            if okT and tex then gui.commIconTex = tex end
        end
        if gui.commIconTex and gui.commIconTex.SetTextureCell and imgui.DrawTextureAnimation then
            local cell = PP.COMMEMORATIVE_ITEM_ICON_ID - PP.DRAGITEM_ICON_ATLAS_OFFSET
            gui.commIconTex:SetTextureCell(cell)
            imgui.DrawTextureAnimation(gui.commIconTex, 22, 22)
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

--- Journal completion: Required/Current counts, then Status() text. MQ datatype taskobjective has no Done member (do not reference .Done() - spams console).
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
    local t0 = mq.gettime()
    while mq.TLO.Zone.ID() ~= zoneId do
        shouldStop()
        mq.delay(500)
        if mq.gettime() - t0 > timeoutMs then
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

--- MQ2Nav: prefer ${Navigation.Active} when present (do not OR with Nav - stale Nav.Active can stuck moving()).
local function navigationIsActive()
    local ok, v = pcall(function()
        local nav = mq.TLO.Navigation or mq.TLO.Nav
        if not nav or not nav.Active then return false end
        local a = nav.Active
        return type(a) == "function" and a() or a
    end)
    if not ok or v == nil then return false end
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local s = v:lower():match("^%s*(.-)%s*$")
        return s == "true" or s == "1" or s == "on" or s == "yes" or s == "active" or s == "running"
    end
    return false
end

--- MQ2Nav: true while path is paused (/nav pause) - path kept; Active may be false while Paused is true.
local function navigationIsPaused()
    local ok, v = pcall(function()
        local nav = mq.TLO.Navigation or mq.TLO.Nav
        if not nav or not nav.Paused then return false end
        local p = nav.Paused
        return type(p) == "function" and p() or p
    end)
    if not ok or v == nil then return false end
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local s = v:lower():match("^%s*(.-)%s*$")
        return s == "true" or s == "1" or s == "on" or s == "yes" or s:find("pause", 1, true) ~= nil
    end
    return false
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
    local stuckLastX = mq.TLO.Me.X() or 0
    local stuckLastY = mq.TLO.Me.Y() or 0
    local stuckLastMoveT = mq.gettime()
    local stuckSampleT = mq.gettime()
    while navigationIsActive() or navigationIsPaused() or gui.navPaused do
        shouldStop()
        runBuffUpkeepTick("moving")
        mq.delay(100)
        -- Stuck detection: sample position every 500ms, only while nav is truly moving (not paused for buff upkeep).
        -- If position unchanged > 3 units in 3s, strafe left briefly to clear geometry clip.
        if navigationIsActive() and not navigationIsPaused() and not gui.navPaused then
            local now = mq.gettime()
            if now - stuckSampleT >= 500 then
                stuckSampleT = now
                local cx = mq.TLO.Me.X() or stuckLastX
                local cy = mq.TLO.Me.Y() or stuckLastY
                local dx, dy = cx - stuckLastX, cy - stuckLastY
                if math.sqrt(dx * dx + dy * dy) > 3 then
                    stuckLastX, stuckLastY = cx, cy
                    stuckLastMoveT = now
                elseif now - stuckLastMoveT > 3000 then
                    debugLog("Nav stuck detected - strafing left to clear geometry.")
                    mq.cmd("/keypress strafe_left hold")
                    mq.delay(500)
                    mq.cmd("/keypress strafe_left release")
                    stuckLastMoveT = now
                    stuckLastX = mq.TLO.Me.X() or cx
                    stuckLastY = mq.TLO.Me.Y() or cy
                end
            end
        end
        if (os.time() - start) * 1000 > timeoutMs then
            warn("Navigation timeout threshold reached; waiting grace period...")
            mq.delay(5000)
            if navigationIsActive() or navigationIsPaused() then
                warn("Navigation still active/paused after grace. Issuing /nav stop and continuing.")
                navStopQuiet()
                mq.delay(1200)
            end
            if navigationIsActive() or navigationIsPaused() then
                warn("Navigation still reports active/paused after /nav stop - continuing run anyway.")
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

--- FindItem.Timer: ready to `/useitem` (tick <= 1). Shared by gate pipeline (stein, philters), invis pipeline (INVIS_ITEM_NAMES), and movement pipeline (MOVEMENT_ITEM_NAMES).
local function itemClickReuseReady(itemName)
    if not itemName or tostring(itemName) == "" then
        return false
    end
    local nm = tostring(itemName)
    local okItem, item = pcall(function() return mq.TLO.FindItem(nm) end)
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

--- Use Zueria Slide to Nektulos when item + level + mode OK. Returns true if zone ID matches Nektulos.
function pppokerZueria.attemptSlideToNektulos(contextLabel)
    contextLabel = contextLabel or "Zueria Slide"
    local c = PP.ZUERIA
    local zs = pppokerZueria.refreshReadiness()
    if zs.summary then
        info(zs.summary)
    end
    if not zs.canAttemptSlide then
        debugLogQuiet(contextLabel .. " - slide skipped (no item or level).")
        return false
    end
    local slideReady = pppokerZueria.ensureTargetMode()
    if not slideReady or not slideReady:find(c.TARGET_MODE, 1, true) then
        return false
    end
    local zid = c.ZONE_ID_NEKTULOS
    info(contextLabel .. " - Zueria Slide to Nektulos.")
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
    return mq.TLO.Zone.ID() == zid
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
    pppokerZueria.attemptSlideToNektulos("After Memento Grog")
    local r = c.readiness
    if r and r.summary then
        pcall(function()
            gui.zueriaSlideInfo = tostring(r.summary)
        end)
    end
end

PP.pppokerZueria = pppokerZueria

local function pppokerSpellGemMemMax()
    local raw = tonumber(mq.TLO.Me.NumGems() or 8) or 8
    local cap = tonumber(PP.SPELLGEM_MEM_CAP)
    if cap and cap >= 1 then
        return math.min(cap, raw)
    end
    return raw
end

local function findFreeGemSlotPpp()
    local cap = pppokerSpellGemMemMax()
    for i = 1, cap do
        local gid = mq.TLO.Me.Gem(i).ID()
        if not gid or tonumber(gid or 0) == 0 then return i end
    end
    info(string.format("all gem slots full (1-%d), clearing slot %d for buff spell.", cap, cap))
    mq.cmdf("/memspell %d clear", cap)
    mq.delay(2000)
    return cap
end

local function meditateToManaPpp(requiredMana)
    requiredMana = requiredMana or 40
    if (mq.TLO.Me.CurrentMana() or 0) >= requiredMana then return end
    -- Med to 50% max mana as safety buffer - avoids repeated sit/stand cycles for each
    -- subsequent cast (invis refresh, re-gate, etc.) during the same run leg.
    local maxMana = 0
    pcall(function() maxMana = tonumber(mq.TLO.Me.MaxMana() or 0) or 0 end)
    local targetMana = math.max(requiredMana, math.floor(maxMana * 0.5))
    info(string.format("meditating for mana (need %d, have %d, target %d)...", requiredMana, mq.TLO.Me.CurrentMana() or 0, targetMana))
    mq.cmd("/sit on")
    local t0 = mq.gettime()
    local timeoutMs = 120000
    while (mq.TLO.Me.CurrentMana() or 0) < targetMana do
        shouldStop()
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

--- Detect death and click standard respawn (bind point). Returns true if the character
--- was dead and has now respawned. Called from runBuffUpkeepTick so it fires during
--- any navigation or objective-wait loop without needing a dedicated poller.
local function handleDeathIfNeeded()
    local ok, state = pcall(function() return mq.TLO.Me.State() end)
    if not ok or not state or state ~= "DEAD" then return false end
    warn("Character is dead - waiting for respawn window...")
    local t0 = mq.gettime()
    while not mq.TLO.Window("RespawnWnd").Open() do
        shouldStop()
        if mq.gettime() - t0 > 30000 then
            warn("Respawn window did not appear after 30s.")
            return false
        end
        mq.delay(500)
    end
    info("Clicking standard respawn (bind point)...")
    mq.cmd('/notify RespawnWnd RSPB_STANDARD leftmouseup')
    -- Wait until no longer dead (zone transition + state change)
    local t1 = mq.gettime()
    while true do
        shouldStop()
        local ok2, st2 = pcall(function() return mq.TLO.Me.State() end)
        if not ok2 or not st2 or st2 ~= "DEAD" then break end
        if mq.gettime() - t1 > 60000 then
            warn("Still dead after 60s - continuing anyway.")
            break
        end
        mq.delay(500)
    end
    mq.delay(2000)  -- settle after zone-in
    info("Respawned - resuming run.")
    return true
end

local function bardSeloActive()
    for i = 1, 30 do
        local s = mq.TLO.Me.Song(i).Name()
        if s and s ~= "" then
            local sl = s:lower()
            if sl:find("selo", 1, true) or sl:find("movement speed", 1, true) then
                return s
            end
        end
    end
    for i = 1, 40 do
        local b = mq.TLO.Me.Buff(i).Name()
        if b and b ~= "" then
            local bl = b:lower()
            if bl:find("selo", 1, true) or bl:find("movement speed", 1, true) then
                return b
            end
        end
    end
    return nil
end

local function pppokerMovementBuffPresent()
    -- Keyring mounts provide speed without a spell buff in the buff bar
    local okM, mountId = pcall(function() return mq.TLO.Me.Mount.ID() end)
    if okM and tonumber(mountId or 0) > 0 then return true, "mounted" end
    -- BRD: Selo songs live in the song window (Me.Song), not buff slots
    if mq.TLO.Me.Class.ShortName() == "BRD" then
        local which = bardSeloActive()
        if which then return true, which end
    end
    -- Scan buff slots for any movement speed effect (SPA 3 = SE_MovementSpeed).
    -- Handles class spells, AAs, and item clickies universally with no name lists needed.
    for i = 1, 42 do
        local buffName = mq.TLO.Me.Buff(i).Name()
        if buffName and buffName ~= "" then
            local ok, hasSpa = pcall(function()
                return mq.TLO.Spell(buffName).HasSPA(3)()
            end)
            if ok and hasSpa then return true, buffName end
        end
    end
    return false, nil
end

local function pppokerMovementAaBuffPresent()
    for _, name in ipairs(PP.MOVEMENT_SELF_AA_NAMES or {}) do
        local ok, id = pcall(function() return mq.TLO.Me.Buff(name).ID() end)
        if ok and id and tonumber(id or 0) > 0 then
            return true, name
        end
    end
    return false, nil
end

local function aaReadyById(aaId)
    aaId = tonumber(aaId or 0) or 0
    if aaId <= 0 then return false end
    local ok, out = pcall(function()
        return mq.parse(string.format("${Me.AltAbilityReady[%d]}", aaId))
    end)
    if not ok or out == nil then
        return true
    end
    local s = tostring(out):upper()
    return s == "TRUE" or s == "1" or s == "ON"
end

local function tryActivateAAById(aaId, verifyFn, label)
    aaId = tonumber(aaId or 0) or 0
    if aaId <= 0 then return false end
    if not aaReadyById(aaId) then
        return false
    end
    info((label or "AA") .. " via /alt act " .. tostring(aaId))
    mq.cmd("/alt act " .. tostring(aaId))
    mq.delay(180)
    if not verifyFn then
        return true
    end
    return waitUntilMs(3000, verifyFn)
end

local function pppokerTryActivateMovementAA(aaName)
    if not aaName or aaName == "" then return false end
    local okId, aaId = pcall(function()
        local a = mq.TLO.Me.AltAbility(aaName)
        return a and tonumber(a.ID() or 0) or 0
    end)
    if not okId or tonumber(aaId or 0) <= 0 then
        return false
    end
    local okReady, ready = pcall(function()
        local r = mq.TLO.Me.AltAbilityReady(aaName)
        return r and r()
    end)
    if not okReady or not ready then
        return false
    end
    info("movement AA: " .. aaName)
    mq.cmd("/alt act " .. tostring(aaId))
    mq.delay(250)
    return waitUntilMs(2500, function()
        local okM, has = pppokerMovementBuffPresent()
        if okM and has then return true end
        local okA, hasAa = pppokerMovementAaBuffPresent()
        return okA and hasAa
    end)
end

local function pppokerApplyMovementViaAA()
    for _, id in ipairs(PP.MOVEMENT_SELF_AA_IDS or {}) do
        if tryActivateAAById(id, function()
            local okM, has = pppokerMovementBuffPresent()
            if okM and has then return true end
            local okA, hasAa = pppokerMovementAaBuffPresent()
            return okA and hasAa
        end, "movement AA") then
            return true, "id:" .. tostring(id)
        end
    end
    for _, name in ipairs(PP.MOVEMENT_SELF_AA_NAMES or {}) do
        if pppokerTryActivateMovementAA(name) then
            return true, name
        end
    end
    return false, nil
end

local function pppokerUseMovementItemList()
    local items = PP.MOVEMENT_ITEM_NAMES or {}
    for _, item in ipairs(items) do
        if item and item ~= "" and hasItem(item) then
            if PP.MOVEMENT_SKIP_ITEM_IF_NOT_READY ~= false and not itemClickReuseReady(item) then
                info(string.format("movement item %s on reuse - skipping.", tostring(item)))
            else
            info("movement item: " .. tostring(item))
            mq.cmdf('/useitem "%s"', tostring(item))
            waitMeNotCasting(6000)
            mq.delay(200)
            local okM, has = pppokerMovementBuffPresent()
            if okM and has then
                return true, tostring(item)
            end
            end  -- reuse check else
        end
    end
    return false, nil
end

local function pppokerApplyMovementClassBuff()
    local class = mq.TLO.Me.Class.ShortName()
    local list = PP.MOVEMENT_CLASS_BUFFS[class]
    if not list then return false end
    local myLevel = tonumber(mq.TLO.Me.Level() or 0) or 0
    for _, spell in ipairs(list) do
        local spellData = mq.TLO.Spell(spell)
        if spellData and spellData.ID() and tonumber(spellData.ID() or 0) > 0 then
            local spellLevel = tonumber(spellData.MinCasterLevel() or 0) or 0
            if spellLevel > 0 and myLevel < spellLevel then
                debugLogQuiet(string.format("movement spell %s requires level %d (have %d) - skipping.", spell, spellLevel, myLevel))
            else
            local gemSlot
            local memMax = pppokerSpellGemMemMax()
            for i = 1, memMax do
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
            local maxRetries = tonumber(PP.BUFF_CAST_MAX_RETRIES) or 3
            local spellMana = math.max(40, tonumber(spellData.Mana() or 0) or 0)
            for attempt = 1, maxRetries do
                if class ~= "BRD" then
                    meditateToManaPpp(spellMana)
                end
                if mq.TLO.Me.SpellReady(spell)() then
                    mq.cmd("/target myself")
                    mq.delay(400)
                    mq.cmdf('/cast "%s"', spell)
                    local castTime = spellData.CastTime() or 5000
                    waitUntilMs(castTime + 3500, function() return not mq.TLO.Me.Casting() end)
                    mq.delay(350)
                    if class == "BRD" then
                        local active = bardSeloActive()
                        if active then
                            info(string.format("movement song active: %s", mqSpell(active)))
                            return true
                        end
                    else
                        local ok, bid = pcall(function() return mq.TLO.Me.Buff(spell).ID() end)
                        if ok and bid and tonumber(bid or 0) > 0 then
                            info(string.format("movement buff applied: %s", mqSpell(spell)))
                            return true
                        end
                    end
                    warn(string.format("%s cast did not stick (attempt %d/%d).", mqSpell(spell), attempt, maxRetries))
                else
                    mq.delay(400)
                end
            end
            end  -- level check else
        end
    end
    return false
end

local function pppokerEnsureMovementBuff(allowSpellCast)
    if allowSpellCast == nil then allowSpellCast = true end
    local hasM, which = pppokerMovementBuffPresent()
    if hasM then return true, which end
    local hasAA, aaWhich = pppokerMovementAaBuffPresent()
    if hasAA then return true, aaWhich end
    local aaOk, aaUsed = pppokerApplyMovementViaAA()
    if aaOk then return true, aaUsed or "movement AA" end
    if allowSpellCast and pppokerApplyMovementClassBuff() then return true, "class spell" end
    local itemOk, itemUsed = pppokerUseMovementItemList()
    if itemOk then return true, itemUsed end
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

--- `${Me.Sneaking}` - TRUE while rogue sneak is up.
local function pppokerRogueSneakingTLO()
    local ok, v = pcall(function()
        local t = mq.TLO.Me.Sneaking
        if t == nil then return false end
        if type(t) == "function" then return t() end
        return t
    end)
    return ok and pppokerMqBool(v)
end

--- `${Me.Hidden}` - TRUE while rogue hide is up (primary stealth state for /doability Hide).
local function pppokerRogueHiddenTLO()
    local ok, v = pcall(function()
        local t = mq.TLO.Me.Hidden
        if t == nil then return false end
        if type(t) == "function" then return t() end
        return t
    end)
    return ok and pppokerMqBool(v)
end

--- `${Me.AbilityReady["Sneak"]}` / `["Hide"]` - skill off cooldown; nil if TLO missing.
local function pppokerAbilityReady(abilityName)
    local ok, r = pcall(function()
        local ar = mq.TLO.Me.AbilityReady(abilityName)
        if ar == nil then return nil end
        if type(ar) == "function" then return ar() end
        return ar
    end)
    if not ok then return nil end
    if r == true then return true end
    if r == false then return false end
    return nil
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

--- MQ buff time remaining: `${Me.Buff[name].Duration.Ticks}` (6s/tick Live). Nil if unknown / shortbuff / API gap.
local function pppokerBuffTicksRemainingByName(buffName)
    if not buffName or buffName == "" then
        return nil
    end
    local ok, ticks = pcall(function()
        local b = mq.TLO.Me.Buff(buffName)
        if not b or not b() then
            return nil
        end
        local d = b.Duration
        if type(d) == "function" then
            d = d()
        end
        if d == nil then
            return nil
        end
        local t = d.Ticks
        if type(t) == "function" then
            return tonumber(t())
        end
        return tonumber(t)
    end)
    if ok and ticks ~= nil then
        return tonumber(ticks)
    end
    return nil
end

local function pppokerInvisCollectTrackableBuffNames()
    local seen = {}
    local out = {}
    local function add(n)
        if not n or n == "" or seen[n] then
            return
        end
        seen[n] = true
        out[#out + 1] = n
    end
    local class = mq.TLO.Me.Class.ShortName()
    for _, n in ipairs(PP.INVIS_CLASS_BUFFS[class] or {}) do
        add(n)
    end
    for _, n in ipairs(PP.INVIS_BRD_AA_NAMES or {}) do
        add(n)
    end
    for _, n in ipairs(PP.INVIS_SELF_AA_NAMES) do
        add(n)
    end
    for _, n in ipairs(PP.INVIS_GROUP_AA_NAMES) do
        add(n)
    end
    for _, n in ipairs(PP.INVIS_ITEM_NAMES or {}) do
        add(n)
    end
    for _, n in ipairs(PP.INVIS_DURATION_TRACK_EXTRA_NAMES or {}) do
        add(n)
    end
    return out
end

local pppokerInvisBuffPresent

--- True if invis appears up but a tracked buff is at or below tick threshold (fading soon). ROG skipped (Hide ticks unreliable here).
local function pppokerInvisFadingBelowTicks(minTicks)
    if not minTicks or tonumber(minTicks) <= 0 then
        return false
    end
    local mt = tonumber(minTicks)
    if mq.TLO.Me.Class.ShortName() == "ROG" then
        return false
    end
    if not pppokerInvisBuffPresent() then
        return false
    end
    local foundTracked = false
    for _, name in ipairs(pppokerInvisCollectTrackableBuffNames()) do
        if pppokerInvisBuffIdByName(name) then
            foundTracked = true
            local ticks = pppokerBuffTicksRemainingByName(name)
            if ticks ~= nil and ticks <= mt then
                return true
            end
        end
    end
    if not foundTracked then
        -- Invis from Me.Invis / Invisible only - no named buff to read
        return false
    end
    return false
end

local function pppokerInvisKnownAaBuffPresent()
    local class = mq.TLO.Me.Class.ShortName()
    if class == "BRD" then
        for _, name in ipairs(PP.INVIS_BRD_AA_NAMES or {}) do
            if pppokerInvisBuffIdByName(name) then return true, name end
        end
    end
    for _, name in ipairs(PP.INVIS_SELF_AA_NAMES) do
        if pppokerInvisBuffIdByName(name) then return true, name end
    end
    for _, name in ipairs(PP.INVIS_GROUP_AA_NAMES) do
        if pppokerInvisBuffIdByName(name) then return true, name end
    end
    return false, nil
end

pppokerInvisBuffPresent = function()
    local class = mq.TLO.Me.Class.ShortName()
    if class == "ROG" then
        if pppokerRogueHiddenTLO() then return true, "Hide" end
        if pppokerRogueSneakingTLO() then return true, "Sneak" end
        if pppokerLivingInvisTLO() then return true, "Invis(1)" end
        if pppokerInvisibleTLO() then return true, "Hide/Sneak" end
        return false, nil
    end
    local list = PP.INVIS_CLASS_BUFFS[class] or {}
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

--- Caster `AltAbility("Invisibility")` resolves; Bard uses different AA names - use `INVIS_BRD_AA_NAMES` first for BRD.
local function pppokerInvisAaSelfNameList()
    local class = mq.TLO.Me.Class.ShortName()
    if class == "BRD" then
        local out = {}
        for _, n in ipairs(PP.INVIS_BRD_AA_NAMES or {}) do
            if n and n ~= "" then out[#out + 1] = n end
        end
        for _, n in ipairs(PP.INVIS_SELF_AA_NAMES or {}) do
            if n and n ~= "" then out[#out + 1] = n end
        end
        return out
    end
    return PP.INVIS_SELF_AA_NAMES or {}
end

local function pppokerSongOrSpellReady(class, spellName)
    if class == "BRD" then
        local ok, r = pcall(function()
            local sr = mq.TLO.Me.SongReady(spellName)
            return sr and sr()
        end)
        return ok and r
    end
    local ok, r = pcall(function()
        local sr = mq.TLO.Me.SpellReady(spellName)
        return sr and sr()
    end)
    return ok and r
end

local function pppokerApplyInvisViaAA()
    local class = mq.TLO.Me.Class.ShortName()
    if class == "ROG" then return false end
    if class == "BRD" then
        for _, id in ipairs(PP.INVIS_BRD_AA_IDS or {}) do
            if tryActivateAAById(id, function()
                return pppokerLivingInvisTLO() or pppokerInvisibleTLO()
            end, "Bard invis AA") then
                return true
            end
        end
    end
    for _, id in ipairs(PP.INVIS_SELF_AA_IDS or {}) do
        if tryActivateAAById(id, function()
            return pppokerLivingInvisTLO() or pppokerInvisibleTLO()
        end, "invis AA") then
            return true
        end
    end
    for _, id in ipairs(PP.INVIS_GROUP_AA_IDS or {}) do
        if tryActivateAAById(id, function()
            return pppokerLivingInvisTLO() or pppokerInvisibleTLO()
        end, "group invis AA") then
            return true
        end
    end
    for _, name in ipairs(pppokerInvisAaSelfNameList()) do
        if pppokerTryActivateInvisAA(name) then return true end
    end
    for _, name in ipairs(PP.INVIS_GROUP_AA_NAMES) do
        if pppokerTryActivateInvisAA(name) then return true end
    end
    return false
end

local function pppokerHasReadyInvisAA()
    if mq.TLO.Me.Class.ShortName() == "BRD" then
        for _, id in ipairs(PP.INVIS_BRD_AA_IDS or {}) do
            if aaReadyById(id) then return true end
        end
    end
    for _, id in ipairs(PP.INVIS_SELF_AA_IDS or {}) do
        if aaReadyById(id) then return true end
    end
    for _, id in ipairs(PP.INVIS_GROUP_AA_IDS or {}) do
        if aaReadyById(id) then return true end
    end
    for _, name in ipairs(pppokerInvisAaSelfNameList()) do
        local ready = pppokerInvisAAReady(name)
        if ready == true then return true end
    end
    for _, name in ipairs(PP.INVIS_GROUP_AA_NAMES or {}) do
        local ready = pppokerInvisAAReady(name)
        if ready == true then return true end
    end
    return false
end

local function pppokerRogueSneakHide()
    if pppokerRogueHiddenTLO()
        or pppokerRogueSneakingTLO()
        or pppokerLivingInvisTLO()
        or pppokerInvisibleTLO()
    then
        return true
    end
    if not pppokerRogueSneakingTLO() then
        local sneakReady = pppokerAbilityReady("Sneak")
        if sneakReady ~= false then
            info("ROG - Sneak (not already sneaking).")
            mq.cmd("/doability Sneak")
            mq.delay(800)
        end
    end
    if pppokerRogueHiddenTLO()
        or pppokerLivingInvisTLO()
        or pppokerInvisibleTLO()
    then
        return true
    end
    if not pppokerRogueHiddenTLO() then
        local hideReady = pppokerAbilityReady("Hide")
        if hideReady ~= false then
            info("ROG - Hide (not already hidden).")
            mq.cmd("/doability Hide")
            mq.delay(1500)
        else
            debugLogQuiet("ROG - Hide on cooldown; skipping /doability Hide.")
        end
    end
    return pppokerRogueHiddenTLO() or pppokerInvisibleTLO()
end

local function pppokerApplyInvisClassBuff()
    local class = mq.TLO.Me.Class.ShortName()
    if class == "ROG" then
        if pppokerRogueHiddenTLO() or pppokerInvisibleTLO() then return true end
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
    local myLevel = tonumber(mq.TLO.Me.Level() or 0) or 0
    for _, spell in ipairs(list) do
        local spellData = mq.TLO.Spell(spell)
        if spellData and spellData.ID() and tonumber(spellData.ID() or 0) > 0 then
            local spellLevel = tonumber(spellData.MinCasterLevel() or 0) or 0
            if spellLevel > 0 and myLevel < spellLevel then
                debugLogQuiet(string.format("invis spell %s requires level %d (have %d) - skipping.", spell, spellLevel, myLevel))
            else
            local gemSlot
            local memMax = pppokerSpellGemMemMax()
            for i = 1, memMax do
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
            local maxRetries = tonumber(PP.BUFF_CAST_MAX_RETRIES) or 3
            local spellMana = math.max(40, tonumber(spellData.Mana() or 0) or 0)
            for attempt = 1, maxRetries do
                meditateToManaPpp(spellMana)
                if pppokerSongOrSpellReady(class, spell) then
                    mq.cmd("/target myself")
                    mq.delay(400)
                    mq.cmdf('/cast "%s"', spell)
                    local castTime = spellData.CastTime() or 5000
                    waitUntilMs(castTime + 3500, function() return not mq.TLO.Me.Casting() end)
                    mq.delay(350)
                    local ok, bid = pcall(function() return mq.TLO.Me.Buff(spell).ID() end)
                    if ok and bid and tonumber(bid or 0) > 0 then
                        info(string.format("invis buff applied: %s", mqSpell(spell)))
                        return true
                    end
                    warn(string.format("invis %s did not stick (attempt %d/%d).", mqSpell(spell), attempt, maxRetries))
                else
                    mq.delay(400)
                end
            end
            end  -- level check else
        end
    end
    return false
end

local function pppokerInvisItemNamesOrdered()
    local t = PP.INVIS_ITEM_LADDER
    if type(t) == "table" and #t > 0 then
        return t
    end
    return PP.INVIS_ITEM_NAMES or {}
end

local function pppokerApplyInvisItem()
    for _, item in ipairs(pppokerInvisItemNamesOrdered()) do
        if item and item ~= "" then
            if not hasItem(item) then
                -- missing or level/class cannot use - try next
            elseif PP.INVIS_SKIP_ITEM_IF_NOT_READY ~= false and not itemClickReuseReady(item) then
                info(string.format("invis item %s on reuse - next in list.", tostring(item)))
            else
                info("invis item: " .. tostring(item))
                mq.cmdf('/useitem "%s"', tostring(item))
                waitMeNotCasting(6000)
                mq.delay(200)
                if pppokerLivingInvisTLO() or pppokerInvisibleTLO() then
                    return true, tostring(item)
                end
            end
        end
    end
    return false, nil
end

local function removeLevitationBuffsIfPresent()
    for _, buffName in ipairs(PP.REMOVE_LEVITATION_BUFFS or {}) do
        if buffName and buffName ~= "" then
            local ok, id = pcall(function() return mq.TLO.Me.Buff(buffName).ID() end)
            if ok and id and tonumber(id or 0) > 0 then
                info("removing lev buff: " .. tostring(buffName))
                mq.cmdf('/removebuff "%s"', tostring(buffName))
                mq.delay(80)
            end
        end
    end
end

local function pppokerEnsureInvisBuff(allowSpellCast)
    if allowSpellCast == nil then allowSpellCast = true end
    local ok, which = pppokerInvisBuffPresent()
    if ok then return true, which end
    if pppokerApplyInvisViaAA() then return true, "AA" end
    if allowSpellCast and pppokerApplyInvisClassBuff() then return true, "spell" end
    local itemOk, itemWhich = pppokerApplyInvisItem()
    if itemOk then return true, itemWhich end
    if pppokerLivingInvisTLO() then return true, "Invis(1) TLO" end
    if pppokerInvisibleTLO() then return true, "Invisible TLO" end
    return false, nil
end

--- Apply invis only if not already present (avoids duplicate casts after preflight / Tassel prep).
local function ensureInvisIfNeeded(label)
    local invOk, invWhich = pppokerInvisBuffPresent()
    local minT = tonumber(PP.INVIS_REFRESH_MIN_TICKS_REMAINING) or 0
    if invOk and minT > 0 and pppokerInvisFadingBelowTicks(minT) then
        info(string.format(
            "invis fading (≤%d ticks) - refreshing (%s).",
            minT,
            tostring(label)
        ))
        pppokerEnsureInvisBuff()
        removeLevitationBuffsIfPresent()
        waitUntilMs(8000, function()
            return not mq.TLO.Me.Casting()
        end)
        mq.delay(300)
        return true
    end
    if invOk then
        if PP.INVIS_PREFER_AA_OVER_EXISTING ~= false then
            local aaBuffUp = pppokerInvisKnownAaBuffPresent()
            if not aaBuffUp and pppokerHasReadyInvisAA() then
                info(string.format(
                    "invis up (%s), but AA ready - upgrading invis via AA (%s).",
                    mqSpell(tostring(invWhich or "?")),
                    tostring(label)
                ))
                pppokerApplyInvisViaAA()
                removeLevitationBuffsIfPresent()
                return true
            end
        end
        info(string.format("invis already up (%s) - skip recast (%s).", mqSpell(tostring(invWhich or "?")), tostring(label)))
        return true
    end
    debugLogQuiet("invis - " .. tostring(label))
    pppokerEnsureInvisBuff()
    removeLevitationBuffsIfPresent()
    waitUntilMs(8000, function()
        return not mq.TLO.Me.Casting()
    end)
    mq.delay(300)
    return true
end

runBuffUpkeepTick = function(contextLabel)
    if PP.BUFF_UPKEEP_ENABLED == false then
        return
    end
    if not gui.running then
        return
    end
    local now = mq.gettime()
    local everyMs = tonumber(PP.BUFF_UPKEEP_CHECK_MS) or 1200
    if now - gui.lastBuffUpkeepTick < everyMs then
        return
    end
    gui.lastBuffUpkeepTick = now
    if handleDeathIfNeeded() then return end  -- respawned; skip buff checks this tick
    local navMoving = navigationIsActive() or navigationIsPaused() or gui.navPaused
    -- Determine what needs applying.
    -- Read invis state once - movement items (Worn Totem) drop invis, so order matters:
    -- skip movement if invis is up; when invis drops the next tick applies movement then invis.
    local invOk = pppokerInvisBuffPresent()
    local movOk = pppokerMovementBuffPresent()
    -- Movement needed only when both are missing (invis up = skip so Worn Totem can't drop it).
    local needMovement = not movOk and not invOk
    local needInvis = false
    if PP.BUFF_UPKEEP_AUTO_INVIS ~= false then
        local minT = tonumber(PP.INVIS_REFRESH_MIN_TICKS_REMAINING) or 0
        needInvis = not invOk or (invOk and minT > 0 and pppokerInvisFadingBelowTicks(minT))
    end
    if (needMovement or needInvis) and not buffsApplyingNow then
        -- Pause nav so MQ2Nav stops sending movement commands that interrupt spell/item casts.
        buffsApplyingNow = true
        if navMoving then
            mq.cmd('/nav pause')
            mq.delay(200)
        end
        if needMovement then
            pppokerEnsureMovementBuff(true)
        end
        if needInvis then
            if invOk then
                debugLogQuiet("upkeep invis fading - " .. tostring(contextLabel))
            elseif contextLabel then
                debugLogQuiet("upkeep invis - " .. tostring(contextLabel))
            end
            pppokerEnsureInvisBuff(true)
        end
        removeLevitationBuffsIfPresent()
        if navMoving then
            mq.cmd('/nav pause off')
        end
        buffsApplyingNow = false
    else
        removeLevitationBuffsIfPresent()
    end
end

--- Speed buff + optional invis before navigating to Tassel painting.
local function prepBeforeTasselLeg()
    pppokerEnsureMovementBuff()
    if PP.TRAVEL_INVIS_BEFORE_TASSEL then
        ensureInvisIfNeeded("Tassel painting (before /nav)")
    end
end

local function prepCityTravel(whereLabel, zoneId)
    if not PP.TRAVEL_CITY_PREP_BEFORE_ZONE then return end
    whereLabel = whereLabel or "city zone"
    local needsPreInvis = tonumber(zoneId or 0) == PP.ZONE.NERIAK_A
        or tonumber(zoneId or 0) == PP.ZONE.NERIAK_B
    debugLogQuiet("prep for " .. whereLabel .. " - movement speed" .. (needsPreInvis and " + invis before zone-in." or " only."))
    local movOk, movDetail = pppokerEnsureMovementBuff()
    if movOk then
        debugLogQuiet("movement OK (" .. tostring(movDetail or "?") .. ").")
    else
        warn("movement buff missing - use SoW/Selo/totem manually.")
    end
    waitUntilMs(8000, function() return not mq.TLO.Me.Casting() end)
    mq.delay(300)
    -- Apply invis before entering Neriak - guards at zone-in are lethal for low-level characters
    if needsPreInvis and PP.TRAVEL_INVIS_BEFORE_NERIAK then
        ensureInvisIfNeeded(whereLabel .. " (before zone-in)")
    end
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
            warn("Mount: still not mounted after wait - continuing (may move before mount completes).")
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
        debugLogQuiet(string.format("Already in %s (%d), skipping /travelto.", tostring(label), zoneId))
        return
    end
    if PP.TRAVEL_CITY_PREP_BEFORE_ZONE and zoneWantsCityPrep(zoneId) then
        prepCityTravel(tostring(label), zoneId)
    end
    info("Traveling to " .. mqItem(tostring(label)) .. ".")
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
    local ok, my, mx, mz = pcall(function()
        return mq.TLO.Me.Y(), mq.TLO.Me.X(), mq.TLO.Me.Z()
    end)
    if not ok then
        return 99999
    end
    local dy, dx, dz = (my or 0) - loc[1], (mx or 0) - loc[2], (mz or 0) - loc[3]
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
    info("Please Start in PoK - not bound to Plane of Knowledge; travelling to Soulbinder Jera to bind.")
    warn("No PoK bind; travelling to Plane of Knowledge to bind with Soulbinder Jera...")
    if mq.TLO.Zone.ID() ~= PP.GATE_ZONE_ID then
        mq.cmdf("/squelch /travelto %s", PP.POK_TRAVEL_SHORTNAME or "poknowledge")
        zoning(PP.GATE_ZONE_ID)
    end
    mq.delay(1000)
    local loc = PP.POK_SOULBINDER_LOC
    if not loc or not loc[1] then
        warn("POK_SOULBINDER_LOC missing - skip Soulbinder nav.")
        return
    end
    mq.cmdf("/squelch /nav locyxz %.1f %.1f %.1f", loc[1], loc[2], loc[3])
    moving()
    local maxD = tonumber(PP.POK_SOULBINDER_MAX_DIST) or 20
    local waitMs = tonumber(PP.POK_SOULBINDER_LOC_WAIT_MS) or 90000
    info(string.format("waiting at Soulbinder loc (within %d) before target...", maxD))
    if not waitNearLocYXZ(loc, maxD, waitMs) then
        warn("did not reach Soulbinder loc within distance - attempting target anyway.")
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

local function gatePotionNamesList()
    local t = PP.GATE_POTION_NAMES
    if type(t) == "table" and #t > 0 then
        return t
    end
    local single = PP.GATE_POTION_NAME
    if single and tostring(single) ~= "" then
        return { tostring(single) }
    end
    return { "Philter of Major Translocation" }
end

local function hasGatePotion()
    for _, n in ipairs(gatePotionNamesList()) do
        local ok, found = pcall(function() return mq.TLO.FindItem(n)() end)
        if ok and found then return true end
    end
    return false
end

local function gateSteinName()
    local n = PP.GATE_STEIN_NAME
    if not n or tostring(n) == "" then
        return nil
    end
    return tostring(n)
end

local function hasGateStein()
    local n = gateSteinName()
    if not n then
        return false
    end
    return hasItem(n)
end

local function hasZueriaSlideForGateLadder()
    local zs = pppokerZueria.refreshReadiness()
    return zs.canAttemptSlide
end

--- Stein, philters, or Zueria Slide item+level - any enables the Gate item phase.
local function hasAnyGateItemPath()
    return hasGateStein() or hasGatePotion() or hasZueriaSlideForGateLadder()
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

--- Poll until checkFn() returns true, already in gate zone, or timeout. Shared by AA, spell, and item waits.
local function waitUntilGateReady(checkFn, label, maxMs)
    maxMs = maxMs or (PP.GATE_WAIT_READY_MS or 240000)
    local poll = PP.GATE_READY_POLL_MS or 250
    local t0 = mq.gettime()
    if checkFn() then return true end
    info(label)
    while mq.gettime() - t0 < maxMs do
        shouldStop()
        if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then return true end
        if checkFn() then return true end
        mq.delay(poll)
    end
    return checkFn()
end

local function waitUntilGatePotionReady(potionName, maxMs)
    maxMs = maxMs or (PP.GATE_WAIT_READY_MS or 240000)
    local poll = PP.GATE_READY_POLL_MS or 250
    local t0 = mq.gettime()
    if itemClickReuseReady(potionName) then return true end
    info("waiting for gate potion item timer (reuse)...")
    while mq.gettime() - t0 < maxMs do
        shouldStop()
        if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then return true end
        if not mq.TLO.FindItem(potionName)() then return false end
        if itemClickReuseReady(potionName) then return true end
        mq.delay(poll)
    end
    return itemClickReuseReady(potionName)
end

--- After a gate cast ends without zoning: poll for zone success OR checkReadyFn() firing.
--- Exits early when the gate ability/gem/item becomes ready again (fizzle/collapse resolved),
--- instead of sitting out the full zoneWaitMs. maxMs is only the safety cap.
local function waitZonedOrGateReady(checkReadyFn, zoneId, maxMs)
    local poll = PP.GATE_READY_POLL_MS or 250
    maxMs = maxMs or (PP.GATE_ZONE_WAIT_MS or 90000)
    local t0 = mq.gettime()
    while mq.gettime() - t0 < maxMs do
        shouldStop()
        if mq.TLO.Zone.ID() == zoneId then
            return true
        end
        if checkReadyFn() then
            return false  -- ready to retry (fizzle/collapse resolved)
        end
        mq.delay(poll)
    end
    return mq.TLO.Zone.ID() == zoneId
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

--- From Neriak Commons (Toadstool): EasyFind nearest zone connection to Neriak Foreign (`neriaka`), then wait for zone / nav (RedGuides `/easyfind` + zone shortname).
local function easyfindNeriakForeignFromCommonsIfNeeded()
    if PP.TRAVEL_TOADSTOOL_LEAVE_EASYFIND_NERIAKA == false then
        return
    end
    if mq.TLO.Zone.ID() ~= PP.ZONE.NERIAK_B then
        return
    end
    local short = tostring(PP.EASYFIND_NERIAKA_SHORTNAME or "neriaka"):gsub("^%s+", ""):gsub("%s+$", "")
    if short == "" then
        return
    end
    info("EasyFind: zone connection to Neriak Foreign Quarter (" .. short .. ") - then Gate or /travelto.")
    mq.cmdf("/squelch /easyfind %s", short)
    moving(180000)
    if mq.TLO.Zone.ID() == PP.ZONE.NERIAK_A then
        return
    end
    info("Waiting to zone into Neriak Foreign Quarter after EasyFind...")
    waitForZoneOrFalse(PP.ZONE.NERIAK_A, 120000)
end

--- Drunkard's Stein - if in inventory but **on reuse timer**, skip (no long wait) so ladder can try Slide/philters.
local function tryGateSteinToPoK()
    local stein = gateSteinName()
    if not stein or not mq.TLO.FindItem(stein)() then
        return false
    end
    if not itemClickReuseReady(stein) then
        info(string.format("%s on reuse - next gate item (Slide/philter).", stein))
        return false
    end
    local waitReadyMs = PP.GATE_WAIT_READY_MS or 240000
    local zoneWaitMs = PP.GATE_ZONE_WAIT_MS or 90000
    local postPotionWait = PP.GATE_POST_POTION_EXTRA_WAIT_MS or 2200
    local retryBackoff = PP.GATE_RETRY_BACKOFF_MS or 1200
    local potionAttempts = PP.GATE_POTION_ATTEMPTS or 4
    for p = 1, potionAttempts do
        shouldStop()
        if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
            return true
        end
        if not mq.TLO.FindItem(stein)() then
            return false
        end
        if not itemClickReuseReady(stein) then
            if not waitUntilGatePotionReady(stein, waitReadyMs) then
                break
            end
        end
        if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
            return true
        end
        if PP.TRAVEL_DISMOUNT_BEFORE_GATE then
            dismountIfMounted("Gate stein")
        end
        info(string.format("%s to PoK (attempt %d/%d).", stein, p, potionAttempts))
        mq.cmd('/useitem "' .. stein .. '"')
        mq.delay(600)
        if waitCastClearOrZoned(PP.GATE_ZONE_ID, 60000) then
            return true
        end
        mq.delay(postPotionWait)
        if waitZonedOrGateReady(function() return itemClickReuseReady(stein) end, PP.GATE_ZONE_ID, zoneWaitMs) then
            return true
        end
        warn(string.format("%s did not reach PoK - waiting for item timer.", stein))
        mq.delay(retryBackoff)
        if not waitUntilGatePotionReady(stein, waitReadyMs) then
            break
        end
    end
    return mq.TLO.Zone.ID() == PP.GATE_ZONE_ID
end

--- Philter / Vial list - **skip** entries on reuse timer (try next name); wait only between retries of the **same** clicky after a failed attempt.
local function tryGatePotionsClickiesToPoK()
    if not hasGatePotion() then
        return false
    end
    local waitReadyMs = PP.GATE_WAIT_READY_MS or 240000
    local zoneWaitMs = PP.GATE_ZONE_WAIT_MS or 90000
    local postPotionWait = PP.GATE_POST_POTION_EXTRA_WAIT_MS or 2200
    local retryBackoff = PP.GATE_RETRY_BACKOFF_MS or 1200
    local potionAttempts = PP.GATE_POTION_ATTEMPTS or 4
    for _, potionName in ipairs(gatePotionNamesList()) do
        if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
            return true
        end
        if not mq.TLO.FindItem(potionName)() then
            -- not in inventory / unusable - next
        elseif not itemClickReuseReady(potionName) then
            info(string.format("%s on reuse - trying next gate clicky.", potionName))
        else
            for p = 1, potionAttempts do
                shouldStop()
                if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                    return true
                end
                if not mq.TLO.FindItem(potionName)() then
                    break
                end
                if not itemClickReuseReady(potionName) then
                    if not waitUntilGatePotionReady(potionName, waitReadyMs) then
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
                if waitZonedOrGateReady(function() return itemClickReuseReady(potionName) end, PP.GATE_ZONE_ID, zoneWaitMs) then
                    return true
                end
                warn(string.format("%s did not reach PoK (fail/collapse) - waiting for item timer.", potionName))
                mq.delay(retryBackoff)
                if not waitUntilGatePotionReady(potionName, waitReadyMs) then
                    break
                end
            end
        end
    end
    return mq.TLO.Zone.ID() == PP.GATE_ZONE_ID
end

--- Gate AA then Gate spell only (no potions). Used to enforce AA→Spell→Item→Potion→Run ordering.
local function tryGateToPoK_AAorSpellOnly()
    if PP.TRAVEL_DISMOUNT_BEFORE_GATE then
        dismountIfMounted("Gate")
    end
    if mq.TLO.Me.ZoneBound.ID() ~= PP.GATE_ZONE_ID then
        return false
    end
    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end

    local maxAttempts = PP.GATE_MAX_ATTEMPTS or 12
    local waitReadyMs = PP.GATE_WAIT_READY_MS or 240000
    local zoneWaitMs = PP.GATE_ZONE_WAIT_MS or 90000
    local postCastWait = PP.GATE_POST_CAST_EXTRA_WAIT_MS or 2000
    local retryBackoff = PP.GATE_RETRY_BACKOFF_MS or 1200
    local spellName = PP.GATE_SPELL_NAME or "Gate"

    if hasGateAA() then
        for attempt = 1, maxAttempts do
            shouldStop()
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if not gateAltAbilityReady() then
                if not waitUntilGateReady(gateAltAbilityReady, "waiting for Gate AA to become ready again (collapse/cooldown)...", waitReadyMs) then
                    warn("Gate AA did not become ready in time - skipping AA.")
                    break
                end
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
            if waitZonedOrGateReady(gateAltAbilityReady, PP.GATE_ZONE_ID, zoneWaitMs) then
                return true
            end
            mq.delay(retryBackoff)
        end
    end

    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end

    if hasGateSpell() then
        local gateSpellMana = math.max(40, tonumber(mq.TLO.Spell(spellName).Mana() or 0) or 0)
        for attempt = 1, maxAttempts do
            shouldStop()
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if not gateSpellReady() then
                if not waitUntilGateReady(gateSpellReady, "waiting for Gate spell to be ready (gem/recast)...", waitReadyMs) then
                    warn("Gate spell did not become ready in time - skipping spell.")
                    break
                end
            end
            meditateToManaPpp(gateSpellMana)
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
            if waitZonedOrGateReady(gateSpellReady, PP.GATE_ZONE_ID, zoneWaitMs) then
                return true
            end
            mq.delay(retryBackoff)
        end
    end

    return mq.TLO.Zone.ID() == PP.GATE_ZONE_ID
end

--- Forward declarations (mutual: item phase ↔ after-slide travel).
local tryGateItemPhaseToPoK
local tryGateToPoKAfterZueriaSlide
local tryGateToPoKAfterZueriaSlideOrTravel

--- After Zueria Slide to Nektulos: AA → spell → `GATE_ITEM_LADDER` with Slide step inactive (`none`).
tryGateToPoKAfterZueriaSlide = function()
    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end
    if tryGateToPoK_AAorSpellOnly() then
        return true
    end
    return tryGateItemPhaseToPoK("none")
end

--- Slide landed in Nek - Gate to PoK or `/travelto poknowledge`.
tryGateToPoKAfterZueriaSlideOrTravel = function()
    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end
    if tryGateToPoKAfterZueriaSlide() then
        return true
    end
    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end
    warn("After Zueria Slide - Gate to PoK unavailable or failed; /travelto " .. tostring(PP.POK_TRAVEL_SHORTNAME or "poknowledge") .. ".")
    mq.cmdf("/squelch /travelto %s", PP.POK_TRAVEL_SHORTNAME or "poknowledge")
    if not waitForZoneOrFalse(PP.GATE_ZONE_ID, 180000) then
        fail("Could not reach Plane of Knowledge after Nektulos.")
    end
    return true
end

--- Zueria Slide allowed for this travel mode (tiger/lion/monolithic gate_full).
local function gateItemPhaseZueriaSlideEnabled(zueriaMode)
    if zueriaMode == "gate_full" and PP.GATE_ITEM_PHASE_ZUERIA_SLIDE ~= false then
        return true
    end
    if zueriaMode == "tiger" and PP.TRAVEL_TIGER_ZUERIA_SLIDE_TO_NEK ~= false then
        return true
    end
    if zueriaMode == "lion" and PP.TRAVEL_LION_ZUERIA_SLIDE_TO_NEK ~= false then
        return true
    end
    return false
end

--- Item phase: `PP.GATE_ITEM_LADDER` order (default stein → zueria_slide → potions). Skip step if unusable; stein/philter skip reuse without blocking Slide.
tryGateItemPhaseToPoK = function(zueriaMode)
    zueriaMode = zueriaMode or "none"
    local ladder = PP.GATE_ITEM_LADDER or { "stein", "zueria_slide", "potions" }
    local slideEnabled = gateItemPhaseZueriaSlideEnabled(zueriaMode)
    for _, step in ipairs(ladder) do
        if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
            return true
        end
        local s = tostring(step or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if s == "stein" or s == "gate_stein" or s == "drunkard" or s == "drunkard_stein" then
            if tryGateSteinToPoK() then
                return true
            end
        elseif s == "zueria_slide" or s == "slide" or s == "zueria" then
            if slideEnabled then
                local label = "Gate pipeline → Nektulos (Zueria Slide)"
                if zueriaMode == "tiger" then
                    label = "Tiger Roar → Nektulos (Zueria Slide)"
                elseif zueriaMode == "lion" then
                    label = "Lion's Mane → Nektulos (Zueria Slide)"
                end
                if pppokerZueria.attemptSlideToNektulos(label) then
                    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                        return true
                    end
                    return tryGateToPoKAfterZueriaSlideOrTravel()
                end
            end
        elseif s == "potions" or s == "gate_potions" or s == "philters" or s == "potion" then
            if tryGatePotionsClickiesToPoK() then
                return true
            end
        end
    end
    return mq.TLO.Zone.ID() == PP.GATE_ZONE_ID
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
    local canItems = hasAnyGateItemPath()
    if not canAA and not canSpell and not canItems then
        info("no Gate AA, no Gate spell, no gate items (stein / slide / philter) - skipping Gate waits (use /travelto or manual).")
        return false
    end

    local maxAttempts = PP.GATE_MAX_ATTEMPTS or 12
    local waitReadyMs = PP.GATE_WAIT_READY_MS or 240000
    local zoneWaitMs = PP.GATE_ZONE_WAIT_MS or 90000
    local postCastWait = PP.GATE_POST_CAST_EXTRA_WAIT_MS or 2000
    local spellName = PP.GATE_SPELL_NAME or "Gate"
    local retryBackoff = PP.GATE_RETRY_BACKOFF_MS or 1200

    if canAA then
        for attempt = 1, maxAttempts do
            shouldStop()
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if not gateAltAbilityReady() then
                if not waitUntilGateReady(gateAltAbilityReady, "waiting for Gate AA to become ready again (collapse/cooldown)...", waitReadyMs) then
                    warn("Gate AA did not become ready in time - trying spell or items if available.")
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
            if waitZonedOrGateReady(gateAltAbilityReady, PP.GATE_ZONE_ID, zoneWaitMs) then
                return true
            end
            warn(string.format(
                "Gate AA did not reach PoK (attempt %d/%d) - collapse/fizzle; retrying.",
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
        local gateSpellMana = math.max(40, tonumber(mq.TLO.Spell(spellName).Mana() or 0) or 0)
        for attempt = 1, maxAttempts do
            shouldStop()
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            if not gateSpellReady() then
                if not waitUntilGateReady(gateSpellReady, "waiting for Gate spell to be ready (gem/recast)...", waitReadyMs) then
                    warn("Gate spell did not become ready in time - trying items if available.")
                    break
                end
            end
            if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
                return true
            end
            meditateToManaPpp(gateSpellMana)
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
            if waitZonedOrGateReady(gateSpellReady, PP.GATE_ZONE_ID, zoneWaitMs) then
                return true
            end
            warn(string.format(
                "Gate spell did not reach PoK (attempt %d/%d) - fizzle/collapse; retrying.",
                attempt,
                maxAttempts
            ))
            mq.delay(retryBackoff)
        end
    end

    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end

    if canItems then
        if tryGateItemPhaseToPoK("gate_full") then
            return true
        end
    end

    return mq.TLO.Zone.ID() == PP.GATE_ZONE_ID
end

--- Gate items only (no AA/spell): Stein → Zueria (per mode) → philters. `zueriaMode`: `"tiger"` | `"lion"` | `"none"` | `"gate_full"`.
local function tryGateToPoK_PotionsOnly(zueriaMode)
    if PP.TRAVEL_DISMOUNT_BEFORE_GATE then
        dismountIfMounted("Gate item")
    end
    if mq.TLO.Me.ZoneBound.ID() ~= PP.GATE_ZONE_ID then
        return false
    end
    if mq.TLO.Zone.ID() == PP.GATE_ZONE_ID then
        return true
    end
    if not hasAnyGateItemPath() then
        return false
    end
    return tryGateItemPhaseToPoK(zueriaMode or "none")
end

--- Gate/potion to PoK when possible; otherwise `/travelto` PoK hub (same pattern as East FP → Neriak).
local function tryGateToPoKOrTraveltoPok()
    if tryGateToPoK() then return true end
    warn("Gate/potion to PoK unavailable or failed - /travelto " .. tostring(PP.POK_TRAVEL_SHORTNAME or "poknowledge") .. ".")
    mq.cmdf("/squelch /travelto %s", PP.POK_TRAVEL_SHORTNAME or "poknowledge")
    if not waitForZoneOrFalse(PP.GATE_ZONE_ID, 180000) then
        fail("Could not reach Plane of Knowledge.")
    end
    return true
end

--- Gate first; if still needed, one-hop `/travelto` to `directZoneId` (fast, matches pre-2.86); PoK hub only if direct does not complete in time.
local function tryGateDirectOrPokFallback(directTravelArg, directZoneId, directLabel)
    directLabel = directLabel or tostring(directTravelArg)
    if tryGateToPoK() then return true end
    if directTravelArg and directZoneId then
        local waitMs = tonumber(PP.TRAVEL_DIRECT_ZONE_WAIT_MS) or 120000
        info(string.format("No Gate - direct /travelto %s (%s).", tostring(directTravelArg), directLabel))
        mq.cmdf("/squelch /travelto %s", directTravelArg)
        if waitForZoneOrFalse(directZoneId, waitMs) then
            return true
        end
        warn(string.format("Direct travel to %s timed out - routing via Plane of Knowledge.", directLabel))
    end
    return tryGateToPoKOrTraveltoPok()
end

--- After Run passes journal checks: speed, mount, Zueria snapshot, AutoSize self 3. No invis here - apply invis in prepBeforeTasselLeg / zone helpers.
local function runPreflightAfterQuestChecks()
    debugLogQuiet("preflight - speed, mount, Zueria Slide check, MQ2AutoSize self 3 (no invis; invis last per leg).")
    pppokerEnsureMovementBuff()
    mountIfNeeded()
    if PP.pppokerZueria and PP.pppokerZueria.refreshReadiness then
        local zs = PP.pppokerZueria.refreshReadiness()
        if zs and zs.summary then
            info(zs.summary)
        end
    end
    local ok, loaded = pcall(function() return mq.TLO.Plugin("MQ2AutoSize").IsLoaded() end)
    if not (ok and loaded) then
        info("Loading MQ2AutoSize...")
        mq.cmd("/plugin MQ2AutoSize")
        mq.delay(500)
    end
    -- Set a consistent self model size for the run. Mount size left to your AutoSize config.
    mq.cmd("/autosize self 3")
end

--- Movement + invis once we are in Neriak Foreign or Commons (zoned in or resumed already there). Dismount first so speed/invis cast on foot; mount keyring not used in Neriak (see mountIfNeeded).
local function ensureSpeedAndInvisInNeriak(contextLabel)
    local z = mq.TLO.Zone.ID()
    if z ~= PP.ZONE.NERIAK_A and z ~= PP.ZONE.NERIAK_B then
        return
    end
    contextLabel = contextLabel or "Neriak"
    debugLogQuiet(string.format("%s - speed + invis on foot (Neriak zone %d).", contextLabel, z))
    dismountIfMounted("Neriak buffs (no mount)")
    mq.delay(400)
    pppokerEnsureMovementBuff()
    if PP.TRAVEL_INVIS_BEFORE_NERIAK then
        ensureInvisIfNeeded(contextLabel)
    end
end

--- North / South Qeynos: speed buff, dismount if mounted, invis last. Navigation: navLocNoMount only (no keyring mount in NQ/SQ).
local function ensureSpeedAndInvisInQeynos(contextLabel)
    local z = mq.TLO.Zone.ID()
    if z ~= PP.ZONE.NQ and z ~= PP.ZONE.SQ then
        return
    end
    contextLabel = contextLabel or "Qeynos"
    debugLogQuiet(string.format("%s - speed, dismount if needed, invis (Qeynos zone %d).", contextLabel, z))
    mq.delay(400)
    waitMeNotCasting(30000)
    pppokerEnsureMovementBuff()
    waitMeNotCasting(30000)
    dismountIfMounted("Qeynos invis (on foot)")
    mq.delay(400)
    waitMeNotCasting(30000)
    if PP.TRAVEL_INVIS_AFTER_QEYNOS_ZONE then
        ensureInvisIfNeeded(contextLabel)
    end
end

--- Highpass Hold: speed buff, mount (if enabled), invis last - no dismount in this helper.
--- navLoc / navLocNoMount still run after; navLocNoMount skips mount for lumber/tiger legs.
local function ensureSpeedInvisInHighpass(contextLabel)
    local z = mq.TLO.Zone.ID()
    if z ~= PP.ZONE.HIGHPASS then
        return
    end
    contextLabel = contextLabel or "Highpass"
    debugLogQuiet(string.format("%s - speed, mount, invis (Highpass zone %d).", contextLabel, z))
    mq.delay(400)
    waitMeNotCasting(30000)
    pppokerEnsureMovementBuff()
    waitMeNotCasting(30000)
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
        info("Traveling to " .. mqItem("Neriak Foreign Quarter") .. string.format(" (attempt %d/3).", attempt))
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
        tryGateToPoKOrTraveltoPok()
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

--- Big Slick (West Freeport): distance to spawn by name - use before target/hail (quest acquire + final objective).
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
    mq.delay(500)
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

--- Plugin DLL names vary by build/CWTN (e.g. NEC is MQ2Necro not MQ2Necromancer). Try each until IsLoaded().
local function cwtnPluginNamesForClass(short)
    short = (short or ""):upper()
    local map = {
        BRD = { "MQ2Bard", "mq2bard" },
        BST = { "MQ2Bst" },
        BER = { "MQ2Berserker" },
        CLR = { "MQ2Cleric" },
        DRU = { "MQ2Druid" },
        ENC = { "MQ2Enchanter" },
        MAG = { "MQ2Mage" },
        MNK = { "MQ2Monk" },
        NEC = { "MQ2Necro", "MQ2Necromancer" },
        PAL = { "MQ2Paladin" },
        RNG = { "MQ2Ranger" },
        ROG = { "MQ2Rogue" },
        SHD = { "MQ2ShadowKnight" },
        SHM = { "MQ2Shaman" },
        WAR = { "MQ2Warrior" },
        WIZ = { "MQ2Wizard" },
    }
    return map[short]
end

local function firstLoadedCwtnPluginFromList(names)
    if not names then return nil end
    for _, pluginName in ipairs(names) do
        local ok, loaded = pcall(function() return mq.TLO.Plugin(pluginName).IsLoaded() end)
        if ok and loaded then return pluginName end
    end
    return nil
end

local function isExpectedCWTNPluginLoaded()
    local short = (mq.TLO.Me.Class.ShortName() or ""):upper()
    local names = cwtnPluginNamesForClass(short)
    if not names then return false, nil end
    local loadedName = firstLoadedCwtnPluginFromList(names)
    if loadedName then return true, loadedName end
    return false, names[1]
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
        debugLogQuiet(string.format("CWTN pause skipped: expected plugin not loaded (%s)", tostring(pluginName or "unknown")))
        return false
    end

    local pausedNow = cwtnAppearsPaused()
    if pausedNow == true then
        debugLogQuiet(string.format("CWTN already paused - skipping /CWTN pause on (%s)", tostring(pluginName)))
        PP.cwtnState.pausedApplied = false
        PP.cwtnState.alreadyPausedAtStart = true
        return true
    end

    mq.cmd("/CWTN pause on")
    PP.cwtnState.pausedApplied = true
    if pausedNow == nil then
        debugLog(string.format(
            "CWTN: pause state not readable (${CWTN.Paused} / TLO.CWTN.Paused) - issued /CWTN pause on (%s)",
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
        debugLog("CWTN was paused before this run - leaving paused (no /CWTN pause off).")
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

local function pauseRGMercs()
    local ok, status = pcall(function() return mq.TLO.Lua.Script('rgmercs').Status() end)
    if ok and status == 'RUNNING' then
        mq.cmd('/rgl pause')
        gui.rgmercPaused = true
    end
end
local function unpauseRGMercs()
    if gui.rgmercPaused then mq.cmd('/rgl unpause') end
    gui.rgmercPaused = false
end

-- True if MQ2AutoSize was already loaded when the script started - we leave it alone on cleanup.
local autosizePreloaded = (function()
    local ok, v = pcall(function() return mq.TLO.Plugin("MQ2AutoSize").IsLoaded() end)
    return ok and v == true
end)()

--- Unpause RGMercs + CWTN, and unload MQ2AutoSize if we were the ones who loaded it.
--- Safe to call on normal completion, early exit, user stop, or error.
local function cleanupAfterRun()
    unpauseRGMercs()
    unpauseCWTNPlugins()
    if not autosizePreloaded then
        local ok, loaded = pcall(function() return mq.TLO.Plugin("MQ2AutoSize").IsLoaded() end)
        if ok and loaded then
            info("Unloading MQ2AutoSize (loaded by PPPoker this run).")
            mq.cmd("/plugin MQ2AutoSize unload")
        end
    end
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

-- Quest progress: mq.TLO.Task. Journal prime uses mq.delay - ONLY call from script main thread (while gui.open), never from ImGui draw.
-- Completion signal: objectiveIsComplete (Done() then Status()). Indices: /lua parse mq.TLO.Task("Paintings Playing Poker").Objective(N).Status()


local function journalSyncMode()
    local m = tostring(PP.TASK_JOURNAL_SYNC_MODE or "legacy_full"):lower()
    if m == "open_once_no_fetch" then
        return "open_once_no_fetch"
    end
    return "legacy_full"
end

--- Every Run: full sync so resume sees current journal (repeatable).
local function syncTaskJournalWindowFull()
    if journalSyncMode() == "open_once_no_fetch" then
        if not gui.journalOpenedOnce then
            pcall(function()
                mq.cmd("/windowstate TaskWnd open")
            end)
            mq.delay(200)
            gui.journalOpenedOnce = true
            debugLogQuiet("TaskWnd: open_once_no_fetch - opened once; no fetch/close loop.")
        end
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
    mq.delay(100)
end

--- Update Task TLO without flashing the journal window (many Live builds). If getTask() still empty, set PP.TASK_JOURNAL_FIRST_SYNC = "full".
local function syncTaskJournalMinimal()
    if journalSyncMode() == "open_once_no_fetch" then
        if not gui.journalOpenedOnce then
            syncTaskJournalWindowFull()
        end
        return
    end
    pcall(function()
        mq.cmd("/windowstate TaskWnd fetch")
    end)
    mq.delay(300)
end

--- mq.TLO.Task("Exact Name")() - evaluate the TLO: truthy if that task exists in journal memory; falsy if not (name is case-sensitive). Use after TaskWnd sync if stale.
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

--- Cached task slot - reset at run start; avoids rescanning up to 30 tasks per objective check.
local paintingsTaskSlot = nil
--- Guard: prevents runBuffUpkeepTick re-entry while buffs are being re-applied (nav pause + cast can take several seconds).
local buffsApplyingNow = false

--- Numeric journal slot 1..N for Paintings (for ${Task[i].Objective[j].*} when named key parse is empty).
local function getPaintingsTaskSlotNumber()
    if paintingsTaskSlot then return paintingsTaskSlot end
    for i = 1, PP.MAX_OBJECTIVES do
        local ti = mq.TLO.Task(i)
        if taskEvalExists(ti) and taskIsPaintingsPlayingPoker(ti) then
            paintingsTaskSlot = i
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

--- Objective TLO ref; do not gate on obj() - see objectiveIsComplete / MQ docs (() can be false briefly).
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
        runBuffUpkeepTick("wait objective")
        if journalSyncMode() ~= "open_once_no_fetch"
            and PP.WAIT_JOURNAL_SYNC_MS and PP.WAIT_JOURNAL_SYNC_MS > 0
            and mq.gettime() >= nextSync then
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
                info(mqObjGreen("Paintings task no longer in journal - objective 16 complete (final turn-in)."))
                return true
            end
        end
        if t and objectiveSlotComplete(t, idx) then
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
            local stStr = "?"
            pcall(function()
                if obj.Status and type(obj.Status) == "function" then
                    stStr = tostring(obj.Status() or "")
                end
            end)
            debugLogQuiet(string.format(
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
        debugLogQuiet("Blightfire (Moors) - speed buff, mount if needed.")
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
    debugLogQuiet(string.format("Poker2 mount pause (Nektulos zone %d) before next travel.", z))
    mq.delay(1000)
    mountIfNeeded()
    waitMeNotCasting(15000)
    mq.delay(3000)
end

--- PoK, Nektulos, or Moors → optional Moors hop + Highpass Hold (obj 8 tail / resume).
local function finishLegToHighpassHold()
    local z = mq.TLO.Zone.ID()
    if z == PP.ZONE.HIGHPASS then
        return
    end
    if z == PP.GATE_ZONE_ID then
        if PP.TRAVEL_HIGHPASS_VIA_MOORS ~= false then
            ensureZone(PP.ZONE.MOORS, "moors", "Blightfire Moors")
        end
        poker2MountDelayInNekOrMoors()
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        return
    end
    if z == PP.ZONE.NEKTULOS then
        poker2MountDelayInNekOrMoors()
        if PP.TRAVEL_HIGHPASS_VIA_MOORS ~= false then
            ensureZone(PP.ZONE.MOORS, "moors", "Blightfire Moors")
        end
        poker2MountDelayInNekOrMoors()
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        return
    end
    if z == PP.ZONE.MOORS then
        poker2MountDelayInNekOrMoors()
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        return
    end
end

--- No Gate AA/spell (runners): from Neriak Commons, nav to prep loc, then `/travelto neriaka` (Foreign) before Gate/moors.
local function runnerCommonsNavThenTraveltoNeriakaIfNeeded()
    if PP.TRAVEL_TOADSTOOL_RUNNER_PRE_NERIAKA_NAV == false then
        return
    end
    if mq.TLO.Zone.ID() ~= PP.ZONE.NERIAK_B then
        return
    end
    if hasGateAA() or hasGateSpell() then
        return
    end
    local loc = PP.LOC.TOADSTOOL_RUNNER_PRE_NERIAKA
    if type(loc) ~= "table" or loc[1] == nil or loc[2] == nil or loc[3] == nil then
        return
    end
    info("Runner path - nav to Foreign Quarter prep, then /travelto neriaka.")
    navLocNoMount(loc, 1200)
    moving()
    mq.delay(600)
    mq.cmd("/squelch /travelto neriaka")
    local waitMs = tonumber(PP.TRAVEL_DIRECT_ZONE_WAIT_MS) or 120000
    if not waitForZoneOrFalse(PP.ZONE.NERIAK_A, waitMs) then
        warn("Did not zone to Neriak Foreign Quarter after /travelto neriaka - continuing.")
    end
end

--- After Toadstool (obj 7): optional EasyFind, Zueria slide→Nek, Gate/potion PoK, or `/travelto moors` when no Gate AA/spell, then Highpass.
local function leaveToadstoolTowardHighpass()
    if mq.TLO.Zone.ID() ~= PP.ZONE.NERIAK_A and mq.TLO.Zone.ID() ~= PP.ZONE.NERIAK_B then
        return
    end
    info("Toadstool done - routing toward Highpass Hold.")
    easyfindNeriakForeignFromCommonsIfNeeded()

    -- Gate pipeline: AA → Spell → Stein → Slide (Nek shortcut) → philter → Run
    if tryGateToPoK_AAorSpellOnly() then
        finishLegToHighpassHold()
        mq.delay(2000)
        return
    end

    if tryGateSteinToPoK() then
        finishLegToHighpassHold()
        mq.delay(2000)
        return
    end

    if PP.TRAVEL_TOADSTOOL_ZUERIA_SLIDE_TO_NEK ~= false then
        if pppokerZueria.attemptSlideToNektulos("Toadstool → Nektulos (Zueria Slide)") then
            finishLegToHighpassHold()
            mq.delay(2000)
            return
        end
    end

    if tryGatePotionsClickiesToPoK() then
        finishLegToHighpassHold()
        mq.delay(2000)
        return
    end

    runnerCommonsNavThenTraveltoNeriakaIfNeeded()

    if (PP.TRAVEL_TOADSTOOL_NO_GATE_USE_MOORS_FIRST ~= false)
        and (not hasGateAA())
        and (not hasGateSpell())
    then
        info("No Gate AA/spell - runner-style zone chain: neriaka → nektulos → moors → highpasshold.")
        ensureZone(PP.ZONE.NERIAK_A, "neriaka", "Neriak Foreign Quarter")
        ensureZone(PP.ZONE.NEKTULOS, "nektulos", "Nektulos Forest")
        poker2MountDelayInNekOrMoors()
        ensureZone(PP.ZONE.MOORS, "moors", "Blightfire Moors")
        poker2MountDelayInNekOrMoors()
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(2000)
        return
    end

    tryGateDirectOrPokFallback("highpasshold", PP.ZONE.HIGHPASS, "Highpass Hold")
    mq.delay(2000)
    finishLegToHighpassHold()
end

--- After Tiger Roar (obj 12): Highpass → North Qeynos - same gate pipeline as Lion / Toadstool (AA/spell → Slide → potion → `tryGateDirectOrPokFallback`).
local function leaveHighpassTowardNorthQeynos()
    if mq.TLO.Zone.ID() ~= PP.ZONE.HIGHPASS then
        return
    end
    local safeLevel = tonumber(PP.HIGHPASS_SAFE_GATE_LEVEL) or 0
    if safeLevel > 0 and (mq.TLO.Me.Level() or 0) < safeLevel then
        info(string.format("Level %d < %d - nav to safe gate loc before leaving Highpass (low-level KOS protection).", mq.TLO.Me.Level() or 0, safeLevel))
        navLocNoMount(PP.LOC.HIGHPASS_SAFE_GATE, 1000)
    end
    info("Tiger Roar done - routing toward North Qeynos (AA → spell → Stein → Slide → philter → run).")

    if tryGateToPoK_AAorSpellOnly() then
        mq.delay(2000)
        return
    end

    if tryGateToPoK_PotionsOnly("tiger") then
        mq.delay(2000)
        return
    end

    tryGateDirectOrPokFallback("qeynos2", PP.ZONE.NQ, "North Qeynos")
    mq.delay(2000)
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
        navLoc(PP.LOC.SLUG, 1500)
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
            leaveToadstoolTowardHighpass()
        end
        if mq.TLO.Zone.ID() ~= PP.ZONE.HIGHPASS then
            finishLegToHighpassHold()
        end
        if mq.TLO.Zone.ID() ~= PP.ZONE.HIGHPASS then
            poker2MountDelayInNekOrMoors()
            ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        end
        mq.delay(tonumber(PP.HIGHPASS_ENTRY_DELAY_MS) or 350)
        ensureSpeedInvisInHighpass("objective 8 (Highpass)")
        navLoc(PP.LOC.QUINN, 1000)
    elseif idx == 9 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(tonumber(PP.HIGHPASS_ENTRY_DELAY_MS) or 350)
        ensureSpeedInvisInHighpass("objective 9 (Highpass - Quinn)")
        navLoc(PP.LOC.QUINN, 800)
        targetOrFail(PP.NPC.QUINN, "Could not target Quinn", 12000, true)
        mq.cmd('/keypress hail')
        mq.delay(tonumber(PP.HIGHPASS_POST_HAIL_DELAY_MS) or 1200)
        mq.cmd('/target ${Me.Name}')
    elseif idx == 10 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(tonumber(PP.HIGHPASS_ENTRY_DELAY_MS) or 350)
        ensureSpeedInvisInHighpass("objective 10 (Highpass - lumber)")
        navLocNoMount(PP.LOC.LUMBER_1, 900)
        navLocNoMount(PP.LOC.LUMBER_2, 900)
        navLocNoMount(PP.LOC.LUMBER_3, 1000)
    elseif idx == 11 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(tonumber(PP.HIGHPASS_ENTRY_DELAY_MS) or 350)
        ensureSpeedInvisInHighpass("objective 11 (Highpass - Mhrai)")
        navLocNoMount(PP.LOC.LUMBER_3, 900)
        targetOrFail(PP.NPC.MHRAI, "Could not target Mhrai", 12000, true)
        mq.cmd('/keypress hail')
        mq.delay(tonumber(PP.HIGHPASS_POST_HAIL_DELAY_MS) or 1200)
        mq.cmd('/target ${Me.Name}')
    elseif idx == 12 then
        ensureZone(PP.ZONE.HIGHPASS, "highpasshold", "Highpass Hold")
        mq.delay(tonumber(PP.HIGHPASS_ENTRY_DELAY_MS) or 350)
        ensureSpeedInvisInHighpass("objective 12 (Highpass - tiger)")
        navLocNoMount(PP.LOC.TIGER, tonumber(PP.TIGER_NAV_SETTLE_MS) or 1200)
        local maxD = tonumber(PP.TIGER_NAV_RETRY_IF_DIST_GT) or 22
        if distanceMeToLocYXZ(PP.LOC.TIGER) > maxD then
            info("Tiger painting - re-nav (still > " .. tostring(maxD) .. " from loc).")
            navLocNoMount(PP.LOC.TIGER, tonumber(PP.TIGER_NAV_RETRY_SETTLE_MS) or 800)
        end
        mq.cmdf("/face heading %d", tonumber(PP.TIGER_FACE_HEADING) or 128)
        mq.delay(tonumber(PP.TIGER_POST_FACE_DELAY_MS) or 350)
    elseif idx == 13 then
        if mq.TLO.Zone.ID() == PP.ZONE.HIGHPASS then
            leaveHighpassTowardNorthQeynos()
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
            info("Lion's Mane done - routing toward West Freeport / Slick.")
            -- Gate pipeline: AA → Spell → Stein → Slide → philter → Run
            if tryGateToPoK_AAorSpellOnly() then
                -- in PoK; continue
            elseif tryGateToPoK_PotionsOnly("lion") then
                -- in PoK; continue
            else
                tryGateToPoKOrTraveltoPok()
            end
            mq.delay(1000)
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

--- End-of-run log: e.g. "2 min 30 seconds", "45 seconds", "1 min 0 seconds".
function formatQuestRunDuration(totalSec)
    local sec = math.max(0, math.floor(tonumber(totalSec) or 0))
    local m = math.floor(sec / 60)
    local s = sec % 60
    if m == 0 then
        return string.format("%d %s", s, s == 1 and "second" or "seconds")
    end
    return string.format("%d min %d %s", m, s, s == 1 and "second" or "seconds")
end

--- Main automation: first incomplete objective → runObjectiveStep → waitObjectiveDone (objectiveIsComplete). Same data as getQuestProgress / GUI bar.
function runQuest()
    gui.journalOpenedOnce = false
    paintingsTaskSlot = nil  -- reset slot cache; task may have been dropped/re-acquired between runs
    local questRunStartTime = os.time()
    mq.cmd(string.format('/popup Starting: Paintings Playing Poker v%s', PP.VERSION))
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
        runBuffUpkeepTick("run loop")
        task = getTask()
        if not task then
            cleanupAfterRun()
            gui.status = "Task became unavailable - stopping."
            warn(gui.status)
            return
        end
        if not taskHasAnyObjectiveRow(task) then
            cleanupAfterRun()
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
        local stepOk, stepErr = pcall(runObjectiveStep, idx, task)
        if not stepOk then
            local em = tostring(stepErr or "")
            -- Re-throw stop/close requests so the main pcall handles them normally.
            if em:find("Stopped by user", 1, true) then error(em) end
            warn(string.format("Objective %d step error - will retry next loop: %s", idx, em))
        else
            local waitMs
            if idx == PP.QUEST_OBJECTIVE_COUNT then
                waitMs = PP.WAIT_OBJECTIVE_TIMEOUT_FINAL_MS or 300000
            elseif idx == 1 and (PP.WAIT_OBJECTIVE_TIMEOUT_OBJ1_MS or 0) > 0 then
                waitMs = PP.WAIT_OBJECTIVE_TIMEOUT_OBJ1_MS
            else
                waitMs = PP.WAIT_OBJECTIVE_TIMEOUT_MS or 120000
            end
            if not waitObjectiveDone(PP.QUEST_TITLE, idx, waitMs) then
                warn(string.format("Timeout waiting objective %d (%s) - loop will retry.", idx, instr))
            else
                info(mqObjGreen(string.format("Objective %d completed.", idx)))
                mq.delay(500)
                if idx == PP.QUEST_OBJECTIVE_COUNT then
                    gui.status = "Quest complete."
                    gui.questComplete = true
                    info(mqObjGreen("All objectives are Done."))
                    break
                end
            end
        end
    end

    do
        local n = getCommemorativeCount()
        info(string.format("\ayYou now have... \ag%d\ay Commemorative Coins \ax!", n))
        info(string.format("\aoQuest Run Time... \ay%s\ax", formatQuestRunDuration(os.time() - questRunStartTime)))
    end

    cleanupAfterRun()

    local ar = tonumber(PP.AUTO_REPEAT_DELAY_SEC)
    if ar and ar > 0 then
        info(string.format("auto-repeat - next Run in %d s (Stop / close window cancels).", ar))
        if delayMsWithStopCheck(ar * 1000) then
            gui.running = true
            stopRequested = false
            gui.navPaused = false
            navPluginUnpause()
            gui.status = "Auto-repeat - starting Run..."
        else
            info("auto-repeat cancelled.")
        end
    end
end

-- EQ \a codes in stored lines - map to ImVec4 for ImGui.TextColored (see changelog 2.62).
function mqColorLetterToImVec4(ch)
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

function parseMqColoredSegments(s)
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

function drawMqColoredDebugLine(line)
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

function drawGUI()
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
        open, draw = imgui.Begin(string.format("PPPoker v%s###PPPokerV2", PP.VERSION), gui.open, winFlags)
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
                imgui.Text(string.format("Progress: - / %d objectives (press Run to scan)", totalObjectives or PP.QUEST_OBJECTIVE_COUNT))
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
                    gui.status = "Nav paused (/nav pause) - click Unpause Nav or /nav pause off to continue."
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
                gui.status = "Stopped - nav and script run halted."
            end
            imgui.SameLine()
            pppokerDrawDebugToggle()

            imgui.Separator()
            drawCommemorativeCoinsRow()
            imgui.Separator()
            drawMountPicker()

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

loadPPSettings()
initMountList()
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
            gui.status = "Run (PPPokerV2.armRun) - starting..."
        end
    end
    if gui.running then
        gui.running = false
        local ok, err = pcall(runQuest)
        if not ok then
            cleanupAfterRun()
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
