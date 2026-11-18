local addonName, ns = ...

-- "Send materials": at the mailbox, a small panel beside it that mails
-- your ore, herbs, leather and cloth to another of your characters, picked
-- from the ones AltGlance knows on the same realm and faction (mail cannot
-- cross factions). Each mail carries up to 12 stacks, the game's limit;
-- after one has gone the next is sent, until everything chosen is on its
-- way. Soulbound items cannot be mailed and are skipped.
--
-- Settings, account-wide: AltGlanceDB.mailKinds = { ore = true, ... } and
-- AltGlanceDB.mailTo[characterKey] = the key of the character they last
-- sent to.

local Usable = ns.Usable
local ACCENT_R, ACCENT_G, ACCENT_B = 0.85, 0.63, 0.40
local PER_MAIL = ATTACHMENTS_MAX_SEND or 12
local SUBJECT = "Materials"

-- Trade Goods (item class 7) subclasses, from the client's own list where
-- it has one.
local TRADE_GOODS = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
local SUB = (Enum and Enum.ItemTradeGoodsSubclass) or {}
local CLASS = (Enum and Enum.ItemClass) or {}
local WEAPON = CLASS.Weapon or 2
local ARMOR = CLASS.Armor or 4
local GEM = CLASS.Gem or 3
local RECIPE = CLASS.Recipe or 9
local JEWELCRAFTING = SUB.Jewelcrafting or 4

-- The original game's gems and pearls, by item ID.
local GEM_IDS = {}
for _, id in ipairs({ 774, 818, 1210, 1206, 1705, 1529, 3864, 7909, 7910, 12799, 12361, 12364, 12800,
        11754, 5498, 5500, 7971, 13926, 12363 }) do
    GEM_IDS[id] = true
end

-- What fishing brings up besides fish named "Raw ...": the original game's
-- catches by name (names, not item IDs, so Forever's own copies match too).
local FISH_NAMES = {}
for _, name in ipairs({ "Oily Blackmouth", "Firefin Snapper", "Stonescale Eel", "Deviate Fish",
        "Darkclaw Lobster", "Winter Squid", "Lightning Eel", "Large Raw Mightfish", "Spinefin Halibut",
        "Feltail", "Bloodfin Catfish", "Small Barnacled Clam", "Thick-shelled Clam", "Big-mouth Clam",
        "Soft-shelled Clam", "Clam Meat", "Tangy Clam Meat", "Zesty Clam Meat", "Golden Pearl",
        "Black Pearl", "Iridescent Pearl", "Small Lustrous Pearl" }) do
    FISH_NAMES[name] = true
end

-- Trade goods subclasses that have a kind of their own.
local OWN_SUBCLASS = {
    [SUB.MetalAndStone or 7] = true, [SUB.Herb or 9] = true, [SUB.Leather or 6] = true, [SUB.Cloth or 5] = true,
}

local function TradeGoods(subclass)
    return function(classID, subclassID) return classID == TRADE_GOODS and subclassID == subclass end
end

-- What can be sent, each turned on or off on the panel. Each kind says
-- whether an item (by class, subclass and quality) is one of it. The first
-- four start on; the rest are off until turned on.
ns.MAIL_KINDS = {
    { key = "ore", label = "Ore & stone", match = TradeGoods(SUB.MetalAndStone or 7) },
    { key = "herb", label = "Herbs", match = TradeGoods(SUB.Herb or 9) },
    { key = "leather", label = "Leather", match = TradeGoods(SUB.Leather or 6) },
    { key = "cloth", label = "Cloth", match = TradeGoods(SUB.Cloth or 5) },
    -- Malachite, Tigerseye, Shadowgem and the like. Forever files these
    -- under trade goods, "Other" (class 7, subclass 11; seen in game
    -- 2026-11-17) along with all sorts, so they are known by ID; the Gem
    -- class and jewelcrafting trade goods count too.
    { key = "gems", label = "Gems", match = function(classID, subclassID, _, itemID)
        return GEM_IDS[itemID] or classID == GEM or (classID == TRADE_GOODS and subclassID == JEWELCRAFTING)
    end },
    -- Recipes, patterns, plans and schematics not yet soulbound.
    { key = "recipes", label = "Recipes & patterns", match = function(classID) return classID == RECIPE end },
    -- Every other trade good (parts, elemental, meat, enchanting materials
    -- and so on): anything of class 7 that no other kind claims, even a kind
    -- that is turned off, so each kind stays its own.
    { key = "other", label = "Other trade goods", match = function(classID, subclassID, _, itemID, name)
        if classID ~= TRADE_GOODS or OWN_SUBCLASS[subclassID] or GEM_IDS[itemID] then return false end
        if subclassID == JEWELCRAFTING then return false end
        return not (type(name) == "string" and (FISH_NAMES[name] or name:sub(1, 4) == "Raw "))
    end },
    -- Anything caught fishing: raw fish ("Raw ..."), and the other catches
    -- and clams by name. Not by category: raw fish share theirs with meat.
    { key = "fish", label = "Fishing catch", match = function(classID, _, _, _, name)
        if type(name) ~= "string" then return false end
        return FISH_NAMES[name] or (name:sub(1, 4) == "Raw " and (classID == TRADE_GOODS or classID == 0))
    end },
    -- Green, blue and purple weapons and armour that are not soulbound yet
    -- (bind on equip): for a bank alt who disenchants.
    { key = "disenchant", label = "Gear to disenchant", match = function(classID, _, quality)
        return (classID == WEAPON or classID == ARMOR) and Usable(quality) and quality >= 2 and quality <= 4
    end },
}

-- Whether this character may mail that one: a known full name (first names
-- are not unique in Forever, so mail only ever goes to a full name), the
-- same realm and the same faction, and not themselves.
local function CanMail(mine, myKey, key, record)
    return key ~= myKey and type(record.fullName) == "string" and record.fullName ~= ""
        and record.fullName ~= mine.fullName
        and record.faction ~= nil and record.faction == mine.faction
        and record.realm ~= nil and record.realm == mine.realm
end
ns.CanMail = CanMail

local function Settings()
    if not ns.db.mailKinds then
        ns.db.mailKinds = { ore = true, herb = true, leather = true, cloth = true }
    end
    ns.db.mailTo = ns.db.mailTo or {}
    ns.db.bankAlt = ns.db.bankAlt or {}
end

---------------------------------------------------------------------------
-- Who to send to, and what
---------------------------------------------------------------------------

-- Whether this character may mail that one: a known full name (first names
-- are not unique in Forever, so mail only ever goes to a full name), the
-- same realm and the same faction, and not themselves.

-- Your other characters this one can mail. A character recorded before
-- 0.6.1 appears once you have logged in to them again (to learn their
-- full name).
function ns.MailRecipients()
    local list = {}
    local me = ns.CurrentKey()
    local mine = me and ns.db.chars[me]
    if not mine then return list end
    for key, record in pairs(ns.db.chars) do
        if CanMail(mine, me, key, record) then
            list[#list + 1] = { key = key, record = record }
        end
    end
    table.sort(list, function(a, b) return a.record.fullName < b.record.fullName end)
    return list
end

---------------------------------------------------------------------------
-- The bank alt: one character per realm and faction whose name is filled
-- in on the Send Mail page by itself (handy with a gamepad, where typing a
-- name is slow). AltGlanceDB.bankAlt["Realm|Faction"] = character key.
---------------------------------------------------------------------------

local function Group(record)
    return (record.realm or "?") .. "|" .. (record.faction or "?")
end

-- This character's bank alt: its key and record, or nil. Never the
-- character being played.
function ns.BankAlt()
    Settings()
    local me = ns.CurrentKey()
    local mine = me and ns.db.chars[me]
    if not mine then return end
    local key = ns.db.bankAlt[Group(mine)]
    local record = key and ns.db.chars[key]
    if not record or not CanMail(mine, me, key, record) then return end
    return key, record
end

-- Whether a character is the bank alt for their realm and faction.
function ns.IsBankAlt(key)
    Settings()
    local record = key and ns.db.chars[key]
    return record ~= nil and ns.db.bankAlt[Group(record)] == key
end

-- Makes a character the bank alt for their realm and faction, or, given
-- the current bank alt, clears it.
function ns.ToggleBankAlt(key)
    Settings()
    local record = key and ns.db.chars[key]
    if not record then return end
    local group = Group(record)
    if ns.db.bankAlt[group] == key then
        ns.db.bankAlt[group] = nil
        ns.Print(ns.DisplayName(record) .. " is no longer your bank alt.")
    else
        ns.db.bankAlt[group] = key
        if ns.CurrentKey() ~= key then ns.db.mailTo[ns.CurrentKey() or ""] = key end
        if record.fullName then
            ns.Print(record.fullName .. " is now your bank alt: their name is filled in when you open Send Mail"
                .. (ns.GamepadMode() and " (not in gamepad mode, where the game does not allow it: use Send on the Send materials panel)." or "."))
        else
            ns.Print(ns.DisplayName(record) .. " is now your bank alt. Log in to them once so AltGlance learns their full name; until then it is not filled in.")
        end
        ns.FillBankAltName()
    end
    if ns.RefreshWindow then ns.RefreshWindow() end
end

-- Puts the bank alt's name in the Send Mail "To" box, if it is empty.
-- Whether the game is in gamepad mode.
function ns.GamepadMode()
    if C_GamePad and C_GamePad.IsEnabled then
        local ok, on = pcall(C_GamePad.IsEnabled)
        if ok and on then return true end
    end
    if GetCVarBool then
        local ok, on = pcall(GetCVarBool, "GamePadEnable")
        if ok and on then return true end
    end
    return false
end

-- Not in gamepad mode: typing into Blizzard's To box from an addon leaves
-- the mail window marked as touched by an addon, and its gamepad steps are
-- then blocked ("Interface action failed because of an AddOn", seen
-- 2026-11-18). There, the panel's Send mails to the bank alt instead.
function ns.FillBankAltName()
    if ns.GamepadMode() then return end
    local _, record = ns.BankAlt()
    local box = SendMailNameEditBox
    if not record or not box or not box.GetText then return end
    local ok, text = pcall(box.GetText, box)
    if ok and (text == nil or text == "") then
        pcall(box.SetText, box, record.fullName)
    end
end

-- The character chosen to send to: the one last used from this character,
-- else the bank alt, else the first on the list.
function ns.MailTarget()
    Settings()
    local list = ns.MailRecipients()
    if #list == 0 then return nil, list end
    local wanted = ns.db.mailTo[ns.CurrentKey() or ""] or ns.BankAlt()
    for index, entry in ipairs(list) do
        if entry.key == wanted then return entry, list, index end
    end
    return list[1], list, 1
end

-- Steps the chosen character forwards (1) or back (-1) through the list.
function ns.StepMailTarget(step)
    local _, list, index = ns.MailTarget()
    if #list == 0 then return end
    index = (((index or 1) - 1 + step) % #list) + 1
    ns.db.mailTo[ns.CurrentKey() or ""] = list[index].key
end

local function CarriedBags()
    local bags = { 0, 1, 2, 3, 4 }
    local index = Enum and Enum.BagIndex
    if index and type(index.ReagentBag) == "number" then bags[#bags + 1] = index.ReagentBag end
    return bags
end

-- The stacks in your bags of the kinds turned on: { bag, slot, itemID, count }.
function ns.MaterialsToSend()
    Settings()
    local wanted = {}
    for _, kind in ipairs(ns.MAIL_KINDS) do
        if ns.db.mailKinds[kind.key] then wanted[#wanted + 1] = kind.match end
    end
    local list = {}
    if not (C_Item and C_Item.GetItemInfoInstant) then return list end
    for _, bag in ipairs(CarriedBags()) do
        local okSlots, slots = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (okSlots and Usable(slots)) and slots or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if Usable(id) and not info.isBound and not info.isLocked then
                local ok, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, id)
                local link = info.hyperlink
                local name = Usable(link) and type(link) == "string" and link:match("%[(.-)%]") or nil
                if ok then
                    for _, match in ipairs(wanted) do
                        if match(classID, subclassID, info.quality, id, name) then
                            list[#list + 1] = { bag = bag, slot = slot, id = id, count = info.stackCount or 1 }
                            break
                        end
                    end
                end
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local sending   -- while a run of mails is going: { to =, mails =, stacks = }

local function AttachedCount()
    if not GetSendMailItem then return 0 end
    local count = 0
    for index = 1, PER_MAIL do
        local ok, name = pcall(GetSendMailItem, index)
        if ok and name then count = count + 1 end
    end
    return count
end

local function Finish(message)
    sending = nil
    if message then ns.Print(message) end
    ns.RefreshMailPanel()
end

-- Sends the next mail: up to 12 stacks to the chosen character. Called by
-- the Send button, and again each time a mail has gone, until nothing is
-- left to send.
-- Right before a mail goes: still one of your characters on the same faction
-- and realm, under a full name.
local function StillMailable(target)
    local me = ns.CurrentKey()
    local mine = me and ns.db.chars[me]
    return mine and CanMail(mine, me, target.key, target.record)
end

local function BoxText(box)
    if not (box and box.GetText) then return "" end
    local ok, text = pcall(box.GetText, box)
    return (ok and Usable(text) and type(text) == "string") and text or ""
end

local function MoneyOn(get)
    if not get then return 0 end
    local ok, amount = pcall(get)
    return (ok and Usable(amount) and tonumber(amount)) or 0
end

function ns.SendNextMail()
    local target = ns.MailTarget()
    if not target then
        return Finish("No other character of yours on this realm and faction to send to yet. A character is offered once you have logged in to them with AltGlance 0.6.1 or later, which learns their full name.")
    end
    -- Items you put on the mail yourself: that mail goes to the bank alt as
    -- it is (with your subject and text, if any), then the materials follow.
    -- Not a mail with money or C.O.D. on it: that is for the mailbox's own
    -- Send, so this button never moves gold.
    local own = AttachedCount()
    if own > 0 then
        if MoneyOn(GetSendMailMoney) > 0 or MoneyOn(GetSendMailCOD) > 0 then
            return Finish("This mail has money or C.O.D. on it: send it with the mailbox's own Send button.")
        end
        local okPrice, price = pcall(GetSendMailPrice)
        if okPrice and Usable(price) and price > GetMoney() then
            return Finish(("Not enough money for the postage (%s)."):format(ns.Money(price)))
        end
        if not StillMailable(target) then
            return Finish("Not sent: " .. ns.DisplayName(target.record) .. " is not a character of yours on this realm and faction.")
        end
        local subject = BoxText(SendMailSubjectEditBox)
        sending = sending or { to = target.record.fullName, mails = 0, stacks = 0 }
        sending.pending = own
        SendMail(target.record.fullName, subject ~= "" and subject or "Items", BoxText(SendMailBodyEditBox))
        return
    end
    local items = ns.MaterialsToSend()
    if #items == 0 then
        if sending then
            return Finish(("Sent %d stack%s in %d mail%s to %s."):format(sending.stacks, sending.stacks == 1 and "" or "s",
                sending.mails, sending.mails == 1 and "" or "s", target.record.fullName))
        end
        return Finish("Nothing to send: no materials of the kinds turned on in your bags.")
    end
    -- Items are attached on the Send Mail page. AltGlance does not switch to
    -- it for you: clicking Blizzard's tab from an addon set off "blocked
    -- from an action only available to the Blizzard UI" in Forever (the
    -- mail still went; 2026-11-17).
    if SendMailFrame and SendMailFrame.IsShown and not SendMailFrame:IsShown() then
        return Finish("Open the Send Mail tab first, then press Send again.")
    end
    local attached = 0
    for _, item in ipairs(items) do
        if attached >= PER_MAIL then break end
        ClearCursor()
        C_Container.PickupContainerItem(item.bag, item.slot)
        ClickSendMailItemButton(attached + 1)
        if CursorHasItem() then
            ClearCursor()
        else
            attached = attached + 1
        end
    end
    if attached == 0 then
        return Finish("The game would not attach the materials to a mail.")
    end
    local okPrice, price = pcall(GetSendMailPrice)
    if okPrice and Usable(price) and price > GetMoney() then
        return Finish(("Not enough money for the postage (%s)."):format(ns.Money(price)))
    end
    if not StillMailable(target) then
        if ClearSendMail then pcall(ClearSendMail) end
        return Finish("Not sent: " .. ns.DisplayName(target.record) .. " is not a character of yours on this realm and faction.")
    end
    sending = sending or { to = target.record.fullName, mails = 0, stacks = 0 }
    sending.pending = attached
    SendMail(target.record.fullName, SUBJECT, "")
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

local panel

-- Layout, top to bottom (pixels). Every button is at least 26 high, to tap.
local WIDTH, PAD = 264, 12
local INNER = WIDTH - PAD * 2

local function Fill(frame, r, g, b, a, layer)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

-- A one-pixel frame round the panel, in the accent colour.
local function Outline(frame, alpha)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
            { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, alpha)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if side[1] == "TOPLEFT" and side[2] == "BOTTOMLEFT" or side[1] == "TOPRIGHT" then
            edge:SetWidth(1)
        else
            edge:SetHeight(1)
        end
    end
end

local function Label(parent, font, justify)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetJustifyH(justify or "LEFT")
    label:SetWordWrap(false)
    return label
end

-- A small heading over each part of the panel.
local function Heading(text, y)
    local heading = Label(panel, "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", PAD, y)
    heading:SetText(text)
    heading:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.85)
    return heading
end

-- A plain button, big enough to tap: a dark box that lights up under the
-- mouse or the gamepad cursor.
local function Button(parent, width, height, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.bg = Fill(button, 0.14, 0.11, 0.08, 1)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.08)
    button.label = Label(button, "GameFontHighlight", "CENTER")
    button.label:SetPoint("LEFT", 8, 0)
    button.label:SetPoint("RIGHT", -8, 0)
    button.label:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function ClassColour(classFile)
    local colour = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if colour then return colour.r, colour.g, colour.b end
    return 1, 1, 1
end

local function Plural(count, word)
    return ("%d %s%s"):format(count, word, count == 1 and "" or "s")
end

function ns.RefreshMailPanel()
    if not panel or not panel:IsShown() then return end
    local target, list = ns.MailTarget()
    if target then
        panel.target:SetText(target.record.fullName)
        panel.target:SetTextColor(ClassColour(target.record.classFile))
    else
        panel.target:SetText("No alt to send to yet")
        panel.target:SetTextColor(0.6, 0.6, 0.6)
    end
    panel.prev:SetShown(#list > 1)
    panel.next:SetShown(#list > 1)

    -- Bank alt: short, as the name is already shown just above.
    panel.bank:SetShown(target ~= nil)
    if target and target.key == ns.BankAlt() then
        panel.bank.label:SetText("Your bank alt")
        panel.bank.label:SetTextColor(0.4, 0.9, 0.4)
        panel.bank.bg:SetColorTexture(0.10, 0.20, 0.10, 1)
    elseif target then
        panel.bank.label:SetText("Make this my bank alt")
        panel.bank.label:SetTextColor(0.9, 0.9, 0.9)
        panel.bank.bg:SetColorTexture(0.14, 0.11, 0.08, 1)
    end

    for _, kind in ipairs(ns.MAIL_KINDS) do
        local toggle = panel.toggles[kind.key]
        local on = ns.db.mailKinds[kind.key] and true or false
        toggle.box:SetColorTexture(on and 0.35 or 0.22, on and 0.8 or 0.22, on and 0.35 or 0.22, 1)
        toggle.label:SetTextColor(on and 1 or 0.55, on and 1 or 0.55, on and 1 or 0.55)
        toggle.state:SetText(on and "On" or "Off")
        toggle.state:SetTextColor(on and 0.4 or 0.5, on and 0.9 or 0.5, on and 0.4 or 0.5)
    end

    local stacks = #ns.MaterialsToSend()
    local own = AttachedCount()
    local mails = math.ceil(stacks / PER_MAIL)
    if sending then
        panel.summary:SetText("Sending...")
    elseif not target then
        panel.summary:SetText("Log in to an alt once, and they appear here.")
    elseif own > 0 and stacks > 0 then
        panel.summary:SetText("Your mail (" .. Plural(own, "item") .. "), then " .. Plural(stacks, "stack"))
    elseif own > 0 then
        panel.summary:SetText("Your mail with " .. Plural(own, "item") .. " on it")
    elseif stacks == 0 then
        panel.summary:SetText("Nothing to send in your bags.")
    else
        panel.summary:SetText(Plural(stacks, "stack") .. " in " .. Plural(mails, "mail"))
    end
    local ready = target ~= nil and (stacks > 0 or own > 0) and not sending
    panel.send:SetEnabled(ready)
    panel.send.label:SetText(sending and "Sending..." or "Send")
    panel.send.label:SetTextColor(ready and 1 or 0.5, ready and 0.95 or 0.5, ready and 0.85 or 0.5)
    panel.send.bg:SetColorTexture(ready and 0.45 or 0.14, ready and 0.30 or 0.11, ready and 0.12 or 0.08, 1)
end

-- Beside the mailbox: placed at its right edge on the screen, but not tied
-- to Blizzard's mail window (anchoring to it, or being part of it, made the
-- game block the mailbox's gamepad steps).
local function PlacePanel()
    panel:ClearAllPoints()
    local right, top = MailFrame and MailFrame.GetRight and MailFrame:GetRight(), MailFrame and MailFrame.GetTop and MailFrame:GetTop()
    if type(right) == "number" and type(top) == "number" then
        local scale = (MailFrame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right * scale + 6, top * scale)
    else
        panel:SetPoint("CENTER")
    end
end

local function CreatePanel()
    -- Its own window beside the mailbox, not a part of it: in gamepad mode
    -- Blizzard's mail navigation walks everything inside the mail window,
    -- and reaching an addon's buttons there got its next step blocked
    -- ("Interface action failed because of an AddOn", 2026-11-18).
    panel = CreateFrame("Frame", addonName .. "MailPanel", UIParent)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    Fill(panel, 0.06, 0.06, 0.07, 0.96)
    Outline(panel, 0.5)
    -- Gone whenever the mailbox is, even if the closing event is missed.
    panel:SetScript("OnUpdate", function(self)
        if MailFrame and MailFrame.IsShown and not MailFrame:IsShown() then self:Hide() end
    end)

    local title = Label(panel, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Send materials")
    title:SetTextColor(1, 0.85, 0.6)

    -- Close (x), big enough to tap.
    local close = Button(panel, 28, 28, "x", function() panel:Hide() end)
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Send to:  [<]  Name Surname  [>]
    local y = -42
    Heading("SEND TO", y)
    y = y - 18
    panel.prev = Button(panel, 30, 30, "<", function() ns.StepMailTarget(-1); ns.RefreshMailPanel() end)
    panel.prev:SetPoint("TOPLEFT", PAD, y)
    panel.next = Button(panel, 30, 30, ">", function() ns.StepMailTarget(1); ns.RefreshMailPanel() end)
    panel.next:SetPoint("TOPRIGHT", -PAD, y)
    panel.target = Label(panel, "GameFontHighlight", "CENTER")
    panel.target:SetPoint("TOPLEFT", PAD + 34, y - 8)
    panel.target:SetPoint("TOPRIGHT", -PAD - 34, y - 8)
    y = y - 36

    -- Bank alt: marks (or unmarks) the character shown above.
    panel.bank = Button(panel, INNER, 26, "", function()
        local target = ns.MailTarget()
        if target then ns.ToggleBankAlt(target.key) end
        ns.RefreshMailPanel()
    end)
    panel.bank.label:SetFontObject("GameFontHighlightSmall")
    panel.bank:SetPoint("TOPLEFT", PAD, y)
    y = y - 40

    -- What to send: one on/off row per kind, a coloured box showing which.
    Heading("WHAT TO SEND", y)
    y = y - 18
    panel.toggles = {}
    for _, kind in ipairs(ns.MAIL_KINDS) do
        local toggle = Button(panel, INNER, 28, "", function()
            ns.db.mailKinds[kind.key] = not ns.db.mailKinds[kind.key]
            ns.RefreshMailPanel()
        end)
        toggle:SetPoint("TOPLEFT", PAD, y)
        toggle.box = toggle:CreateTexture(nil, "ARTWORK")
        toggle.box:SetSize(12, 12)
        toggle.box:SetPoint("LEFT", 10, 0)
        toggle.label:ClearAllPoints()
        toggle.label:SetPoint("LEFT", 30, 0)
        toggle.label:SetPoint("RIGHT", -44, 0)
        toggle.label:SetJustifyH("LEFT")
        toggle.label:SetText(kind.label)
        toggle.state = Label(toggle, "GameFontHighlightSmall", "RIGHT")
        toggle.state:SetPoint("RIGHT", -10, 0)
        panel.toggles[kind.key] = toggle
        y = y - 32
    end

    -- What will go, then Send.
    y = y - 6
    panel.summary = Label(panel, "GameFontHighlightSmall", "CENTER")
    panel.summary:SetPoint("TOPLEFT", PAD, y)
    panel.summary:SetPoint("TOPRIGHT", -PAD, y)
    y = y - 22
    panel.send = Button(panel, INNER, 34, "Send", function()
        if not sending then ns.SendNextMail() end
        ns.RefreshMailPanel()
    end)
    panel.send.label:SetFontObject("GameFontNormalLarge")
    panel.send:SetPoint("TOPLEFT", PAD, y)
    y = y - 34 - PAD

    panel:SetSize(WIDTH, -y)
    ns.mailPanel = panel
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then
        for _, name in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "BAG_UPDATE_DELAYED",
                "MAIL_SEND_INFO_UPDATE" }) do
            pcall(self.RegisterEvent, self, name)
        end
        return
    end
    if event == "MAIL_SHOW" then
        Settings()
        if not panel then CreatePanel() end
        panel:Show()
        PlacePanel()
        -- No hook on Blizzard's Send Mail page: an addon's code running
        -- inside Blizzard's mail code marks it as touched, and in gamepad
        -- mode its next steps were blocked (2026-11-18). The name is filled
        -- in here, from the game's event, and after each mail.
        pcall(ns.FillBankAltName)
    elseif event == "MAIL_CLOSED" then
        if sending then Finish("The mailbox was closed, so sending stopped.") end
        if panel then panel:Hide() end
        return
    elseif event == "MAIL_SEND_SUCCESS" and not sending then
        -- The game empties the "To" box after a mail: the bank alt again.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.2, function() pcall(ns.FillBankAltName) end)
        else
            pcall(ns.FillBankAltName)
        end
    elseif event == "MAIL_SEND_SUCCESS" and sending then
        sending.mails = sending.mails + 1
        sending.stacks = sending.stacks + (sending.pending or 0)
        sending.pending = nil
        -- The next one, once the bags have caught up.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function() if sending then ns.SendNextMail() end end)
        else
            ns.SendNextMail()
        end
    elseif event == "MAIL_FAILED" and sending then
        ns.Print("A mail did not go, so sending stopped.")
        if ClearSendMail then pcall(ClearSendMail) end
        Finish()
        return
    end
    pcall(ns.RefreshMailPanel)
end)
