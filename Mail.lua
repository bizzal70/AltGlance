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
ns.MAIL_KINDS = {
    { key = "ore", label = "Ore & stone", subclass = SUB.MetalAndStone or 7 },
    { key = "herb", label = "Herbs", subclass = SUB.Herb or 9 },
    { key = "leather", label = "Leather", subclass = SUB.Leather or 6 },
    { key = "cloth", label = "Cloth", subclass = SUB.Cloth or 5 },
    -- Green, blue and purple weapons and armour that are not soulbound yet
    -- (bind on equip): for a bank alt who disenchants. Off until turned on.
    { key = "disenchant", label = "Gear to disenchant", gear = true },
}
local WEAPON = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
local ARMOR = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4

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

-- Your other characters this one can mail: same realm, same faction.
function ns.MailRecipients()
    local list = {}
    local me = ns.CurrentKey()
    local mine = me and ns.db.chars[me]
    if not mine then return list end
    for key, record in pairs(ns.db.chars) do
        if key ~= me and record.name and record.faction == mine.faction and record.realm == mine.realm then
            list[#list + 1] = { key = key, record = record }
        end
    end
    table.sort(list, function(a, b) return a.record.name < b.record.name end)
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
    if not record or key == me or Group(record) ~= Group(mine) then return end
    return key, record
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
        ns.Print(record.name .. " is no longer your bank alt.")
    else
        ns.db.bankAlt[group] = key
        ns.db.mailTo[ns.CurrentKey() or ""] = key
        ns.Print(record.name .. " is now your bank alt: their name is filled in when you open Send Mail.")
        ns.FillBankAltName()
    end
end

-- Puts the bank alt's name in the Send Mail "To" box, if it is empty.
function ns.FillBankAltName()
    local _, record = ns.BankAlt()
    local box = SendMailNameEditBox
    if not record or not box or not box.GetText then return end
    local ok, text = pcall(box.GetText, box)
    if ok and (text == nil or text == "") then
        pcall(box.SetText, box, record.name)
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
    local wanted, gear = {}, false
    for _, kind in ipairs(ns.MAIL_KINDS) do
        if ns.db.mailKinds[kind.key] then
            if kind.gear then gear = true else wanted[kind.subclass] = true end
        end
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
                local quality = info.quality
                local isGear = gear and (classID == WEAPON or classID == ARMOR)
                    and Usable(quality) and quality >= 2 and quality <= 4
                if ok and ((classID == TRADE_GOODS and wanted[subclassID]) or isGear) then
                    list[#list + 1] = { bag = bag, slot = slot, id = id, count = info.stackCount or 1 }
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
function ns.SendNextMail()
    local target = ns.MailTarget()
    if not target then
        return Finish("No other character of yours on this realm and faction to send to yet. A character is known once you have logged in to them with AltGlance on.")
    end
    local items = ns.MaterialsToSend()
    if #items == 0 then
        if sending then
            return Finish(("Sent %d stack%s in %d mail%s to %s."):format(sending.stacks, sending.stacks == 1 and "" or "s",
                sending.mails, sending.mails == 1 and "" or "s", target.record.name))
        end
        return Finish("Nothing to send: no materials of the kinds turned on in your bags.")
    end
    if AttachedCount() > 0 then
        return Finish("The mail being written already has items on it. Send it or take them off, then press Send again.")
    end
    -- Items are attached on the Send Mail page.
    if MailFrameTab2 and MailFrameTab2.Click then pcall(MailFrameTab2.Click, MailFrameTab2) end
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
    sending = sending or { to = target.record.name, mails = 0, stacks = 0 }
    sending.pending = attached
    SendMail(target.record.name, SUBJECT, "")
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

local panel

local function Fill(frame, r, g, b, a, layer)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function Label(parent, font, justify)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetJustifyH(justify or "LEFT")
    return label
end

-- A plain button, big enough to tap: a dark box that lights up under the
-- mouse or the gamepad cursor.
local function Button(parent, width, height, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.bg = Fill(button, 0.16, 0.12, 0.08, 1)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.1)
    button.label = Label(button, "GameFontHighlight", "CENTER")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function ClassColour(classFile)
    local colour = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if colour then return colour.r, colour.g, colour.b end
    return 1, 1, 1
end

function ns.RefreshMailPanel()
    if not panel or not panel:IsShown() then return end
    local target, list = ns.MailTarget()
    if target then
        panel.target:SetText(target.record.name)
        panel.target:SetTextColor(ClassColour(target.record.classFile))
    else
        panel.target:SetText("No one to send to")
        panel.target:SetTextColor(0.6, 0.6, 0.6)
    end
    panel.prev:SetShown(#list > 1)
    panel.next:SetShown(#list > 1)
    local bankKey = ns.BankAlt()
    panel.bank:SetShown(target ~= nil)
    if target and target.key == bankKey then
        panel.bank.label:SetText(target.record.name .. " is your bank alt")
        panel.bank.label:SetTextColor(0.3, 0.9, 0.3)
    elseif target then
        panel.bank.label:SetText("Make " .. target.record.name .. " my bank alt")
        panel.bank.label:SetTextColor(1, 1, 1)
    end
    for _, kind in ipairs(ns.MAIL_KINDS) do
        local toggle = panel.toggles[kind.key]
        local on = ns.db.mailKinds[kind.key]
        toggle.state:SetText(on and "on" or "off")
        toggle.state:SetTextColor(on and 0.3 or 0.6, on and 0.9 or 0.6, on and 0.3 or 0.6)
    end
    local items = ns.MaterialsToSend()
    local stacks = #items
    local mails = math.ceil(stacks / PER_MAIL)
    if sending then
        panel.summary:SetText("Sending...")
    elseif stacks == 0 then
        panel.summary:SetText("Nothing to send.")
    else
        panel.summary:SetText(("%d stack%s: %d mail%s"):format(stacks, stacks == 1 and "" or "s", mails, mails == 1 and "" or "s"))
    end
    panel.send:SetEnabled(target ~= nil and stacks > 0 and not sending)
    panel.send.label:SetText(target and ("Send to " .. target.record.name) or "Send")
end

local function CreatePanel()
    panel = CreateFrame("Frame", addonName .. "MailPanel", MailFrame or UIParent)
    panel:SetSize(220, 310)
    if MailFrame then
        panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
    else
        panel:SetPoint("CENTER")
    end
    panel:EnableMouse(true)
    Fill(panel, 0.05, 0.05, 0.06, 0.95)

    local title = Label(panel, "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Send materials")
    title:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B)

    -- Who to: < name >
    local to = Label(panel, "GameFontDisableSmall")
    to:SetPoint("TOPLEFT", 10, -34)
    to:SetText("To")
    panel.prev = Button(panel, 28, 28, "<", function() ns.StepMailTarget(-1); ns.RefreshMailPanel() end)
    panel.prev:SetPoint("TOPLEFT", 10, -48)
    panel.next = Button(panel, 28, 28, ">", function() ns.StepMailTarget(1); ns.RefreshMailPanel() end)
    panel.next:SetPoint("TOPRIGHT", -10, -48)
    panel.target = Label(panel, "GameFontHighlight", "CENTER")
    panel.target:SetPoint("TOPLEFT", 42, -55)
    panel.target:SetPoint("TOPRIGHT", -42, -55)

    -- Bank alt: marks (or unmarks) the character shown above.
    panel.bank = Button(panel, 200, 24, "", function()
        local target = ns.MailTarget()
        if target then ns.ToggleBankAlt(target.key) end
        ns.RefreshMailPanel()
    end)
    panel.bank:SetPoint("TOPLEFT", 10, -82)

    -- What: one on/off button per kind.
    panel.toggles = {}
    for index, kind in ipairs(ns.MAIL_KINDS) do
        local toggle = Button(panel, 200, 26, "", function()
            ns.db.mailKinds[kind.key] = not ns.db.mailKinds[kind.key]
            ns.RefreshMailPanel()
        end)
        toggle:SetPoint("TOPLEFT", 10, -114 - (index - 1) * 30)
        toggle.label:ClearAllPoints()
        toggle.label:SetPoint("LEFT", 8, 0)
        toggle.label:SetText(kind.label)
        toggle.state = Label(toggle, "GameFontHighlight", "RIGHT")
        toggle.state:SetPoint("RIGHT", -8, 0)
        panel.toggles[kind.key] = toggle
    end

    panel.summary = Label(panel, "GameFontHighlightSmall", "CENTER")
    panel.summary:SetPoint("BOTTOMLEFT", 10, 46)
    panel.summary:SetPoint("BOTTOMRIGHT", -10, 46)

    panel.send = Button(panel, 200, 30, "Send", function()
        if not sending then ns.SendNextMail() end
        ns.RefreshMailPanel()
    end)
    panel.send:SetPoint("BOTTOMLEFT", 10, 10)
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
        for _, name in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "BAG_UPDATE_DELAYED" }) do
            pcall(self.RegisterEvent, self, name)
        end
        return
    end
    if event == "MAIL_SHOW" then
        Settings()
        if not panel then CreatePanel() end
        panel:Show()
        -- The bank alt's name, whenever the Send Mail page opens.
        if SendMailFrame and SendMailFrame.HookScript and not ns.sendMailHooked then
            ns.sendMailHooked = true
            SendMailFrame:HookScript("OnShow", function() pcall(ns.FillBankAltName) end)
        end
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
