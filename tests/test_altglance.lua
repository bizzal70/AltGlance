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

-- Send materials at the mailbox, and the bank alt. Aaron (Alliance) is
-- being played; Mirabel is Alliance on the same realm, Tolan is Horde.
local CATEGORY = { [774] = { 7, 11 }, [818] = { 7, 11 }, [999] = { 7, 11 }, [6271] = { 9, 2 }, [6272] = { 9, 2 }, [1000] = { 2, 7 }, [1001] = { 4, 2 }, [1002] = { 4, 1 }, [2770] = { 7, 7 }, [2771] = { 7, 7 }, [765] = { 7, 9 }, [2318] = { 7, 6 }, [2589] = { 7, 5 }, [117] = { 0, 5 } }
C_Item = C_Item or {}
C_Item.GetItemInfoInstant = function(id) local c = CATEGORY[id]; if c then return id, "", "", "", 0, c[1], c[2] end end
ITEM_NAMES[2318], ITEM_NAMES[117] = "Light Leather", "Tough Jerky"
ITEM_NAMES[1000], ITEM_NAMES[1001], ITEM_NAMES[1002] = "Green Sword", "Blue Vest", "Grey Boots"
ITEM_NAMES[999] = "Some Reagent"
ITEM_NAMES[774], ITEM_NAMES[818], ITEM_NAMES[6271], ITEM_NAMES[6272] = "Malachite", "Tigerseye", "Pattern: Red Linen Vest", "Pattern: Bound"
C_Container.GetContainerItemInfo = function(bag, slot)
    local item = ME.items and ME.items[bag] and ME.items[bag][slot]
    if not item then return nil end
    return { itemID = item[1], stackCount = item[2], isBound = item.bound, quality = item.quality,
        hyperlink = "|cffffffff|Hitem:" .. item[1] .. "::|h[" .. ITEM_NAMES[item[1]] .. "]|h|r" }
end
local cursor, attached, sentMails, timers = nil, {}, {}, {}
C_Container.PickupContainerItem = function(bag, slot) cursor = { bag = bag, slot = slot } end
ClickSendMailItemButton = function(index) if cursor then attached[index] = cursor; cursor = nil end end
CursorHasItem = function() return cursor ~= nil end
ClearCursor = function() cursor = nil end
GetSendMailItem = function(index) if attached[index] then return "item" end end
GetSendMailPrice = function() local n = 0; for _ in pairs(attached) do n = n + 1 end; return 30 * n end
SendMail = function(to, subject)
    local stacks = 0
    for _, a in pairs(attached) do ME.items[a.bag][a.slot] = nil; stacks = stacks + 1 end
    sentMails[#sentMails + 1] = { to = to, subject = subject, stacks = stacks }
    attached = {}
end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
local nameBox = { text = "" }
function nameBox:GetText() return self.text end
function nameBox:SetText(t) self.text = t end
SendMailNameEditBox = nameBox
ME.bags[1] = { 16, 0 }
ME.items = { [0] = { { 2770, 20 }, { 765, 5 }, { 2318, 8 }, { 2589, 10 }, { 117, 4 }, { 2770, 20, bound = true } }, [1] = {} }
for slot = 1, 10 do ME.items[1][slot] = { 2771, 5 } end
Fire("BAG_UPDATE_DELAYED")
-- Forever's full names: first and last. Learned when a character is played.
GetUnitName = function(unit, withRealm) return ME.name .. " " .. (ME.surname or "Stone") end
Fire("PLAYER_MONEY")
check(ns.db.chars["Player-3"].fullName == "Aaron Stone", "the full name (first and last) is recorded")
GetUnitName = nil
UnitName = function() return ME.name, "Ashford" end
Fire("PLAYER_MONEY")
ns.db.chars["Player-3"].fullName = nil; Fire("PLAYER_MONEY")
check(ns.db.chars["Player-3"].fullName == "Aaron Ashford", "without GetUnitName, it is the first name and UnitName's second value")
ns.db.chars["Player-3"].fullName = "Aaron Stone"
UnitName = function() return ME.name end
Fire("MAIL_SHOW")
local panel = ns.mailPanel
check(#ns.MailRecipients() == 0, "a character whose full name is not known yet is not offered (mail only goes to full names)")
ns.db.chars["Player-1"].fullName = "Mirabel Brightwater"
ns.db.chars["Player-2"].fullName = "Tolan Grimbane"
ns.RefreshMailPanel()
check(panel and panel:IsShown(), "opening the mailbox shows the Send materials panel")
local list = ns.MailRecipients()
check(#list == 1 and list[1].record.fullName == "Mirabel Brightwater", "only characters this one can mail are offered: same realm and faction")
check(#ns.MaterialsToSend() == 14, "ore, herbs, leather and cloth are picked up; food and soulbound items are not")
-- Forever's GetRealmName can come back empty: the realm is then taken from
-- another character on the same realm server (the number in the GUID).
do
    local chars = ns.db.chars
    chars["Player-77-0A"] = { name = "Bizzall", fullName = "Bizzall Wolfbane", realm = "", faction = "Alliance" }
    chars["Player-77-0B"] = { name = "Shannbizz", fullName = "Shannbizz Wolfbane", realm = "CAMWOW Realm 10", faction = "Alliance" }
    chars["Player-78-0C"] = { name = "Farbizz", fullName = "Farbizz Wolfbane", realm = "CAMWOW Realm 9", faction = "Alliance" }
    check(ns.RealmOf("Player-77-0A", chars["Player-77-0A"]) == "CAMWOW Realm 10", "an empty realm name is filled in from a character on the same realm server")
    chars["Player-77-0A"].realm = "CAMWOWRealm10"
    check(ns.RealmOf("Player-77-0A", chars["Player-77-0A"]) == "CAMWOW Realm 10"
        and ns.CanMail(chars["Player-77-0A"], "Player-77-0A", "Player-77-0B", chars["Player-77-0B"]),
        "a realm name spelt differently (no spaces) still counts as the same realm, by the server number")
    chars["Player-77-0A"].realm = ""
    check(ns.CanMail(chars["Player-77-0A"], "Player-77-0A", "Player-77-0B", chars["Player-77-0B"])
        and not ns.CanMail(chars["Player-77-0A"], "Player-77-0A", "Player-78-0C", chars["Player-78-0C"]),
        "so a character with no realm name can still mail its alts on that realm, and not those elsewhere")
    local realGuid, realRealm = UnitGUID, GetRealmName
    UnitGUID = function() return "Player-77-0A" end
    GetRealmName = function() return "" end
    ns.db.bankAlt["CAMWOW Realm 10|Alliance"] = "Player-77-0B"
    check(ns.BankAlt() == "Player-77-0B", "and finds the bank alt set for that realm")
    Fire("PLAYER_MONEY")
    check(chars["Player-77-0A"].realm == nil, "an empty realm name from the game is not saved")
    UnitGUID, GetRealmName = realGuid, realRealm
    chars["Player-77-0A"], chars["Player-77-0B"], chars["Player-78-0C"] = nil, nil, nil
    ns.db.bankAlt["CAMWOW Realm 10|Alliance"] = nil
end
-- Materials a quest asks for stay in the bags.
C_QuestLog = {
    GetNumQuestLogEntries = function() return 2, 1 end,
    GetInfo = function(index)
        if index == 1 then return { isHeader = true, title = "Elwynn Forest" } end
        return { questID = 77, title = "Linen for the Tailor" }
    end,
    GetQuestObjectives = function()
        return { { text = "4/6 Linen Cloth", type = "item", numRequired = 6 }, { text = "2/8 Wolves slain", type = "monster", numRequired = 8 } }
    end,
}
local materials, kept = ns.MaterialsToSend()
local hasLinen = false
for _, m in ipairs(materials) do if m.id == 2589 then hasLinen = true end end
check(#materials == 13 and not hasLinen and kept["Linen Cloth"] == 10, "cloth a quest in the log asks for is kept, not mailed")
ns.RefreshMailPanel()
check(panel.questNote.__text == "Kept for quests: Linen Cloth 10", "and the panel says what was kept: " .. tostring(panel.questNote.__text))
-- Two stacks of tin, five each, and a quest wanting 8: both stay; wanting 5, one stays and the rest go.
C_QuestLog = nil
local tinWanted = 8
GetNumQuestLogEntries = function() return 1 end
GetNumQuestLeaderBoards = function() return 2 end
GetQuestLogLeaderBoard = function(objective)
    if objective == 1 then return "Tin Ore: 0/" .. tinWanted, "item", false end
    return "Defias Thug slain: 3/10", "monster", false
end
materials, kept = ns.MaterialsToSend()
check(#materials == 12 and kept["Tin Ore"] == 10, "with the original game's quest log, enough stacks are kept to cover the quest")
tinWanted = 5
materials, kept = ns.MaterialsToSend()
check(#materials == 13 and kept["Tin Ore"] == 5, "and only as many stacks as it takes")
GetQuestLogLeaderBoard = function() error("something this client does differently") end
check(#ns.MaterialsToSend() == 14, "a surprise from the quest log keeps nothing back, without an error")
GetNumQuestLogEntries, GetNumQuestLeaderBoards, GetQuestLogLeaderBoard = nil, nil, nil
ns.RefreshMailPanel()
check(panel.questNote.__text == "", "with no quests wanting anything, the note is empty")
panel.toggles.cloth.__scripts.OnClick(panel.toggles.cloth)
check(#ns.MaterialsToSend() == 13 and not ns.db.mailKinds.cloth, "a kind can be turned off")
check(nameBox.text == "", "with no bank alt, the To box is left empty")
-- Making Mirabel the bank alt fills in the To box.
panel.bank.__scripts.OnClick(panel.bank)
check(ns.BankAlt() == "Player-1" and nameBox.text == "Mirabel Brightwater", "Make Mirabel my bank alt fills her name in on Send Mail")
-- Sending: 12 stacks a mail, the rest after the first has gone.
GetMoney = function() return 100000 end
-- On the Inbox page: AltGlance does not click Blizzard's tab for you (blocked in Forever).
SendMailFrame = { IsShown = function() return false end }
panel.send.__scripts.OnClick(panel.send)
check(#sentMails == 0 and printed[#printed]:find("Open the Send Mail tab first", 1, true), "on the Inbox page it asks you to open Send Mail instead of switching tabs itself")
SendMailFrame = { IsShown = function() return true end }
panel.send.__scripts.OnClick(panel.send)
check(#sentMails == 1 and sentMails[1].to == "Mirabel Brightwater" and sentMails[1].stacks == 12 and sentMails[1].subject == "Materials", "Send mails the first 12 stacks to Mirabel")
Fire("MAIL_SEND_SUCCESS"); RunTimers()
check(#sentMails == 2 and sentMails[2].stacks == 1, "then the rest once the first has gone")

Fire("MAIL_SEND_SUCCESS"); RunTimers()
check(#sentMails == 2 and printed[#printed]:find("Sent 13 stacks in 2 mails to Mirabel", 1, true), "and says what was sent: " .. tostring(printed[#printed]))
check(ME.items[0][4] ~= nil and ME.items[0][6] ~= nil, "the cloth (turned off) and the soulbound ore stay")
-- After an ordinary mail the To box is filled in again.
nameBox.text = ""
Fire("MAIL_SEND_SUCCESS"); RunTimers()
check(nameBox.text == "Mirabel Brightwater", "after a mail is sent, the bank alt's name is filled in again")
-- In gamepad mode the To box is never typed into (the game blocks gamepad steps after).
nameBox.text = ""
C_GamePad = { IsEnabled = function() return true end }
Fire("MAIL_SHOW")
check(nameBox.text == "", "in gamepad mode the bank alt name is not typed into Blizzard's To box")
C_GamePad = nil
nameBox.text = "Someone"
Fire("MAIL_SHOW")
check(nameBox.text == "Someone", "a name you typed is never replaced")
-- Not enough money for postage: nothing goes.
panel.toggles.cloth.__scripts.OnClick(panel.toggles.cloth)
GetMoney = function() return 10 end
panel.send.__scripts.OnClick(panel.send)
check(#sentMails == 2 and printed[#printed]:find("Not enough money for the postage", 1, true), "without money for postage nothing is sent")
attached = {}
-- Something already on the mail: it waits.
GetMoney = function() return 100000 end
attached[1] = { bag = 0, slot = 4 }
panel.send.__scripts.OnClick(panel.send)
check(#sentMails == 3 and sentMails[3].to == "Mirabel Brightwater" and sentMails[3].stacks == 1 and sentMails[3].subject == "Items",
    "items you put on the mail yourself: Send mails that mail to the bank alt")
Fire("MAIL_SEND_SUCCESS"); RunTimers()
-- ...but never one with money or C.O.D. on it.
attached[1] = { bag = 0, slot = 1 }
GetSendMailMoney = function() return 500 end
panel.send.__scripts.OnClick(panel.send)
check(#sentMails == 3 and printed[#printed]:find("money or C.O.D.", 1, true), "a mail with money on it is left for the mailbox's own Send")
GetSendMailMoney = nil
attached = {}
-- /alts bank
SlashCmdList.ALTGLANCE("bank")
check(printed[#printed]:find("Mirabel Brightwater is your bank alt", 1, true), "/alts bank says who the bank alt is")
SlashCmdList.ALTGLANCE("bank tol")
check(printed[#printed]:find("another realm or faction", 1, true) and ns.BankAlt() == "Player-1", "a character of the other faction cannot be the bank alt")
SlashCmdList.ALTGLANCE("bank off")
check(ns.BankAlt() == nil, "/alts bank off clears it")
SlashCmdList.ALTGLANCE("bank mira")
check(ns.BankAlt() == "Player-1", "/alts bank <name> sets it")
-- Other trade goods: off until turned on; whatever no other kind claims.
ITEM_NAMES[4363], ITEM_NAMES[2678] = "Copper Modulator", "Mild Spices"
CATEGORY[4363], CATEGORY[2678] = { 7, 1 }, { 7, 8 }
ME.items[0] = { { 4363, 1 }, { 2678, 4 }, { 774, 2 }, { 2770, 5 }, { 6291, 3 } }
ITEM_NAMES[6291] = "Raw Brilliant Smallfish"; CATEGORY[6291] = { 7, 8 }
for _, key in ipairs({ "ore", "herb", "leather", "cloth" }) do ns.db.mailKinds[key] = false end
check(#ns.MaterialsToSend() == 0, "other trade goods are never sent unless turned on")
panel.toggles.other.__scripts.OnClick(panel.toggles.other)
local others = ns.MaterialsToSend()
check(#others == 2 and others[1].id == 4363 and others[2].id == 2678, "Other trade goods: parts and spices; not gems, ore or fish, even with those kinds off")
panel.toggles.other.__scripts.OnClick(panel.toggles.other)
for _, key in ipairs({ "ore", "herb", "leather", "cloth" }) do ns.db.mailKinds[key] = true end
-- Fishing catch: off until turned on; raw fish and named catches, not meat.
ITEM_NAMES[6291], ITEM_NAMES[6358], ITEM_NAMES[2677], ITEM_NAMES[7973] = "Raw Brilliant Smallfish", "Oily Blackmouth", "Boar Ribs", "Big-mouth Clam"
CATEGORY[6291], CATEGORY[6358], CATEGORY[2677], CATEGORY[7973] = { 7, 8 }, { 7, 8 }, { 7, 8 }, { 15, 0 }
ME.items[0] = { { 6291, 12 }, { 6358, 3 }, { 2677, 5 }, { 7973, 2 } }
check(#ns.MaterialsToSend() == 0 and not ns.db.mailKinds.fish, "fishing catch is never sent unless turned on")
panel.toggles.fish.__scripts.OnClick(panel.toggles.fish)
local caught = ns.MaterialsToSend()
check(#caught == 3 and caught[1].id == 6291 and caught[2].id == 6358 and caught[3].id == 7973, "Fishing catch: raw fish, Oily Blackmouth and clams; not the boar ribs")
panel.toggles.fish.__scripts.OnClick(panel.toggles.fish)
-- Gems and recipes: off until turned on; soulbound recipes never.
panel.toggles.disenchant.__scripts.OnClick(panel.toggles.disenchant)
ME.items[0] = { { 774, 7 }, { 818, 1 }, { 6271, 1 }, { 6272, 1, bound = true }, { 999, 3 } }
check(#ns.MaterialsToSend() == 0 and not ns.db.mailKinds.gems and not ns.db.mailKinds.recipes, "gems and recipes are never sent unless turned on")
panel.toggles.gems.__scripts.OnClick(panel.toggles.gems)
check(#ns.MaterialsToSend() == 2, "Gems: Malachite and Tigerseye, filed by Forever under trade goods Other, are known by ID; other Other goods are not")
panel.toggles.recipes.__scripts.OnClick(panel.toggles.recipes)
local found = ns.MaterialsToSend()
check(#found == 3 and found[3].id == 6271, "Recipes & patterns: ones not yet soulbound")
panel.toggles.gems.__scripts.OnClick(panel.toggles.gems)
panel.toggles.recipes.__scripts.OnClick(panel.toggles.recipes)
panel.toggles.disenchant.__scripts.OnClick(panel.toggles.disenchant)
-- Gear to disenchant: off until turned on; then green to purple gear not yet soulbound.
ME.items[0] = { { 1000, 1, quality = 2 }, { 1001, 1, quality = 3, bound = true }, { 1002, 1, quality = 0 } }
ME.items[1] = {}
check(#ns.MaterialsToSend() == 0 and not ns.db.mailKinds.disenchant, "gear is never sent unless Gear to disenchant is turned on")
panel.toggles.disenchant.__scripts.OnClick(panel.toggles.disenchant)
local gearList = ns.MaterialsToSend()
check(#gearList == 1 and gearList[1].id == 1000, "turned on: green, blue and purple gear not yet soulbound; not bound gear, not grey")
panel.send.__scripts.OnClick(panel.send)
check(#sentMails == 4 and sentMails[4].to == "Mirabel Brightwater" and sentMails[4].stacks == 1, "and it is mailed to the bank alt")
Fire("MAIL_SEND_SUCCESS"); RunTimers()
-- The last check before a mail goes: if the chosen character turns out
-- to be on the other faction, nothing is sent.
ME.items[0] = { { 2770, 20 } }
ns.db.chars["Player-1"].faction = "Horde"
local before = #sentMails
local target = { key = "Player-1", record = ns.db.chars["Player-1"] }
local realTarget = ns.MailTarget
ns.MailTarget = function() return target, { target }, 1 end
ns.SendNextMail()
ns.MailTarget = realTarget
check(#sentMails == before and printed[#printed]:find("Not sent", 1, true), "right before sending, a character of the other faction is refused: " .. tostring(printed[#printed]))
ns.db.chars["Player-1"].faction = "Alliance"
attached = {}
-- The mail window is put in place a moment after the mailbox opens: the panel follows its edge.
local mailRight = 1900
MailFrame = { IsShown = function() return true end, GetRight = function() return mailRight end, GetTop = function() return 700 end, GetEffectiveScale = function() return 1 end }
local placedAt
rawset(panel, "SetPoint", function(_, a, b, c, x, y) placedAt = x end)
panel.__scripts.OnUpdate(panel)
check(placedAt == 1906, "the panel sits at the mail window's right edge")
mailRight = 400; panel.__scripts.OnUpdate(panel)
check(placedAt == 406, "and follows it when Blizzard moves the window into place")
MailFrame = nil
-- The panel hides itself whenever the mailbox is gone, even without MAIL_CLOSED.
MailFrame = { IsShown = function() return false end }
panel.__scripts.OnUpdate(panel)
check(not panel:IsShown(), "with the mailbox gone, the panel hides itself")
MailFrame = nil
Fire("MAIL_SHOW")
check(panel:IsShown(), "and comes back with the next mailbox")
Fire("MAIL_CLOSED")
check(not panel:IsShown(), "closing the mailbox hides the panel")
ME.items = nil; ME.bags[1] = { 8, 2 }
GetMoney = function() return ME.money end

-- The Bank alt column in the list: tick to choose, untick to clear.
SlashCmdList.ALTGLANCE("bank off")
local wasShown = AltGlanceWindow:IsShown()
if not wasShown then ns.ToggleWindow() end
local mirabelRow
for _, f in ipairs(Frames()) do
    if rawget(f, "bank") and rawget(f, "record") and f.record.key == "Player-1" and f.__shown then mirabelRow = f end
end
check(mirabelRow and not mirabelRow.bank.tick.__shown, "each row has a Bank alt tick box, unticked")
mirabelRow.bank.__scripts.OnClick(mirabelRow.bank)
check(ns.BankAlt() == "Player-1" and mirabelRow.bank.tick.__shown, "ticking it makes that character the bank alt")
mirabelRow.bank.__scripts.OnEnter(mirabelRow.bank)
mirabelRow.bank.__scripts.OnClick(mirabelRow.bank)
check(ns.BankAlt() == nil and not mirabelRow.bank.tick.__shown, "unticking it clears the bank alt")
mirabelRow.bank.__scripts.OnClick(mirabelRow.bank)
if not wasShown then ns.ToggleWindow() end

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

UnitXPMax = function() return ME.xpMax end

-- The profession planner. Aaron (Alliance, being played) is the crafter;
-- Bizz is Alliance on the same realm, Hordie is Horde.
ITEM_NAMES[2320], ITEM_NAMES[2996] = "Coarse Thread", "Bolt of Linen Cloth"
CATEGORY[2320] = { 7, 11 }
ME.items = { [0] = { { 2589, 3 } } }
Fire("BAG_UPDATE_DELAYED")
ns.db.chars["Player-3"].fullName = "Aaron Stone"
ns.db.chars["Player-3"].bankItems = {}
ns.db.chars["Player-5"] = { name = "Bizz", fullName = "Bizz Wolf", realm = "Stonehold", faction = "Alliance", classFile = "MAGE",
    bagItems = { [2589] = 30, [2320] = 2 }, bankItems = {} }
ns.db.chars["Player-6"] = { name = "Hordie", fullName = "Hordie Grim", realm = "Stonehold", faction = "Horde",
    bagItems = { [2320] = 9 } }
local RECIPES = {
    [101] = { name = "Bolt of Linen Cloth", learned = true, out = 2996, reagents = { { 2589, 2 } } },
    [102] = { name = "Linen Bag", learned = true, reagents = { { 2589, 4 }, { 2320, 1 } } },
    [103] = { name = "Not Learned Yet", learned = false, reagents = { { 2589, 1 } } },
}
local linked = false
Enum.CraftingReagentType = { Modifying = 0, Basic = 1 }
C_TradeSkillUI = {
    GetBaseProfessionInfo = function() return { professionName = "Tailoring" } end,
    GetAllRecipeIDs = function() return { 101, 102, 103 } end,
    GetRecipeInfo = function(id) return { name = RECIPES[id].name, learned = RECIPES[id].learned } end,
    GetRecipeSchematic = function(id)
        local recipe, slots = RECIPES[id], {}
        for _, r in ipairs(recipe.reagents) do
            slots[#slots + 1] = { reagents = { { itemID = r[1] } }, quantityRequired = r[2], required = true, reagentType = 1 }
        end
        -- An optional extra (a modifying reagent) is not a material it needs.
        slots[#slots + 1] = { reagents = { { itemID = 9999 } }, quantityRequired = 1, required = false, reagentType = 0 }
        return { name = recipe.name, outputItemID = recipe.out, reagentSlotSchematics = slots }
    end,
    IsTradeSkillLinked = function() return linked end,
}
Fire("TRADE_SKILL_SHOW"); RunTimers()
local book = ns.db.recipes["Player-3"] and ns.db.recipes["Player-3"].Tailoring
check(book and #book.list == 2 and book.list[1].name == "Bolt of Linen Cloth" and book.list[2].name == "Linen Bag",
    "opening a profession window records the recipes learned, A to Z")
check(#book.list[2].reagents == 2 and book.list[1].out == 2996, "with the materials each needs, not optional extras")
check(printed[#printed]:find("Recorded 2 Tailoring recipes", 1, true) ~= nil, "and says so the first time: " .. tostring(printed[#printed]))
linked = true
ns.db.recipes["Player-3"] = nil
Fire("TRADE_SKILL_SHOW"); RunTimers()
check(ns.db.recipes["Player-3"] == nil, "someone else's linked profession is not recorded")
linked = false
Fire("TRADE_SKILL_SHOW"); RunTimers()
book = ns.db.recipes["Player-3"].Tailoring

local own, all = ns.Makeable("Player-3", book.list[1])
check(own == 1 and all == 16, "Bolt of Linen: 1 with Aaron's own linen, 16 with Bizz's too")
own, all = ns.Makeable("Player-3", book.list[2])
check(own == 0 and all == 2, "Linen Bag: none alone, 2 with Bizz's thread (the Horde character's cannot be mailed)")
local mine, alts, others = ns.ReagentStock("Player-3", 2320)
check(mine == 0 and alts == 2 and #others == 2 and others[1].record.name == "Hordie" and not others[1].mailable and others[2].mailable,
    "who holds a material: every character, the other faction marked as not mailable")

-- the window
SlashCmdList.ALTGLANCE("prof")
check(AltGlancePlanner:IsShown(), "/alts prof opens the planner")
local function Shown(text)
    for _, f in ipairs(Frames()) do
        local t = rawget(f, "__text")
        if t and t:find(text, 1, true) then return f end
    end
end
check(Shown("Aaron Stone  -  Tailoring (2)") ~= nil, "it starts on the character being played and their profession")
check(Shown("x1") and Shown("x2 *"), "each recipe shows how many can be made, * when it needs materials from alts")
check(Shown("1 from alts") ~= nil or Shown("Ready") ~= nil, "the chosen recipe lists its materials and where they come from")
AltGlancePlanner.filter.__scripts.OnClick(AltGlancePlanner.filter)
check(ns.db.plannerFilter == "now", "the filter steps to recipes that can be made now")
AltGlancePlanner.filter.__scripts.OnClick(AltGlancePlanner.filter)
AltGlancePlanner.filter.__scripts.OnClick(AltGlancePlanner.filter)
check(ns.db.plannerFilter == "all", "and back round to all")
AltGlanceWindow.plannerButton.__scripts.OnClick(AltGlanceWindow.plannerButton)
check(not AltGlancePlanner:IsShown(), "the Professions button in the list toggles the planner")
AltGlanceWindow.plannerButton.__scripts.OnClick(AltGlanceWindow.plannerButton)

-- the plan, and sending its materials from another character
ns.PlanAdd("Player-3", "Tailoring", book.list[2], 2)
local needs, to = ns.PlanNeeds()
check(to == "Player-3" and needs[2589] == 8 and needs[2320] == 2, "a plan of 2 Linen Bags needs 8 linen and 2 thread")
ns.PlanAdd("Player-3", "Tailoring", book.list[2], 1)
check(#ns.db.plan.items == 1 and ns.db.plan.items[1].count == 3, "adding the same recipe again adds to its count")
ns.db.plan.items[1].count = 2
AltGlancePlanner:Hide()

ME = { guid = "Player-5", name = "Bizz", class = "Mage", classFile = "MAGE", level = 20, money = 50000, zone = "Stormwind",
    xp = 1, xpMax = 10, rested = 0, resting = true, professions = {},
    bags = { [0] = { 16, 10 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
    items = { [0] = { { 2589, 20 }, { 2589, 10 }, { 2320, 2 }, { 2770, 5 } } } }
Fire("BAG_UPDATE_DELAYED")
ns.db.mailKinds.cloth, ns.db.mailKinds.ore = false, false
ns.db.mailTo["Player-5"] = nil
Fire("MAIL_SHOW")
check(ns.MailTarget().key == "Player-3" and printed[#printed]:find("planned for Aaron Stone", 1, true) ~= nil,
    "at the mailbox, a character holding planned materials is set to send to the crafter")
check(ns.db.mailKinds.planned and #ns.MaterialsToSend() == 3, "Planned for crafting picks the linen and thread, nothing else")
ns.db.chars["Player-3"].bagItems[2589] = 8
check(#ns.MaterialsToSend() == 1, "materials the crafter already has enough of are not sent")
ns.db.mailTo["Player-5"] = "Player-1"
check(not ns.PlanWants(2320) or ns.MailTarget().key == "Player-3", "planned materials only go to the crafter")
Fire("MAIL_CLOSED")
SlashCmdList.ALTGLANCE("prof")
AltGlancePlanner.clear.__scripts.OnClick(AltGlancePlanner.clear)
check(ns.db.plan == nil and #ns.MaterialsToSend() == 0, "Clear plan empties it")

-- Crafting from the planner.
local crafted, opened = {}, {}
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionName = "Tailoring", professionID = 197 } end
C_TradeSkillUI.GetRecipeInfo = function(id) return { name = RECIPES[id].name, learned = RECIPES[id].learned, numAvailable = 4 } end
C_TradeSkillUI.CraftRecipe = function(id, count) crafted[#crafted + 1] = { id = id, count = count } end
C_TradeSkillUI.OpenTradeSkill = function(line) opened[#opened + 1] = line end
local aaronBook = ns.db.recipes["Player-3"].Tailoring
local crafterEntry = { key = "Player-3", record = ns.db.chars["Player-3"], profession = "Tailoring", list = aaronBook.list }
local count, reason = ns.CraftState(crafterEntry, aaronBook.list[1], 10)
check(count == nil and reason:find("Log in to Aaron Stone", 1, true), "another character's recipe cannot be crafted from here: " .. tostring(reason))
ME.guid = "Player-3"
Fire("TRADE_SKILL_CLOSE")
Fire("TRADE_SKILL_SHOW"); RunTimers()
aaronBook = ns.db.recipes["Player-3"].Tailoring
check(aaronBook.list[1].id == 101 and aaronBook.skillLine == 197, "each recipe's ID and the profession are remembered for crafting")
count = ns.CraftState(crafterEntry, aaronBook.list[1], 10)
check(count == 4, "with the profession window open, it crafts as many as wanted and the bags allow")
ns.TogglePlanner(); ns.TogglePlanner()
check(AltGlancePlanner:IsShown() and AltGlancePlanner.craft.label:GetText() == "Craft 1", "the Craft button shows how many it will make: " .. tostring(AltGlancePlanner.craft.label:GetText()))
AltGlancePlanner.craft.__scripts.OnClick(AltGlancePlanner.craft)
check(#crafted == 1 and crafted[1].id == 101 and crafted[1].count == 1, "pressing Craft crafts the chosen recipe")
Fire("TRADE_SKILL_CLOSE")
count, reason = ns.CraftState(crafterEntry, aaronBook.list[1], 10)
check(count == nil and AltGlancePlanner.craft.label:GetText() == "Open Tailoring", "with the window closed, the button offers to open it")
AltGlancePlanner.craft.__scripts.OnClick(AltGlancePlanner.craft)
check(#crafted == 1 and opened[1] == 197, "and pressing it opens the profession window, crafting nothing")
IN_COMBAT = true
Fire("TRADE_SKILL_SHOW"); RunTimers()
count, reason = ns.CraftState(crafterEntry, aaronBook.list[1], 10)
check(count == nil and reason:find("combat", 1, true), "nothing is crafted in combat")
IN_COMBAT = false
Fire("TRADE_SKILL_CLOSE")

-- Record my professions: AltGlance opens each window not recorded yet.
do
    local me = ns.CurrentKey()
    local openedLines, closed, open = {}, 0, nil
    local LINES = { [129] = "First Aid", [186] = "Mining", [393] = "Skinning" }
    local profs = { { "Mining", 186 }, { "Skinning", 393 }, { "First Aid", 129 } }
    GetProfessions = function() return 1, 2, nil, nil, 3 end
    GetProfessionInfo = function(index) local p = profs[index]; return p[1], "icon", 50, 75, 0, 0, p[2] end
    C_TradeSkillUI.OpenTradeSkill = function(line) openedLines[#openedLines + 1] = line; open = LINES[line]; Fire("TRADE_SKILL_SHOW") end
    C_TradeSkillUI.CloseTradeSkill = function() closed = closed + 1; open = nil; Fire("TRADE_SKILL_CLOSE") end
    C_TradeSkillUI.GetBaseProfessionInfo = function() return open and { professionName = open, professionID = 129 } or nil end
    C_TradeSkillUI.GetAllRecipeIDs = function() if open == "First Aid" then return { 101 } end return {} end
    local missing = ns.UnrecordedProfessions()
    check(#missing == 2 and missing[1].name == "Mining" and missing[2].name == "First Aid",
        "Record offers the professions with recipes not recorded yet (not Skinning)")
    if not AltGlancePlanner:IsShown() then ns.TogglePlanner() end
    ns.RefreshPlanner()
    local record = AltGlancePlanner.record
    check(record:IsShown() and record.label:GetText() == "Record my Mining (1 more)", "the planner shows the Record button: " .. tostring(record.label:GetText()))
    record.__scripts.OnClick(record)
    check(record.label:GetText() == "Recording...", "and says so while it works")
    for _ = 1, 40 do RunTimers() end
    check(#openedLines == 1 and openedLines[1] == 186 and closed == 1, "one press opens one window (the game allows no more without a click), and closes it")
    check(record:IsShown() and record.label:GetText() == "Record my First Aid", "then the button offers the next: " .. tostring(record.label:GetText()))
    record.__scripts.OnClick(record)
    for _ = 1, 40 do RunTimers() end
    check(#openedLines == 2 and openedLines[2] == 129 and closed == 2, "and the next press records that one")
    check(ns.db.recipes[me]["First Aid"] and #ns.db.recipes[me]["First Aid"].list == 1, "First Aid's recipes are recorded")
    check(ns.db.recordTried[me].Mining, "Mining, with nothing to record, is not offered again")
    check(not record:IsShown(), "and the button goes once everything is recorded")
    -- The game not opening the window for an addon.
    ns.db.recipes[me]["First Aid"] = nil
    C_TradeSkillUI.OpenTradeSkill = function() end
    ns.RefreshPlanner()
    record.__scripts.OnClick(record)
    for _ = 1, 40 do RunTimers() end
    check(printed[#printed]:find("did not open your First Aid window", 1, true) ~= nil, "if the game does not open it, it says so: " .. tostring(printed[#printed]))
    check(record:IsShown() and record.label:GetText() == "Record my First Aid", "and the button stays for another try")
end
