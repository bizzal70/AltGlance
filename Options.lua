local addonName, ns = ...

-- The Options window: AltGlance's settings in one place. Each row can be
-- clicked or tapped, or reached with the controller's D-pad and pressed
-- with A. Opened with the Options button in the list, or /alts options.

local ACCENT_R, ACCENT_G, ACCENT_B = 0.85, 0.63, 0.40
local WIDTH, PAD, HEADER, ROW_HEIGHT, ROW_GAP = 400, 14, 38, 30, 4

local window, bankLine, padHint
local rows = {}
local chosen = 1   -- the row the controller's D-pad is on

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
    local text = parent:CreateFontString(nil, "OVERLAY", ns.Font(font))
    text:SetJustifyH(justify or "LEFT")
    return text
end

-- Every AltGlance window back in the middle of the screen (handy if one was
-- dragged off a small screen).
function ns.ResetWindowPositions()
    ns.db.windowPosition = nil
    for _, name in ipairs({ "AltGlanceWindow", "AltGlancePlanner", "AltGlanceOptions" }) do
        local frame = _G[name]
        if frame and frame.ClearAllPoints then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER")
        end
    end
end

-- The rows: a setting that turns on and off (get, toggle), or a button that
-- does something (action).
local ROWS = {
    { text = "Show the minimap button",
      get = function() return ns.db.minimapButton end,
      toggle = function()
          ns.db.minimapButton = not ns.db.minimapButton
          ns.UpdateMinimapButton()
      end },
    { text = "Item tooltips show each character's count",
      get = function() return ns.db.itemTooltip end,
      toggle = function() ns.db.itemTooltip = not ns.db.itemTooltip end },
    { text = "Say how old bank counts are in tooltips",
      get = function() return ns.db.bankAge ~= false end,
      toggle = function() ns.db.bankAge = not (ns.db.bankAge ~= false) end },
    { text = "Put the AltGlance windows back in the middle",
      action = function()
          ns.ResetWindowPositions()
          ns.Print("The AltGlance windows are back in the middle of the screen.")
      end },
}
ns.OPTION_ROWS = ROWS

local function Refresh()
    if not window then return end
    local gamepad = ns.GamepadMode and ns.GamepadMode() or false
    for index, row in ipairs(rows) do
        local option = ROWS[index]
        if option.get then row.tick:SetShown(option.get() and true or false) end
        row.chosen:SetShown(gamepad and index == chosen)
    end
    local record
    if ns.BankAlt then record = select(2, ns.BankAlt()) end
    bankLine:SetText(record and ("Bank alt here: %s. Tick another character's box in the list to change it."):format(ns.DisplayName(record))
        or "No bank alt for this realm and faction: tick a character's Bank alt box in the list.")
    padHint:SetShown(gamepad)
end
ns.RefreshOptions = Refresh

-- Presses a row: turns its setting on or off, or does its job.
local function Press(index)
    local option = ROWS[index]
    if not option then return end
    chosen = index
    if option.toggle then option.toggle() else option.action() end
    Refresh()
    if ns.RefreshWindow then ns.RefreshWindow() end
end
ns.PressOption = Press

local function CreateRow(index, y)
    local option = ROWS[index]
    local row = CreateFrame("Button", nil, window)
    row:SetSize(WIDTH - PAD * 2, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PAD, y)
    Fill(row, 1, 1, 1, 0.04)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.08)
    -- Where the controller's D-pad is.
    row.chosen = Fill(row, ACCENT_R, ACCENT_G, ACCENT_B, 0.22, "BORDER")
    row.chosen:Hide()
    local label = Label(row, "GameFontHighlight", option.action and "CENTER" or "LEFT")
    if option.action then
        Outline(row, 0.45)
        label:SetPoint("CENTER")
    else
        local box = CreateFrame("Frame", nil, row)
        box:SetSize(16, 16)
        box:SetPoint("LEFT", 8, 0)
        Fill(box, 0, 0, 0, 0.5)
        Outline(box, 0.7)
        row.tick = box:CreateTexture(nil, "ARTWORK")
        row.tick:SetPoint("TOPLEFT", 3, -3)
        row.tick:SetPoint("BOTTOMRIGHT", -3, 3)
        row.tick:SetColorTexture(0.4, 0.9, 0.4, 1)
        label:SetPoint("LEFT", box, "RIGHT", 10, 0)
        label:SetPoint("RIGHT", -8, 0)
    end
    label:SetText(option.text)
    row:SetScript("OnClick", function() Press(index) end)
    rows[index] = row
end

local function CreateWindow()
    window = CreateFrame("Frame", addonName .. "Options", UIParent)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:Hide()
    Fill(window, 0.05, 0.05, 0.06, 0.97)
    Outline(window, 0.55)
    tinsert(UISpecialFrames, addonName .. "Options")
    ns.CloseWithPadB(window)
    -- While it is open the controller's D-pad moves between the rows and A
    -- presses one (ahead of the other AltGlance windows).
    ns.PadKey(window, "PADDUP", function() chosen = math.max(1, chosen - 1); Refresh() end, 3)
    ns.PadKey(window, "PADDDOWN", function() chosen = math.min(#ROWS, chosen + 1); Refresh() end, 3)
    ns.PadKey(window, "PAD1", function() Press(chosen) end, 3)

    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    Fill(header, 0.16, 0.12, 0.08, 1)
    local title = Label(header, "GameFontNormalLarge")
    title:SetPoint("LEFT", PAD, 0)
    title:SetText("AltGlance  -  Options")
    title:SetTextColor(1, 0.9, 0.75)
    local close = CreateFrame("Button", nil, header)
    close:SetSize(HEADER - 6, HEADER - 6)
    close:SetPoint("RIGHT", -3, 0)
    local closeHover = close:CreateTexture(nil, "HIGHLIGHT")
    closeHover:SetAllPoints()
    closeHover:SetColorTexture(0.9, 0.2, 0.2, 0.45)
    local closeLabel = Label(close, "GameFontHighlightLarge", "CENTER")
    closeLabel:SetPoint("CENTER")
    closeLabel:SetText("x")
    close:SetScript("OnClick", function() window:Hide() end)

    local y = -(HEADER + PAD)
    for index = 1, #ROWS do
        CreateRow(index, y)
        y = y - ROW_HEIGHT - ROW_GAP
    end
    y = y - 6
    bankLine = Label(window, "GameFontHighlightSmall")
    bankLine:SetPoint("TOPLEFT", PAD, y)
    bankLine:SetWidth(WIDTH - PAD * 2)
    bankLine:SetWordWrap(true)
    y = y - 30
    local more = Label(window, "GameFontDisableSmall")
    more:SetPoint("TOPLEFT", PAD, y)
    more:SetWidth(WIDTH - PAD * 2)
    more:SetWordWrap(true)
    more:SetText("What Send materials mails is chosen on its panel at the mailbox.")
    y = y - 18
    padHint = Label(window, "GameFontDisableSmall")
    padHint:SetPoint("TOPLEFT", PAD, y)
    padHint:SetText("Controller: D-pad up/down picks a row, A changes it, B closes.")
    y = y - 18 - PAD
    window:SetSize(WIDTH, -y)
end

function ns.ToggleOptions()
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        Refresh()
        window:Show()
        ns.FitWindow(window)
    end
end
