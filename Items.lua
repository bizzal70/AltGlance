local addonName, ns = ...

-- "On my alts": what each character carries in their bags and keeps in
-- their bank, shown in item tooltips and searchable with /alts find.
--
-- Bags are read whenever they change. The bank can only be read while it
-- is open, so a character's bank is known from the last time they opened
-- it. Counts are saved in each character's record:
--   record.bagItems  = { [itemID] = count }
--   record.bankItems = { [itemID] = count }, record.bankSeen = time()
-- and, account-wide, the item's link (for its name and a clickable link):
--   AltGlanceDB.itemLinks = { [itemID] = link }

local Usable = ns.Usable

-- The backpack and the four bag slots, plus a reagent bag if the client
-- has one.
local function CarriedBags()
    local bags = { 0, 1, 2, 3, 4 }
    local index = Enum and Enum.BagIndex
    if index and type(index.ReagentBag) == "number" then
        bags[#bags + 1] = index.ReagentBag
    end
    return bags
end

-- The bank's containers. Taken from the client's own list where it has
-- one (Retail has changed them more than once: bank bags, then bank tabs),
-- otherwise the original game's numbers.
local function BankBags()
    local ids, seen = {}, {}
    local function Add(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    local index = Enum and Enum.BagIndex
    if type(index) == "table" then
        for name, id in pairs(index) do
            if type(name) == "string" and (name == "Bank" or name:lower() == "reagentbank"
                or name:match("^BankBag") or name:match("^CharacterBankTab")) then
                Add(id)
            end
        end
    end
    if #ids == 0 then
        Add(BANK_CONTAINER or -1)
        for bag = 5, 11 do Add(bag) end
    end
    table.sort(ids)
    return ids
end
ns.BankBags = BankBags

-- Counts every item in the given containers. Returns nil when the game
-- withholds something or shows no space at all (bags not loaded yet, or
-- already cleared while logging out), so a half-read never replaces what
-- was known.
local function Count(bags)
    local counts, slotsSeen = {}, 0
    for _, bag in ipairs(bags) do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if ok and Usable(slots) and slots > 0 then
            slotsSeen = slotsSeen + slots
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info then
                    local id, stack = info.itemID, info.stackCount
                    if not Usable(id) or not Usable(stack) then return end
                    counts[id] = (counts[id] or 0) + stack
                    local link = info.hyperlink
                    if Usable(link) and type(link) == "string" then
                        ns.db.itemLinks[id] = link
                    end
                end
            end
        elseif ok and slots ~= nil and not Usable(slots) then
            return
        end
    end
    if slotsSeen == 0 then return end
    return counts
end

local bankOpen = false

-- Item links are remembered for every item seen in the bags, so names can
-- be shown for characters not being played. Kept only for items a
-- character still holds, or that a recorded recipe makes or uses; the rest
-- are dropped once per session, so the saved data does not keep growing.
function ns.TrimItemLinks()
    local keep = {}
    for _, record in pairs(ns.db.chars) do
        for id in pairs(record.bagItems or {}) do keep[id] = true end
        for id in pairs(record.bankItems or {}) do keep[id] = true end
    end
    for _, book in pairs(ns.db.recipes or {}) do
        for _, profession in pairs(book) do
            for _, recipe in ipairs(profession.list or {}) do
                if recipe.out then keep[recipe.out] = true end
                for _, reagent in ipairs(recipe.reagents or {}) do keep[reagent.id] = true end
            end
        end
    end
    local dropped = 0
    for id in pairs(ns.db.itemLinks) do
        if not keep[id] then
            ns.db.itemLinks[id] = nil
            dropped = dropped + 1
        end
    end
    return dropped
end

-- Reads the bags of the character being played, and the bank too while it
-- is open.
function ns.ReadItems()
    local key = ns.CurrentKey()
    local record = key and ns.db.chars[key]
    if not record then return end
    local bags = Count(CarriedBags())
    if bags then record.bagItems = bags end
    if bankOpen then
        local bank = Count(BankBags())
        if bank then
            record.bankItems = bank
            record.bankSeen = time()
        end
    end
end

---------------------------------------------------------------------------
-- Who holds what
---------------------------------------------------------------------------

-- Every character holding the item, most first: { record, bags, bank, total }.
function ns.ItemHolders(itemID)
    local holders = {}
    for _, record in pairs(ns.db.chars) do
        local bags = record.bagItems and record.bagItems[itemID] or 0
        local bank = record.bankItems and record.bankItems[itemID] or 0
        if bags + bank > 0 then
            holders[#holders + 1] = { record = record, bags = bags, bank = bank, total = bags + bank }
        end
    end
    table.sort(holders, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return ns.DisplayName(a.record) < ns.DisplayName(b.record)
    end)
    return holders
end

-- "12 (bags 8, bank 4)", "4 (bank)", "8"
-- How old a character's bank count is, once it is more than a day old: the
-- bank is only read while it is open, so it is as of their last visit.
local function BankAge(holder)
    local seen = holder.record and holder.record.bankSeen
    if ns.db.bankAge == false or type(seen) ~= "number" or time() - seen < 86400 then return "" end
    return ", " .. ns.Ago(seen)
end

function ns.HolderText(holder)
    if holder.bank > 0 and holder.bags > 0 then
        return ("%d (bags %d, bank %d%s)"):format(holder.total, holder.bags, holder.bank, BankAge(holder))
    elseif holder.bank > 0 then
        return ("%d (bank%s)"):format(holder.total, BankAge(holder))
    end
    return tostring(holder.total)
end

local function ClassColour(classFile)
    local colour = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if colour then return colour.r, colour.g, colour.b end
    return 1, 1, 1
end

local function NameWithCrest(record)
    local faction = ns.FACTIONS and ns.FACTIONS[record.faction or ""]
    local name = ns.DisplayName(record)
    if faction then
        return ("|T%s:0|t %s"):format(faction.icon, name)
    end
    return name
end

-- The lines added under an item's tooltip.
function ns.AddItemLines(tooltip, itemID)
    if not ns.db or not ns.db.itemTooltip then return end
    if not Usable(itemID) or type(itemID) ~= "number" then return end
    local holders = ns.ItemHolders(itemID)
    if #holders == 0 then return end
    tooltip:AddLine("On your characters:", 0.85, 0.63, 0.40)
    local total = 0
    for _, holder in ipairs(holders) do
        local r, g, b = ClassColour(holder.record.classFile)
        tooltip:AddDoubleLine(NameWithCrest(holder.record), ns.HolderText(holder), r, g, b, 1, 1, 1)
        total = total + holder.total
    end
    if #holders > 1 then
        tooltip:AddDoubleLine("Total", tostring(total), 0.85, 0.63, 0.40, 1, 1, 1)
    end
    tooltip:Show()
end

-- Only the main tooltip and the one a clicked link opens; not the
-- comparison tooltips beside them.
local function Wanted(tooltip)
    return tooltip == GameTooltip or (ItemRefTooltip and tooltip == ItemRefTooltip)
end

local function HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if Wanted(tooltip) and data then
                pcall(ns.AddItemLines, tooltip, data.id)
            end
        end)
        return
    end
    -- Older tooltip style, in case this client has it.
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tooltip and tooltip.HookScript then
            pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(self)
                local _, link = self:GetItem()
                local id = Usable(link) and type(link) == "string" and tonumber(link:match("item:(%d+)"))
                if id then pcall(ns.AddItemLines, self, id) end
            end)
        end
    end
end

---------------------------------------------------------------------------
-- /alts find
---------------------------------------------------------------------------

local MAX_FOUND = 8

local function ItemName(link)
    return link and link:match("%[(.-)%]")
end

-- Items whose name contains the text, ignoring case, with who holds them.
function ns.FindItems(text)
    text = text:lower()
    local found = {}
    for id, link in pairs(ns.db.itemLinks) do
        local name = ItemName(link)
        if name and name:lower():find(text, 1, true) then
            local holders = ns.ItemHolders(id)
            if #holders > 0 then
                found[#found + 1] = { id = id, name = name, link = link, holders = holders }
            end
        end
    end
    table.sort(found, function(a, b) return a.name < b.name end)
    return found
end

function ns.PrintFind(text)
    if text == "" then
        ns.Print("Type part of an item's name, for example: /alts find linen")
        return
    end
    local found = ns.FindItems(text)
    if #found == 0 then
        ns.Print(("None of your characters has anything called \"%s\". A character's bank is known once they have opened it with AltGlance on."):format(text))
        return
    end
    for index, item in ipairs(found) do
        if index > MAX_FOUND then
            ns.Print(("...and %d more. Type more of the name to narrow it down."):format(#found - MAX_FOUND))
            break
        end
        local parts = {}
        for _, holder in ipairs(item.holders) do
            parts[#parts + 1] = ns.DisplayName(holder.record) .. " " .. ns.HolderText(holder)
        end
        ns.Print(item.link .. ": " .. table.concat(parts, ", "))
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
-- Newer clients say "the banker's window opened" this way instead.
local function IsBanker(kind)
    local types = Enum and Enum.PlayerInteractionType
    return types and types.Banker ~= nil and kind == types.Banker
end

frame:SetScript("OnEvent", function(self, event, kind)
    if not ns.db then return end
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if not IsBanker(kind) then return end
        event = event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and "BANKFRAME_OPENED" or "BANKFRAME_CLOSED"
    end
    if event == "PLAYER_LOGIN" then
        -- Registering an event this client does not have throws.
        for _, name in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
            "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED",
            "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do
            pcall(self.RegisterEvent, self, name)
        end
        pcall(HookTooltips)
        -- Once the bags have been read, tidy the remembered links.
        if C_Timer and C_Timer.After then
            C_Timer.After(20, function() pcall(ns.TrimItemLinks) end)
        end
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then
        -- Read once more before it closes for good.
        pcall(ns.ReadItems)
        bankOpen = false
        return
    end
    -- Reading the bags must never put an error on screen.
    pcall(ns.ReadItems)
end)
