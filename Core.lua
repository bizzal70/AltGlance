local addonName, ns = ...

-- Keeps a short record of every character on the account (level, gold,
-- where they are, rested experience, professions, bag space) so they can
-- all be seen at once, from whichever character is logged in.
--
-- A character's record is refreshed while that character is played; the
-- others are shown as they were when last seen.

-- The backpack and the four bag slots.
local FIRST_BAG, LAST_BAG = 0, 4
-- Rested experience is capped at one and a half levels.
local RESTED_CAP_LEVELS = 1.5
-- In an inn or city a character rests a twentieth of a level every eight
-- hours; elsewhere, a quarter as fast. From the original game; treated
-- here as an estimate.
local RESTED_PER_SECOND = 0.05 / (8 * 3600)
local RESTED_OUTDOORS = 0.25

local defaults = {
    minimapButton = true,
    minimapAngle = 2.6,
    -- Which column the list is sorted by, and which way.
    sortBy = "level",
    sortDescending = true,
    -- "On your characters" lines in item tooltips.
    itemTooltip = true,
}

function ns.Print(msg)
    print("|cffd9a066AltGlance|r: " .. tostring(msg))
end

-- A value the client may withhold cannot be compared or stored.
local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end
ns.Usable = Usable

-- A character's name as shown: the full name (first and last) once known.
function ns.DisplayName(record)
    return record.fullName or record.name or "?"
end

-- 12345 copper -> "1g 23s 45c"
function ns.Money(copper)
    copper = math.floor(copper + 0.5)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local rest = copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "g" end
    if silver > 0 then parts[#parts + 1] = silver .. "s" end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. "c" end
    return table.concat(parts, " ")
end

-- "3 min ago", "2 h ago", "5 days ago"
function ns.Ago(timestamp)
    local seconds = math.max(0, time() - timestamp)
    if seconds < 90 then
        return "just now"
    elseif seconds < 5400 then
        return ("%d min ago"):format(seconds / 60)
    elseif seconds < 172800 then
        return ("%d h ago"):format(seconds / 3600)
    end
    return ("%d days ago"):format(seconds / 86400)
end

---------------------------------------------------------------------------
-- Recording the character being played
---------------------------------------------------------------------------

function ns.CurrentKey()
    local guid = UnitGUID("player")
    return Usable(guid) and guid or nil
end

-- The realm server number in a character's key (their GUID,
-- "Player-<server>-<id>"): characters on the same realm share it.
local function ServerID(key)
    return type(key) == "string" and key:match("^Player%-(%d+)%-") or nil
end

-- A character's realm. Forever's GetRealmName sometimes gives an empty name
-- (seen 2026-11-22: "" on one character, the full name on the others), so
-- the realm goes by the server number in the GUID: the name most of the
-- characters on that server were recorded with. Without a server number,
-- the character's own realm name.
function ns.RealmOf(key, record)
    local own = type(record.realm) == "string" and record.realm ~= "" and record.realm or nil
    local server = ServerID(key)
    if not server then return own end
    local votes, best, most = {}, nil, 0
    for otherKey, other in pairs(ns.db.chars) do
        local realm = other.realm
        if ServerID(otherKey) == server and type(realm) == "string" and realm ~= "" then
            votes[realm] = (votes[realm] or 0) + 1
            if votes[realm] > most or (votes[realm] == most and realm < best) then
                best, most = realm, votes[realm]
            end
        end
    end
    return best or own or ("Realm " .. server)
end

-- Whether two characters are on the same realm: by the GUID's server number
-- when both have one, else by realm name.
function ns.SameRealm(keyA, recordA, keyB, recordB)
    local a, b = ServerID(keyA), ServerID(keyB)
    if a and b then return a == b end
    local realm = ns.RealmOf(keyA, recordA)
    return realm ~= nil and realm == ns.RealmOf(keyB, recordB)
end

-- The realm name, or nil when the game gives an empty one. Only
-- GetRealmName: on Forever, UnitFullName's "realm" is the character's last
-- name ("Wolfbane", seen 2026-11-22), as with UnitName's second value.
local function ReadRealm()
    local ok, realm = pcall(GetRealmName)
    if ok and Usable(realm) and type(realm) == "string" and realm ~= "" then return realm end
end

-- Controller buttons for AltGlance's windows. While a window is shown, some
-- controller buttons are borrowed for it (B closes it; the planner and the
-- list add the D-pad and more): each is bound to an invisible button that
-- does the job, and gets its usual job back once the window hides. When a
-- fight starts every borrowed button is handed back at once (the last moment
-- the game allows it), so the D-pad and face buttons always work in a fight,
-- and they are borrowed again once it is over.
local padOwner = CreateFrame("Frame")
local padWindows = {}   -- { window =, priority =, keys = { [key] = button name } }, highest priority first
local inFight = false

local function PadApply()
    if not (SetOverrideBinding and ClearOverrideBindings) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    ClearOverrideBindings(padOwner)
    if inFight then return end
    local taken = {}
    for _, entry in ipairs(padWindows) do
        if entry.window:IsShown() then
            for key, button in pairs(entry.keys) do
                if not taken[key] then
                    taken[key] = true
                    SetOverrideBinding(padOwner, true, key, "CLICK " .. button .. ":LeftButton")
                end
            end
        end
    end
end
function ns.PadApply() pcall(PadApply) end

padOwner:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inFight = true
        if ClearOverrideBindings then pcall(ClearOverrideBindings, padOwner) end
    else
        inFight = false
        pcall(PadApply)
    end
end)
pcall(padOwner.RegisterEvent, padOwner, "PLAYER_REGEN_DISABLED")
pcall(padOwner.RegisterEvent, padOwner, "PLAYER_REGEN_ENABLED")

-- Borrows a controller button for a window while it is shown: "PAD2" is B,
-- "PAD3" X, "PAD4" Y, "PADDUP" and so on the D-pad. When two open windows
-- want the same button, the one with the higher priority has it.
function ns.PadKey(window, key, action, priority)
    local entry
    for _, existing in ipairs(padWindows) do
        if existing.window == window then entry = existing end
    end
    if not entry then
        entry = { window = window, priority = 0, keys = {} }
        padWindows[#padWindows + 1] = entry
        window:HookScript("OnShow", function() pcall(PadApply) end)
        window:HookScript("OnHide", function() pcall(PadApply) end)
    end
    if priority then entry.priority = priority end
    table.sort(padWindows, function(a, b) return a.priority > b.priority end)
    local name = window:GetName() .. "Pad" .. key
    -- Never placed on screen, and not clickable with the mouse.
    local button = CreateFrame("Button", name, UIParent)
    button:EnableMouse(false)
    button:SetScript("OnClick", function() if window:IsShown() then action() end end)
    entry.keys[key] = name
    return button
end

-- The controller's B closes the window, as Escape does.
function ns.CloseWithPadB(window)
    window.padClose = ns.PadKey(window, "PAD2", function() window:Hide() end)
end

---------------------------------------------------------------------------
-- Fitting the windows to any screen and text size
---------------------------------------------------------------------------

-- How much bigger the game's text is than the usual size (GameFontHighlight
-- at 12), 1 to 2.
local BASE_TEXT = 12
function ns.TextScale()
    local font = GameFontHighlight
    if font and font.GetFont then
        local ok, _, size = pcall(font.GetFont, font)
        if ok and type(size) == "number" and size > 0 then
            return math.min(2, math.max(1, size / BASE_TEXT))
        end
    end
    return 1
end

-- AltGlance's windows are laid out for the usual text size. Its text uses
-- copies of the game's fonts brought back to that size, and the whole
-- window is scaled up instead (ns.FitWindow): the same look, just bigger,
-- so a larger text size (or a handheld's) never makes text overlap.
local pinned = {}
function ns.Font(template)
    if pinned[template] ~= nil then return pinned[template] or template end
    local name = addonName .. template
    local ok = pcall(function()
        local source = _G[template]
        local file, size, flags = source:GetFont()
        assert(type(file) == "string" and type(size) == "number" and size > 0)
        local font = CreateFont(name)
        font:SetFontObject(source)
        font:SetFont(file, size / ns.TextScale(), flags or "")
    end)
    pinned[template] = ok and name or false
    return ok and name or template
end

-- Scales a window up as much as the game's text is bigger than usual, but
-- never past the screen: a window that would not fit is shrunk to fit.
function ns.FitWindow(window)
    local scale = ns.TextScale()
    local okSize, width, height = pcall(function() return window:GetWidth(), window:GetHeight() end)
    local okScreen, screenWidth, screenHeight = pcall(function() return UIParent:GetWidth(), UIParent:GetHeight() end)
    if okSize and okScreen and type(width) == "number" and type(height) == "number" and width > 0 and height > 0
            and type(screenWidth) == "number" and type(screenHeight) == "number" and screenWidth > 0 and screenHeight > 0 then
        scale = math.min(scale, screenWidth * 0.96 / width, screenHeight * 0.92 / height)
    end
    pcall(window.SetScale, window, scale)
    return scale
end

-- A scroll bar for a list: up and down buttons big enough to press with a
-- controller's cursor, and a track that pages when clicked above or below
-- its thumb. onScroll(offset) is called with the new first row.
function ns.CreateScrollBar(parent, height, onScroll, wheelStep)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(16, height)
    bar.offset, bar.total, bar.visible = 0, 0, 1
    local function Max() return math.max(0, bar.total - bar.visible) end
    local function Arrow(text, point)
        local button = CreateFrame("Button", nil, bar)
        button:SetSize(16, 18)
        button:SetPoint(point)
        local back = button:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(0.30, 0.22, 0.12, 1)
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.15)
        local label = button:CreateFontString(nil, "OVERLAY", ns.Font("GameFontHighlightSmall"))
        label:SetPoint("CENTER", 0, 1)
        label:SetText(text)
        return button
    end
    local up = Arrow("^", "TOP")
    local down = Arrow("v", "BOTTOM")
    up:SetScript("OnClick", function() onScroll(math.max(0, bar.offset - 1)) end)
    down:SetScript("OnClick", function() onScroll(math.min(Max(), bar.offset + 1)) end)
    local track = CreateFrame("Button", nil, bar)
    track:SetPoint("TOPLEFT", up, "BOTTOMLEFT", 0, -2)
    track:SetPoint("BOTTOMRIGHT", down, "TOPRIGHT", 0, 2)
    local trackBack = track:CreateTexture(nil, "BACKGROUND")
    trackBack:SetAllPoints()
    trackBack:SetColorTexture(0, 0, 0, 0.45)
    -- The handle: drag it, or click the track above or below it.
    local thumb = CreateFrame("Button", nil, track)
    local thumbTexture = thumb:CreateTexture(nil, "ARTWORK")
    thumbTexture:SetAllPoints()
    thumbTexture:SetColorTexture(0.85, 0.63, 0.40, 0.8)
    local thumbHover = thumb:CreateTexture(nil, "HIGHLIGHT")
    thumbHover:SetAllPoints()
    thumbHover:SetColorTexture(1, 1, 1, 0.2)
    bar.thumb = thumb
    local function CursorY()
        local ok, y = pcall(function()
            local _, cursorY = GetCursorPosition()
            return cursorY / track:GetEffectiveScale()
        end)
        return ok and type(y) == "number" and y or nil
    end
    thumb:SetScript("OnMouseDown", function(self)
        self.dragY, self.dragOffset = CursorY(), bar.offset
        if not self.dragY then return end
        self:SetScript("OnUpdate", function(handle)
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                handle:SetScript("OnUpdate", nil)
                return
            end
            local y = CursorY()
            local room = (bar.trackHeight or 0) - (bar.thumbHeight or 0)
            if not y or room <= 0 then return end
            local rows = math.floor((handle.dragY - y) / room * Max() + 0.5)
            local value = math.min(Max(), math.max(0, handle.dragOffset + rows))
            if value ~= bar.offset then onScroll(value) end
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    thumb:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    -- The mouse wheel over any part of the bar scrolls too.
    local function Wheel(_, delta)
        local value = math.min(Max(), math.max(0, bar.offset - delta * (wheelStep or 1)))
        if value ~= bar.offset then onScroll(value) end
    end
    for _, part in ipairs({ bar, up, down, track, thumb }) do
        part:EnableMouseWheel(true)
        part:SetScript("OnMouseWheel", Wheel)
    end
    track:SetScript("OnClick", function()
        -- Above the thumb pages up, below it pages down.
        local page = math.max(1, bar.visible - 1)
        local okCursor, cursorY = pcall(function()
            local _, y = GetCursorPosition()
            return y / track:GetEffectiveScale()
        end)
        local okThumb, thumbTop = pcall(thumb.GetTop, thumb)
        if okCursor and okThumb and type(cursorY) == "number" and type(thumbTop) == "number" and cursorY > thumbTop then
            onScroll(math.max(0, bar.offset - page))
        else
            onScroll(math.min(Max(), bar.offset + page))
        end
    end)
    function bar.Update(self, offset, total, visible)
        self.offset, self.total, self.visible = offset, total, visible
        if total <= visible then
            self:Hide()
            return
        end
        self:Show()
        local trackHeight = height - 40
        local thumbHeight = math.max(14, trackHeight * visible / total)
        self.trackHeight, self.thumbHeight = trackHeight, thumbHeight
        local y = (trackHeight - thumbHeight) * offset / math.max(1, total - visible)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 2, -y)
        thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", -2, -y)
        thumb:SetHeight(thumbHeight)
    end
    return bar
end

-- Sets a field only when the game gave a usable answer, so a value it
-- withholds for a moment does not wipe out what was known.
local function Keep(record, field, value)
    if Usable(value) then
        record[field] = value
    end
end

local function ReadProfessions()
    if not GetProfessions or not GetProfessionInfo then return end
    local professions = {}
    for slot = 1, 5 do
        local index = (select(slot, GetProfessions()))
        if Usable(index) then
            local name, _, level, maxLevel = GetProfessionInfo(index)
            if Usable(name) and Usable(level) then
                professions[#professions + 1] = { name = name, level = level, max = Usable(maxLevel) and maxLevel or nil }
            end
        end
    end
    return professions
end

local function ReadBags()
    local free, total = 0, 0
    for bag = FIRST_BAG, LAST_BAG do
        local slots = C_Container.GetContainerNumSlots(bag)
        local open = C_Container.GetContainerNumFreeSlots(bag)
        if not Usable(slots) or not Usable(open) then return end
        free, total = free + open, total + slots
    end
    return free, total
end

-- Writes down how the current character stands right now.
function ns.Snapshot()
    local key = ns.CurrentKey()
    if not key then return end
    local record = ns.db.chars[key]
    if not record then
        record = {}
        ns.db.chars[key] = record
    end

    -- Forever characters have a first and a last name, and first names are
    -- not unique: UnitName gives "Shannizz" plus "Wolfbane" as a second
    -- value, GetUnitName("player", true) gives "Shannizz Wolfbane" (seen in
    -- game 2026-11-17). The full name is what tells characters apart, and
    -- what mail is sent to.
    local first, second = UnitName("player")
    Keep(record, "name", first)
    local full
    if GetUnitName then
        local ok, text = pcall(GetUnitName, "player", true)
        if ok and Usable(text) and type(text) == "string" and text ~= "" then full = text end
    end
    if not full and Usable(first) and Usable(second) and type(second) == "string" and second ~= "" then
        full = first .. " " .. second
    end
    Keep(record, "fullName", full)
    -- An empty realm name is not kept (see ns.RealmOf).
    if record.realm == "" then record.realm = nil end
    -- 0.9.1 could save the last name as the realm: drop it.
    if record.realm and type(second) == "string" and record.realm == second then record.realm = nil end
    Keep(record, "realm", ReadRealm())
    local className, classFile = UnitClass("player")
    Keep(record, "class", className)
    Keep(record, "classFile", classFile)
    Keep(record, "faction", UnitFactionGroup("player"))
    Keep(record, "level", UnitLevel("player"))
    Keep(record, "money", GetMoney())
    Keep(record, "zone", GetRealZoneText())

    Keep(record, "xp", UnitXP("player"))
    Keep(record, "xpMax", UnitXPMax("player"))
    -- nil from the game means "not rested", which is an answer too.
    local rested = GetXPExhaustion()
    if rested == nil or Usable(rested) then
        record.rested = rested or 0
    end
    local resting = IsResting()
    if Usable(resting) then
        record.resting = resting and true or false
    end

    local professions = ReadProfessions()
    if professions then record.professions = professions end
    local free, total = ReadBags()
    -- Every character has a backpack, so no bag space at all means the
    -- bags are not loaded yet (just after logging in), not an empty answer.
    if free and total > 0 then
        record.bagFree, record.bagTotal = free, total
    end

    record.seen = time()
    return record
end

---------------------------------------------------------------------------
-- Reading the records back
---------------------------------------------------------------------------

-- Rested experience as a fraction of a level: what was recorded, and for a
-- character who is not being played, what it has probably grown to since.
-- The second value says whether the figure is such an estimate.
function ns.Rested(record, isCurrent)
    if not record.xpMax or record.xpMax <= 0 then return 0, false end
    local fraction = (record.rested or 0) / record.xpMax
    if isCurrent or not record.seen then return fraction, false end
    local rate = RESTED_PER_SECOND * (record.resting and 1 or RESTED_OUTDOORS)
    local grown = fraction + math.max(0, time() - record.seen) * rate
    return math.min(RESTED_CAP_LEVELS, grown), true
end

local SORTS = {
    faction = function(record) return record.faction or "" end,
    name = function(record) return ns.DisplayName(record):lower() end,
    level = function(record) return record.level or 0 end,
    money = function(record) return record.money or 0 end,
    zone = function(record) return (record.zone or ""):lower() end,
    rested = function(record) return (ns.Rested(record, record.isCurrent)) end,
    bags = function(record) return record.bagFree or -1 end,
    seen = function(record) return record.seen or 0 end,
}
ns.SORTS = SORTS

-- Every character on record, sorted as the settings say, with the total
-- money across them. Each entry is the saved record plus its key and
-- whether it is the character being played.
function ns.Characters()
    local current = ns.CurrentKey()
    local list, total = {}, 0
    for key, record in pairs(ns.db.chars) do
        local entry = setmetatable({ key = key, isCurrent = key == current }, { __index = record })
        list[#list + 1] = entry
        total = total + (record.money or 0)
    end
    local value = SORTS[ns.db.sortBy] or SORTS.level
    local descending = ns.db.sortDescending
    local byFaction = ns.db.sortBy == "faction"
    table.sort(list, function(a, b)
        local va, vb = value(a), value(b)
        if va ~= vb then
            if descending then return va > vb end
            return va < vb
        end
        -- Within a faction: highest level first, whichever faction leads.
        if byFaction and (a.level or 0) ~= (b.level or 0) then
            return (a.level or 0) > (b.level or 0)
        end
        -- Same in the sorted column: by name, so the order is steady.
        return ns.DisplayName(a) < ns.DisplayName(b)
    end)
    return list, total
end

-- Removes a character's record. Returns their name if there was one.
function ns.Forget(key)
    local record = ns.db.chars[key]
    if not record then return end
    ns.db.chars[key] = nil
    return ns.DisplayName(record)
end

-- Finds a record by the start of its name, ignoring case.
local function FindByName(text)
    text = text:lower()
    local found
    for key, record in pairs(ns.db.chars) do
        -- By the start of the first name, or of the full name ("shanbizz g").
        local full = ns.DisplayName(record):lower()
        if (record.name and record.name:lower():sub(1, #text) == text and not text:find(" ", 1, true))
                or full:sub(1, #text) == text then
            if found then return nil, "more than one character's name starts with that" end
            found = key
        end
    end
    return found, "no character on record has a name starting with that"
end

SLASH_ALTGLANCE1 = "/altglance"
SLASH_ALTGLANCE2 = "/alts"
SlashCmdList.ALTGLANCE = function(msg)
    local command, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        ns.ToggleWindow()
    elseif command == "button" then
        ns.db.minimapButton = not ns.db.minimapButton
        ns.UpdateMinimapButton()
        ns.Print("Minimap button " .. (ns.db.minimapButton and "shown." or "hidden."))
    elseif command == "find" then
        ns.PrintFind(rest)
    elseif command == "prof" or command == "plan" or command == "professions" then
        if rest:lower() == "debug" then ns.PlannerDebug() else ns.TogglePlanner() end
    elseif command == "bank" then
        if rest == "" then
            local _, record = ns.BankAlt()
            ns.Print(record and (ns.DisplayName(record) .. " is your bank alt here. /alts bank off to clear it.")
                or "No bank alt for this realm and faction. /alts bank <name> to choose one.")
        elseif rest:lower() == "off" then
            local key = ns.BankAlt()
            if key then ns.ToggleBankAlt(key) else ns.Print("There is no bank alt to clear.") end
        else
            local key, problem = FindByName(rest)
            if not key then
                ns.Print("No bank alt set: " .. problem .. ".")
            elseif key == ns.CurrentKey() then
                ns.Print("That is the character you are playing; choose the one you send things to.")
            elseif key == ns.BankAlt() then
                ns.Print(ns.DisplayName(ns.db.chars[key]) .. " is already your bank alt.")
            else
                local mine, theirs = ns.db.chars[ns.CurrentKey() or ""], ns.db.chars[key]
                if mine and (not ns.SameRealm(ns.CurrentKey(), mine, key, theirs) or mine.faction ~= theirs.faction) then
                    ns.Print(ns.DisplayName(theirs) .. " is on another realm or faction, so they cannot be mailed from here.")
                elseif not theirs.fullName then
                    ns.Print(theirs.name .. "'s full name is not known yet: log in to them once, then choose them again.")
                else
                    ns.ToggleBankAlt(key)
                end
            end
        end
    elseif command == "options" or command == "settings" or command == "config" then
        ns.ToggleOptions()
    elseif command == "tooltip" then
        ns.db.itemTooltip = not ns.db.itemTooltip
        ns.Print("Item tooltips " .. (ns.db.itemTooltip and "show" or "no longer show") .. " how many of the item each character has.")
    elseif command == "forget" and rest ~= "" then
        local key, problem = FindByName(rest)
        if not key then
            ns.Print("Nothing removed: " .. problem .. ".")
        elseif key == ns.CurrentKey() then
            ns.Print("That is the character you are playing; their record would only come straight back.")
        else
            ns.Print(("Removed %s from the list."):format(ns.Forget(key)))
            ns.RefreshWindow()
        end
    else
        ns.Print("/alts - open the list of your characters")
        ns.Print("/alts find <item> - which of your characters has an item, in bags or bank")
        ns.Print("/alts prof - the profession planner: what you can make, and who holds the materials")
        ns.Print("/alts options - the Options window")
        ns.Print("/alts tooltip - item tooltips showing each character's count, on or off")
        ns.Print("/alts bank <name> - your bank alt, whose name the mailbox fills in (/alts bank off to clear)")
        ns.Print("/alts forget <name> - remove a character you no longer have")
        ns.Print("/alts button - show or hide the minimap button")
    end
end

-- Entry in the minimap's addon list.
function AltGlance_OnAddonCompartmentClick()
    ns.ToggleWindow()
end

-- What changes a character's record while they are played. Not
-- PLAYER_LOGOUT: by then Forever has cleared money, experience, bags and
-- professions to 0, and a last read overwrote every character's real
-- figures with zeros (found 2026-11-08).
local REFRESH_EVENTS = {
    "PLAYER_MONEY", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION",
    "PLAYER_UPDATE_RESTING", "ZONE_CHANGED_NEW_AREA", "SKILL_LINES_CHANGED",
    "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD",
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loaded)
    if event == "ADDON_LOADED" then
        if loaded ~= addonName then return end
        AltGlanceDB = AltGlanceDB or {}
        for key, value in pairs(defaults) do
            if AltGlanceDB[key] == nil then
                AltGlanceDB[key] = value
            end
        end
        AltGlanceDB.chars = AltGlanceDB.chars or {}
        AltGlanceDB.itemLinks = AltGlanceDB.itemLinks or {}
        ns.db = AltGlanceDB
        self:UnregisterEvent("ADDON_LOADED")
        return
    end
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then
        -- Registering an event this client does not have throws.
        for _, name in ipairs(REFRESH_EVENTS) do
            pcall(self.RegisterEvent, self, name)
        end
        ns.UpdateMinimapButton()
        -- Some figures arrive a moment after logging in: read again then.
        if C_Timer and C_Timer.After then
            C_Timer.After(5, function()
                if pcall(ns.Snapshot) then ns.RefreshWindow() end
            end)
        end
    end
    -- Reading the character must never put an error on screen.
    if pcall(ns.Snapshot) then
        ns.RefreshWindow()
    end
end)
