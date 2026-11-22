local addonName, ns = ...

-- The list of characters: one row each, columns that sort when their
-- heading is clicked, a total at the bottom. Drawn from plain colours and
-- lines, so it needs no texture files.

local ACCENT_R, ACCENT_G, ACCENT_B = 0.85, 0.63, 0.40
local HEADER_HEIGHT, HEADING_HEIGHT, FOOTER_HEIGHT = 38, 24, 34
local ROW_HEIGHT, VISIBLE_ROWS = 24, 14
local PADDING = 12

-- Columns, left to right. A column with a sort key sorts when clicked.
local COLUMNS = {
    { key = "faction", label = "Faction", width = 44, sort = "faction", justify = "CENTER" },
    { key = "name", label = "Character", width = 150, sort = "name" },
    { key = "bank", label = "Bank alt", width = 52, justify = "CENTER" },
    { key = "level", label = "Level", width = 44, sort = "level", justify = "RIGHT" },
    { key = "money", label = "Gold", width = 112, sort = "money", justify = "RIGHT" },
    { key = "zone", label = "Last seen in", width = 150, sort = "zone" },
    { key = "rested", label = "Rested", width = 62, sort = "rested", justify = "RIGHT" },
    { key = "professions", label = "Professions", width = 200 },
    { key = "bags", label = "Bags free", width = 64, sort = "bags", justify = "RIGHT" },
    { key = "seen", label = "Played", width = 80, sort = "seen", justify = "RIGHT" },
}
local COLUMN_GAP = 10
local REMOVE_WIDTH = 22

local WIDTH = PADDING * 2 + REMOVE_WIDTH
for _, column in ipairs(COLUMNS) do
    WIDTH = WIDTH + column.width + COLUMN_GAP
end
local HEIGHT = HEADER_HEIGHT + HEADING_HEIGHT + ROW_HEIGHT * VISIBLE_ROWS + FOOTER_HEIGHT + 8

local window, footerLabel, emptyLabel
local rows, headings = {}, {}
local offset = 0
local list = {}
-- The character whose remove button was pressed once, and when.
local armedKey, armedAt

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

-- Money with the game's coin icons where it offers them, otherwise as text.
local function MoneyText(copper)
    local coins = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
    if coins then
        local ok, text = pcall(coins, copper)
        if ok and ns.Usable(text) then return text end
    end
    return ns.Money(copper)
end

local function ClassColor(classFile)
    if classFile then
        local color = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classFile)
            or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
        if color and color.r then
            return color.r, color.g, color.b
        end
    end
    return 1, 1, 1
end

-- Each faction's crest (the game's own small icons) and colour: a red tint
-- for the Horde and a blue one for the Alliance, behind the whole row.
local FACTIONS = {
    Horde = { icon = "Interface\\FriendsFrame\\PlusManz-Horde", r = 0.75, g = 0.12, b = 0.10 },
    Alliance = { icon = "Interface\\FriendsFrame\\PlusManz-Alliance", r = 0.15, g = 0.35, b = 0.85 },
}
ns.FACTIONS = FACTIONS
local ICON_SIZE = 16

local function ProfessionText(record)
    local parts = {}
    for _, profession in ipairs(record.professions or {}) do
        parts[#parts + 1] = ("%s %d"):format(profession.name, profession.level)
    end
    return table.concat(parts, ", ")
end

-- "+45%" of a level, with "~" in front when it is an estimate.
local function RestedText(record)
    local fraction, estimated = ns.Rested(record, record.isCurrent)
    if fraction <= 0.005 then return "" end
    return ("%s+%d%%"):format(estimated and "~" or "", fraction * 100 + 0.5)
end

local CELLS = {
    -- The faction column shows the crest (row.faction), no text.
    faction = function() return "" end,
    -- The Bank alt column shows a tick box (row.bank), no text.
    bank = function() return "" end,
    name = function(record) return ns.DisplayName(record) end,
    level = function(record) return record.level and tostring(record.level) or "" end,
    money = function(record) return record.money and MoneyText(record.money) or "" end,
    zone = function(record) return record.zone or "" end,
    rested = RestedText,
    professions = ProfessionText,
    bags = function(record)
        return record.bagFree and ("%d / %d"):format(record.bagFree, record.bagTotal or 0) or ""
    end,
    seen = function(record)
        if record.isCurrent then return "now" end
        return record.seen and ns.Ago(record.seen) or ""
    end,
}

local function RowOnEnter(row)
    local record = row.record
    if not record then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local r, g, b = ClassColor(record.classFile)
    GameTooltip:AddLine(ns.DisplayName(record), r, g, b)
    local who = {}
    if record.level then who[#who + 1] = "Level " .. record.level end
    if record.class then who[#who + 1] = record.class end
    if #who > 0 then GameTooltip:AddLine(table.concat(who, " "), 1, 1, 1) end
    local faction = FACTIONS[record.faction or ""]
    if faction then
        GameTooltip:AddLine(("|T%s:0|t %s"):format(faction.icon, record.faction),
            math.min(1, faction.r + 0.25), math.min(1, faction.g + 0.25), math.min(1, faction.b + 0.25))
    elseif record.faction then
        GameTooltip:AddLine(record.faction, 0.7, 0.7, 0.7)
    end
    if record.realm and record.realm ~= "" then GameTooltip:AddLine(record.realm, 0.7, 0.7, 0.7) end
    if record.money then
        GameTooltip:AddLine(MoneyText(record.money), 1, 1, 1)
    end
    if record.xp and record.xpMax and record.xpMax > 0 then
        GameTooltip:AddLine(("%d%% of the way through the level"):format(record.xp / record.xpMax * 100), 1, 1, 1)
    end
    local fraction, estimated = ns.Rested(record, record.isCurrent)
    if fraction > 0.005 then
        GameTooltip:AddLine(("Rested: %d%% of a level%s"):format(fraction * 100 + 0.5,
            estimated and " (estimated from time away)" or ""), 0.6, 0.8, 1)
    end
    for _, profession in ipairs(record.professions or {}) do
        GameTooltip:AddLine(profession.max and ("%s %d / %d"):format(profession.name, profession.level, profession.max)
            or ("%s %d"):format(profession.name, profession.level), 1, 0.82, 0)
    end
    if record.seen and not record.isCurrent then
        GameTooltip:AddLine(("Last played %s, on %s"):format(ns.Ago(record.seen), date("%Y-%m-%d", record.seen)), 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, window)
    row:SetSize(WIDTH - PADDING * 2, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + HEADING_HEIGHT + (index - 1) * ROW_HEIGHT))
    if index % 2 == 0 then
        Fill(row, 1, 1, 1, 0.03)
    end
    -- The faction's colour, faintly, behind the row.
    row.tint = Fill(row, 1, 1, 1, 0, "BORDER")
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.07)
    -- Marks the character being played.
    row.stripe = row:CreateTexture(nil, "ARTWORK")
    row.stripe:SetPoint("TOPLEFT")
    row.stripe:SetPoint("BOTTOMLEFT")
    row.stripe:SetWidth(3)
    row.stripe:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)

    -- The faction's crest, centred in the Faction column.
    row.faction = row:CreateTexture(nil, "ARTWORK")
    row.faction:SetSize(ICON_SIZE, ICON_SIZE)
    row.faction:SetPoint("LEFT", 8 + (COLUMNS[1].width - ICON_SIZE) / 2, 0)

    row.cells = {}
    local x = 8
    for _, column in ipairs(COLUMNS) do
        local cell = Label(row, "GameFontHighlightSmall", column.justify)
        cell:SetPoint("LEFT", x, 0)
        cell:SetWidth(column.width)
        row.cells[column.key] = cell
        if column.key == "bank" then
            -- A tick box: ticked for this realm and faction's bank alt.
            local box = CreateFrame("Button", nil, row)
            box:SetSize(18, 18)
            box:SetPoint("LEFT", x + (column.width - 18) / 2, 0)
            Fill(box, ACCENT_R, ACCENT_G, ACCENT_B, 0.7)
            local inside = box:CreateTexture(nil, "BORDER")
            inside:SetPoint("TOPLEFT", 1, -1)
            inside:SetPoint("BOTTOMRIGHT", -1, 1)
            inside:SetColorTexture(0.08, 0.08, 0.09, 1)
            box.tick = box:CreateTexture(nil, "ARTWORK")
            box.tick:SetPoint("TOPLEFT", 4, -4)
            box.tick:SetPoint("BOTTOMRIGHT", -4, 4)
            box.tick:SetColorTexture(0.4, 0.9, 0.4, 1)
            local glow = box:CreateTexture(nil, "HIGHLIGHT")
            glow:SetAllPoints()
            glow:SetColorTexture(1, 1, 1, 0.15)
            box:SetScript("OnClick", function(self)
                local record = row.record
                if record then ns.ToggleBankAlt(record.key) end
            end)
            box:SetScript("OnEnter", function(self)
                local record = row.record
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Bank alt", 1, 1, 1)
                GameTooltip:AddLine(("The character whose name the mailbox fills in, for %s on this realm. Click to %s."):format(
                    record and record.faction or "their faction",
                    record and ns.IsBankAlt(record.key) and "clear it" or "make " .. (record and ns.DisplayName(record) or "them") .. " the bank alt"),
                    0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            box:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.bank = box
        end
        x = x + column.width + COLUMN_GAP
    end

    -- Removing takes two presses, so a slip does not lose a record.
    local remove = CreateFrame("Button", nil, row)
    remove:SetSize(REMOVE_WIDTH - 4, ROW_HEIGHT - 6)
    remove:SetPoint("RIGHT", -2, 0)
    local removeHover = remove:CreateTexture(nil, "HIGHLIGHT")
    removeHover:SetAllPoints()
    removeHover:SetColorTexture(0.9, 0.2, 0.2, 0.45)
    local removeLabel = Label(remove, "GameFontDisableSmall", "CENTER")
    removeLabel:SetPoint("CENTER")
    removeLabel:SetText("x")
    remove:SetScript("OnClick", function()
        local record = row.record
        if not record then return end
        if armedKey == record.key and GetTime() - armedAt < 6 then
            armedKey = nil
            ns.Print(("Removed %s from the list."):format(ns.Forget(record.key)))
            ns.RefreshWindow()
        else
            armedKey, armedAt = record.key, GetTime()
            ns.Print(("Press the x again to remove %s from the list."):format(ns.DisplayName(record)))
        end
    end)
    remove:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Remove from the list", 1, 1, 1)
        GameTooltip:AddLine("For a character you no longer have. Press twice.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    remove:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.remove = remove

    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
    return row
end

local function Refresh()
    local total
    list, total = ns.Characters()
    offset = math.min(offset, math.max(0, #list - VISIBLE_ROWS))

    for index = 1, VISIBLE_ROWS do
        local record = list[index + offset]
        local row = rows[index]
        if record then
            row = row or CreateRow(index)
            row.record = record
            for _, column in ipairs(COLUMNS) do
                row.cells[column.key]:SetText(CELLS[column.key](record))
            end
            row.cells.name:SetTextColor(ClassColor(record.classFile))
            local faction = FACTIONS[record.faction or ""]
            if faction then
                row.faction:SetTexture(faction.icon)
                row.faction:Show()
                row.tint:SetColorTexture(faction.r, faction.g, faction.b, 0.16)
            else
                row.faction:Hide()
                row.tint:SetColorTexture(1, 1, 1, 0)
            end
            row.stripe:SetShown(record.isCurrent)
            row.bank.tick:SetShown(ns.IsBankAlt and ns.IsBankAlt(record.key) or false)
            -- The character being played cannot be removed; it would only
            -- be recorded again straight away.
            row.remove:SetShown(not record.isCurrent)
            row:Show()
        elseif row then
            row:Hide()
        end
    end

    -- An arrow on the heading the list is sorted by.
    for _, heading in ipairs(headings) do
        local column = heading.column
        local arrow = ""
        if column.sort and column.sort == ns.db.sortBy then
            arrow = ns.db.sortDescending and " v" or " ^"
        end
        heading.label:SetText(column.label .. arrow)
    end

    emptyLabel:SetShown(#list == 0)
    -- Gold cannot cross between the factions, so each one's total is shown
    -- as well, behind its crest.
    local count, gold = {}, {}
    for _, record in ipairs(list) do
        local key = FACTIONS[record.faction or ""] and record.faction or nil
        if key then
            count[key] = (count[key] or 0) + 1
            gold[key] = (gold[key] or 0) + (record.money or 0)
        end
    end
    local text = ("%d character%s      Total: %s"):format(#list, #list == 1 and "" or "s", MoneyText(total))
    for _, key in ipairs({ "Horde", "Alliance" }) do
        if count[key] then
            text = text .. ("      |T%s:0|t %s %d: %s"):format(FACTIONS[key].icon, key, count[key], MoneyText(gold[key]))
        end
    end
    footerLabel:SetText(text)
end

local function SortBy(key)
    if ns.db.sortBy == key then
        ns.db.sortDescending = not ns.db.sortDescending
    else
        -- Names, zones and factions read best A to Z; numbers, biggest first.
        ns.db.sortBy = key
        ns.db.sortDescending = not (key == "name" or key == "zone" or key == "faction")
    end
    offset = 0
    Refresh()
end

local function CreateWindow()
    window = CreateFrame("Frame", addonName .. "Window", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    local position = ns.db.windowPosition
    if position then
        window:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    else
        window:SetPoint("CENTER")
    end
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:Hide()
    Fill(window, 0.05, 0.05, 0.06, 0.97)
    Outline(window, 0.55)
    -- Lets Escape close the window.
    tinsert(UISpecialFrames, addonName .. "Window")

    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_HEIGHT)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        local point, _, relativePoint, x, y = window:GetPoint()
        ns.db.windowPosition = { point, relativePoint, x, y }
    end)
    Fill(header, 0.16, 0.12, 0.08, 1)
    local title = Label(header, "GameFontNormalLarge")
    title:SetPoint("LEFT", PADDING, 0)
    title:SetText("AltGlance")
    title:SetTextColor(1, 0.9, 0.75)

    local close = CreateFrame("Button", nil, header)
    close:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    close:SetPoint("RIGHT")
    local closeHover = close:CreateTexture(nil, "HIGHLIGHT")
    closeHover:SetAllPoints()
    closeHover:SetColorTexture(0.9, 0.2, 0.2, 0.45)
    -- The cross is two drawn strokes, so it needs no font glyph or texture.
    for _, direction in ipairs({ 1, -1 }) do
        local stroke = close:CreateLine(nil, "ARTWORK")
        stroke:SetThickness(2)
        stroke:SetColorTexture(0.9, 0.9, 0.9, 1)
        stroke:SetStartPoint("CENTER", close, -6, 6 * direction)
        stroke:SetEndPoint("CENTER", close, 6, -6 * direction)
    end
    close:SetScript("OnClick", function() window:Hide() end)

    -- Opens the profession planner.
    local planner = CreateFrame("Button", nil, header)
    planner:SetSize(110, HEADER_HEIGHT - 12)
    planner:SetPoint("RIGHT", close, "LEFT", -8, 0)
    Fill(planner, 0.30, 0.22, 0.12, 1)
    Outline(planner, 0.6)
    local plannerHover = planner:CreateTexture(nil, "HIGHLIGHT")
    plannerHover:SetAllPoints()
    plannerHover:SetColorTexture(1, 1, 1, 0.12)
    local plannerLabel = Label(planner, "GameFontHighlight", "CENTER")
    plannerLabel:SetPoint("CENTER")
    plannerLabel:SetText("Professions")
    planner:SetScript("OnClick", function() ns.TogglePlanner() end)
    window.plannerButton = planner

    -- Column headings; the sortable ones are buttons.
    local x = PADDING + 8
    for _, column in ipairs(COLUMNS) do
        local heading = CreateFrame(column.sort and "Button" or "Frame", nil, window)
        heading:SetSize(column.width, HEADING_HEIGHT)
        heading:SetPoint("TOPLEFT", x, -HEADER_HEIGHT)
        heading.column = column
        heading.label = Label(heading, "GameFontDisableSmall", column.justify)
        heading.label:SetAllPoints()
        heading.label:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
        if column.sort then
            local hover = heading:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(1, 1, 1, 0.08)
            heading:SetScript("OnClick", function() SortBy(column.sort) end)
        end
        headings[#headings + 1] = heading
        x = x + column.width + COLUMN_GAP
    end

    emptyLabel = window:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("CENTER")
    emptyLabel:SetText("No characters recorded yet.")

    local footer = CreateFrame("Frame", nil, window)
    footer:SetPoint("BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(FOOTER_HEIGHT)
    Fill(footer, 0, 0, 0, 0.35)
    footerLabel = Label(footer, "GameFontHighlight")
    footerLabel:SetPoint("LEFT", PADDING, 0)
    local hint = Label(footer, "GameFontDisableSmall", "RIGHT")
    hint:SetPoint("RIGHT", -PADDING, 0)
    hint:SetText("Click a heading to sort.")

    window:EnableMouseWheel(true)
    window:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta)
        Refresh()
    end)
end

function ns.ToggleWindow()
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        ns.Snapshot()
        Refresh()
        window:Show()
    end
end

-- Called when a record changes.
function ns.RefreshWindow()
    if window and window:IsShown() then
        Refresh()
    end
end
