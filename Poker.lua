-- poker.lua 23rd anniversary task
-- Version 1.4b
-- Created: 3/25/2022
-- Updated: 3/31/2022
-- Creator: JB321
-- Quest: https://everquest.allakhazam.com/db/quest.html?quest=10723

local mq = require('mq')

local function moving()
    while mq.TLO.Nav.Active() do mq.delay(1) end
    return
end

local function zoning(z_id)
    while mq.TLO.Zone.ID() ~= z_id do mq.delay(1) end
    return
end

-- possible TODO
-- auto shrink
-- auto invis functions
-- if we are in neriak shrink and invis
-- or just neriak commons
-- replace npc with locs

mq.cmd('/popup Starting: Paintings Playing Poker 23rd Anniversary Quest')
local start_time = os.time()
mq.cmd('/removelev')
mq.cmd('/squelch /travelto freeportwest')
zoning(383)
mq.cmd('/squelch /nav spawn slick')
moving()
mq.cmd('/tar slick')
mq.delay(2500)
mq.cmd('/say paintings')
mq.delay(2500)
mq.cmd('/squelch /nav locyxz -177 -415 -85')
moving()
mq.delay(5500)
mq.cmd('/travelto freeporteast')
zoning(382)
mq.cmd('/nav spawn bluffin')
moving()
mq.cmd('/tar bluffin')
mq.delay(1500)
mq.cmd('/keypress hail')
mq.delay(1500)
mq.cmd('/autoinv')
mq.delay(1500)
-- Neriak Foreign Quarter
mq.cmd('/travelto neriaka')
zoning(40)
mq.delay(1500)
mq.cmd('/squelch /nav locyx -352 -207')
moving()
mq.delay(1500)
mq.cmd('/nav spawn slug')
moving()
mq.delay(1500)
-- Neriak Commons
mq.cmd('/travelto neriakb')
zoning(41)
mq.delay(1500)
-- The Blind Fish
mq.cmd('/nav spawn maren')
moving()
mq.delay(1500)
-- Toadstool Tavern
mq.cmd('/squelch /nav locyxz -148 -994 -26')
moving()
mq.delay(5500)
-- Zone Helper NAV
mq.cmd('/squelch /nav locyx -1 -482')
moving()
mq.delay(1500)
-- Highpass Hold
mq.cmd('/travelto highpasshold')
zoning(407)
mq.delay(1500)
mq.cmd('/nav spawn quads')
moving()
mq.delay(1500)
mq.cmd('/tar quads')
mq.delay(1500)
mq.cmd('/keypress hail')
mq.delay(1500)
mq.cmd('/nav spawn gubli')
moving()
mq.delay(1500)
mq.cmd('/squelch /nav locyx -432 -257')
moving()
mq.delay(1500)
mq.cmd('/nav locyxz -414 -264 -11')
moving()
mq.delay(1500)
mq.cmd('/nav spawn queen')
moving()
mq.delay(1500)
mq.cmd('/tar queen')
mq.delay(1500)
mq.cmd('/keypress hail')
mq.delay(1500)
mq.cmd('/nav spawn gubli')
moving()
mq.delay(1500)
mq.cmd('/nav spawn poker')
moving()
mq.delay(1500)
mq.cmd('/nav locyxz -121 612 -12')
moving()
mq.delay(1500)
mq.cmd('/travelto qeynos2')
zoning(2)
mq.delay(1500)
mq.cmd('/nav locyxz 118 335 1')
moving()
mq.delay(3500)
mq.cmd('/travelto qeynos')
zoning(1)
mq.delay(1500)
-- Fish's Ale
mq.cmd('/squelch /nav locyxz -282 -230 2')
moving()
mq.delay(7500)
-- The Lion's Mane Tavern
mq.cmd('/squelch /nav locyxz 311 -173 4')
moving()
mq.delay(2500)
-- West Freeport
mq.cmd('/travelto freeportwest')
zoning(383)
-- Big Slick Jones
mq.cmd('/nav spawn slick')
moving()
mq.cmd('/tar slick')
mq.delay(2500)
mq.cmd('/keypress hail')
mq.delay(3500)
mq.cmd('/travelto poknowledge')
local end_time = os.time()
print("Quest Run Time... " .. end_time - start_time .. " Seconds")
