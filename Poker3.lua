-- poker.lua 23rd anniversary task
-- Version 1.2b
-- Created: 3/25/2022
-- Updated: 3/27/2022
-- Creator: JB321
-- Quest: https://everquest.allakhazam.com/db/quest.html?quest=10723
-- Cannonballdex added invis support and updated a few locations
-- Magoo 20230318
-- Magoo 20230319 add Origin to Neriak departure options.
-- Magoo 20230322 add Cannonbaldex's zoning code, Redfrog's Neriak riposte direction.
-- Magoo 20230322b Tweaked Neriak Commons for my characters.

local mq = require('mq')
local function moving()
    while mq.TLO.Nav.Active() do mq.delay(1) end
    return
end
local function zoning(z_id)
    if Debug then print('\at DEBUG - WAITING ON ZONE') end
    ::DoorClick::
    if mq.TLO.Zone.ID() == z_id then return end
    if mq.TLO.Navigation.Velocity == 0 and mq.TLO.Zone.ID() ~= z_id then
        mq.cmd('/doortarget')
        mq.delay('5s')
    end
    if mq.TLO.Switch() ~= nil and mq.TLO.Navigation.Velocity() == 0 and mq.TLO.Switch.Distance() <= 20 and mq.TLO.Zone.ID() ~= z_id then
        if Debug then print('\at DEBUG - TARGET CLICK STUCK DOOR') end
        mq.cmd('/doortarget')
        mq.cmd('/click left door')
    end
    while mq.TLO.Zone.ID() ~= z_id do goto DoorClick end
    mq.delay(1500)
end
--Start
mq.cmd('/popup Starting: Paintings Playing Poker 23rd Anniversary Quest')
local start_time = os.time()

-- West Freeport. Talk to Big Slick for quest.
if mq.TLO.Zone.ID() ~= 383 then
   mq.cmd('/squelch /travelto freeportwest')
   zoning(383)
end
mq.delay(1000)
mq.cmd('/squelch /nav locyxz 19 136 -54')
moving()
mq.delay(1000)
mq.cmd('/removelev')
mq.cmd('/tar Slick')
mq.delay(1000)
mq.cmd('/face fast')
mq.cmd('/say paintings')
mq.delay(2000)
mq.cmd('/keypress esc')
-- Tassel's Tavern for update. Spawn Darrisa.
mq.cmd('/squelch /nav locyxz -177 -415 -85')
moving()
mq.delay(1500)

-- East Freeport. Crab and Grog Tavern. Spawn Bluffing Betty.
mq.cmd('/travelto freeporteast')
zoning(382)
mq.delay(1000)
mq.cmd('/squelch /nav locyxz 153 -806 7')
moving()
mq.delay(1000)
mq.cmd('/tar Bluffing')
mq.delay(1000)
mq.cmd('/face fast')
mq.cmd('/keypress hail')
mq.delay(2000)
mq.cmd('/autoinv')
mq.delay(2000)
mq.cmd('/autoinv')
mq.cmd('/keypress esc')
-- One for the road...
while mq.TLO.FindItem("Memento Grog")() do
   mq.cmd('/autoinv')
   mq.cmd('/useitem Memento Grog')
   mq.delay(1000)
end
mq.delay(1000)
mq.cmd('/autoinv')
-- Charm item gate.
if mq.TLO.FindItem("Zueria Slide: Nektulos")() then
   mq.cmd('/casting "Zueria Slide: Nektulos" Item')
   mq.delay(22000)
   while mq.TLO.Zone.ID() ~= 25 and not mq.TLO.Me.Casting() do
      mq.cmd('/casting "Zueria Slide: Nektulos" Item')
      mq.delay(22000)
      zoning(25)
   end
   zoning(25)
end
mq.delay(1000)
-- Gate Code.
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 and mq.TLO.Zone.ID() ~= 25 then
    mq.cmd('/alt act 1217')
    mq.delay(11000)
    repeat
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(1000)
        mq.cmd('/alt act 1217')
        mq.delay(11000)
    end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
-- Gate potion.
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 and mq.TLO.Zone.ID() ~= 25 then
   mq.cmd('/casting "Philter of Major Translocation" Item')
   mq.delay(13000)
   repeat
      while mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
      mq.delay(1000)
      mq.cmd('/casting "Philter of Major Translocation" Item')
      mq.delay(13000)
      end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
mq.delay(1000)

-- Nav around tents in PoK if running from Freeport to Neriak.
if mq.TLO.Zone.ID() ~= 25 then
   mq.cmd('/autoinv')
   mq.cmd('/travelto poknowledge')
   zoning(202)
end
mq.delay(1000)
if mq.TLO.Zone.ID() == 202 then
   mq.cmd('/nav locyx -660 280')
   moving()
   mq.cmd('/nav locyx -660 160')
   moving()
end
--

-- Neriak Foreign Quarter.
mq.cmd('/travelto neriaka')
zoning(40)
mq.delay(1000)
-- The Bull Pit. Spawn Svunsa.
mq.cmd('/squelch /nav locyx -352 -207')
moving()
mq.delay(1000)
-- Slug's Tavern. Spawn Slug.
mq.cmd('/squelch /nav locyx 204 -243 3') 
moving()
mq.delay(1000)

-- Neriak Commons
mq.cmd('/travelto neriakb')
zoning(41)
mq.delay(1000)
-- Invis code.
-- Invis AA.
-- Bard does not have AA.
--if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BRD' then
--    mq.cmd('/alt act 3704')
--    mq.delay(2000)
--    mq.cmd('/alt act 231')
--    mq.delay(2000)
--    mq.cmd('/removelev')
--end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'DRU' then
   mq.cmd('/alt act 518')
   mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'ENC' then
   mq.cmd('/alt act 1210')
   mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'MAG' then
   mq.cmd('/alt act 1210')
   mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'NEC' then
   mq.cmd('/alt act 1210')
   mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHD' then
   mq.cmd('/alt act 531')
   mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 3730')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WIZ' then
   mq.cmd('/alt act 1210')
   mq.delay(1000)
end
-- Invis Potion.
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BRD' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'CLR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'PAL' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WAR' then
    mq.cmd('/useitem Cloudy Potion')
end
-- Rogue.
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'ROG' then
    mq.cmd('/makemevisible')
    if mq.TLO.Me.Sneaking() == false then
        while mq.TLO.Me.AbilityReady('Sneak')() == false do
            mq.delay(10)
        end
        mq.cmd('/doability sneak')
    end 
    while mq.TLO.Me.AbilityReady('Hide')() == false do
        mq.delay(10)
    end
    mq.cmd('/doability hide')
end
-- The Blind Fish. Spawn  Marenkor
mq.cmd('/squelch /nav locyxz 12 -850 -52')
moving()
mq.delay(1000)
-- Toadstool Tavern. Spawn Rista
mq.cmd('/squelch /nav locyxz -148 -994 -26')
moving()
mq.delay(1500)
mq.cmd('/face heading 315')
-- Gate Code.
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.cmd('/alt act 1217')
    mq.delay(11000)
    repeat
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(1000)
        mq.cmd('/alt act 1217')
        mq.delay(11000)
    end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
-- Gate potion.
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/casting "Philter of Major Translocation" Item')
   mq.delay(13000)
   repeat
      while mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
      mq.delay(1000)
      mq.cmd('/casting "Philter of Major Translocation" Item')
      mq.delay(13000)
      end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
mq.delay(1000)
-- Origin to Crescent Reach, if able, for run to Highpass Hold. (Neriakb 41)(Crescent 394)
if mq.TLO.Me.AltAbilityReady('Origin')() and mq.TLO.Me.Origin.ID() == 394 and mq.TLO.Zone.ID() == 41 then
    mq.cmd('/alt act 331')
    mq.delay(17000)
    repeat
    while mq.TLO.Zone.ID() ~= 394 and not mq.TLO.Me.Casting() do
        mq.delay(1000)
        mq.cmd('/alt act 331')
        mq.delay(17000)
    end
    until
    mq.TLO.Zone.ID() == 394
    zoning(394)
end
-- Moves to get you to Foreign Quarter zone if still in in Neriak and running out. 
if mq.TLO.Zone.ID() ~= 202 and mq.TLO.Zone.ID() ~= 394 then
   mq.cmd('/nav spawn fleshweav')
   moving()
   mq.delay(1000)
   mq.cmd('/squelch /nav locyx -1 -482')
   moving()
   mq.delay(1000)
end

-- Highpass Hold
mq.cmd('/travelto highpasshold')
zoning(407)
mq.delay(1000)
-- Golden Roosters. Spawn Quinn of Quads
mq.cmd('/squelch /nav locyxz 454 -620 22')
moving()
mq.delay(1000)
mq.cmd('/tar Quads')
mq.delay(1000)
mq.cmd('/keypress hail')
mq.delay(1000)
mq.cmd('/keypress esc')
-- The Lumberyard. Spawn Gubli
mq.cmd('/squelch /nav locyxz -442 -215 -12')
moving()
mq.cmd('/squelch /nav locyxz -426 -263 -12')
moving()
mq.cmd('/nav locyxz -408 -267 -12')
moving()
mq.cmd('/tar Queen')
mq.delay(1000)
mq.cmd('/keypress hail')
mq.delay(1000)
mq.cmd('/keypress esc')
-- The Tiger's Roar. Spawn Poker.
mq.cmd('/nav locyxz -125 540 -13')
moving()
mq.delay(1000)
-- Gate Code.
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.cmd('/alt act 1217')
    mq.delay(11000)
    repeat
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(1000)
        mq.cmd('/alt act 1217')
        mq.delay(11000)
    end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
-- Gate potion.
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/casting "Philter of Major Translocation" Item')
   mq.delay(13000)
   repeat
      while mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
      mq.delay(1000)
      mq.cmd('/casting "Philter of Major Translocation" Item')
      mq.delay(13000)
      end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
mq.delay(1000)

-- North Qeynos
mq.cmd('/travelto qeynos2')
zoning(2)
mq.delay(1000)
-- Crow's Pub and Casino. Spawn Segran.
mq.cmd('/nav locyxz 118 335 1')
moving()
mq.delay(1500)

-- South Qeynos
mq.cmd('/travelto qeynos')
zoning(1)
mq.delay(1000)
-- Fish's Ale. Spawn Bruno.
mq.cmd('/squelch /nav locyxz -282 -230 2')
moving()
mq.delay(1500)
-- The Lion's Mane Tavern. Spawn Tomas.
mq.cmd('/squelch /nav locyxz 311 -173 4')
moving()
mq.delay(1500)
-- Gate Code.
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.cmd('/alt act 1217')
    mq.delay(11000)
    repeat
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(1000)
        mq.cmd('/alt act 1217')
        mq.delay(11000)
    end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
-- Gate potion.
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/casting "Philter of Major Translocation" Item')
   mq.delay(13000)
   repeat
      while mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
      mq.delay(1000)
      mq.cmd('/casting "Philter of Major Translocation" Item')
      mq.delay(13000)
      end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
mq.delay(1000)

-- West Freeport -- Big Slick Jones for Reward.
mq.cmd('/travelto freeportwest')
zoning(383)
mq.delay(1000)
mq.cmd('/squelch /nav locyxz 19 136 -54')
moving()
mq.cmd('/tar Slick')
mq.delay(1000)
mq.cmd('/face fast')
mq.cmd('/keypress hail')
mq.delay(1000)
-- Completion beep.
mq.cmd('/beep')
local end_time = os.time()
print("Quest Run Time... " .. end_time - start_time .. " Seconds")
-- Auto repeat.
mq.cmd('/timed 100 /lua run poker3')
