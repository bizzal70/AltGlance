-- The game's side: whichever character is logged in.
-- Each character's faction (Alliance unless set).
UnitFactionGroup = function() return ME.faction or "Alliance" end
ME = {
    guid = "Player-1", name = "Mirabel", class = "Mage", classFile = "MAGE", level = 12, money = 23456,
    zone = "Elwynn Forest", xp = 500, xpMax = 2000, rested = 400, resting = true,
    professions = { [1] = { "Mining", 45, 75 }, [2] = { "Herbalism", 60, 75 } },
    bags = { [0] = { 16, 5 }, { 8, 2 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },   -- bag -> { slots, free }
    items = { [0] = { { 2589, 20 }, { 2770, 4 } }, [1] = { [3] = { 2589, 6 } } },
}
PLAYER_GUID = ME.guid
UnitGUID = function() return ME.guid end
UnitName = function() return ME.name end
GetRealmName = function() return "Stonehold" end
UnitClass = function() return ME.class, ME.classFile end
UnitLevel = function() return ME.level end
GetMoney = function() return ME.money end
GetRealZoneText = function() return ME.zone end
UnitXP = function() return ME.xp end
UnitXPMax = function() return ME.xpMax end
GetXPExhaustion = function() return ME.rested end
IsResting = function() return ME.resting end
GetProfessions = function() return ME.professions[1] and 1 or nil, ME.professions[2] and 2 or nil end
GetProfessionInfo = function(index) local p = ME.professions[index]; return p[1], "icon", p[2], p[3] end
-- Item names for the fake links.
local ITEM_NAMES = { [2589] = "Linen Cloth", [2770] = "Copper Ore", [2771] = "Tin Ore", [765] = "Silverleaf" }
C_Container = {
    GetContainerNumSlots = function(bag) return ME.bags[bag] and ME.bags[bag][1] or 0 end,
    GetContainerNumFreeSlots = function(bag) return ME.bags[bag] and ME.bags[bag][2] or 0 end,
    -- ME.items[bag][slot] = { itemID, count }
    GetContainerItemInfo = function(bag, slot)
        local item = ME.items and ME.items[bag] and ME.items[bag][slot]
        if not item then return nil end
        return { itemID = item[1], stackCount = item[2],
            hyperlink = "|cffffffff|Hitem:" .. item[1] .. "::|h[" .. ITEM_NAMES[item[1]] .. "]|h|r" }
    end,
}
-- The item tooltip hook, and the lines it adds.
local tooltipHook
TooltipDataProcessor = { AddTooltipPostCall = function(kind, hook) if kind == "item" then tooltipHook = hook end end }
Enum.TooltipDataType = { Item = "item" }
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
local tooltipLines = {}
rawset(GameTooltip, "AddLine", function(_, text) tooltipLines[#tooltipLines + 1] = text end)
rawset(GameTooltip, "AddDoubleLine", function(_, left, right) tooltipLines[#tooltipLines + 1] = left .. " = " .. right end)
local function Hover(itemID)
    tooltipLines = {}
    tooltipHook(GameTooltip, { id = itemID })
    return table.concat(tooltipLines, "\n")
end
-- What the addon prints in chat.
local printed = {}
print = function(m) printed[#printed + 1] = m end
C_ClassColor = { GetClassColor = function(classFile) if classFile == "MAGE" then return { r = 0.25, g = 0.78, b = 0.92 } end end }
-- The fake clock the addon reads; tests move it forward.
local clock = 1800000000
time = function() return clock end

local ns = LoadAddon(ADDON_DIR, "AltGlance")
local function check(cond, what) if not cond then error("CHECK FAILED: " .. what, 2) end; io.write("pass  ", what, "\n") end
local function near(a, b) return math.abs(a - b) < 0.0001 end

Fire("PLAYER_LOGIN")
check(AltGlanceDB == nil, "before its settings load, nothing is recorded")
Fire("ADDON_LOADED", "AltGlance"); Fire("PLAYER_LOGIN")
local me = ns.db.chars["Player-1"]
check(me and me.name == "Mirabel" and me.level == 12 and me.money == 23456 and me.zone == "Elwynn Forest" and me.classFile == "MAGE" and me.faction == "Alliance" and me.realm == "Stonehold", "logging in records the character")
check(#me.professions == 2 and me.professions[1].name == "Mining" and me.professions[1].level == 45 and me.professions[1].max == 75, "with their professions")
check(me.bagFree == 7 and me.bagTotal == 24, "and their free bag space")
check(me.rested == 400 and me.resting == true and me.seen == clock, "and their rested experience and when they were seen")

ME.money = 30000; Fire("PLAYER_MONEY")
ME.level = 13; Fire("PLAYER_LEVEL_UP")
ME.zone = "Westfall"; Fire("ZONE_CHANGED_NEW_AREA")
check(me.money == 30000 and me.level == 13 and me.zone == "Westfall", "money, level and zone are kept up to date as they change")

-- a value the game withholds must not wipe out what is known
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
ME.money = SECRET; Fire("PLAYER_MONEY")
check(me.money == 30000, "a value the game withholds for a moment does not replace the known one")
ME.money = 30000
ME.rested = nil; Fire("UPDATE_EXHAUSTION")
check(me.rested == 0, "no rested experience is recorded as none")
ME.rested = 400; Fire("UPDATE_EXHAUSTION")

-- Logging out: Forever has already cleared money, experience, bags and
-- professions to 0 by then. That must not overwrite the real figures.
local real = { money = ME.money, xp = ME.xp, bags = ME.bags, professions = ME.professions }
ME.money, ME.xp, ME.xpMax = 0, 0, 0
ME.bags = { [0] = { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
ME.professions = {}
Fire("PLAYER_LOGOUT")
check(me.money == 30000 and me.xp == 500 and me.bagTotal == 24 and #me.professions == 2,
    "logging out does not overwrite the character with the zeros the game reports then")
-- Just after logging in, before the bags have loaded, bag space is not wiped either.
Fire("BAG_UPDATE_DELAYED")
check(me.bagTotal == 24, "bags that have not loaded yet (no space at all) are not recorded as empty")
ME.money, ME.xp, ME.xpMax, ME.bags, ME.professions = real.money, real.xp, 2000, real.bags, real.professions
-- A second read a moment after logging in picks up figures that arrive late.
local before = #AFTERS
Fire("PLAYER_LOGIN")
check(#AFTERS > before, "logging in reads the character again a moment later")
ME.money = 31000
AFTERS[#AFTERS]()
check(me.money == 31000, "and that later read is recorded")
ME.money = 30000; Fire("PLAYER_MONEY")

-- a second and third character
ME = {
    guid = "Player-2", name = "Tolan", class = "Hunter", classFile = "HUNTER", level = 10, money = 500, faction = "Horde",
    zone = "Dun Morogh", xp = 0, xpMax = 1000, rested = 0, resting = false, professions = {},
    bags = { [0] = { 16, 16 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
    items = { [0] = { { 2589, 5 } } },
}
clock = clock + 3600
Fire("PLAYER_LOGIN")
ME = {
    guid = "Player-3", name = "Aaron", class = "Warrior", classFile = "WARRIOR", level = 30, money = 1000000,
    zone = "Stormwind", xp = 100, xpMax = 10000, rested = 0, resting = true, professions = { [1] = { "Skinning", 150, 225 } },
    bags = { [0] = { 16, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
}
clock = clock + 3600
Fire("PLAYER_LOGIN")

local list, total = ns.Characters()
check(#list == 3 and total == 30000 + 500 + 1000000, "every character is listed, with the total of their money")

-- "On my alts": what each character holds, in tooltips and /alts find
check(ns.db.chars["Player-1"].bagItems[2589] == 26 and ns.db.chars["Player-1"].bagItems[2770] == 4,
    "each character's bags are counted, stacks in different bags added up")
check(ns.db.chars["Player-2"].bagItems[2589] == 5 and ns.db.chars["Player-3"].bagItems ~= nil and next(ns.db.chars["Player-3"].bagItems) == nil,
    "a character with empty bags has nothing counted")
check(ns.db.itemLinks[2589]:find("Linen Cloth", 1, true), "item links are kept for their names")
-- Aaron, being played, opens the bank: the bank and its bags are read while it is open.
ME.bags[-1] = { 28, 26 }; ME.bags[6] = { 10, 9 }
ME.items = { [-1] = { { 2589, 12 }, { 765, 3 } }, [6] = { [4] = { 2771, 7 } } }
Fire("BAG_UPDATE_DELAYED")
check(ns.db.chars["Player-3"].bankItems == nil, "the bank is not read while it is closed")
Fire("BANKFRAME_OPENED")
local aaron = ns.db.chars["Player-3"]
check(aaron.bankItems and aaron.bankItems[2589] == 12 and aaron.bankItems[765] == 3 and aaron.bankItems[2771] == 7 and aaron.bankSeen == clock,
    "opening the bank reads it, bank bags included")
check(next(aaron.bagItems) == nil, "bank items are not counted as carried")
ME.items[-1][1] = { 2589, 2 }; Fire("PLAYERBANKSLOTS_CHANGED")
check(aaron.bankItems[2589] == 2, "taking items out of the open bank is kept up to date")
Fire("BANKFRAME_CLOSED")
ME.items[-1][1] = nil; Fire("BAG_UPDATE_DELAYED")
check(aaron.bankItems[2589] == 2, "once closed, the bank is remembered as it was")
-- Hovering over Linen Cloth
local text = Hover(2589)
check(text:find("On your characters:", 1, true) and text:find("Mirabel = 26", 1, true) and text:find("Tolan = 5", 1, true)
    and text:find("Aaron = 2 (bank)", 1, true) and text:find("Total = 33", 1, true), "the item tooltip lists each character's count and the total: " .. text)
check(text:find("Mirabel") < text:find("Tolan") and text:find("Tolan") < text:find("Aaron"), "most first")
check(text:find("PlusManz%-Horde") and text:find("PlusManz%-Alliance"), "with each character's faction crest")
ME.items[0] = { { 765, 1 } }; Fire("BAG_UPDATE_DELAYED")
check(Hover(765):find("Aaron = 4 (bags 1, bank 3)", 1, true), "bags and bank are told apart")
check(not Hover(765):find("Total", 1, true), "one character: no total line")
check(Hover(12345) == "", "an item nobody holds adds nothing")
check(Hover(SECRET) == "" and Hover(nil) == "", "an item the game withholds adds nothing, without an error")
SlashCmdList.ALTGLANCE("tooltip")
check(Hover(2589) == "" and not ns.db.itemTooltip, "/alts tooltip turns the lines off")
SlashCmdList.ALTGLANCE("tooltip")
check(Hover(2589) ~= "", "and on again")
-- /alts find
local found = ns.FindItems("ore")
check(#found == 2 and found[1].name == "Copper Ore" and found[2].name == "Tin Ore", "/alts find matches part of a name, ignoring case")
printed = {}
SlashCmdList.ALTGLANCE("find LINEN")
check(#printed == 1 and printed[1]:find("Linen Cloth", 1, true) and printed[1]:find("Mirabel 26, Tolan 5, Aaron 2 (bank)", 1, true),
    "/alts find prints who holds it: " .. tostring(printed[1]))
printed = {}
SlashCmdList.ALTGLANCE("find dragonscale")
check(#printed == 1 and printed[1]:find("None of your characters", 1, true), "and says so when nobody has it")
SlashCmdList.ALTGLANCE("find")
ME.items = nil; ME.bags[-1] = nil; ME.bags[6] = nil
check(list[1].name == "Aaron" and list[2].name == "Mirabel" and list[3].name == "Tolan", "sorted by level, highest first, to begin with")
check(list[1].isCurrent and not list[2].isCurrent, "and the one being played is marked")

-- rested experience grows while a character is away
local fraction, estimated = ns.Rested(ns.db.chars["Player-1"], false)
check(estimated and near(fraction, 0.2 + 7200 * 0.05 / (8 * 3600)), "a resting character's rested bonus is estimated to have grown while away")
clock = clock + 400 * 3600
fraction = ns.Rested(ns.db.chars["Player-1"], false)
check(near(fraction, 1.5), "but never past one and a half levels")
local outdoors = ns.Rested(ns.db.chars["Player-2"], false)
local inInn = ns.Rested({ xpMax = 1000, rested = 0, resting = true, seen = ns.db.chars["Player-2"].seen }, false)
check(outdoors > 0 and near(math.min(1.5, outdoors * 4), inInn), "and a quarter as fast out in the world")
fraction, estimated = ns.Rested(ns.db.chars["Player-3"], true)
check(not estimated and fraction == 0, "the character being played shows the exact figure")
clock = clock - 400 * 3600

check(ns.Money(1234567) == "123g 45s 67c" and ns.Ago(clock - 7200) == "2 h ago" and ns.Ago(clock - 3 * 86400) == "3 days ago", "money and elapsed time are written plainly")

-- the window
SlashCmdList.ALTGLANCE("")
check(AltGlanceWindow:IsShown(), "/alts opens the list")
local shown = {}
for _, f in ipairs(Frames()) do
    if rawget(f, "cells") and f.__shown then shown[#shown + 1] = f end
end
check(#shown == 3 and shown[1].cells.name.__text == "Aaron" and shown[2].cells.level.__text == "13", "one row per character, in order")
check(shown[2].cells.professions.__text == "Mining 45, Herbalism 60" and shown[2].cells.bags.__text == "7 / 24", "showing professions and bag space")
check(shown[1].cells.seen.__text == "now" and shown[2].cells.seen.__text == "2 h ago", "and when each was last played")
check(shown[1].cells.money.__text == "100g" and shown[3].cells.money.__text == "5s", "and their money")
check(shown[2].cells.rested.__text:sub(1, 1) == "~", "an estimated rested figure is marked as approximate")
for _, row in ipairs(shown) do row.__scripts.OnEnter(row) end

-- Horde or Alliance at a glance: the faction's crest before the name, the
-- row faintly tinted red or blue, and each faction's gold in the footer.
check(shown[1].faction.__texture:find("PlusManz%-Alliance") and shown[3].faction.__texture:find("PlusManz%-Horde"),
    "each row shows its faction's crest")
check(shown[3].tint.__rgba[1] > shown[3].tint.__rgba[3] and shown[1].tint.__rgba[3] > shown[1].tint.__rgba[1],
    "and is tinted red for the Horde, blue for the Alliance")
local footer
for _, f in ipairs(Frames()) do
    local text = rawget(f, "__text")
    if text and text:find("Total:", 1, true) then footer = text end
end
check(footer and footer:find("Horde 1: 5s", 1, true) and footer:find("Alliance 2: 103g", 1, true),
    "the footer shows each faction's characters and gold, which cannot cross factions: " .. tostring(footer))

-- sorting by clicking a heading
local headings = {}
for _, f in ipairs(Frames()) do
    if rawget(f, "column") and f.__scripts.OnClick then headings[f.column.key] = f end
end
headings.name.__scripts.OnClick(headings.name)
list = ns.Characters()
check(ns.db.sortBy == "name" and list[1].name == "Aaron" and list[3].name == "Tolan", "clicking Character sorts A to Z")
headings.name.__scripts.OnClick(headings.name)
list = ns.Characters()
check(list[1].name == "Tolan", "clicking it again reverses the order")
headings.money.__scripts.OnClick(headings.money)
list = ns.Characters()
check(list[1].name == "Aaron" and list[3].name == "Tolan", "clicking Gold sorts richest first")
headings.faction.__scripts.OnClick(headings.faction)
list = ns.Characters()
check(ns.db.sortBy == "faction" and list[1].name == "Aaron" and list[2].name == "Mirabel" and list[3].name == "Tolan",
    "clicking Faction groups the Alliance first, highest level first within it")
headings.faction.__scripts.OnClick(headings.faction)
list = ns.Characters()
check(list[1].name == "Tolan" and list[2].name == "Aaron" and list[3].name == "Mirabel",
    "clicking it again puts the Horde first, still highest level first within each faction")
for key, heading in pairs(headings) do heading.__scripts.OnClick(heading) end
check(true, "every sortable heading sorts without error")

-- removing a character takes two presses
headings.level.__scripts.OnClick(headings.level)
if not ns.db.sortDescending then headings.level.__scripts.OnClick(headings.level) end
local row = nil
for _, f in ipairs(Frames()) do
    if rawget(f, "cells") and f.__shown and f.record.name == "Tolan" then row = f end
end
check(row.remove.__shown and not shown[1].remove.__shown, "every character but the one being played can be removed")
row.remove.__scripts.OnClick(row.remove)
check(ns.db.chars["Player-2"] ~= nil, "one press on the x does not remove anyone")
row.remove.__scripts.OnClick(row.remove)
check(ns.db.chars["Player-2"] == nil and #ns.Characters() == 2, "a second press does")
row.remove.__scripts.OnEnter(row.remove)

SlashCmdList.ALTGLANCE("forget aar")
check(ns.db.chars["Player-3"] ~= nil, "/alts forget will not remove the character being played")
SlashCmdList.ALTGLANCE("forget nobody")
SlashCmdList.ALTGLANCE("forget mira")
check(ns.db.chars["Player-1"] == nil and #ns.Characters() == 1, "/alts forget removes a character by the start of their name")

-- the minimap button
check(AltGlanceMinimapButton.__shown, "the minimap button shows by default")
AltGlanceMinimapButton.__scripts.OnClick(AltGlanceMinimapButton)
check(not AltGlanceWindow:IsShown(), "and toggles the list")
AltGlanceMinimapButton.__scripts.OnEnter(AltGlanceMinimapButton)
AltGlanceMinimapButton.__scripts.OnDragStart(AltGlanceMinimapButton)
AltGlanceMinimapButton.__scripts.OnUpdate(AltGlanceMinimapButton, 0.1)
AltGlanceMinimapButton.__scripts.OnDragStop(AltGlanceMinimapButton)
SlashCmdList.ALTGLANCE("button")
check(not AltGlanceMinimapButton.__shown and not ns.db.minimapButton, "/alts button hides it")
SlashCmdList.ALTGLANCE("button")
AltGlance_OnAddonCompartmentClick()
check(AltGlanceWindow:IsShown(), "the minimap addon list entry opens the list")
SlashCmdList.ALTGLANCE("help")

-- the game misbehaving must not leave an error on screen
UnitXPMax = function() error("something this client does differently") end
local ok = pcall(Fire, "PLAYER_XP_UPDATE")
check(ok, "a surprise from the game while recording does not raise an error")
