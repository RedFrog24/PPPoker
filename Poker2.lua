-- poker.lua 23rd anniversary task
-- Version 2.1
-- Created: 3/25/2022
-- Updated: 4/24/2023
-- Creator: JB321
-- Quest: https://everquest.allakhazam.com/db/quest.html?quest=10723
-- Cannonballdex added invis support and updated a few locations
-- Magoo edited for Magoo useage.
-- Redfrog tinkering.

local mq = require('mq')
local function moving()
    while mq.TLO.Nav.Active() do mq.delay(1) end
    return
end
local function zoning(z_id)
    while mq.TLO.Zone.ID() ~= z_id do mq.delay(1) end
    return
end

-- To-Do
--pause CWTN, RGmerc
--bind check pok
--use relocate
--add Onlyloot or looly off
--use Task check to restart if crash
--add invis for lower level
--add run to pok if no gate/potion after last neriak stage
--add currency status upon success
--Gate Section fix

--Start
mq.cmd('/beep')
-- Delay to stop/pause before repeat.
-- /lua stop poker or /lua pause poker
--mq.delay(30000)
mq.cmd('/popup Starting: Paintings Playing Poker 23rd Anniversary Quest')
local start_time = os.time()
mq.cmd('/removelev')
--mq.cmd('/useitem ${Me.Inventory[Ammo]}')

-- West Freeport. Talk to Big Slick for quest.
if mq.TLO.Zone.ID() ~= 383 then
   mq.cmd('/squelch /travelto freeportwest')
   zoning(383)
end
mq.delay(1000)
mq.cmd('/squelch /nav locyxz 19 136 -54')
moving()
mq.delay(1000)
mq.cmd('/tar Slick')
mq.delay(1000)
mq.cmd('/face fast')
mq.cmd('/say paintings')
mq.delay(2000)
mq.cmd('/keypress esc')
mq.delay(1000)
if mq.TLO.Me.Height() > 2.50 then mq.cmd('/useitem Guise of the Deceiver') mq.delay(8500) mq.cmd('/popup You are a bit tall, lets shrink a little to make it easier')
end
mq.cmd('/popup Lets start our Bar Run!')

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
if mq.TLO.FindItem("Zueria Slide: Nektulos")() then
    mq.cmd('/casting "Zueria Slide: Nektulos" Item')
    mq.delay(22000)
    while mq.TLO.Zone.ID() ~= 25 and not mq.TLO.Me.Casting() do
        mq.cmd('/casting "Zueria Slide: Nektulos" Item')
        zoning(25)
    end
    zoning(25)
end
mq.delay(1000)

-- Neriak Foreign Quarter.
mq.delay(1000)
mq.cmd('/useitem ${Me.Inventory[Ammo]}')
mq.delay(3000)
mq.cmd('/travelto neriaka')
zoning(40)
mq.delay(1000)
-- The Bull Pit. Spawn Svunsa.
mq.cmd('/squelch /nav locyx -352 -207')
moving()
mq.delay(1500)
-- Slug's Tavern. Spawn Slug.
mq.cmd('/squelch /nav locyx 204 -243 3') 
moving()
mq.delay(1500)

-- Neriak Commons
mq.cmd('/travelto neriakb')
zoning(41)
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
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/alt act 1217')
  mq.delay(10000)
    repeat
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(1000)
        mq.cmd('/alt act 1217')
        mq.delay(10000)
    end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
-- Gate potion. Three tries for collapses...
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/casting "Philter of Major Translocation" Item')
   mq.delay(12000)
   while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
      mq.delay(10500)
      mq.cmd('/casting "Philter of Major Translocation" Item')
      mq.delay(12000)
       while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
         mq.delay(10500)
         mq.cmd('/casting "Philter of Major Translocation" Item')
          mq.delay(12000)
          zoning(202)
      end
      zoning(202)
   end
   zoning(202)
end
mq.delay(1000)

-- Highpass Hold
mq.cmd('/travelto moors')
zoning(395)
mq.delay(1000)
mq.cmd('/useitem ${Me.Inventory[Ammo]}')
mq.delay(3000)
mq.cmd('/travelto highpasshold')
mq.delay(1500)
zoning(407)
--mq.delay(1000)
--mq.cmd('/dismount')

-- Golden Roosters. Spawn Quinn of Quads
mq.cmd('/squelch /nav locyxz 454 -620 22')
moving()
mq.delay(1000)
mq.cmd('/dismount')
mq.delay(1500)
mq.cmd('/tar Quads')
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
mq.cmd('/tar Queen')
mq.delay(1000)
mq.cmd('/keypress hail')
mq.delay(1500)
mq.cmd('/keypress esc')
-- The Tiger's Roar. Spawn Poker.
mq.cmd('/nav locyxz -125 540 -13')
moving()
mq.delay(1000)
-- Gate code. Try three times for collapses...
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/alt act 1217')
   mq.delay(10000)
    repeat
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(1000)
        mq.cmd('/alt act 1217')
        mq.delay(10000)
    end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
-- Gate potion. Three tries for collapses...
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/casting "Philter of Major Translocation" Item')
   mq.delay(12000)
   while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
      mq.delay(10500)
      mq.cmd('/casting "Philter of Major Translocation" Item')
      mq.delay(12000)
       while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
         mq.delay(10500)
         mq.cmd('/casting "Philter of Major Translocation" Item')
          mq.delay(12000)
          zoning(202)
      end
      zoning(202)
   end
   zoning(202)
end
mq.delay(1000)

-- North Qeynos
mq.delay(1000)
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
-- Gate code. Try three times for collapses...
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/alt act 1217')
   mq.delay(10000)
    repeat
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(1000)
        mq.cmd('/alt act 1217')
        mq.delay(10000)
    end
    until
    mq.TLO.Zone.ID() == 202
    zoning(202)
end
-- Gate potion. Three tries for collapses...
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/casting "Philter of Major Translocation" Item')
   mq.delay(12000)
   while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
      mq.delay(10500)
      mq.cmd('/casting "Philter of Major Translocation" Item')
      mq.delay(12000)
       while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
         mq.delay(10500)
         mq.cmd('/casting "Philter of Major Translocation" Item')
          mq.delay(12000)
          zoning(202)
      end
      zoning(202)
   end
   zoning(202)
end
mq.delay(1000)

-- West Freeport -- Big Slick Jones for Reward.
mq.delay(1000)
mq.cmd('/travelto freeportwest')
zoning(383)
mq.delay(1000)
mq.cmd('/squelch /nav locyxz 19 136 -54')
moving()
mq.delay(1000)
mq.cmd('/dismount')
mq.cmd('/tar Slick')
mq.delay(1000)
mq.cmd('/face fast')
mq.cmd('/keypress hail')
mq.delay(1000)
-- Completion beeps.
mq.cmd('/beep')
mq.cmd('/beep')
print("You now have... " .. mq.TLO.Me.Commemoratives() .. " Commemorative Coins !")
local end_time = os.time()
print("Quest Run Time... " .. end_time - start_time .. " Seconds")
-- Auto repeat.
mq.cmd('/timed 10 /lua run poker2')
