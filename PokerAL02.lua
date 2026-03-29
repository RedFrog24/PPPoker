-- poker.lua 23rd anniversary task
-- Version 1.2b
-- Created: 3/25/2022
-- Updated: 3/27/2022
-- Creator: JB321
-- Quest: https://everquest.allakhazam.com/db/quest.html?quest=10723
-- Cannonballdex added invis support and updated a few locations
-- Added Sow Support for shaman and bard
-- Added Shrink support for shaman and zerker with shrink stick
-- Added Gate and Fellowship support if camp is in POK or Bind in Pok
-- Might recast gate if it collapses and reclick pok stones if failed the first time (Under Construction)

local mq = require('mq')

local function moving()
    while mq.TLO.Nav.Active() do mq.delay(1) end
end

local function zoning(z_id)
    while mq.TLO.Zone.ID() ~= z_id do mq.delay(1) end
end

mq.cmd('/popup Starting: Paintings Playing Poker 23rd Anniversary Quest')
local start_time = os.time()
mq.cmd('/removelev')
--if mq.TLO.Zone.ShortName.Equal(poknowledge)() == false then
--while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Moving() do
--    mq.cmd('/squelch /travelto poknowledge')
--end
--zoning(202)
--            mq.cmd('/squelch /target clear')
--            mq.cmd('/squelch /nav locyxz -198.97 -90.83 -160.0')
--            mq.cmd('/makemevisible')
--            mq.cmd('/target npc Soulbinder')
--            mq.delay(500)
--            mq.cmd('/say Bind my soul')
--end
-- Bind in PoK if your not.
if mq.TLO.Me.ZoneBound.ID() == 202 then
   mq.cmd('/squelch /travelto poknowledge')
   zoning(202)
   mq.delay(1000)
-- Use either of these. I'd pick the loc.
--   mq.cmd('/nav spawn Soulbinder')
   mq.cmd('/squelch /nav locyxz -198.97 -90.83 -160.0')
   moving()
   mq.delay(1000)
-- Sure you need to unvis to bind?
--   mq.cmd('/makemevisible')
   mq.cmd('/target Soulbinder')
   mq.delay(1000)
   mq.cmd('/say Bind my soul')
   mq.delay(1000)
end
-- If your in FreeportWest, it already knows.
--mq.cmd('/squelch /travelto freeportwest')
--zoning(383)
--mq.delay(500)
while mq.TLO.Zone.ID() ~= 383 and not mq.TLO.Me.Moving() do
    mq.cmd('/squelch /travelto freeportwest')
end
zoning(383)

mq.cmd('/squelch /nav spawn slick')
moving()
mq.cmd('/tar slick')
mq.delay(1500)
mq.cmd('/say paintings')
print('Freeport Time')
-- mq.delay(1500)

-- Tassel's Tavern
if mq.TLO.Me.Height() > 2.50 then mq.cmd('/useitem Guise of the Deceiver') mq.delay(8500) mq.cmd('/popup You are a bit tall, lets shrink a little to make it easier')
end

mq.cmd('/popup Lets start our Bar Run!')
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WAR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'CLR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'PAL' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem Wand of Imperceptibility')
    mq.delay(8500)
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BRD' then
    mq.cmd('/alt act 3704')
    mq.delay(2000)
    mq.cmd('/alt act 231')
    mq.delay(2000)
    mq.cmd('/removelev')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'MAG' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WIZ' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHD' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'NEC' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
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
mq.delay(1500)
mq.cmd('/squelch /nav locyxz -177 -415 -85')
moving()
mq.delay(4000)
mq.cmd('/travelto freeporteast')
mq.delay(2000)
while mq.TLO.Zone.ID() ~= 382 and not mq.TLO.Me.Moving() do
    mq.cmd('/squelch /travelto freeporteast')
end
zoning(382)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem Wand of Imperceptibility')
    mq.delay(8500)
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end

-- The Grub n Grog Tavern
mq.cmd('/nav spawn bluffin')
moving()
mq.cmd('/tar bluffin')
mq.delay(2000)
mq.cmd('/keypress hail')
mq.delay(1500)
mq.cmd('/autoinv')
mq.delay(1500)
-- One for the road...
if mq.TLO.FindItem("Memento Grog")() then
   mq.cmd('/useitem Memento Grog')
   mq.delay(500)
end
if mq.TLO.FindItem("Zueria Slide: Nektulos")() then
    mq.cmd('/casting "Zueria Slide: Nektulos" Item')
    mq.delay(22000)
    while mq.TLO.Zone.ID() ~= 25 and not mq.TLO.Me.Casting() do
        mq.delay(1000)
        mq.cmd('/casting "Zueria Slide: Nektulos" Item')
        zoning(25)
    end
    zoning(25)
end
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.cmd('/alt act 1217')
    mq.delay(5000)
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(60000)
        mq.cmd('/alt act 1217')
        mq.delay(5000)
        zoning(202)
    end
    zoning(202)
end
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.cmd('/casting "Philter of Major Translocation" Item')
    mq.delay(12000)
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(10500)
        mq.cmd('/casting "Philter of Major Translocation" Item')
        zoning(202)
    end
    zoning(202)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WAR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'CLR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'PAL' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem Wand of Imperceptibility')
    mq.delay(8500)
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BRD' then
    mq.cmd('/alt act 3704')
    mq.delay(2000)
    mq.cmd('/alt act 231')
    mq.delay(2000)
    mq.cmd('/removelev')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'MAG' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WIZ' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHD' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'NEC' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
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
mq.cmd('/travelto poknowledge')
mq.delay(1500)
zoning(202)
mq.delay(1500)
while mq.TLO.Zone.ID() == 202 and mq.TLO.Me.Fellowship.Campfire() == false and not mq.TLO.Me.Hovering() and mq.TLO.SpawnCount('radius 50 fellowship')() < 3 do
    print('\ayWaiting on group to drop a campfire')
    mq.delay(1000)
    end
mq.delay(2500)
if mq.TLO.SpawnCount('radius 50 fellowship')() > 2 then
    mq.cmd('/windowstate FellowshipWnd open')
    mq.delay(1000)
    mq.cmd('/nomodkey /notify FellowshipWnd FP_Subwindows tabselect 2')
    mq.delay(1000)
    mq.cmd('/nomodkey /notify FellowshipWnd FP_RefreshList leftmouseup')
    mq.delay(1000)
    mq.cmd('/nomodkey /notify FellowshipWnd FP_CampsiteKitList listselect 1')
    mq.delay(1000)
    mq.cmd('/nomodkey /notify FellowshipWnd FP_CreateCampsite leftmouseup')
    mq.delay(1000)
    mq.cmd('/windowstate FellowshipWnd close')
    mq.delay(1000)
    print('\agDropped a Campfire')
    mq.delay(5000)
end
mq.delay(1500)

-- Neriak Foreign Quarter
mq.cmd('/travelto neriaka')
mq.delay(1500)
while mq.TLO.Zone.ID() ~= 40 and not mq.TLO.Me.Moving() do
        mq.cmd('/squelch /travelto neriaka')
end
zoning(40)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem Wand of Imperceptibility')
    mq.delay(8500)
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
mq.delay(1500)
mq.cmd('/squelch /nav locyx -352 -207')
moving()
mq.delay(1500)
mq.cmd('/nav spawn slug')
moving()
mq.delay(1500)

-- Neriak Commons
mq.cmd('/travelto neriakb')
mq.delay(1500)
while mq.TLO.Zone.ID() ~= 41 and not mq.TLO.Me.Moving() do
    mq.cmd('/squelch /travelto neriakb')
end
zoning(41)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem Wand of Imperceptibility')
    mq.delay(8500)
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
mq.delay(1500)

-- The Blind Fish
mq.cmd('/nav spawn maren')
moving()
mq.delay(1500)

-- Toadstool Tavern
mq.cmd('/squelch /nav locyxz -148 -994 -26')
moving()
mq.delay(2000)
-- Zone Helper NAV
mq.cmd('/squelch /nav locyx -1 -482')
moving()
mq.delay(1500)
mq.cmd('/squelch /nav locyx -1 -482')
moving()
mq.delay(1500)
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.cmd('/alt act 1217')
    mq.delay(5000)
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(60000)
        mq.cmd('/alt act 1217')
        mq.delay(5000)
        zoning(202)
    end
    zoning(202)
end
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.cmd('/casting "Philter of Major Translocation" Item')
    mq.delay(12000)
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(10500)
        mq.cmd('/casting "Philter of Major Translocation" Item')
        zoning(202)
    end
    zoning(202)
end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WAR' then
        mq.cmd('/useitem Cloudy Potion')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'CLR' then
        mq.cmd('/useitem Cloudy Potion')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'PAL' then
        mq.cmd('/useitem Cloudy Potion')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
        mq.cmd('/useitem Wand of Imperceptibility')
        mq.delay(8500)
        mq.cmd('/useitem Cloudy Potion')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
        mq.cmd('/alt act 3709')
        mq.delay(3500)
        mq.cmd('/alt act 7025')
        mq.delay(3500)
        mq.cmd('/alt act 980')
        mq.delay(1000)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BRD' then
        mq.cmd('/alt act 3704')
        mq.delay(2000)
        mq.cmd('/alt act 231')
        mq.delay(2000)
        mq.cmd('/removelev')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
        mq.cmd('/alt act 9503')
        mq.delay(3500)
        mq.cmd('/alt act 630')
        mq.delay(1500)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'MAG' then
        mq.cmd('/alt act 1210')
        mq.delay(1000)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WIZ' then
        mq.cmd('/alt act 1210')
        mq.delay(1000)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHD' then
        mq.cmd('/alt act 531')
        mq.delay(1000)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'NEC' then
        mq.cmd('/alt act 531')
        mq.delay(1000)
    end
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
mq.delay(1000)

-- Highpass Hold
mq.cmd('/travelto moors')
zoning(395)
mq.cmd('/travelto highpasshold')
mq.delay(1500)
while mq.TLO.Zone.ID() ~= 407 and not mq.TLO.Me.Moving() do
    mq.cmd('/squelch /travelto highpasshold')
end
zoning(407)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem Wand of Imperceptibility')
    mq.delay(8500)
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
mq.delay(1500)

-- The Golden Rooster
mq.cmd('/nav spawn quads')
moving()
mq.delay(1500)
mq.cmd('/tar quads')
mq.delay(1500)
mq.cmd('/makemevisible')
mq.delay(1500)
mq.cmd('/keypress hail')
mq.delay(1500)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WAR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'CLR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'PAL' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem Wand of Imperceptibility')
    mq.delay(8500)
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BRD' then
    mq.cmd('/alt act 3704')
    mq.delay(2000)
    mq.cmd('/alt act 231')
    mq.delay(2000)
    mq.cmd('/removelev')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'MAG' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WIZ' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHD' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'NEC' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
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
mq.delay(1500)
mq.cmd('/squelch /nav locyxz -436 -229 -12')
moving()
mq.delay(1500)
mq.cmd('/squelch /nav locyx -432 -257')
moving()
mq.delay(1500)

-- The Tiger's Roar
mq.cmd('/nav locyxz -414 -264 -11')
moving()
mq.delay(1500)

-- Crow's Pub and Casino
mq.cmd('/nav spawn queen')
moving()
mq.delay(1500)
mq.cmd('/tar queen')
mq.delay(1500)
mq.cmd('/makemevisible')
mq.delay(1500)
mq.cmd('/keypress hail')
mq.delay(1500)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WAR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'CLR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'PAL' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem Wand of Imperceptibility')
    mq.delay(8500)
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BRD' then
    mq.cmd('/alt act 3704')
    mq.delay(2000)
    mq.cmd('/alt act 231')
    mq.delay(2000)
    mq.cmd('/removelev')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'MAG' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WIZ' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHD' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'NEC' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
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
mq.delay(1500)
mq.cmd('/squelch /nav locyxz -436 -229 -12')
moving()
mq.delay(1500)
mq.cmd('/nav spawn poker')
moving()
mq.delay(500)
mq.cmd('/nav locyxz -124 538 -11')
moving()
mq.delay(1500)
mq.cmd('/nav locyxz -119 550 -12')
moving()
mq.delay(1500)

if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.cmd('/alt act 1217')
    mq.delay(5000)
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(60000)
        mq.cmd('/alt act 1217')
        mq.delay(5000)
        zoning(202)
    end
    zoning(202)
end
while mq.TLO.Me.Fellowship.Campfire() and mq.TLO.FindItem("Fellowship Registration Insignia").TimerReady() ~= 0 do
    mq.delay(1000)
end
if mq.TLO.Me.Fellowship.Campfire() and mq.TLO.FindItem("Fellowship Registration Insignia").TimerReady() == 0 and not mq.TLO.Me.Hovering() then
    mq.cmd('/makemevisible')
mq.cmd('/casting "Fellowship Registration Insignia" Item -maxtries|2')
zoning(202)
end

mq.delay(1500)
if mq.TLO.Me.AltAbilityReady('Throne of Heroes')() then
    mq.cmd('/alt act 511')
    mq.delay(20000)
    while mq.TLO.Zone.ID() ~= 344 and not mq.TLO.Me.Casting() do
        mq.delay(60000)
        mq.cmd('/alt act 511')
        mq.delay(5000)
        zoning(344)
    end
    zoning(344)
    mq.delay(5000)
    mq.cmd('/travelto qeynos2')
    mq.delay(1000)
    zoning(2)
end
--if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
--    mq.cmd('/casting "Philter of Major Translocation" Item')
--    mq.delay(12000)
 --   while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
--        mq.delay(10500)
--        mq.cmd('/casting "Philter of Major Translocation" Item')
--        zoning(202)
--    end
--    zoning(202)
--end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WAR' then
        mq.cmd('/useitem Cloudy Potion')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'CLR' then
        mq.cmd('/useitem Cloudy Potion')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'PAL' then
        mq.cmd('/useitem Cloudy Potion')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
        mq.cmd('/useitem Wand of Imperceptibility')
        mq.delay(8500)
        mq.cmd('/useitem Cloudy Potion')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
        mq.cmd('/alt act 3709')
        mq.delay(3500)
        mq.cmd('/alt act 7025')
        mq.delay(3500)
        mq.cmd('/alt act 980')
        mq.delay(1000)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BRD' then
        mq.cmd('/alt act 3704')
        mq.delay(2000)
        mq.cmd('/alt act 231')
        mq.delay(2000)
        mq.cmd('/removelev')
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
        mq.cmd('/alt act 9503')
        mq.delay(3500)
        mq.cmd('/alt act 630')
        mq.delay(1500)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'MAG' then
        mq.cmd('/alt act 1210')
        mq.delay(1000)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WIZ' then
        mq.cmd('/alt act 1210')
        mq.delay(1000)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHD' then
        mq.cmd('/alt act 531')
        mq.delay(1000)
    end
    if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'NEC' then
        mq.cmd('/alt act 531')
        mq.delay(1000)
    end
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

mq.delay(1500)
mq.cmd('/travelto qeynos2')
mq.delay(1500)
while mq.TLO.Zone.ID() ~= 2 and not mq.TLO.Me.Moving() do
    mq.cmd('/squelch /travelto qeynos2')
end
zoning(2)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem "Wand of Imperceptibility"')
    mq.delay(8500)
    mq.cmd('/useitem "Cloudy Potion"')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
mq.delay(1500)
mq.cmd('/nav locyxz 118 335 1')
moving()
mq.delay(2000)
mq.cmd('/travelto qeynos')
mq.delay(1500)
while mq.TLO.Zone.ID() ~= 1 and not mq.TLO.Me.Moving() do
    mq.cmd('/squelch /travelto qeynos')
end
zoning(1)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem "Wand of Imperceptibility"')
    mq.delay(8500)
    mq.cmd('/useitem "Cloudy Potion"')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
mq.delay(1500)

-- Fish's Ale
mq.cmd('/squelch /nav locyxz -282 -230 2')
moving()
mq.delay(1500)

-- The Lion's Mane Tavern
mq.cmd('/squelch /nav locyxz 311 -173 4')
moving()
mq.delay(1500)
if mq.TLO.Me.AltAbilityReady('Gate')() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.delay(5000)
    mq.cmd('/alt act 1217')
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(60000)
        mq.cmd('/alt act 1217')
        mq.delay(5000)
        zoning(202)
    end
    zoning(202)
end
if mq.TLO.FindItem("Philter of Major Translocation")() and mq.TLO.Me.ZoneBound.ID() == 202 then
    mq.cmd('/casting "Philter of Major Translocation" Item')
    mq.delay(12000)
    while mq.TLO.Zone.ID() ~= 202 and not mq.TLO.Me.Casting() do
        mq.delay(10500)
        mq.cmd('/casting "Philter of Major Translocation" Item')
        zoning(202)
    end
    zoning(202)
end
mq.delay(1000)

-- West Freeport
mq.cmd('/travelto freeportwest')
mq.delay(2000)
while mq.TLO.Zone.ID() ~= 383 and not mq.TLO.Me.Moving() do
    mq.cmd('/squelch /travelto freeportwest')
end
zoning(383)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem "Wand of Imperceptibility"')
    mq.delay(8500)
    mq.cmd('/useitem "Cloudy Potion"')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end

-- Big Slick Jones
mq.cmd('/nav spawn slick')
moving()
mq.cmd('/tar slick')
mq.delay(1500)
mq.cmd('/keypress hail')
mq.delay(1500)
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WAR' then
    mq.cmd('/useitem Cloudy Potion')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'CLR' then
    mq.cmd('/useitem "Cloudy Potion"')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'PAL' then
    mq.cmd('/useitem "Cloudy Potion"')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BER' then
    mq.cmd('/useitem "Wand of Imperceptibility"')
    mq.delay(8500)
    mq.cmd('/useitem "Cloudy Potion"')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BST' then
    mq.cmd('/alt act 3709')
    mq.delay(3500)
    mq.cmd('/alt act 7025')
    mq.delay(3500)
    mq.cmd('/alt act 980')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'BRD' then
    mq.cmd('/alt act 3704')
    mq.delay(2000)
    mq.cmd('/alt act 231')
    mq.delay(2000)
    mq.cmd('/removelev')
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHM' then
    mq.cmd('/alt act 9503')
    mq.delay(3500)
    mq.cmd('/alt act 630')
    mq.delay(1500)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'MAG' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'WIZ' then
    mq.cmd('/alt act 1210')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'SHD' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
if mq.TLO.Me.Invis('SOS')() == false and mq.TLO.Me.Class.ShortName() == 'NEC' then
    mq.cmd('/alt act 531')
    mq.delay(1000)
end
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
mq.delay(2500)
--mq.cmd('/travelto guildhalllrg')
mq.cmd('/timed 10 /lua run poker')
local end_time = os.time()
print("Quest Run Time... " .. end_time - start_time .. " Seconds")