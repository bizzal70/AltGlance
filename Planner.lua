local addonName, ns = ...

-- The profession planner. Each character's recipes are recorded while their
-- profession window is open. For a chosen recipe the planner shows what it
-- takes, how much of it the crafter holds, which of your other characters
-- hold the rest, and how many can be made. "Add to plan" keeps a list of
-- what to craft; at the mailbox, the Send materials panel's "Planned
-- crafting materials" then sends those materials to the crafter.
--
-- Saved:
--   AltGlanceDB.recipes[characterKey][professionName] =
--     { seen = time(), list = { { name =, out = itemID, reagents = { { id =, n =, name = } } } } }
--   AltGlanceDB.plan = { to = characterKey, items = { { name =, profession =, count = } } }

local Usable = ns.Usable

local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local result = { pcall(fn, ...) }
    if not result[1] then return end
    return unpack(result, 2)
end

local function Text(value)
    return Usable(value) and type(value) == "string" and value ~= "" and value or nil
end

local function Number(value)
    return Usable(value) and type(value) == "number" and value or nil
end

local function Settings()
    ns.db.recipes = ns.db.recipes or {}
    ns.db.plannerFilter = ns.db.plannerFilter or "all"
end

-- An item's name, from what AltGlance has seen or the game knows; nil if
-- neither knows it yet.
function ns.ItemName(id)
    local link = ns.db.itemLinks[id]
    local name = link and link:match("%[(.-)%]")
    if name then return name end
    if C_Item and C_Item.GetItemNameByID then
        name = Text(Call(C_Item.GetItemNameByID, id))
        if name then return name end
    end
    if C_Item and C_Item.GetItemInfo then
        name = Text(Call(C_Item.GetItemInfo, id))
        if name then return name end
    end
end

local function ReagentName(reagent)
    return ns.ItemName(reagent.id) or reagent.name or ("item " .. reagent.id)
end

---------------------------------------------------------------------------
-- Recording recipes while a profession window is open
---------------------------------------------------------------------------

-- The current game's way: recipe IDs and their schematics.
local function ReadModern(api)
    local base = Call(api.GetBaseProfessionInfo)
    local profession = type(base) == "table" and Text(base.professionName) or nil
    if not profession then
        local child = Call(api.GetChildProfessionInfo)
        profession = type(child) == "table" and (Text(child.parentProfessionName) or Text(child.professionName)) or nil
    end
    local ids = Call(api.GetAllRecipeIDs)
    if not profession or type(ids) ~= "table" then return end
    local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
    local list = {}
    for _, recipeID in ipairs(ids) do
        local info = Call(api.GetRecipeInfo, recipeID)
        if type(info) == "table" and info.learned and not info.isDummyRecipe and not info.isRecraft
                and not info.isSalvageRecipe then
            local schematic = Call(api.GetRecipeSchematic, recipeID, false)
            local recipe = { id = recipeID, name = Text(info.name) or (type(schematic) == "table" and Text(schematic.name)) or nil, reagents = {} }
            if type(schematic) == "table" then
                recipe.out = Number(schematic.outputItemID)
                for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
                    local first = type(slot.reagents) == "table" and slot.reagents[1]
                    local itemID = first and Number(first.itemID)
                    local count = Number(slot.quantityRequired)
                    local needed = slot.required ~= false and (basic == nil or slot.reagentType == nil or slot.reagentType == basic)
                    if itemID and count and count > 0 and needed then
                        recipe.reagents[#recipe.reagents + 1] = { id = itemID, n = count, name = ns.ItemName(itemID) }
                    end
                end
            end
            if recipe.name and #recipe.reagents > 0 then list[#list + 1] = recipe end
        end
    end
    return profession, list, type(base) == "table" and Number(base.professionID) or nil
end

-- The original game's way, in case this client has it instead.
local function ReadClassic()
    if not GetNumTradeSkills then return end
    local profession = Text(Call(GetTradeSkillLine))
    local count = Number(Call(GetNumTradeSkills))
    if not profession or not count then return end
    local list = {}
    for index = 1, count do
        local name, kind = Call(GetTradeSkillInfo, index)
        if Text(name) and kind ~= "header" and kind ~= "subheader" then
            local recipe = { name = name, index = index, reagents = {} }
            local link = Text(Call(GetTradeSkillItemLink, index))
            recipe.out = link and tonumber(link:match("item:(%d+)")) or nil
            for reagentIndex = 1, (Number(Call(GetTradeSkillNumReagents, index)) or 0) do
                local reagentName, _, needed = Call(GetTradeSkillReagentInfo, index, reagentIndex)
                local reagentLink = Text(Call(GetTradeSkillReagentItemLink, index, reagentIndex))
                local id = reagentLink and tonumber(reagentLink:match("item:(%d+)"))
                if id and Number(needed) then
                    ns.db.itemLinks[id] = ns.db.itemLinks[id] or reagentLink
                    recipe.reagents[#recipe.reagents + 1] = { id = id, n = needed, name = Text(reagentName) }
                end
            end
            if #recipe.reagents > 0 then list[#list + 1] = recipe end
        end
    end
    return profession, list
end

-- Reads the open profession window into the character's record. Returns
-- the profession and how many recipes, or nil.
function ns.ReadRecipes()
    Settings()
    local api = C_TradeSkillUI
    -- Not someone else's profession (a linked one, a guild's or an NPC's).
    if api and (Call(api.IsTradeSkillLinked) or Call(api.IsTradeSkillGuild) or Call(api.IsNPCCrafting)) then return end
    local profession, list, skillLine
    if api and api.GetAllRecipeIDs then profession, list, skillLine = ReadModern(api) end
    if not profession then profession, list = ReadClassic() end
    local key = ns.CurrentKey()
    if not key or not profession or not list or #list == 0 then return end
    table.sort(list, function(a, b) return a.name < b.name end)
    ns.db.recipes[key] = ns.db.recipes[key] or {}
    local known = ns.db.recipes[key][profession]
    ns.db.recipes[key][profession] = { seen = time(), list = list, skillLine = skillLine }
    ns.openProfession = profession
    if not known then
        ns.Print(("Recorded %d %s recipes. See what you can make, and who holds the materials: /alts prof"):format(#list, profession))
    end
    ns.RefreshPlanner()
    return profession, #list
end

---------------------------------------------------------------------------
-- Record my professions: the game gives recipes only while a profession
-- window is open, so AltGlance opens one not recorded yet, reads it, and
-- closes it again. One per press: the game lets an addon open a profession
-- window only straight after a click ("Interface action failed because of
-- an AddOn" for the second one, opened from a timer, seen 2026-11-22).
---------------------------------------------------------------------------

-- Skill lines with no recipes: Herbalism, Skinning, Fishing, Archaeology.
local NO_RECIPES = { [182] = true, [393] = true, [356] = true, [794] = true }
-- Half-second looks at a window before giving up on it.
local RECORD_TRIES = 10

-- The playing character's professions with recipes that are not recorded
-- yet: { { name =, skillLine = } }. A profession opened once and found to
-- have nothing to record is left out.
function ns.UnrecordedProfessions()
    Settings()
    local list = {}
    local api = C_TradeSkillUI
    local key = ns.CurrentKey()
    if not key or not (api and api.OpenTradeSkill) or not GetProfessions or not GetProfessionInfo then return list end
    local book = ns.db.recipes[key] or {}
    local tried = ns.db.recordTried and ns.db.recordTried[key] or {}
    local indices = { Call(GetProfessions) }
    for slot = 1, 5 do
        local index = Number(indices[slot])
        if index then
            local name, _, _, _, _, _, skillLine = Call(GetProfessionInfo, index)
            name, skillLine = Text(name), Number(skillLine)
            if name and skillLine and not NO_RECIPES[skillLine] and not book[name] and not tried[name] then
                list[#list + 1] = { name = name, skillLine = skillLine }
            end
        end
    end
    return list
end

local recording   -- while recording: { queue =, current =, tries =, shown = }

local function FinishRecording(message)
    recording = nil
    if message then ns.Print(message) end
    ns.plannerShowMe = true
    if ns.RefreshPlanner then pcall(ns.RefreshPlanner) end
end

local RecordNext

-- Looks at the window just opened until its recipes can be read.
local function Look()
    local job = recording
    if not job then return end
    job.tries = job.tries + 1
    local profession, count
    if job.shown then
        local ok, read, number = pcall(ns.ReadRecipes)
        if ok then profession, count = read, number end
    end
    if not profession and job.tries < RECORD_TRIES then
        C_Timer.After(0.5, Look)
        return
    end
    if not profession then
        if not job.shown then
            return FinishRecording(("The game did not open your %s window for AltGlance. Open it once yourself, and it is recorded."):format(job.current.name))
        end
        if job.current.update then
            Call(C_TradeSkillUI.CloseTradeSkill)
            return FinishRecording(("Could not read your %s recipes. Open the window yourself once to update them."):format(job.current.name))
        end
        local key = ns.CurrentKey() or "?"
        ns.db.recordTried = ns.db.recordTried or {}
        ns.db.recordTried[key] = ns.db.recordTried[key] or {}
        ns.db.recordTried[key][job.current.name] = true
        ns.Print(("%s has no recipes to record."):format(job.current.name))
    elseif job.current.update then
        ns.Print(("Updated your %s recipes: %d."):format(profession, count or 0))
    end
    Call(C_TradeSkillUI.CloseTradeSkill)
    FinishRecording()
end

-- Opens the next profession window waiting to be recorded.
function RecordNext()
    local job = recording
    if not job then return end
    local item = table.remove(job.queue, 1)
    if not item then return FinishRecording() end
    if InCombatLockdown and InCombatLockdown() then
        return FinishRecording("Recording stopped: not while in combat. Press Record again afterwards.")
    end
    job.current, job.tries, job.shown = item, 0, false
    if not pcall(C_TradeSkillUI.OpenTradeSkill, item.skillLine) then
        return FinishRecording(("The game would not open your %s window. Open it once yourself, and it is recorded."):format(item.name))
    end
    C_Timer.After(0.5, Look)
end

-- The Record button: records the next profession not recorded yet.
function ns.RecordProfessions()
    if recording then return end
    local queue = ns.UnrecordedProfessions()
    if #queue == 0 then
        ns.Print("All your professions with recipes are recorded.")
        return
    end
    recording = { queue = { queue[1] } }
    RecordNext()
    if ns.RefreshPlanner then pcall(ns.RefreshPlanner) end
end

function ns.IsRecording()
    return recording ~= nil
end

-- The skill line that opens one of the playing character's professions.
local function SkillLine(name)
    if GetProfessions and GetProfessionInfo then
        local indices = { Call(GetProfessions) }
        for slot = 1, 5 do
            local index = Number(indices[slot])
            if index then
                local found, _, _, _, _, _, skillLine = Call(GetProfessionInfo, index)
                if Text(found) == name and Number(skillLine) then return skillLine end
            end
        end
    end
    local book = ns.db.recipes[ns.CurrentKey() or ""]
    return book and book[name] and book[name].skillLine
end

-- The Update button: reads one of the playing character's professions
-- again, so recipes learned since show up.
function ns.UpdateProfession(name)
    if recording or not name then return end
    if ns.openProfession == name then
        -- Already open: just read it.
        local ok, profession, count = pcall(ns.ReadRecipes)
        ns.Print(ok and profession and ("Updated your %s recipes: %d."):format(profession, count or 0)
            or ("Could not read your %s recipes."):format(name))
        return
    end
    local skillLine = SkillLine(name)
    if not skillLine or not (C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill) then
        ns.Print(("Open your %s window yourself to update its recipes."):format(name))
        return
    end
    recording = { queue = { { name = name, skillLine = skillLine, update = true } } }
    RecordNext()
    if ns.RefreshPlanner then pcall(ns.RefreshPlanner) end
end

-- "just now", "5 min ago", "3 h ago", "2 days ago"
local function Age(seen)
    if type(seen) ~= "number" then return "unknown" end
    local seconds = math.max(0, time() - seen)
    if seconds < 60 then return "just now" end
    if seconds < 3600 then return ("%d min ago"):format(math.floor(seconds / 60)) end
    if seconds < 86400 then return ("%d h ago"):format(math.floor(seconds / 3600)) end
    local days = math.floor(seconds / 86400)
    return ("%d day%s ago"):format(days, days == 1 and "" or "s")
end
ns.RecipeAge = Age

---------------------------------------------------------------------------
-- Who holds what, and how many can be made
---------------------------------------------------------------------------

local function Holds(record, id)
    return (record.bagItems and record.bagItems[id] or 0) + (record.bankItems and record.bankItems[id] or 0)
end

-- Whether materials can be mailed between the two: same realm and faction,
-- and the crafter's full name is known (mail only goes to full names).
local function CanSupply(crafterKey, crafter, key, record)
    return crafter.fullName ~= nil and ns.SameRealm(crafterKey, crafter, key, record)
        and record.faction ~= nil and record.faction == crafter.faction
end

-- For one material: how many the crafter holds, how many their other
-- characters could mail them, and every other holder, most first.
function ns.ReagentStock(crafterKey, id)
    local crafter = ns.db.chars[crafterKey]
    local own = crafter and Holds(crafter, id) or 0
    local fromAlts, others = 0, {}
    for key, record in pairs(ns.db.chars) do
        if key ~= crafterKey then
            local count = Holds(record, id)
            if count > 0 then
                local mailable = crafter ~= nil and CanSupply(crafterKey, crafter, key, record)
                others[#others + 1] = { key = key, record = record, count = count, mailable = mailable }
                if mailable then fromAlts = fromAlts + count end
            end
        end
    end
    table.sort(others, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return ns.DisplayName(a.record) < ns.DisplayName(b.record)
    end)
    return own, fromAlts, others
end

-- How many the crafter can make with what they hold, and with what their
-- other characters could mail them too.
function ns.Makeable(crafterKey, recipe)
    local own, all
    for _, reagent in ipairs(recipe.reagents) do
        local mine, alts = ns.ReagentStock(crafterKey, reagent.id)
        local a, b = math.floor(mine / reagent.n), math.floor((mine + alts) / reagent.n)
        own = own and math.min(own, a) or a
        all = all and math.min(all, b) or b
    end
    return own or 0, all or 0
end

-- Whether the chosen recipe can be crafted right now, and how many of the
-- wanted number: the count, or nil and why not ("open" when pressing the
-- button can open the profession window).
function ns.CraftState(crafter, recipe, wanted)
    if crafter.key ~= ns.CurrentKey() then
        return nil, ("Log in to %s to craft this."):format(ns.DisplayName(crafter.record)), "login"
    end
    if InCombatLockdown and InCombatLockdown() then
        return nil, "Not while in combat."
    end
    local api = C_TradeSkillUI
    if ns.openProfession ~= crafter.profession then
        local book = ns.db.recipes[crafter.key] and ns.db.recipes[crafter.key][crafter.profession]
        if book and book.skillLine and api and api.OpenTradeSkill then
            return nil, ("Your %s window needs to be open to craft: press to open it."):format(crafter.profession), "open"
        end
        return nil, ("Open your %s window to craft."):format(crafter.profession)
    end
    if recipe.id and api and api.CraftRecipe then
        local info = Call(api.GetRecipeInfo, recipe.id)
        local available = type(info) == "table" and Number(info.numAvailable) or nil
        if available == 0 then return nil, "Not enough materials in your bags for one." end
        return math.min(wanted, available or wanted)
    end
    if recipe.index and DoTradeSkill then
        local name, _, available = Call(GetTradeSkillInfo, recipe.index)
        if name ~= recipe.name then
            return nil, ("Close and open your %s window again, so AltGlance finds this recipe."):format(crafter.profession)
        end
        if Number(available) == 0 then return nil, "Not enough materials in your bags for one." end
        return math.min(wanted, Number(available) or wanted)
    end
    return nil, ("Open your %s window once more, so AltGlance learns how to craft this."):format(crafter.profession)
end

-- Crafts the recipe, as many as wanted and the bags allow, or opens the
-- profession window first.
function ns.Craft(crafter, recipe, wanted)
    local count, reason, action = ns.CraftState(crafter, recipe, wanted)
    local api = C_TradeSkillUI
    if count then
        local ok, problem
        if recipe.id and api and api.CraftRecipe then
            ok, problem = pcall(api.CraftRecipe, recipe.id, count)
        else
            ok, problem = pcall(DoTradeSkill, recipe.index, count)
        end
        if ok then
            ns.Print(("Crafting %d %s. Moving stops it."):format(count, recipe.name))
        else
            ns.Print("The game would not craft it: " .. tostring(problem))
        end
        return ok
    elseif action == "open" then
        local book = ns.db.recipes[crafter.key][crafter.profession]
        pcall(api.OpenTradeSkill, book.skillLine)
        ns.Print(("Opening your %s window: press Craft again once it is open."):format(crafter.profession))
    else
        ns.Print(reason)
    end
end

local function FindRecipe(key, profession, name)
    local book = ns.db.recipes and ns.db.recipes[key] and ns.db.recipes[key][profession]
    for _, recipe in ipairs(book and book.list or {}) do
        if recipe.name == name then return recipe end
    end
end

---------------------------------------------------------------------------
-- The plan: what to craft, and so which materials to send the crafter
---------------------------------------------------------------------------

function ns.PlanAdd(crafterKey, profession, recipe, count)
    local plan = ns.db.plan
    if plan and plan.to ~= crafterKey and #plan.items > 0 then
        local old = ns.db.chars[plan.to]
        ns.Print(("The plan was for %s; it now starts afresh for %s."):format(
            old and ns.DisplayName(old) or "another character", ns.DisplayName(ns.db.chars[crafterKey])))
    end
    if not plan or plan.to ~= crafterKey then
        plan = { to = crafterKey, items = {} }
        ns.db.plan = plan
    end
    for _, item in ipairs(plan.items) do
        if item.name == recipe.name and item.profession == profession then
            item.count = item.count + count
            return
        end
    end
    plan.items[#plan.items + 1] = { name = recipe.name, profession = profession, count = count }
end

function ns.PlanClear()
    ns.db.plan = nil
end

-- Everything the plan needs: { [itemID] = how many in all }, and the crafter.
function ns.PlanNeeds()
    local plan = ns.db.plan
    if not plan or not ns.db.chars[plan.to] or #plan.items == 0 then return end
    local needs = {}
    for _, item in ipairs(plan.items) do
        local recipe = FindRecipe(plan.to, item.profession, item.name)
        for _, reagent in ipairs(recipe and recipe.reagents or {}) do
            needs[reagent.id] = (needs[reagent.id] or 0) + reagent.n * item.count
        end
    end
    return needs, plan.to
end

-- Whether the Send materials panel should send this item: the plan needs
-- it, the crafter is still short of it (as last seen), and the crafter is
-- who the panel is sending to.
function ns.PlanWants(itemID)
    local needs, to = ns.PlanNeeds()
    if not needs or not needs[itemID] then return false end
    local target = ns.MailTarget and ns.MailTarget()
    if not target or target.key ~= to then return false end
    return Holds(ns.db.chars[to], itemID) < needs[itemID]
end

-- At the mailbox on a character holding planned materials: point Send
-- materials at the crafter.
local function OfferPlan()
    local needs, to = ns.PlanNeeds()
    local me = ns.CurrentKey()
    local mine = me and ns.db.chars[me]
    local crafter = to and ns.db.chars[to]
    if not needs or not mine or not crafter or to == me then return end
    if not (ns.CanMail and ns.CanMail(mine, me, to, crafter)) then return end
    for id, count in pairs(needs) do
        if Holds(mine, id) > 0 and Holds(crafter, id) < count then
            ns.db.mailTo = ns.db.mailTo or {}
            if ns.db.mailTo[me] ~= to then
                ns.db.mailTo[me] = to
                ns.Print(("You hold materials planned for %s: Send materials is set to send to them."):format(crafter.fullName))
            end
            if ns.RefreshMailPanel then pcall(ns.RefreshMailPanel) end
            return
        end
    end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local ACCENT_R, ACCENT_G, ACCENT_B = 0.85, 0.63, 0.40
local WIDTH, HEIGHT, PAD = 740, 560, 12
local HEADER = 38
local LIST_TOP, LIST_WIDTH, ROW_HEIGHT, ROWS = 92, 300, 22, 18
local DETAIL_LEFT = PAD + LIST_WIDTH + 16
local DETAIL_WIDTH = WIDTH - DETAIL_LEFT - PAD
local REAGENT_ROWS, REAGENT_HEIGHT = 7, 30
local ACTION_HEIGHT = 32
local FILTERS = {
    { key = "all", label = "All recipes" },
    { key = "now", label = "Can make now" },
    { key = "alts", label = "Can make with alts' help" },
}

local window
local rows, reagentRows = {}, {}
local crafters, recipes = {}, {}
local pick = 1           -- which crafter and profession
local offset = 0         -- scroll of the recipe list
local selected           -- name of the chosen recipe
local quantity = 1

local function Fill(frame, r, g, b, a, layer)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function Outline(frame, alpha)
    local function Edge(point1, point2, isVertical)
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, alpha)
        edge:SetPoint(point1)
        edge:SetPoint(point2)
        if isVertical then edge:SetWidth(1) else edge:SetHeight(1) end
    end
    Edge("TOPLEFT", "TOPRIGHT", false)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", false)
    Edge("TOPLEFT", "BOTTOMLEFT", true)
    Edge("TOPRIGHT", "BOTTOMRIGHT", true)
end

local function Label(parent, font, justify)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetJustifyH(justify or "LEFT")
    label:SetWordWrap(false)
    return label
end

local function Button(parent, width, height, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.bg = Fill(button, 0.14, 0.11, 0.08, 1)
    Outline(button, 0.5)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.1)
    button.label = Label(button, ns.Font("GameFontHighlight"), "CENTER")
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

-- Every recorded character and profession: the one being played first.
local function Crafters()
    local list = {}
    local me = ns.CurrentKey()
    for key, book in pairs(ns.db.recipes or {}) do
        local record = ns.db.chars[key]
        if record then
            for profession, entry in pairs(book) do
                list[#list + 1] = { key = key, record = record, profession = profession, list = entry.list or {} }
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.key == me) ~= (b.key == me) then return a.key == me end
        local an, bn = ns.DisplayName(a.record), ns.DisplayName(b.record)
        if an ~= bn then return an < bn end
        return a.profession < b.profession
    end)
    return list
end

local function Current()
    return crafters[pick]
end

local function Filtered(crafter)
    local list = {}
    for _, recipe in ipairs(crafter.list) do
        local own, all = ns.Makeable(crafter.key, recipe)
        local keep = ns.db.plannerFilter == "all"
            or (ns.db.plannerFilter == "now" and own > 0)
            or (ns.db.plannerFilter == "alts" and all > 0)
        if keep then list[#list + 1] = { recipe = recipe, own = own, all = all } end
    end
    return list
end

local function PlanText()
    local plan = ns.db.plan
    if not plan or #plan.items == 0 or not ns.db.chars[plan.to] then
        return "No plan yet. Choose a recipe and press Add to plan; the Send materials panel at the mailbox then sends what it takes to the crafter."
    end
    local parts = {}
    for _, item in ipairs(plan.items) do
        parts[#parts + 1] = ("%d %s"):format(item.count, item.name)
    end
    return ("Plan for %s: %s."):format(ns.DisplayName(ns.db.chars[plan.to]), table.concat(parts, ", "))
end

-- "Alts: Bizzall 8, Shannizz 8   +16 on the other faction"
local function OthersText(others)
    local parts, more, elsewhere = {}, 0, 0
    for _, other in ipairs(others) do
        if not other.mailable then
            elsewhere = elsewhere + other.count
        elseif #parts < 3 then
            parts[#parts + 1] = ("%s %d"):format(other.record.name or ns.DisplayName(other.record), other.count)
        else
            more = more + other.count
        end
    end
    local text = ""
    if #parts > 0 then
        text = "Alts: " .. table.concat(parts, ", ")
        if more > 0 then text = text .. (", others %d"):format(more) end
    end
    if elsewhere > 0 then
        text = text .. (text ~= "" and "   " or "") .. ("+%d on the other faction"):format(elsewhere)
    end
    return text
end

local function RefreshDetail(crafter, entry)
    local detail = window.detail
    if not entry then
        detail:Hide()
        return
    end
    detail:Show()
    local recipe = entry.recipe
    local outLink = recipe.out and ns.db.itemLinks[recipe.out]
    detail.title:SetText(outLink or recipe.name)
    local who = crafter.record.name or ns.DisplayName(crafter.record)
    if entry.all > entry.own then
        detail.makes:SetText(("%s can make %d now, %d with materials from your alts."):format(who, entry.own, entry.all))
    else
        detail.makes:SetText(("%s can make %d now."):format(who, entry.own))
    end
    detail.count:SetText(tostring(quantity))
    detail.heading:SetText(("MATERIALS FOR %d"):format(quantity))
    local short = {}
    for index = 1, REAGENT_ROWS do
        local row = reagentRows[index]
        local reagent = recipe.reagents[index]
        if reagent then
            local need = reagent.n * quantity
            local mine, alts, others = ns.ReagentStock(crafter.key, reagent.id)
            row.id = reagent.id
            row.name:SetText(("%s  x%d"):format(ReagentName(reagent), need))
            local elsewhere = OthersText(others)
            row.who:SetText(("%s has %d%s"):format(who, mine, elsewhere ~= "" and ("   |cff808080-|r   " .. elsewhere) or ""))
            if mine >= need then
                row.state:SetText("Ready")
                row.state:SetTextColor(0.4, 0.9, 0.4)
            elseif mine + alts >= need then
                row.state:SetText(("%d from alts"):format(need - mine))
                row.state:SetTextColor(1, 0.82, 0.2)
            else
                local missing = need - mine - alts
                row.state:SetText(("Short %d"):format(missing))
                row.state:SetTextColor(1, 0.3, 0.25)
                short[#short + 1] = ("%d %s"):format(missing, ReagentName(reagent))
            end
            row:Show()
        else
            row.id = nil
            row:Hide()
        end
    end
    local hidden = #recipe.reagents - REAGENT_ROWS
    if hidden > 0 then
        short[#short + 1] = ("and %d more material%s not shown"):format(hidden, hidden == 1 and "" or "s")
    end
    if #short > 0 then
        detail.short:SetText("To buy or gather: " .. table.concat(short, ", ") .. ".")
        detail.short:SetTextColor(1, 0.55, 0.45)
    else
        detail.short:SetText("Everything for this is on your characters.")
        detail.short:SetTextColor(0.5, 0.9, 0.5)
    end

    local count, reason, action = ns.CraftState(crafter, recipe, quantity)
    local craft = window.craft
    craft.reason = reason
    if count then
        craft.label:SetText("Craft " .. count)
    elseif action == "open" then
        craft.label:SetText("Open " .. crafter.profession)
    else
        craft.label:SetText("Craft")
    end
    local ready = count ~= nil or action == "open"
    detail.note:SetText(count and "" or (reason or ""))
    craft.label:SetTextColor(ready and 1 or 0.5, ready and 0.95 or 0.5, ready and 0.85 or 0.5)
    craft.bg:SetColorTexture(ready and 0.45 or 0.14, ready and 0.30 or 0.11, ready and 0.12 or 0.08, 1)
end

local function Refresh()
    if not window or not window:IsShown() then return end
    Settings()
    crafters = Crafters()
    if ns.plannerShowMe then
        ns.plannerShowMe = nil
        if crafters[1] and crafters[1].key == ns.CurrentKey() then pick, offset, selected = 1, 0, nil end
    end
    pick = math.min(math.max(pick, 1), math.max(#crafters, 1))
    local crafter = Current()
    window.empty:SetShown(crafter == nil)

    -- Record / Update: the playing character's professions not recorded
    -- yet first; otherwise the profession shown, if it is theirs.
    local missing = ns.UnrecordedProfessions()
    local record = window.record
    record.missing, record.crafter, record.mode = missing, crafter, "record"
    local canOpen = C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill and true or false
    record:SetShown(canOpen or #missing > 0)
    local active = true
    if ns.IsRecording() then
        record.label:SetText("Recording...")
    elseif #missing == 1 then
        record.label:SetText("Record my " .. missing[1].name)
    elseif #missing > 1 then
        record.label:SetText(("Record my %s (%d more)"):format(missing[1].name, #missing - 1))
    elseif crafter and crafter.key == ns.CurrentKey() then
        record.mode = "update"
        record.label:SetText("Update my " .. crafter.profession)
    else
        record.mode = "other"
        record.label:SetText("Update recipes")
        active = false
    end
    record.label:SetTextColor(active and 1 or 0.5, active and 0.85 or 0.5, active and 0.45 or 0.5)
    window.prev:SetShown(#crafters > 1)
    window.next:SetShown(#crafters > 1)
    -- The button back to the character being played: only when they have
    -- recipes and there are others to browse; dimmed while already there.
    local me = ns.CurrentKey()
    local mine = me and ns.db.chars[me]
    local hasMine = false
    for _, entry in ipairs(crafters) do
        if entry.key == me then hasMine = true break end
    end
    window.home:SetShown(hasMine and #crafters > 1)
    if mine then
        window.home.label:SetText(mine.name or ns.DisplayName(mine))
        window.home.who = ns.DisplayName(mine)
        local here = crafter ~= nil and crafter.key == me
        window.home.label:SetTextColor(here and 0.5 or 1, here and 0.5 or 0.85, here and 0.5 or 0.45)
    end
    for _, filter in ipairs(FILTERS) do
        if filter.key == ns.db.plannerFilter then window.filter.label:SetText(filter.label) end
    end
    window.plan:SetText(PlanText())
    window.clear:SetShown(ns.db.plan ~= nil)
    if not crafter then
        window.crafter:SetText("No recipes recorded yet")
        window.crafter:SetTextColor(0.6, 0.6, 0.6)
        for _, row in ipairs(rows) do row:Hide() end
        RefreshDetail(nil, nil)
        return
    end
    window.crafter:SetText(("%s  -  %s (%d)"):format(ns.DisplayName(crafter.record), crafter.profession, #crafter.list))
    window.crafter:SetTextColor(ClassColour(crafter.record.classFile))

    recipes = Filtered(crafter)
    offset = math.min(offset, math.max(0, #recipes - ROWS))
    window.scrollBar:Update(offset, #recipes, ROWS)
    local chosen
    for _, entry in ipairs(recipes) do
        if entry.recipe.name == selected then chosen = entry end
    end
    if not chosen and recipes[1] then
        chosen = recipes[1]
        selected, quantity = chosen.recipe.name, 1
    end
    for index = 1, ROWS do
        local row = rows[index]
        local entry = recipes[index + offset]
        if entry then
            row.entry = entry
            row.name:SetText(entry.recipe.name)
            if entry.own > 0 then
                row.name:SetTextColor(0.4, 0.9, 0.4)
                row.count:SetText("x" .. entry.own)
            elseif entry.all > 0 then
                row.name:SetTextColor(1, 0.82, 0.2)
                row.count:SetText("x" .. entry.all .. " *")
            else
                row.name:SetTextColor(0.6, 0.6, 0.6)
                row.count:SetText("")
            end
            row.pick:SetShown(entry == chosen)
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end
    window.listEmpty:SetShown(#recipes == 0)
    RefreshDetail(crafter, chosen)
end
ns.RefreshPlanner = Refresh

local function CreateRecipeRow(index)
    local row = CreateFrame("Button", nil, window)
    row:SetSize(LIST_WIDTH - 20, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PAD, -(LIST_TOP + (index - 1) * ROW_HEIGHT))
    if index % 2 == 0 then Fill(row, 1, 1, 1, 0.03) end
    row.pick = Fill(row, ACCENT_R, ACCENT_G, ACCENT_B, 0.22, "BORDER")
    row.pick:Hide()
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.07)
    row.name = Label(row, ns.Font("GameFontHighlightSmall"))
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetPoint("RIGHT", -52, 0)
    row.count = Label(row, ns.Font("GameFontHighlightSmall"), "RIGHT")
    row.count:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnClick", function(self)
        if not self.entry then return end
        selected, quantity = self.entry.recipe.name, 1
        Refresh()
    end)
    rows[index] = row
end

local function CreateReagentRow(parent, index, top)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(DETAIL_WIDTH, REAGENT_HEIGHT)
    row:SetPoint("TOPLEFT", 0, top - (index - 1) * REAGENT_HEIGHT)
    if index % 2 == 1 then Fill(row, 1, 1, 1, 0.03) end
    row:EnableMouse(true)
    row.name = Label(row, ns.Font("GameFontHighlight"))
    row.name:SetPoint("TOPLEFT", 8, -3)
    row.name:SetPoint("RIGHT", -100, 0)
    row.who = Label(row, ns.Font("GameFontDisableSmall"))
    row.who:SetPoint("BOTTOMLEFT", 8, 3)
    row.who:SetPoint("RIGHT", -100, 0)
    row.state = Label(row, ns.Font("GameFontHighlight"), "RIGHT")
    row.state:SetPoint("RIGHT", -8, 0)
    -- The item's own tooltip, with AltGlance's "On your characters" lines.
    row:SetScript("OnEnter", function(self)
        if not self.id then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if not pcall(GameTooltip.SetItemByID, GameTooltip, self.id) then
            GameTooltip:AddLine(row.name:GetText() or "")
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    reagentRows[index] = row
end

local function SetQuantity(value)
    quantity = math.max(1, math.min(999, value))
    Refresh()
end

local function CreateWindow()
    window = CreateFrame("Frame", addonName .. "Planner", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:Hide()
    Fill(window, 0.05, 0.05, 0.06, 0.97)
    Outline(window, 0.55)
    tinsert(UISpecialFrames, addonName .. "Planner")
    ns.CloseWithPadB(window)

    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    Fill(header, 0.16, 0.12, 0.08, 1)
    local title = Label(header, ns.Font("GameFontNormalLarge"))
    title:SetPoint("LEFT", PAD, 0)
    title:SetText("AltGlance  -  Profession planner")
    title:SetTextColor(1, 0.9, 0.75)
    local close = Button(header, 30, 30, "x", function() window:Hide() end)
    close:SetPoint("RIGHT", -4, 0)
    -- Record: opens each profession window not recorded yet, reads it, closes it.
    window.record = Button(header, 230, 28, "", function(self)
        if self.mode == "update" and self.crafter then
            ns.UpdateProfession(self.crafter.profession)
        elseif self.mode == "other" then
            ns.Print(self.crafter and ("Log in to %s to update their recipes."):format(ns.DisplayName(self.crafter.record))
                or "Press this on each character to record their recipes.")
        else
            ns.RecordProfessions()
        end
        Refresh()
    end)
    window.record:SetPoint("RIGHT", close, "LEFT", -8, 0)
    window.record.label:SetTextColor(1, 0.85, 0.45)
    window.record:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local crafter = self.crafter
        local book = crafter and ns.db.recipes[crafter.key] and ns.db.recipes[crafter.key][crafter.profession]
        if self.mode == "update" then
            GameTooltip:AddLine("Update my " .. crafter.profession, 1, 1, 1)
            GameTooltip:AddLine("Reads your recipes again, so ones learned since show up. Last read: " .. Age(book and book.seen) .. ".", 1, 0.85, 0.45, true)
        elseif self.mode == "other" then
            GameTooltip:AddLine("Update recipes", 1, 1, 1)
            if crafter then
                GameTooltip:AddLine(("Log in to %s to update their %s recipes. Last read: %s."):format(
                    ns.DisplayName(crafter.record), crafter.profession, Age(book and book.seen)), 0.9, 0.9, 0.9, true)
            end
        else
            GameTooltip:AddLine("Record my professions", 1, 1, 1)
        end
        local names = {}
        for _, item in ipairs(self.missing or {}) do names[#names + 1] = item.name end
        if #names > 0 then GameTooltip:AddLine("Not recorded yet: " .. table.concat(names, ", "), 1, 0.85, 0.45, true) end
        GameTooltip:AddLine("The game shows recipes only in the profession window, so AltGlance opens it, reads it and closes it again. One per press: the game lets an addon open a profession window only right after a click.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    window.record:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Crafter and profession:  [<]  Name Surname - Tailoring (42)  [>]
    local y = -(HEADER + 10)
    window.prev = Button(window, 30, 30, "<", function() pick = pick - 1; if pick < 1 then pick = #crafters end; offset = 0; selected = nil; Refresh() end)
    window.prev:SetPoint("TOPLEFT", PAD, y)
    window.next = Button(window, 30, 30, ">", function() pick = pick + 1; if pick > #crafters then pick = 1 end; offset = 0; selected = nil; Refresh() end)
    window.next:SetPoint("TOPLEFT", PAD + 380, y)
    window.crafter = Label(window, ns.Font("GameFontHighlight"), "CENTER")
    window.crafter:SetPoint("TOPLEFT", PAD + 36, y - 8)
    window.crafter:SetWidth(338)
    -- Back to the character being played, after browsing the others.
    window.home = Button(window, 92, 30, "", function()
        local me = ns.CurrentKey()
        for index, entry in ipairs(crafters) do
            if entry.key == me then
                pick, offset, selected = index, 0, nil
                break
            end
        end
        Refresh()
    end)
    window.home:SetPoint("TOPLEFT", PAD + 416, y)
    window.home.label:SetFontObject(ns.Font("GameFontHighlightSmall"))
    window.home:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Back to the character you are playing", 1, 1, 1)
        if self.who then GameTooltip:AddLine(self.who .. "'s professions.", 0.8, 0.8, 0.8) end
        GameTooltip:Show()
    end)
    window.home:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Which recipes the list shows.
    window.filter = Button(window, 200, 30, "", function()
        local index = 1
        for i, filter in ipairs(FILTERS) do
            if filter.key == ns.db.plannerFilter then index = i % #FILTERS + 1 end
        end
        ns.db.plannerFilter = FILTERS[index].key
        offset = 0
        Refresh()
    end)
    window.filter:SetPoint("TOPRIGHT", -PAD, y)

    for index = 1, ROWS do CreateRecipeRow(index) end
    -- A scroll bar for the recipes, for a controller or a long list.
    window.scrollBar = ns.CreateScrollBar(window, ROWS * ROW_HEIGHT, function(value)
        offset = value
        Refresh()
    end)
    window.scrollBar:SetPoint("TOPLEFT", PAD + LIST_WIDTH - 16, -LIST_TOP)
    window.listEmpty = Label(window, ns.Font("GameFontDisable"), "CENTER")
    window.listEmpty:SetPoint("TOPLEFT", PAD, -(LIST_TOP + 20))
    window.listEmpty:SetWidth(LIST_WIDTH)
    window.listEmpty:SetText("None of these recipes right now.")
    local legend = Label(window, ns.Font("GameFontDisableSmall"))
    legend:SetPoint("TOPLEFT", PAD + 4, -(LIST_TOP + ROWS * ROW_HEIGHT + 6))
    legend:SetText("|cff66e666Green|r: can make now.  |cffffd133Yellow *|r: with materials from alts.")

    window.empty = Label(window, ns.Font("GameFontHighlight"), "CENTER")
    window.empty:SetPoint("CENTER", 0, 20)
    window.empty:SetWidth(WIDTH - 80)
    window.empty:SetWordWrap(true)
    window.empty:SetText("No recipes recorded yet.\n\nPress Record at the top on each of your characters (or open their profession windows),\nand AltGlance records what they can make.")

    -- The chosen recipe.
    local detail = CreateFrame("Frame", nil, window)
    detail:SetPoint("TOPLEFT", DETAIL_LEFT, -LIST_TOP)
    detail:SetSize(DETAIL_WIDTH, HEIGHT - LIST_TOP - 70)
    window.detail = detail
    detail.title = Label(detail, ns.Font("GameFontNormalLarge"))
    detail.title:SetPoint("TOPLEFT", 4, 0)
    detail.title:SetWidth(DETAIL_WIDTH - 8)
    detail.makes = Label(detail, ns.Font("GameFontHighlightSmall"))
    detail.makes:SetPoint("TOPLEFT", 4, -24)
    detail.makes:SetWidth(DETAIL_WIDTH - 8)

    -- Make:  [-]  2  [+]  [Most]
    local amount = Label(detail, ns.Font("GameFontHighlight"))
    amount:SetPoint("TOPLEFT", 4, -55)
    amount:SetText("Make:")
    local minus = Button(detail, 30, 28, "-", function() SetQuantity(quantity - 1) end)
    minus:SetPoint("TOPLEFT", 52, -48)
    detail.count = Label(detail, ns.Font("GameFontHighlightLarge"), "CENTER")
    detail.count:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    detail.count:SetWidth(44)
    local plus = Button(detail, 30, 28, "+", function() SetQuantity(quantity + 1) end)
    plus:SetPoint("LEFT", minus, "RIGHT", 52, 0)
    local most = Button(detail, 64, 28, "Most", function()
        local crafter = Current()
        for _, entry in ipairs(recipes) do
            if crafter and entry.recipe.name == selected then SetQuantity(math.max(entry.all, 1)) end
        end
    end)
    most:SetPoint("LEFT", plus, "RIGHT", 8, 0)
    -- Craft: makes it, if this is the crafter and their profession window
    -- is open (the game crafts only from there).
    local half = (DETAIL_WIDTH - 8 - 8) / 2
    local craft = Button(detail, half, ACTION_HEIGHT, "Craft", function()
        local crafter = Current()
        local recipe = crafter and FindRecipe(crafter.key, crafter.profession, selected)
        if recipe then ns.Craft(crafter, recipe, quantity) end
        Refresh()
    end)
    craft:SetPoint("BOTTOMLEFT", 4, 0)
    craft.label:SetFontObject(ns.Font("GameFontNormal"))
    craft:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Craft", 1, 1, 1)
        GameTooltip:AddLine(self.reason or "Makes the number above, as many as the materials in your bags allow.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    craft:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.craft = craft
    local add = Button(detail, half, ACTION_HEIGHT, "Add to plan", function()
        local crafter = Current()
        local recipe = crafter and FindRecipe(crafter.key, crafter.profession, selected)
        if not recipe then return end
        ns.PlanAdd(crafter.key, crafter.profession, recipe, quantity)
        ns.Print(("Planned: %d %s for %s. At the mailbox on your other characters, Send materials sends what it takes."):format(
            quantity, recipe.name, ns.DisplayName(crafter.record)))
        Refresh()
    end)
    add:SetPoint("BOTTOMRIGHT", -4, 0)
    add.label:SetFontObject(ns.Font("GameFontNormal"))
    window.add = add
    -- Why Craft cannot be pressed, just above it.
    detail.note = Label(detail, ns.Font("GameFontDisableSmall"))
    detail.note:SetPoint("BOTTOMLEFT", 4, ACTION_HEIGHT + 8)
    detail.note:SetWidth(DETAIL_WIDTH - 8)

    detail.heading = Label(detail, ns.Font("GameFontDisableSmall"))
    detail.heading:SetPoint("TOPLEFT", 4, -88)
    detail.heading:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B)
    for index = 1, REAGENT_ROWS do CreateReagentRow(detail, index, -104) end
    detail.short = Label(detail, ns.Font("GameFontHighlightSmall"))
    detail.short:SetPoint("TOPLEFT", 4, -(104 + REAGENT_ROWS * REAGENT_HEIGHT + 8))
    detail.short:SetWidth(DETAIL_WIDTH - 8)
    detail.short:SetWordWrap(true)

    -- The plan, along the bottom.
    local footer = CreateFrame("Frame", nil, window)
    footer:SetPoint("BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(48)
    Fill(footer, 0, 0, 0, 0.35)
    window.plan = Label(footer, ns.Font("GameFontHighlightSmall"))
    window.plan:SetPoint("LEFT", PAD, 0)
    window.plan:SetWidth(WIDTH - PAD * 3 - 100)
    window.plan:SetWordWrap(true)
    window.clear = Button(footer, 100, 28, "Clear plan", function()
        ns.PlanClear()
        Refresh()
    end)
    window.clear:SetPoint("RIGHT", -PAD, 0)

    window:EnableMouseWheel(true)
    window:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta * 3)
        Refresh()
    end)
end

-- /alts prof debug: what the open profession window gives AltGlance.
function ns.PlannerDebug()
    local api = C_TradeSkillUI
    if not api then
        ns.Print("Debug: no C_TradeSkillUI. Classic list: " .. tostring(GetNumTradeSkills and Call(GetNumTradeSkills)))
        return
    end
    local base = Call(api.GetBaseProfessionInfo)
    local ids = Call(api.GetAllRecipeIDs)
    local learned = 0
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        local info = Call(api.GetRecipeInfo, id)
        if type(info) == "table" and info.learned then learned = learned + 1 end
    end
    ns.Print(("Debug: profession %s, %s recipe IDs, %d learned, linked %s. Reading now..."):format(
        tostring(type(base) == "table" and base.professionName), tostring(type(ids) == "table" and #ids or ids),
        learned, tostring(Call(api.IsTradeSkillLinked))))
    local profession, count = ns.ReadRecipes()
    ns.Print(profession and ("Debug: recorded %d %s recipes."):format(count, profession)
        or "Debug: nothing recorded. Is a profession window open?")
end

function ns.TogglePlanner()
    Settings()
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        -- Start on the character being played, if they have recipes.
        crafters = Crafters()
        if crafters[pick] == nil or (crafters[1] and crafters[1].key == ns.CurrentKey() and crafters[pick].key ~= ns.CurrentKey()) then
            pick, offset, selected = 1, 0, nil
        end
        window:Show()
        Refresh()
        ns.FitWindow(window)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local pending = false
local function ReadSoon()
    if pending then return end
    pending = true
    local function Run()
        pending = false
        pcall(ns.ReadRecipes)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, Run) else Run() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then
        Settings()
        -- Registering an event this client does not have throws.
        for _, name in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
                "TRADE_SKILL_UPDATE", "NEW_RECIPE_LEARNED", "MAIL_SHOW", "BAG_UPDATE_DELAYED", "TRADE_SKILL_CLOSE",
                "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
            pcall(self.RegisterEvent, self, name)
        end
        return
    end
    if event == "MAIL_SHOW" then
        pcall(OfferPlan)
    elseif event == "TRADE_SKILL_CLOSE" then
        ns.openProfession = nil
        if window and window:IsShown() then pcall(Refresh) end
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if window and window:IsShown() then pcall(Refresh) end
    else
        if recording then recording.shown = true end
        ReadSoon()
    end
end)
