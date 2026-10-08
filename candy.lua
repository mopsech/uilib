--[[
    Nexus UI Library
    Reworked / rebranded. Not affiliated with NeverLose.
    Style: dark slate, purple accent, compact geometry.
]]

do
    local G = getfenv()
    G.NEXUS_PROTECT = G.NEXUS_PROTECT or function(f) return f end
end

-- === Environment shims ===
cloneref       = cloneref       or function(i) return i end
gethui         = gethui         or get_hidden_gui
getcustomasset = getcustomasset or getsynasset
getgenv        = getgenv        or getfenv

-- === Studio file shim ===
local function installStudioFS()
    if not game:GetService('RunService'):IsStudio() then return end

    local host = game:GetService('ReplicatedFirst'):FindFirstChild('NX_HOST')
        or Instance.new('Folder', game:GetService('ReplicatedFirst'))
    host.Name = 'NX_HOST\0' .. tostring(math.random(10000, 99999))

    local function split(p)
        if string.find(p, '/', 1, true) then return string.split(p, '/') end
        if string.find(p, '\\', 1, true) then return string.split(p, '\\') end
        return {p}
    end

    local function resolve(p)
        local node = host
        for _, part in ipairs(split(p)) do
            node = node[part]
        end
        return node
    end

    getgenv().readfile = function(p)
        return resolve(p).Value
    end
    getgenv().isfile = function(p)
        local ok, node = pcall(resolve, p)
        return ok and not node:IsA('Folder')
    end
    getgenv().isfolder = function(p)
        local ok, node = pcall(resolve, p)
        return ok and node:IsA('Folder')
    end
    getgenv().writefile = function(p, content)
        local parts = split(p)
        local node = host
        for i, name in ipairs(parts) do
            local child = node:FindFirstChild(name)
            if not child then
                child = Instance.new('StringValue', node)
                child.Name = tostring(name)
                child.Value = content
            elseif i == #parts and child:IsA('StringValue') then
                child.Value = content
            end
            node = child
        end
    end
    getgenv().listfiles = function(p)
        local out = {}
        for _, c in ipairs(resolve(p):GetChildren()) do
            if c:IsA('StringValue') then
                table.insert(out, p .. '/' .. c.Name)
            end
        end
        return out
    end
    getgenv().makefolder = function(p)
        local node = host
        for _, name in ipairs(split(p)) do
            local child = node:FindFirstChild(name)
            if not child then
                child = Instance.new('Folder', node)
                child.Name = tostring(name)
            end
            node = child
        end
    end
    getgenv().delfile = function(p)
        local ok, node = pcall(resolve, p)
        if ok and node:IsA('StringValue') then node:Destroy() end
    end
end

installStudioFS()

writefile    = writefile    or getgenv().writefile
makefolder   = makefolder   or getgenv().makefolder
readfile     = readfile     or getgenv().readfile
delfile      = delfile      or getgenv().delfile
listfiles    = listfiles    or getgenv().listfiles
isfolder     = isfolder     or getgenv().isfolder
isfile       = isfile       or getgenv().isfile

-- === Services ===
local TweenService  = cloneref(game:GetService('TweenService'))
local UIS           = cloneref(game:GetService('UserInputService'))
local TextService   = cloneref(game:GetService('TextService'))
local RunService    = cloneref(game:GetService('RunService'))
local GuiService    = cloneref(game:GetService('GuiService'))
local Players       = cloneref(game:GetService('Players'))
local HttpService   = cloneref(game:GetService('HttpService'))
local LP            = Players.LocalPlayer
local CoreGui       = (gethui and gethui())
                   or cloneref(game:FindFirstChild('CoreGui'))
                   or cloneref(LP.PlayerGui)
local Mouse         = LP:GetMouse()
local protect_gui   = protect_gui or protectgui or (syn and syn.protect_gui) or function(s) return s end

-- === Nexus root ===
local Nexus = {}
Nexus.Connections = {}
Nexus.Flags       = {}
Nexus.Screen      = Instance.new('ScreenGui')

local DEFAULT_ACCENT = Color3.fromRGB(160, 110, 255)
Nexus.Palette = {
    Base      = Color3.fromRGB(14, 16, 24),
    Surface   = Color3.fromRGB(22, 24, 34),
    Surface2  = Color3.fromRGB(30, 33, 46),
    Stroke    = Color3.fromRGB(48, 52, 68),
    Text      = Color3.fromRGB(232, 234, 242),
    Muted     = Color3.fromRGB(140, 146, 162),
    Accent    = DEFAULT_ACCENT,
    Good      = Color3.fromRGB(120, 220, 160),
    Bad       = Color3.fromRGB(230, 90, 110),
}

Nexus.Tween = {
    Fast  = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Med   = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Slow  = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
}

Nexus.Icons = {
    Regular = Font.new('rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json',
        Enum.FontWeight.Regular, Enum.FontStyle.Normal),
    Bold    = Font.new('rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json',
        Enum.FontWeight.Bold, Enum.FontStyle.Normal),
}

protect_gui(Nexus.Screen)
Nexus.Screen.Name         = 'NexusUI_' .. tostring(math.random(1e6, 9e6))
Nexus.Screen.IgnoreGuiInset = true
Nexus.Screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
Nexus.Screen.ResetOnSpawn = false
Nexus.Screen.DisplayOrder = 5000
Nexus.Screen.Parent       = CoreGui

-- === Utilities ===
local function tweens(obj, info, props)
    if not obj or not obj.Parent then return end
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end
local function track(conn)
    table.insert(Nexus.Connections, conn)
    return conn
end
local function hoverFrame(frame)
    local p, s = frame.AbsolutePosition, frame.AbsoluteSize
    return Mouse.X >= p.X and Mouse.X <= p.X + s.X
       and Mouse.Y >= p.Y and Mouse.Y <= p.Y + s.Y
end
local function round(n, d)
    d = d or 0
    local m = 10 ^ d
    return math.floor(n * m + 0.5) / m
end

Nexus.hoverFrame = hoverFrame
Nexus.round      = round
Nexus.tweens     = tweens
Nexus.track      = track

-- === Accent system ===
local AccentBindings = setmetatable({}, {__mode = 'k'})

function Nexus:bindAccent(inst, prop)
    prop = prop or 'BackgroundColor3'
    if not AccentBindings[inst] then AccentBindings[inst] = {} end
    AccentBindings[inst][prop] = true
    pcall(function() inst[prop] = Nexus.Palette.Accent end)
    return inst
end

function Nexus:pushAccent(color)
    Nexus.Palette.Accent = color
    for inst, props in pairs(AccentBindings) do
        if typeof(inst) == 'Instance' and inst.Parent then
            for prop in pairs(props) do
                pcall(function() inst[prop] = color end)
            end
        else
            AccentBindings[inst] = nil
        end
    end
end

-- === Element registry (for search) ===
Nexus.SearchRegistry = {}

-- === Signal helper ===
function Nexus:signal(default)
    local ev = Instance.new('BindableEvent')
    local s = {Value = default, _ev = ev}
    function s:get() return s.Value end
    function s:set(v)
        s.Value = v
        ev:Fire(v)
    end
    function s:on(fn)
        return track(ev.Event:Connect(fn))
    end
    return s
end

-- === Base64 (compact) ===
do
    local alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local enc, dec = {}, {}
    for i = 1, 64 do
        local ch = string.sub(alpha, i, i)
        enc[i - 1] = ch
        dec[string.byte(ch)] = i - 1
    end
    local pads = {'', '==', '='}

    Nexus.b64encode = function(data)
        local out, oi = {}, 0
        local i, len = 1, #data
        while i + 2 <= len do
            local b1, b2, b3 = string.byte(data, i, i + 2)
            local v = b1 * 65536 + b2 * 256 + b3
            oi = oi + 1
            out[oi] = enc[bit32.rshift(v, 18)]
                .. enc[bit32.band(bit32.rshift(v, 12), 63)]
                .. enc[bit32.band(bit32.rshift(v, 6), 63)]
                .. enc[bit32.band(v, 63)]
            i = i + 3
        end
        local rest = len - i + 1
        if rest == 1 then
            local b1 = string.byte(data, i)
            oi = oi + 1
            out[oi] = enc[bit32.rshift(b1, 2)] .. enc[bit32.lshift(bit32.band(b1, 3), 4)]
        elseif rest == 2 then
            local b1, b2 = string.byte(data, i, i + 1)
            oi = oi + 1
            out[oi] = enc[bit32.rshift(b1, 2)]
                .. enc[bit32.lshift(bit32.band(b1, 3), 4) + bit32.rshift(b2, 4)]
                .. enc[bit32.lshift(bit32.band(b2, 15), 2)]
        end
        return table.concat(out) .. pads[len % 3 + 1]
    end

    Nexus.b64decode = function(data)
        local acc, bits, n = 0, 0, 0
        local bytes = {}
        for i = 1, #data do
            local v = dec[string.byte(data, i)]
            if v then
                acc = bit32.lshift(acc, 6) + v
                bits = bits + 6
                if bits >= 8 then
                    bits = bits - 8
                    n = n + 1
                    bytes[n] = bit32.band(bit32.rshift(acc, bits), 255)
                    acc = bit32.band(acc, bit32.lshift(1, bits) - 1)
                end
            end
        end
        return string.char(table.unpack(bytes, 1, n))
    end
end

-- === Obfuscation (simple) ===
local Obf = {}
function Obf.encrypt(data)
    local seed = ((#data + 3782) % 111) + 1
    local bytes = {}
    for i = 1, #data do
        bytes[i] = string.byte(data, i) + seed
    end
    return '{' .. tostring(seed + 72667) .. '}?' .. table.concat(bytes, '?')
end
function Obf.decrypt(data)
    local head = string.find(data, '?', 1, true)
    if not head then return '' end
    local seed = tonumber(string.gsub(string.sub(data, 1, head - 1), '[{}]', ''))
    if not seed then return '' end
    seed = seed - 72667
    local out = {}
    local pos = head + 1
    while pos <= #data do
        local stop = string.find(data, '?', pos, true)
        local last = (stop or #data + 1) - 1
        local n = tonumber(string.sub(data, pos, last))
        if n then out[#out + 1] = string.char(n - seed) end
        if not stop then break end
        pos = stop + 1
    end
    return table.concat(out)
end

-- === Shadow (subtle, not NeverLose-like) ===
function Nexus:shadow(parent)
    local strokes = {}
    for _, thickness in ipairs({5, 4, 3, 2}) do
        local s = Instance.new('UIStroke')
        s.Thickness = thickness
        s.Transparency = 1
        s.Parent = parent
        table.insert(strokes, s)
    end

    local sh = {}
    function sh:render(on)
        for _, s in ipairs(strokes) do
            tweens(s, Nexus.Tween.Slow, {Transparency = on and 0.92 or 1})
        end
    end
    return sh
end

-- === Tooltip ===
function Nexus:tooltip(anchor, title, body)
    local tip = Instance.new('Frame')
    tip.Name = 'NexusTip_' .. tostring(math.random(1e5, 9e5))
    tip.BackgroundColor3 = Nexus.Palette.Surface
    tip.BackgroundTransparency = 1
    tip.BorderSizePixel = 0
    tip.Size = UDim2.fromOffset(0, 0)
    tip.Position = UDim2.fromOffset(-9999, -9999)
    tip.ZIndex = 900

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = tip
    local stroke = Instance.new('UIStroke')
    stroke.Color = Nexus.Palette.Stroke
    stroke.Transparency = 1
    stroke.Parent = tip
    local sh = Nexus:shadow(tip)

    local name = Instance.new('TextLabel')
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.GothamBold
    name.Text = title
    name.TextColor3 = Nexus.Palette.Text
    name.TextSize = 13
    name.TextTransparency = 1
    name.Position = UDim2.fromOffset(10, 6)
    name.Size = UDim2.fromOffset(1, 16)
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 901
    name.Parent = tip

    local desc = Instance.new('TextLabel')
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.GothamMedium
    desc.Text = body
    desc.TextColor3 = Nexus.Palette.Muted
    desc.TextSize = 11
    desc.TextTransparency = 1
    desc.Position = UDim2.fromOffset(10, 24)
    desc.Size = UDim2.fromOffset(1, 14)
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.ZIndex = 901
    desc.Parent = tip

    local w = math.max(
        TextService:GetTextSize(title, 13, Enum.Font.GothamBold, Vector2.new(9e4, 9e4)).X,
        TextService:GetTextSize(body, 11, Enum.Font.GothamMedium, Vector2.new(9e4, 9e4)).X
    ) + 24
    tip.Size = UDim2.fromOffset(w, 44)

    local API = {Root = tip}

    function API:render(on)
        if on then
            tip.Parent = Nexus.Screen
            tip.Position = UDim2.fromOffset(
                anchor.AbsolutePosition.X + 6,
                anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 6
            )
            tweens(tip, Nexus.Tween.Med, {BackgroundTransparency = 0.05})
            tweens(stroke, Nexus.Tween.Med, {Transparency = 0.7})
            tweens(name, Nexus.Tween.Med, {TextTransparency = 0})
            tweens(desc, Nexus.Tween.Med, {TextTransparency = 0.35})
            sh:render(true)
        else
            tweens(tip, Nexus.Tween.Med, {BackgroundTransparency = 1})
            tweens(stroke, Nexus.Tween.Med, {Transparency = 1})
            tweens(name, Nexus.Tween.Med, {TextTransparency = 1})
            tweens(desc, Nexus.Tween.Med, {TextTransparency = 1})
            sh:render(false)
            tip.Parent = nil
        end
    end

    local hovered = false
    local delayToken = 0

    track(anchor.MouseEnter:Connect(function()
        delayToken = delayToken + 1
        local my = delayToken
        task.delay(0.4, function()
            if my == delayToken then
                hovered = true
                API:render(true)
            end
        end)
    end))
    track(anchor.MouseLeave:Connect(function()
        delayToken = delayToken + 1
        if hovered then
            hovered = false
            API:render(false)
        end
    end))

    return API
end

-- === Keybinds ===
Nexus.KeyMap = {
    One='1', Two='2', Three='3', Four='4', Five='5', Six='6', Seven='7', Eight='8', Nine='9', Zero='0',
    Minus='-', Plus='+', BackSlash='\\', Slash='/', Period='.', Semicolon=';', Colon=':',
    LeftControl='LCtrl', RightControl='RCtrl', LeftShift='LShift', RightShift='RShift',
    Return='Enter', LeftBracket='[', RightBracket=']', Quote="'", Comma=',', Equals='=',
    LeftSuper='Super', RightSuper='Super', LeftAlt='LAlt', RightAlt='RAlt', Escape='Esc',
}
Nexus.KeyMapRev = {}
for k, v in pairs(Nexus.KeyMap) do Nexus.KeyMapRev[v] = k end

function Nexus:keyToStr(k)
    if typeof(k) == 'string' then return Nexus.KeyMap[k] or k end
    return Nexus.KeyMap[k.Name] or k.Name
end
function Nexus:strToKey(s)
    if Nexus.KeyMapRev[s] then return Enum.KeyCode[Nexus.KeyMapRev[s]] end
    return Enum.KeyCode[s]
end

-- === Keybind panel (right click) ===
Nexus.ElementKeybinds = {}
Nexus.__activeBindMenu = nil

function Nexus:makeKeybindPanel(element, elementType, getValue, setValue, displayName, signal, sliderInfo)
    local id = displayName or element.Name
    local data = Nexus.ElementKeybinds[id] or {
        Type = elementType,
        Key = nil,
        Mode = 'Toggle',
        SliderValue = sliderInfo and sliderInfo.Min or 0,
        Active = false,
    }
    Nexus.ElementKeybinds[id] = data
    data.Type  = elementType
    data.Name  = displayName or id
    data.GetValue = getValue

    local panel = Instance.new('Frame')
    panel.BackgroundColor3 = Nexus.Palette.Surface
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Size = UDim2.fromOffset(0, 0)
    panel.Position = UDim2.fromOffset(-9999, -9999)
    panel.Visible = false
    panel.ZIndex = 950

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = panel
    local stroke = Instance.new('UIStroke')
    stroke.Color = Nexus.Palette.Stroke
    stroke.Transparency = 1
    stroke.Parent = panel
    local sh = Nexus:shadow(panel)

    local PAD = 8
    local hasMode = elementType ~= 'Button'
    local hasSlider = elementType == 'Slider' and sliderInfo ~= nil
    local titleW = TextService:GetTextSize(data.Name, 11, Enum.Font.GothamBold, Vector2.new(9e4, 9e4)).X
    local panelW = math.clamp(titleW + 2 + PAD * 2, 140, 210)
    local panelH = hasSlider and 92 or 62

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = data.Name
    title.TextColor3 = Nexus.Palette.Text
    title.TextSize = 11
    title.TextTransparency = 0.1
    title.Position = UDim2.fromOffset(PAD, 6)
    title.Size = UDim2.new(1, -PAD * 2, 0, 14)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 951
    title.Parent = panel

    local keyBox = Instance.new('TextButton')
    keyBox.BackgroundColor3 = Nexus.Palette.Surface2
    keyBox.BorderSizePixel = 0
    keyBox.AutoButtonColor = false
    keyBox.Text = ''
    keyBox.Position = UDim2.fromOffset(PAD, 26)
    keyBox.Size = UDim2.fromOffset(62, 20)
    keyBox.ZIndex = 951
    keyBox.Parent = panel
    local kbCorner = Instance.new('UICorner')
    kbCorner.CornerRadius = UDim.new(0, 4)
    kbCorner.Parent = keyBox
    local kbStroke = Instance.new('UIStroke')
    kbStroke.Color = Nexus.Palette.Stroke
    kbStroke.Transparency = 0.6
    kbStroke.Parent = keyBox

    local keyLabel = Instance.new('TextLabel')
    keyLabel.BackgroundTransparency = 1
    keyLabel.Font = Enum.Font.GothamMedium
    keyLabel.Text = 'None'
    keyLabel.TextColor3 = Nexus.Palette.Text
    keyLabel.TextSize = 10
    keyLabel.TextTransparency = 0.3
    keyLabel.Size = UDim2.fromScale(1, 1)
    keyLabel.ZIndex = 952
    keyLabel.Parent = keyBox

    local modeBtn
    if hasMode then
        modeBtn = Instance.new('TextButton')
        modeBtn.BackgroundColor3 = Nexus.Palette.Surface2
        modeBtn.BorderSizePixel = 0
        modeBtn.AutoButtonColor = false
        modeBtn.Text = ''
        modeBtn.Position = UDim2.fromOffset(PAD + 62 + 6, 26)
        modeBtn.Size = UDim2.fromOffset(panelW - PAD * 2 - 62 - 6 - 20, 20)
        modeBtn.ZIndex = 951
        modeBtn.Parent = panel
        local mCorner = Instance.new('UICorner')
        mCorner.CornerRadius = UDim.new(0, 4)
        mCorner.Parent = modeBtn
        local mStroke = Instance.new('UIStroke')
        mStroke.Color = Nexus.Palette.Stroke
        mStroke.Transparency = 0.6
        mStroke.Parent = modeBtn
        local mLabel = Instance.new('TextLabel')
        mLabel.BackgroundTransparency = 1
        mLabel.Font = Enum.Font.GothamMedium
        mLabel.Text = data.Mode
        mLabel.TextColor3 = Nexus.Palette.Text
        mLabel.TextSize = 10
        mLabel.TextTransparency = 0.3
        mLabel.Size = UDim2.new(1, -8, 1, 0)
        mLabel.Position = UDim2.fromOffset(6, 0)
        mLabel.TextXAlignment = Enum.TextXAlignment.Left
        mLabel.ZIndex = 952
        mLabel.Parent = modeBtn

        track(modeBtn.MouseButton1Click:Connect(function()
            data.Mode = data.Mode == 'Toggle' and 'Hold' or 'Toggle'
            mLabel.Text = data.Mode
        end))
    end

    local del = Instance.new('TextButton')
    del.BackgroundTransparency = 1
    del.AutoButtonColor = false
    del.Text = ''
    del.Position = UDim2.fromOffset(panelW - PAD - 14, 26)
    del.Size = UDim2.fromOffset(14, 20)
    del.ZIndex = 952
    del.Parent = panel
    local delIcon = Instance.new('TextLabel')
    delIcon.BackgroundTransparency = 1
    delIcon.FontFace = Nexus.Icons.Bold
    delIcon.Text = 'trash-can'
    delIcon.TextColor3 = Nexus.Palette.Muted
    delIcon.TextSize = 12
    delIcon.Size = UDim2.fromScale(1, 1)
    delIcon.ZIndex = 953
    delIcon.Parent = del

    track(del.MouseButton1Click:Connect(function()
        data.Key = nil
        keyLabel.Text = 'None'
    end))

    local slider, sLabel
    if hasSlider then
        local sMin  = sliderInfo.Min or 0
        local sMax  = sliderInfo.Max or 100
        local sRound = sliderInfo.Rounding or 0

        sLabel = Instance.new('TextLabel')
        sLabel.BackgroundTransparency = 1
        sLabel.Font = Enum.Font.GothamMedium
        sLabel.Text = tostring(data.SliderValue)
        sLabel.TextColor3 = Nexus.Palette.Muted
        sLabel.TextSize = 10
        sLabel.Position = UDim2.fromOffset(PAD, 56)
        sLabel.Size = UDim2.fromOffset(panelW - PAD * 2, 12)
        sLabel.TextXAlignment = Enum.TextXAlignment.Left
        sLabel.ZIndex = 952
        sLabel.Parent = panel

        local trackBg = Instance.new('Frame')
        trackBg.BackgroundColor3 = Nexus.Palette.Surface2
        trackBg.BorderSizePixel = 0
        trackBg.Position = UDim2.fromOffset(PAD, 74)
        trackBg.Size = UDim2.fromOffset(panelW - PAD * 2, 6)
        trackBg.ZIndex = 951
        trackBg.Parent = panel
        local tCorner = Instance.new('UICorner')
        tCorner.CornerRadius = UDim.new(1, 0)
        tCorner.Parent = trackBg

        local fill = Instance.new('Frame')
        fill.BackgroundColor3 = Nexus.Palette.Accent
        fill.BorderSizePixel = 0
        fill.Size = UDim2.fromScale(0, 1)
        fill.ZIndex = 952
        fill.Parent = trackBg
        local fCorner = Instance.new('UICorner')
        fCorner.CornerRadius = UDim.new(1, 0)
        fCorner.Parent = fill
        Nexus:bindAccent(fill)

        local knob = Instance.new('Frame')
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(0, 0, 0.5, 0)
        knob.Size = UDim2.fromOffset(10, 10)
        knob.ZIndex = 953
        knob.Parent = fill
        local kCorner = Instance.new('UICorner')
        kCorner.CornerRadius = UDim.new(1, 0)
        kCorner.Parent = knob

        local function refresh()
            local alpha = sMax ~= sMin and math.clamp((data.SliderValue - sMin) / (sMax - sMin), 0, 1) or 0
            fill.Size = UDim2.fromScale(alpha, 1)
            sLabel.Text = tostring(data.SliderValue)
        end
        refresh()

        local drag = false
        track(trackBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                drag = true
            end
        end))
        track(UIS.InputChanged:Connect(function(input)
            if not drag then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
               and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local a = math.clamp((Mouse.X - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
            data.SliderValue = round(sMin + (sMax - sMin) * a, sRound)
            refresh()
        end))
        track(UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                drag = false
            end
        end))

        slider = {refresh = refresh}
    end

    local panelOpen = false
    local outsideConn

    local function closePanel()
        if not panelOpen then return end
        panelOpen = false
        if Nexus.__activeBindMenu == closePanel then
            Nexus.__activeBindMenu = nil
        end
        if outsideConn then
            outsideConn:Disconnect()
            outsideConn = nil
        end
        tweens(panel, Nexus.Tween.Med, {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(panelW, 0),
        })
        tweens(stroke, Nexus.Tween.Med, {Transparency = 1})
        sh:render(false)
        task.delay(0.2, function()
            if not panelOpen then panel.Visible = false end
        end)
    end

    local function openPanel()
        if Nexus.__activeBindMenu and Nexus.__activeBindMenu ~= closePanel then
            Nexus.__activeBindMenu()
        end
        Nexus.__activeBindMenu = closePanel

        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        local ep = element.AbsolutePosition
        local es = element.AbsoluteSize
        local px = ep.X + es.X + 8
        if px + panelW > vp.X then px = ep.X - panelW - 8 end
        px = math.max(8, px)
        local py = math.clamp(ep.Y + es.Y / 2 - panelH / 2, 8, math.max(8, vp.Y - panelH - 8))

        panel.Position = UDim2.fromOffset(px, py)
        panel.Size = UDim2.fromOffset(panelW, 0)
        panel.Visible = true
        panelOpen = true

        tweens(panel, Nexus.Tween.Med, {
            BackgroundTransparency = 0.05,
            Size = UDim2.fromOffset(panelW, panelH),
        })
        tweens(stroke, Nexus.Tween.Med, {Transparency = 0.7})
        sh:render(true)

        outsideConn = UIS.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                if not hoverFrame(panel) and not hoverFrame(element) then
                    closePanel()
                end
            end
        end)
    end

    -- Right-click to open
    local lastToggle = 0
    local function attachRightClick(frame)
        track(frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                if os.clock() - lastToggle < 0.1 then return end
                lastToggle = os.clock()
                if panelOpen then closePanel() else openPanel() end
            end
        end))
    end
    attachRightClick(element)
    for _, c in ipairs(element:GetDescendants()) do
        if c:IsA('GuiObject') then attachRightClick(c) end
    end
    track(element.DescendantAdded:Connect(function(c)
        if c:IsA('GuiObject') then attachRightClick(c) end
    end))

    -- Keybind capture
    track(keyBox.MouseButton1Click:Connect(function()
        keyLabel.Text = '...'
        local captured
        while not captured do
            local k = UIS.InputBegan:Wait()
            if k.KeyCode ~= Enum.KeyCode.Unknown then
                captured = k.KeyCode.Name
            elseif k.UserInputType == Enum.UserInputType.MouseButton1 then
                captured = 'MouseLeft'
            elseif k.UserInputType == Enum.UserInputType.MouseButton2 then
                captured = 'MouseRight'
            end
        end        data.Key = captured
        keyLabel.Text = Nexus:keyToStr(captured)
    end))

    -- Input handling
    local function matches(input, typing)
        local k = data.Key
        if not k then return false end
        if k == 'MouseLeft' then return input.UserInputType == Enum.UserInputType.MouseButton1 end
        if k == 'MouseRight' then return input.UserInputType == Enum.UserInputType.MouseButton2 end
        if typing then return false end
        local ok, kc = pcall(Nexus.strToKey, Nexus, k)
        return ok and kc and input.KeyCode == kc
    end

    local holding = false
    track(UIS.InputBegan:Connect(function(input, typing)
        if not matches(input, typing) then return end
        if elementType == 'Button' then return end
        if data.Mode == 'Hold' then
            holding = true
            data.Active = true
            if elementType == 'Toggle' then
                setValue(true)
            elseif elementType == 'Slider' then
                setValue(data.SliderValue)
            end
        else
            if elementType == 'Toggle' then
                setValue(not getValue())
            elseif elementType == 'Slider' then
                if data.Active then
                    data.Active = false
                else
                    data.Active = true
                    setValue(data.SliderValue)
                end
            end
        end
    end))
    track(UIS.InputEnded:Connect(function(input)
        if data.Mode ~= 'Hold' or not holding then return end
        if not matches(input, false) then return end
        holding = false
        data.Active = false
        if elementType == 'Toggle' then
            setValue(false)
        end
    end))

    return data
end

-- === Section registry (elements live inside) ===
function Nexus:sectionHandler(holder, tabSignal, displayName)
    local H = {}
    H.DisplayName = displayName

    function H:AddToggle(cfg)
        cfg = cfg or {}
        local default   = cfg.Default or false
        local flag      = cfg.Flag
        local callback  = cfg.Callback or function() end

        local wrap = Instance.new('Frame')
        wrap.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
        wrap.BorderSizePixel = 0
        wrap.ClipsDescendants = true
        wrap.Size = UDim2.fromOffset(34, 18)
        wrap.ZIndex = holder.ZIndex + 5
        wrap.LayoutOrder = -(#holder:GetChildren() + 5)
        wrap.Parent = holder
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = wrap

        local knob = Instance.new('Frame')
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BackgroundTransparency = 0.4
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(0.3, 0, 0.5, 0)
        knob.Size = UDim2.fromOffset(14, 14)
        knob.ZIndex = wrap.ZIndex + 1
        knob.Parent = wrap
        local kCorner = Instance.new('UICorner')
        kCorner.CornerRadius = UDim.new(1, 0)
        kCorner.Parent = knob

        local lib = {Root = wrap}

        local function paint(v)
            if v then
                tweens(wrap, Nexus.Tween.Med, {BackgroundColor3 = Nexus.Palette.Accent})
                tweens(knob, Nexus.Tween.Med, {
                    Position = UDim2.new(0.72, 0, 0.5, 0),
                    BackgroundTransparency = 0,
                })
            else
                tweens(wrap, Nexus.Tween.Med, {BackgroundColor3 = Color3.fromRGB(12, 14, 22)})
                tweens(knob, Nexus.Tween.Med, {
                    Position = UDim2.new(0.3, 0, 0.5, 0),
                    BackgroundTransparency = 0.4,
                })
            end
        end

        paint(default)
        track(holder.AncestryChanged:Connect(function()
            wrap.Visible = holder.Visible
        end))
        local button = Instance.new('TextButton')
        button.BackgroundTransparency = 1
        button.Text = ''
        button.Size = UDim2.fromScale(1, 1)
        button.ZIndex = wrap.ZIndex + 2
        button.Parent = wrap
        track(button.MouseButton1Click:Connect(function()
            default = not default
            paint(default)
            callback(default)
        end))

        function lib:GetValue() return default end
        function lib:SetValue(v)
            default = v
            paint(v)
            callback(v)
        end

        if flag then Nexus.Flags[flag] = lib end
        Nexus:makeKeybindPanel(wrap, 'Toggle',
            function() return default end,
            function(v) lib:SetValue(v) end,
            H.DisplayName or flag or 'Toggle',
            tabSignal, nil)

        return lib
    end

    function H:AddSlider(cfg)
        cfg = cfg or {}
        local default = cfg.Default or 0
        local min, max = cfg.Min or 0, cfg.Max or 100
        local rounding = cfg.Rounding or 0
        local flag = cfg.Flag
        local callback = cfg.Callback or function() end
        local width = cfg.Size or 120

        local root = Instance.new('Frame')
        root.BackgroundTransparency = 1
        root.Size = UDim2.fromOffset(width, 18)
        root.ZIndex = holder.ZIndex + 5
        root.LayoutOrder = -(#holder:GetChildren() + 5)
        root.Parent = holder

        local valFrame = Instance.new('Frame')
        valFrame.BackgroundColor3 = Nexus.Palette.Surface2
        valFrame.BorderSizePixel = 0
        valFrame.AnchorPoint = Vector2.new(1, 0)
        valFrame.Position = UDim2.new(1, 0, 0, 0)
        valFrame.Size = UDim2.fromOffset(40, 18)
        valFrame.ZIndex = root.ZIndex + 1
        valFrame.Parent = root
        local vCorner = Instance.new('UICorner')
        vCorner.CornerRadius = UDim.new(0, 4)
        vCorner.Parent = valFrame

        local valLabel = Instance.new('TextBox')
        valLabel.BackgroundTransparency = 1
        valLabel.Font = Enum.Font.GothamMedium
        valLabel.Text = tostring(default)
        valLabel.TextColor3 = Nexus.Palette.Text
        valLabel.TextSize = 10
        valLabel.TextTransparency = 0.3
        valLabel.ClearTextOnFocus = false
        valLabel.Size = UDim2.fromScale(1, 1)
        valLabel.ZIndex = valFrame.ZIndex + 1
        valLabel.Parent = valFrame

        local bg = Instance.new('Frame')
        bg.BackgroundColor3 = Nexus.Palette.Surface2
        bg.BorderSizePixel = 0
        bg.AnchorPoint = Vector2.new(0, 0.5)
        bg.Position = UDim2.new(0, 0, 0.5, 0)
        bg.Size = UDim2.new(1, -46, 0, 5)
        bg.ZIndex = root.ZIndex + 1
        bg.Parent = root
        local bgCorner = Instance.new('UICorner')
        bgCorner.CornerRadius = UDim.new(1, 0)
        bgCorner.Parent = bg

        local fill = Instance.new('Frame')
        fill.BackgroundColor3 = Nexus.Palette.Accent
        fill.BorderSizePixel = 0
        fill.Size = UDim2.fromScale(0, 1)
        fill.ZIndex = bg.ZIndex + 1
        fill.Parent = bg
        local fCorner = Instance.new('UICorner')
        fCorner.CornerRadius = UDim.new(1, 0)
        fCorner.Parent = fill
        Nexus:bindAccent(fill)

        local knob = Instance.new('Frame')
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(1, 0, 0.5, 0)
        knob.Size = UDim2.fromOffset(10, 10)
        knob.ZIndex = fill.ZIndex + 1
        knob.Parent = fill
        local kCorner = Instance.new('UICorner')
        kCorner.CornerRadius = UDim.new(1, 0)
        kCorner.Parent = knob

        local lib = {Root = root}

        local function alpha()
            if max == min then return 0 end
            return math.clamp((default - min) / (max - min), 0, 1)
        end
        local function paint()
            fill.Size = UDim2.fromScale(alpha(), 1)
            valLabel.Text = tostring(default)
        end
        paint()

        local drag = false
        track(bg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                drag = true
                local a = math.clamp((Mouse.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
                default = round(min + (max - min) * a, rounding)
                paint()
                callback(default)
            end
        end))
        track(UIS.InputChanged:Connect(function(input)
            if not drag then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
               and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local a = math.clamp((Mouse.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
            default = round(min + (max - min) * a, rounding)
            paint()
            callback(default)
        end))
        track(UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                drag = false
            end
        end))

        track(valLabel.FocusLost:Connect(function()
            local n = tonumber(valLabel.Text)
            if n then
                default = round(math.clamp(n, min, max), rounding)
                paint()
                callback(default)
            else
                paint()
            end
        end))

        function lib:GetValue() return default end
        function lib:SetValue(v)
            default = v
            paint()
            callback(v)
        end

        if flag then Nexus.Flags[flag] = lib end
        Nexus:makeKeybindPanel(root, 'Slider',
            function() return default end,
            function(v) lib:SetValue(v) end,
            H.DisplayName or flag or 'Slider',
            tabSignal, {Min = min, Max = max, Rounding = rounding})

        return lib
    end

    function H:AddKeybind(cfg)
        cfg = cfg or {}
        local default = cfg.Default
        local flag = cfg.Flag
        local callback = cfg.Callback or function() end

        local box = Instance.new('TextButton')
        box.BackgroundColor3 = Nexus.Palette.Surface2
        box.BorderSizePixel = 0
        box.AutoButtonColor = false
        box.Text = ''
        box.Size = UDim2.fromOffset(52, 18)
        box.ZIndex = holder.ZIndex + 5
        box.LayoutOrder = -(#holder:GetChildren() + 5)
        box.Parent = holder
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = box
        local stroke = Instance.new('UIStroke')
        stroke.Color = Nexus.Palette.Stroke
        stroke.Transparency = 0.6
        stroke.Parent = box

        local label = Instance.new('TextLabel')
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = Nexus:keyToStr(default or 'None')
        label.TextColor3 = Nexus.Palette.Text
        label.TextSize = 10
        label.TextTransparency = 0.35
        label.Size = UDim2.fromScale(1, 1)
        label.ZIndex = box.ZIndex + 1
        label.Parent = box

        local lib = {}

        track(box.MouseButton1Click:Connect(function()
            label.Text = '...'
            local captured
            while not captured do
                local k = UIS.InputBegan:Wait()
                if k.KeyCode ~= Enum.KeyCode.Unknown then
                    captured = k.KeyCode.Name
                elseif k.UserInputType == Enum.UserInputType.MouseButton1 then
                    captured = 'M1B'
                elseif k.UserInputType == Enum.UserInputType.MouseButton2 then
                    captured = 'M2B'
                end
            end
            default = captured
            label.Text = Nexus:keyToStr(captured)
            callback(captured)
        end))

        function lib:GetValue() return default end
        function lib:SetValue(v)
            default = v
            label.Text = Nexus:keyToStr(v)
            callback(v)
        end

        if flag then Nexus.Flags[flag] = lib end
        return lib
    end

    function H:AddTextbox(cfg)
        cfg = cfg or {}
        local default = cfg.Default or ''
        local placeholder = cfg.Placeholder or ''
        local numeric = cfg.Numeric or false
        local flag = cfg.Flag
        local callback = cfg.Callback or function() end
        local size = cfg.Size or 110

        local root = Instance.new('Frame')
        root.BackgroundColor3 = Nexus.Palette.Surface2
        root.BorderSizePixel = 0
        root.Size = UDim2.fromOffset(size, 18)
        root.ZIndex = holder.ZIndex + 5
        root.LayoutOrder = -(#holder:GetChildren() + 5)
        root.Parent = holder
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = root
        local stroke = Instance.new('UIStroke')
        stroke.Color = Nexus.Palette.Stroke
        stroke.Transparency = 0.6
        stroke.Parent = root

        local box = Instance.new('TextBox')
        box.BackgroundTransparency = 1
        box.Font = Enum.Font.GothamMedium
        box.PlaceholderText = placeholder
        box.Text = tostring(default)
        box.TextColor3 = Nexus.Palette.Text
        box.TextSize = 11
        box.TextTransparency = 0.35
        box.ClearTextOnFocus = false
        box.Position = UDim2.fromOffset(6, 0)
        box.Size = UDim2.new(1, -6, 1, 0)
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.ZIndex = root.ZIndex + 1
        box.Parent = root

        local lib = {}

        track(box:GetPropertyChangedSignal('Text'):Connect(function()
            local t = box.Text
            if numeric then
                t = string.gsub(t, '[^%d%.%-]', '')
                box.Text = t
                local n = tonumber(t)
                if n then
                    default = n
                    callback(n)
                end
            else
                default = t
                callback(t)
            end
        end))

        function lib:GetValue() return default end
        function lib:SetValue(v)
            default = v
            box.Text = tostring(v)
            callback(v)
        end

        if flag then Nexus.Flags[flag] = lib end
        return lib
    end

    function H:AddDropdown(cfg)
        cfg = cfg or {}
        local values = cfg.Values or {}
        local multi = cfg.Multi or false
        local flag = cfg.Flag
        local callback = cfg.Callback or function() end
        local width = cfg.Size or 110

        local function normalize(v)
            if typeof(v) == 'table' then
                local t = {}
                for k, val in pairs(v) do
                    if typeof(k) == 'number' then t[val] = true else t[k] = val end
                end
                return t
            end
            return v
        end

        local default = normalize(cfg.Default)
        if default == nil then default = multi and {} or nil end

        local root = Instance.new('Frame')
        root.BackgroundColor3 = Nexus.Palette.Surface2
        root.BorderSizePixel = 0
        root.ClipsDescendants = true
        root.Size = UDim2.fromOffset(width, 18)
        root.ZIndex = holder.ZIndex + 5
        root.LayoutOrder = -(#holder:GetChildren() + 5)
        root.Parent = holder
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = root
        local stroke = Instance.new('UIStroke')
        stroke.Color = Nexus.Palette.Stroke
        stroke.Transparency = 0.6
        stroke.Parent = root

        local label = Instance.new('TextLabel')
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.TextColor3 = Nexus.Palette.Text
        label.TextSize = 11
        label.TextTransparency = 0.3
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Position = UDim2.fromOffset(6, 0)
        label.Size = UDim2.new(1, -22, 1, 0)
        label.ZIndex = root.ZIndex + 1
        label.Parent = root

        local arrow = Instance.new('TextLabel')
        arrow.BackgroundTransparency = 1
        arrow.FontFace = Nexus.Icons.Bold
        arrow.Text = 'chevron-small-down'
        arrow.TextColor3 = Nexus.Palette.Muted
        arrow.TextSize = 14
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -2, 0.5, 0)
        arrow.Size = UDim2.fromOffset(18, 18)
        arrow.ZIndex = root.ZIndex + 1
        arrow.Parent = root

        local function pretty(v)
            if not v then return 'Select' end
            if typeof(v) == 'table' then
                local list = {}
                for k, val in pairs(v) do
                    if val then table.insert(list, tostring(k)) end
                end
                if #list == 0 then return 'Select' end
                return table.concat(list, ', ')
            end
            return tostring(v)
        end

        label.Text = pretty(default)

        -- Dropdown popup
        local popup = Instance.new('Frame')
        popup.BackgroundColor3 = Nexus.Palette.Surface
        popup.BackgroundTransparency = 1
        popup.BorderSizePixel = 0
        popup.ClipsDescendants = true
        popup.Size = UDim2.fromOffset(0, 0)
        popup.Position = UDim2.fromOffset(-9999, -9999)
        popup.Visible = false
        popup.ZIndex = 940
        local pCorner = Instance.new('UICorner')
        pCorner.CornerRadius = UDim.new(0, 6)
        pCorner.Parent = popup
        local pStroke = Instance.new('UIStroke')
        pStroke.Color = Nexus.Palette.Stroke
        pStroke.Transparency = 1
        pStroke.Parent = popup
        local pShadow = Nexus:shadow(popup)

        local scroll = Instance.new('ScrollingFrame')
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.Size = UDim2.new(1, -6, 1, -6)
        scroll.Position = UDim2.fromOffset(3, 3)
        scroll.ScrollBarThickness = 2
        scroll.ScrollBarImageColor3 = Nexus.Palette.Stroke
        scroll.ZIndex = 941
        scroll.Parent = popup
        local listLayout = Instance.new('UIListLayout')
        listLayout.Parent = scroll
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 2)

        local lib = {Root = root, PopupRoot = popup}
        local rowCalls = {}

        local function isSelected(v)
            if typeof(default) == 'table' then
                return default[v] == true or table.find(default, v) ~= nil
            end
            return default == v
        end

        local function rebuild()
            for _, c in ipairs(scroll:GetChildren()) do
                if c:IsA('Frame') then c:Destroy() end
            end
            rowCalls = {}

            local longest = 0
            for _, v in ipairs(values) do
                local row = Instance.new('TextButton')
                row.BackgroundColor3 = Nexus.Palette.Surface
                row.BorderSizePixel = 0
                row.AutoButtonColor = false
                row.Text = ''
                row.Size = UDim2.new(1, 0, 0, 24)
                row.ZIndex = 942
                row.Parent = scroll
                local rowCorner = Instance.new('UICorner')
                rowCorner.CornerRadius = UDim.new(0, 4)
                rowCorner.Parent = row

                local rowLabel = Instance.new('TextLabel')
                rowLabel.BackgroundTransparency = 1
                rowLabel.Font = Enum.Font.GothamMedium
                rowLabel.Text = tostring(v)
                rowLabel.TextColor3 = Nexus.Palette.Text
                rowLabel.TextSize = 11
                rowLabel.TextTransparency = isSelected(v) and 0 or 0.4
                rowLabel.TextXAlignment = Enum.TextXAlignment.Left
                rowLabel.Position = UDim2.fromOffset(10, 0)
                rowLabel.Size = UDim2.new(1, -10, 1, 0)
                rowLabel.ZIndex = 943
                rowLabel.Parent = row

                local w = TextService:GetTextSize(tostring(v), 11, Enum.Font.GothamMedium, Vector2.new(9e4, 9e4)).X
                if w > longest then longest = w end

                track(row.MouseEnter:Connect(function()
                    tweens(row, Nexus.Tween.Fast, {BackgroundColor3 = Nexus.Palette.Surface2})
                end))
                track(row.MouseLeave:Connect(function()
                    tweens(row, Nexus.Tween.Fast, {BackgroundColor3 = Nexus.Palette.Surface})
                end))
                track(row.MouseButton1Click:Connect(function()
                    if multi then
                        if typeof(default) ~= 'table' then default = {} end
                        default[v] = not default[v]
                    else
                        default = v
                    end
                    label.Text = pretty(default)
                    for _, fn in ipairs(rowCalls) do fn() end
                    callback(default)
                    if not multi then closePopup() end
                end))

                table.insert(rowCalls, function()
                    rowLabel.TextTransparency = isSelected(v) and 0 or 0.4
                end)
            end

            scroll.CanvasSize = UDim2.fromOffset(0, #values * 26)
            popup.Size = UDim2.fromOffset(math.max(width, longest + 30), math.min(#values * 26 + 8, 180))
        end

        local popupOpen = false
        local outside

        function closePopup()
            if not popupOpen then return end
            popupOpen = false
            if outside then outside:Disconnect() outside = nil end
            tweens(popup, Nexus.Tween.Med, {BackgroundTransparency = 1})
            tweens(pStroke, Nexus.Tween.Med, {Transparency = 1})
            pShadow:render(false)
            task.delay(0.2, function()
                if not popupOpen then popup.Visible = false end
            end)
        end

        local function openPopup()
            local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            local ep = root.AbsolutePosition
            local es = root.AbsoluteSize
            popup.Position = UDim2.fromOffset(ep.X, ep.Y + es.Y + 4)
            if popup.Position.Y.Offset + popup.Size.Y.Offset > vp.Y then
                popup.Position = UDim2.fromOffset(ep.X, ep.Y - popup.Size.Y.Offset - 4)
            end
            popup.Visible = true
            popupOpen = true
            tweens(popup, Nexus.Tween.Med, {BackgroundTransparency = 0.05})
            tweens(pStroke, Nexus.Tween.Med, {Transparency = 0.7})
            pShadow:render(true)

            outside = UIS.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                   or input.UserInputType == Enum.UserInputType.Touch then
                    if not hoverFrame(popup) and not hoverFrame(root) then
                        closePopup()
                    end
                end
            end)
        end

        rebuild()

        local btn = Instance.new('TextButton')
        btn.BackgroundTransparency = 1
        btn.Text = ''
        btn.Size = UDim2.fromScale(1, 1)
        btn.ZIndex = root.ZIndex + 2
        btn.Parent = root
        track(btn.MouseButton1Click:Connect(function()
            if popupOpen then closePopup() else openPopup() end
        end))

        function lib:GetValue() return default end
        function lib:SetValue(v)
            default = normalize(v)
            label.Text = pretty(default)
            for _, fn in ipairs(rowCalls) do fn() end
            callback(default)
        end
        function lib:SetValues(v)
            values = v or {}
            rebuild()
        end

        if flag then Nexus.Flags[flag] = lib end
        return lib
    end

    function H:AddButton(cfg)
        cfg = cfg or {}
        local icon = cfg.Icon or 'chevron-large-right'
        local name = cfg.Name or 'Button'
        local callback = cfg.Callback or function() end
        local tooltip = cfg.ToolTip

        local row = Instance.new('Frame')
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 26)
        row.ZIndex = holder.ZIndex + 5
        row.LayoutOrder = -(#holder:GetChildren() + 5)
        row.Parent = holder

        local btn = Instance.new('TextButton')
        btn.BackgroundColor3 = Nexus.Palette.Surface2
        btn.BackgroundTransparency = 1
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Text = ''
        btn.Size = UDim2.fromScale(1, 1)
        btn.ZIndex = row.ZIndex + 1
        btn.Parent = row
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = btn

        local iconLabel = Instance.new('TextLabel')
        iconLabel.BackgroundTransparency = 1
        iconLabel.FontFace = Nexus.Icons.Bold
        iconLabel.Text = icon
        iconLabel.TextColor3 = Nexus.Palette.Text
        iconLabel.TextSize = 14
        iconLabel.TextTransparency = 0.3
        iconLabel.AnchorPoint = Vector2.new(0, 0.5)
        iconLabel.Position = UDim2.fromOffset(8, 0)
        iconLabel.Size = UDim2.fromOffset(18, 18)
        iconLabel.ZIndex = btn.ZIndex + 1
        iconLabel.Parent = btn

        local text = Instance.new('TextLabel')
        text.BackgroundTransparency = 1
        text.Font = Enum.Font.GothamMedium
        text.Text = name
        text.TextColor3 = Nexus.Palette.Text
        text.TextSize = 12
        text.TextTransparency = 0.2
        text.TextXAlignment = Enum.TextXAlignment.Left
        text.AnchorPoint = Vector2.new(0, 0.5)
        text.Position = UDim2.fromOffset(32, 0)
        text.Size = UDim2.new(1, -36, 1, 0)
        text.ZIndex = btn.ZIndex + 1
        text.Parent = btn

        track(btn.MouseEnter:Connect(function()
            tweens(btn, Nexus.Tween.Fast, {BackgroundTransparency = 0.4})
        end))
        track(btn.MouseLeave:Connect(function()
            tweens(btn, Nexus.Tween.Fast, {BackgroundTransparency = 1})
        end))
        track(btn.MouseButton1Click:Connect(callback))

        local lib = {
            Root = row,
            SetText = function(_, t) text.Text = t end,
            SetIcon = function(_, i) iconLabel.Text = i end,
        }

        if tooltip then Nexus:tooltip(btn, name, tooltip) end
        return lib
    end

    function H:AddLabel(text, wrap)
        local row = Instance.new('Frame')
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 24)
        row.ZIndex = holder.ZIndex + 5
        row.LayoutOrder = -(#holder:GetChildren() + 5)
        row.Parent = holder

        local lbl = Instance.new('TextLabel')
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.Text = text
        lbl.TextColor3 = Nexus.Palette.Muted
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTransparency = 0.2
        lbl.Position = UDim2.fromOffset(8, 0)
        lbl.Size = UDim2.new(1, -16, 1, 0)
        lbl.ZIndex = row.ZIndex + 1
        lbl.TextWrapped = wrap == true
        lbl.Parent = row

        table.insert(Nexus.SearchRegistry, {Root = row, Id = text})
        return {Root = row, SetText = function(_, t) lbl.Text = t end}
    end

    function H:AddColorPicker(cfg)
        cfg = cfg or {}
        local flag = cfg.Flag
        local callback = cfg.Callback or function() end
        local value = cfg.Default or Color3.fromRGB(255, 255, 255)
        if typeof(value) == 'string' then value = Color3.fromHex(value:gsub('#', '')) end

        local btn = Instance.new('TextButton')
        btn.BackgroundColor3 = value
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Text = ''
        btn.Size = UDim2.fromOffset(18, 18)
        btn.ZIndex = holder.ZIndex + 5
        btn.LayoutOrder = -(#holder:GetChildren() + 5)
        btn.Parent = holder
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        local stroke = Instance.new('UIStroke')
        stroke.Color = Nexus.Palette.Stroke
        stroke.Transparency = 0.6
        stroke.Parent = btn

        local lib = {}

        track(btn.MouseButton1Click:Connect(function()
            -- Minimal HSV popup
            local popup = Instance.new('Frame')
            popup.BackgroundColor3 = Nexus.Palette.Surface
            popup.BackgroundTransparency = 1
            popup.BorderSizePixel = 0
            popup.ClipsDescendants = true
            popup.Position = UDim2.fromOffset(btn.AbsolutePosition.X + 20, btn.AbsolutePosition.Y + 20)
            popup.Size = UDim2.fromOffset(0, 0)
            popup.ZIndex = 920
            local pCorner = Instance.new('UICorner')
            pCorner.CornerRadius = UDim.new(0, 8)
            pCorner.Parent = popup
            local pStroke = Instance.new('UIStroke')
            pStroke.Color = Nexus.Palette.Stroke
            pStroke.Transparency = 1
            pStroke.Parent = popup
            local pShadow = Nexus:shadow(popup)

            -- Simple hue slider + value slider (lightweight)
            local hue = Instance.new('Frame')
            hue.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            hue.BorderSizePixel = 0
            hue.Position = UDim2.fromOffset(10, 10)
            hue.Size = UDim2.fromOffset(200, 14)
            hue.ZIndex = 921
            hue.Parent = popup
            local hCorner = Instance.new('UICorner')
            hCorner.CornerRadius = UDim.new(0, 4)
            hCorner.Parent = hue
            local hueGrad = Instance.new('UIGradient')
            hueGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.34, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.51, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.68, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.85, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
            })
            hueGrad.Parent = hue

            local val = Instance.new('Frame')
            val.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            val.BorderSizePixel = 0
            val.Position = UDim2.fromOffset(10, 34)
            val.Size = UDim2.fromOffset(200, 14)
            val.ZIndex = 921
            val.Parent = popup
            local vCorner = Instance.new('UICorner')
            vCorner.CornerRadius = UDim.new(0, 4)
            vCorner.Parent = val
            local vGrad = Instance.new('UIGradient')
            vGrad.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(255, 255, 255))
            vGrad.Parent = val

            popup.Size = UDim2.fromOffset(220, 60)
            tweens(popup, Nexus.Tween.Med, {BackgroundTransparency = 0.05})
            tweens(pStroke, Nexus.Tween.Med, {Transparency = 0.7})
            pShadow:render(true)

            local hDrag, vDrag = false, false
            track(hue.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then hDrag = true end
            end))
            track(val.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then vDrag = true end
            end))
            track(UIS.InputChanged:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                if hDrag then
                    local a = math.clamp((Mouse.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1)
                    local h, s, v = Color3.toHSV(value)
                    value = Color3.fromHSV(a, s, v)
                    btn.BackgroundColor3 = value
                    callback(value)
                elseif vDrag then
                    local a = math.clamp((Mouse.X - val.AbsolutePosition.X) / val.AbsoluteSize.X, 0, 1)
                    local h, s, _ = Color3.toHSV(value)
                    value = Color3.fromHSV(h, s, a)
                    btn.BackgroundColor3 = value
                    callback(value)
                end
            end))
            track(UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    hDrag, vDrag = false, false
                end
            end))

            local close
            close = UIS.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if not hoverFrame(popup) and not hoverFrame(btn) then
                        if close then close:Disconnect() end
                        tweens(popup, Nexus.Tween.Med, {BackgroundTransparency = 1})
                        tweens(pStroke, Nexus.Tween.Med, {Transparency = 1})
                        pShadow:render(false)
                        task.delay(0.2, function() popup:Destroy() end)
                    end
                end
            end)
        end))

        function lib:GetValue() return value end
        function lib:SetValue(v)
            value = v
            btn.BackgroundColor3 = v
            callback(v)
        end

        if flag then Nexus.Flags[flag] = lib end
        return lib
    end

    return H
end

-- === Options menu (right-click gear on element) ===
function Nexus:optionsWindow(anchor, zIndex)
    local menu = Instance.new('Frame')
    menu.BackgroundColor3 = Nexus.Palette.Surface
    menu.BackgroundTransparency = 1
    menu.BorderSizePixel = 0
    menu.ClipsDescendants = true
    menu.Size = UDim2.fromOffset(180, 0)
    menu.Position = UDim2.fromOffset(-9999, -9999)
    menu.Visible = false
    menu.ZIndex = (zIndex or 9) + 20
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = menu
    local stroke = Instance.new('UIStroke')
    stroke.Color = Nexus.Palette.Stroke
    stroke.Transparency = 1
    stroke.Parent = menu
    local sh = Nexus:shadow(menu)
    local layout = Instance.new('UIListLayout')
    layout.Parent = menu
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)

    local signal = Nexus:signal(false)
    local API = {Root = menu, Signal = signal}

    function API:render(on)
        if on then
            local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            local ep = anchor.AbsolutePosition
            local es = anchor.AbsoluteSize
            local px = ep.X + es.X + 6
            if px + menu.Size.X.Offset > vp.X then px = ep.X - menu.Size.X.Offset - 6 end
            menu.Position = UDim2.fromOffset(px, ep.Y)
            menu.Visible = true
            tweens(menu, Nexus.Tween.Med, {
                BackgroundTransparency = 0.05,
                Size = UDim2.fromOffset(menu.Size.X.Offset, math.max(24, layout.AbsoluteContentSize.Y + 6)),
            })
            tweens(stroke, Nexus.Tween.Med, {Transparency = 0.7})
            sh:render(true)
        else
            tweens(menu, Nexus.Tween.Med, {BackgroundTransparency = 1})
            tweens(stroke, Nexus.Tween.Med, {Transparency = 1})
            sh:render(false)
            task.delay(0.2, function()
                if not signal:get() then menu.Visible = false end
            end)
        end
    end

    track(layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        if signal:get() then
            tweens(menu, Nexus.Tween.Med, {
                Size = UDim2.fromOffset(menu.Size.X.Offset, math.max(24, layout.AbsoluteContentSize.Y + 6)),
            })
        end
    end))

    signal:on(function(v) API:render(v) end)

    return API
end

-- === Tab / Section construction ===
function Nexus:createTab(window, cfg)
    cfg = cfg or {}
    local icon = cfg.Icon or 'crosshairs'
    local name = cfg.Name or 'Tab'
    local layoutMode = cfg.Layout or 'Double'

    local tab = {Signal = Nexus:signal(false), Idx = nil}

    local btn = Instance.new('Frame')
    btn.BackgroundColor3 = Nexus.Palette.Surface2
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Size = UDim2.new(1, -6, 0, 28)
    btn.ZIndex = 8
    btn.Parent = window.TabList
    local bCorner = Instance.new('UICorner')
    bCorner.CornerRadius = UDim.new(0, 5)
    bCorner.Parent = btn

    local iconLabel = Instance.new('TextLabel')
    iconLabel.BackgroundTransparency = 1
    iconLabel.FontFace = Nexus.Icons.Bold
    iconLabel.Text = icon
    iconLabel.TextColor3 = Nexus.Palette.Muted
    iconLabel.TextSize = 15
    iconLabel.AnchorPoint = Vector2.new(0, 0.5)
    iconLabel.Position = UDim2.fromOffset(6, 0)
    iconLabel.Size = UDim2.fromOffset(20, 20)
    iconLabel.ZIndex = btn.ZIndex + 1
    iconLabel.Parent = btn

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamMedium
    title.Text = name
    title.TextColor3 = Nexus.Palette.Muted
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.AnchorPoint = Vector2.new(0, 0.5)
    title.Position = UDim2.fromOffset(30, 0)
    title.Size = UDim2.new(1, -34, 1, 0)
    title.ZIndex = btn.ZIndex + 1
    title.Parent = btn

    -- Content
    local content = Instance.new('Frame')
    content.BackgroundTransparency = 1
    content.Size = UDim2.fromScale(1, 1)
    content.Visible = false
    content.ZIndex = 5
    content.Parent = window.Content
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Position = UDim2.fromScale(0.5, 0.5)

    local leftScroll = Instance.new('ScrollingFrame')
    leftScroll.BackgroundTransparency = 1
    leftScroll.BorderSizePixel = 0
    leftScroll.AnchorPoint = Vector2.new(0.5, 0.5)
    leftScroll.Position = UDim2.fromScale(0.25, 0.5)
    leftScroll.Size = UDim2.new(0.5, -4, 1, -8)
    leftScroll.ScrollBarThickness = 0
    leftScroll.ZIndex = 6
    leftScroll.Parent = content
    local leftLayout = Instance.new('UIListLayout')
    leftLayout.Parent = leftScroll
    leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Padding = UDim.new(0, 6)

    local rightScroll
    local rightLayout

    if layoutMode == 'Single' then
        rightScroll = leftScroll
        rightLayout = leftLayout
        leftScroll.Size = UDim2.new(1, -8, 1, -8)
        leftScroll.Position = UDim2.fromScale(0.5, 0.5)
    else
        rightScroll = Instance.new('ScrollingFrame')
        rightScroll.BackgroundTransparency = 1
        rightScroll.BorderSizePixel = 0
        rightScroll.AnchorPoint = Vector2.new(0.5, 0.5)
        rightScroll.Position = UDim2.fromScale(0.75, 0.5)
        rightScroll.Size = UDim2.new(0.5, -4, 1, -8)
        rightScroll.ScrollBarThickness = 0
        rightScroll.ZIndex = 6
        rightScroll.Parent = content
        rightLayout = Instance.new('UIListLayout')
        rightLayout.Parent = rightScroll
        rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rightLayout.Padding = UDim.new(0, 6)

        track(rightLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            rightScroll.CanvasSize = UDim2.fromOffset(0, rightLayout.AbsoluteContentSize.Y)
        end))
    end

    track(leftLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        leftScroll.CanvasSize = UDim2.fromOffset(0, leftLayout.AbsoluteContentSize.Y)
    end))

    function tab:SetValue(v)
        if v then
            content.Visible = true
            tweens(btn, Nexus.Tween.Med, {BackgroundTransparency = 0.3, BackgroundColor3 = Nexus.Palette.Surface2})
            tweens(iconLabel, Nexus.Tween.Med, {TextColor3 = Nexus.Palette.Accent, TextTransparency = 0})
            tweens(title, Nexus.Tween.Med, {TextColor3 = Nexus.Palette.Text, TextTransparency = 0})
        else
            tweens(btn, Nexus.Tween.Med, {BackgroundTransparency = 1})
            tweens(iconLabel, Nexus.Tween.Med, {TextColor3 = Nexus.Palette.Muted})
            tweens(title, Nexus.Tween.Med, {TextColor3 = Nexus.Palette.Muted})
            content.Visible = false
        end
    end

    local clickBtn = Instance.new('TextButton')
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ''
    clickBtn.Size = UDim2.fromScale(1, 1)
    clickBtn.ZIndex = btn.ZIndex + 2
    clickBtn.Parent = btn
    track(clickBtn.MouseButton1Click:Connect(function()
        for i, t in ipairs(window.Tabs) do
            if t == tab then
                t:SetValue(true)
                window.CurrentTab = i
            else
                t:SetValue(false)
            end
        end
    end))

    table.insert(window.Tabs, tab)

    function tab:AddSection(cfg2)
        cfg2 = cfg2 or {}
        local secName = cfg2.Name or 'Section'
        local pos = string.lower(cfg2.Position or 'left')

        local wrap = Instance.new('Frame')
        wrap.BackgroundColor3 = Nexus.Palette.Surface
        wrap.BackgroundTransparency = 0.5
        wrap.BorderSizePixel = 0
        wrap.ClipsDescendants = true
        wrap.Size = UDim2.new(1, -4, 0, 0)
        wrap.ZIndex = 7
        wrap.Parent = pos == 'left' and leftScroll or rightScroll
        local wCorner = Instance.new('UICorner')
        wCorner.CornerRadius = UDim.new(0, 6)
        wCorner.Parent = wrap
        local wStroke = Instance.new('UIStroke')
        wStroke.Color = Nexus.Palette.Stroke
        wStroke.Transparency = 0.6
        wStroke.Parent = wrap

        local secLabel = Instance.new('TextLabel')
        secLabel.BackgroundTransparency = 1
        secLabel.Font = Enum.Font.GothamBold
        secLabel.Text = secName
        secLabel.TextColor3 = Nexus.Palette.Muted
        secLabel.TextSize = 11
        secLabel.TextTransparency = 0.25
        secLabel.TextXAlignment = Enum.TextXAlignment.Left
        secLabel.Position = UDim2.fromOffset(12, 6)
        secLabel.Size = UDim2.new(1, -20, 0, 14)
        secLabel.ZIndex = 8
        secLabel.Parent = wrap

        local holder = Instance.new('Frame')
        holder.BackgroundTransparency = 1
        holder.Position = UDim2.fromOffset(0, 24)
        holder.Size = UDim2.new(1, 0, 0, 0)
        holder.ZIndex = 8
        holder.Parent = wrap
        local hLayout = Instance.new('UIListLayout')
        hLayout.Parent = holder
        hLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        hLayout.SortOrder = Enum.SortOrder.LayoutOrder

        track(hLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            local h = hLayout.AbsoluteContentSize.Y + 30
            tweens(wrap, Nexus.Tween.Slow, {Size = UDim2.new(1, -4, 0, h)})
            holder.Size = UDim2.new(1, 0, 0, hLayout.AbsoluteContentSize.Y)
        end))

        track(tab.Signal:on(function(v)
            tweens(wrap, Nexus.Tween.Med, {BackgroundTransparency = v and 0.5 or 1})
            tweens(wStroke, Nexus.Tween.Med, {Transparency = v and 0.6 or 1})
            tweens(secLabel, Nexus.Tween.Med, {TextTransparency = v and 0.25 or 1})
        end))

        -- Ensure the tab signal reflects the section
        tab.Signal:on(function() end)

        local H = Nexus:sectionHandler(holder, tab.Signal, secName)
        H.Root = wrap
        H.Holder = holder
        return H
    end

    return tab
end

-- === Window ===
function Nexus:createWindow(cfg)
    cfg = cfg or {}
    local logo = cfg.Logo or ''
    local title = cfg.Name or 'Nexus'
    local subtitle = cfg.Content or ''
    local size = cfg.Size or UDim2.fromOffset(620, 440)
    local configFolder = cfg.ConfigFolder or 'NexusCfg'
    local keybind = cfg.Keybind or 'Insert'

    local window = {
        Name = title,
        Content = subtitle,
        Size = size,
        ConfigFolder = configFolder,
        Tabs = {},
        CurrentTab = 1,
        Keybind = keybind,
        Signal = Nexus:signal(true),
    }

    if not isfolder(configFolder) then makefolder(configFolder) end

    local frame = Instance.new('Frame')
    frame.Name = 'NexusWin_' .. tostring(math.random(1e6, 9e6))
    frame.BackgroundColor3 = Nexus.Palette.Base
    frame.BackgroundTransparency = 0.02
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.Size = size
    frame.Parent = Nexus.Screen
    local fCorner = Instance.new('UICorner')
    fCorner.CornerRadius = UDim.new(0, 10)
    fCorner.Parent = frame

    local sh = Nexus:shadow(frame)
    sh:render(true)

    -- Top drag bar
    local dragBar = Instance.new('Frame')
    dragBar.BackgroundTransparency = 1
    dragBar.Size = UDim2.new(1, 0, 0, 44)
    dragBar.ZIndex = 12
    dragBar.Parent = frame
    local dragStart, startPos, dragging
    track(dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end))
    track(UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    track(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    -- Left sidebar
    local sidebar = Instance.new('Frame')
    sidebar.BackgroundTransparency = 1
    sidebar.Size = UDim2.new(0, 160, 1, 0)
    sidebar.ZIndex = 7
    sidebar.Parent = frame

    -- Header
    local header = Instance.new('Frame')
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 44)
    header.ZIndex = 8
    header.Parent = sidebar

    local logoFrame = Instance.new('Frame')
    logoFrame.BackgroundColor3 = Nexus.Palette.Surface2
    logoFrame.BorderSizePixel = 0
    logoFrame.AnchorPoint = Vector2.new(0, 0.5)
    logoFrame.Position = UDim2.fromOffset(10, 0)
    logoFrame.Size = UDim2.fromOffset(28, 28)
    logoFrame.ZIndex = 9
    logoFrame.Parent = header
    local lCorner = Instance.new('UICorner')
    lCorner.CornerRadius = UDim.new(0, 6)
    lCorner.Parent = logoFrame
    local lStroke = Instance.new('UIStroke')
    lStroke.Color = Nexus.Palette.Stroke
    lStroke.Transparency = 0.4
    lStroke.Parent = logoFrame

    if logo ~= '' then
        local li = Instance.new('ImageLabel')
        li.BackgroundTransparency = 1
        li.Image = logo
        li.Size = UDim2.fromScale(1, 1)
        li.ZIndex = 10
        li.Parent = logoFrame
    end

    local nameLbl = Instance.new('TextLabel')
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Text = title
    nameLbl.TextColor3 = Nexus.Palette.Text
    nameLbl.TextSize = 16
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Position = UDim2.fromOffset(46, 6)
    nameLbl.Size = UDim2.new(1, -52, 0, 18)
    nameLbl.ZIndex = 9
    nameLbl.Parent = header

    local subLbl = Instance.new('TextLabel')
    subLbl.BackgroundTransparency = 1
    subLbl.Font = Enum.Font.GothamMedium
    subLbl.Text = subtitle
    subLbl.TextColor3 = Nexus.Palette.Muted
    subLbl.TextSize = 10
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    subLbl.Position = UDim2.fromOffset(46, 24)
    subLbl.Size = UDim2.new(1, -52, 0, 14)
    subLbl.ZIndex = 9
    subLbl.Parent = header

    -- Tab list
    local tabList = Instance.new('ScrollingFrame')
    tabList.BackgroundTransparency = 1
    tabList.BorderSizePixel = 0
    tabList.Position = UDim2.fromOffset(4, 52)
    tabList.Size = UDim2.new(1, -8, 1, -100)
    tabList.ScrollBarThickness = 0
    tabList.ZIndex = 8
    tabList.Parent = sidebar
    local tabLayout = Instance.new('UIListLayout')
    tabLayout.Parent = tabList
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 4)

    track(tabLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 4)
    end))

    window.TabList = tabList

    -- Bottom user info
    local bottom = Instance.new('Frame')
    bottom.AnchorPoint = Vector2.new(0, 1)
    bottom.BackgroundTransparency = 1
    bottom.Position = UDim2.new(0, 0, 1, 0)
    bottom.Size = UDim2.new(1, 0, 0, 44)
    bottom.ZIndex = 8
    bottom.Parent = sidebar

    local avatar = Instance.new('ImageLabel')
    avatar.BackgroundColor3 = Nexus.Palette.Surface2
    avatar.BorderSizePixel = 0
    avatar.Image = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    avatar.AnchorPoint = Vector2.new(0, 0.5)
    avatar.Position = UDim2.fromOffset(10, 0)
    avatar.Size = UDim2.fromOffset(28, 28)
    avatar.ZIndex = 9
    avatar.Parent = bottom
    local aCorner = Instance.new('UICorner')
    aCorner.CornerRadius = UDim.new(1, 0)
    aCorner.Parent = avatar

    local userLbl = Instance.new('TextLabel')
    userLbl.BackgroundTransparency = 1
    userLbl.Font = Enum.Font.GothamBold
    userLbl.Text = LP.DisplayName
    userLbl.TextColor3 = Nexus.Palette.Text
    userLbl.TextSize = 12
    userLbl.TextXAlignment = Enum.TextXAlignment.Left
    userLbl.Position = UDim2.fromOffset(46, 6)
    userLbl.Size = UDim2.new(1, -52, 0, 16)
    userLbl.ZIndex = 9
    userLbl.Parent = bottom

    local expLbl = Instance.new('TextLabel')
    expLbl.BackgroundTransparency = 1
    expLbl.Font = Enum.Font.GothamMedium
    expLbl.Text = 'active'
    expLbl.TextColor3 = Nexus.Palette.Muted
    expLbl.TextSize = 10
    expLbl.TextXAlignment = Enum.TextXAlignment.Left
    expLbl.Position = UDim2.fromOffset(46, 22)
    expLbl.Size = UDim2.new(1, -52, 0, 14)
    expLbl.ZIndex = 9
    expLbl.Parent = bottom

    -- Content area
    local rightSide = Instance.new('Frame')
    rightSide.BackgroundColor3 = Nexus.Palette.Surface
    rightSide.BackgroundTransparency = 0.5
    rightSide.BorderSizePixel = 0
    rightSide.Position = UDim2.fromOffset(160, 8)
    rightSide.Size = UDim2.new(1, -168, 1, -16)
    rightSide.ZIndex = 5
    rightSide.Parent = frame
    local rCorner = Instance.new('UICorner')
    rCorner.CornerRadius = UDim.new(0, 8)
    rCorner.Parent = rightSide
    local rStroke = Instance.new('UIStroke')
    rStroke.Color = Nexus.Palette.Stroke
    rStroke.Transparency = 0.6
    rStroke.Parent = rightSide

    local content = Instance.new('Frame')
    content.BackgroundTransparency = 1
    content.Size = UDim2.fromScale(1, 1)
    content.ZIndex = 6
    content.Parent = rightSide
    window.Content = content

    -- Show / hide
    function window:render(v)
        if v then
            frame.Visible = true
            tweens(frame, Nexus.Tween.Slow, {
                BackgroundTransparency = 0.02,
                Size = size,
            })
            sh:render(true)
        else
            tweens(frame, Nexus.Tween.Med, {
                BackgroundTransparency = 1,
                Size = size - UDim2.fromOffset(20, 20),
            })
            sh:render(false)
            task.delay(0.3, function()
                if not window.Signal:get() then frame.Visible = false end
            end)
        end
    end

    window.Signal:on(function(v) window:render(v) end)

    function window:Toggle()
        window.Signal:set(not window.Signal:get())
    end

    track(UIS.InputBegan:Connect(function(input, typing)
        if typing then return end
        if input.KeyCode == Enum.KeyCode[keybind] then
            window:Toggle()
        end
    end))

    function window:AddTab(cfg2)
        return Nexus:createTab(window, cfg2)
    end

    -- Config manager
    local configMenu = Nexus:optionsWindow(frame, 20)
    window.ConfigMenu = configMenu

    local configBtn = Instance.new('TextButton')
    configBtn.BackgroundColor3 = Nexus.Palette.Surface2
    configBtn.BackgroundTransparency = 0.6
    configBtn.BorderSizePixel = 0
    configBtn.AutoButtonColor = false
    configBtn.Text = ''
    configBtn.AnchorPoint = Vector2.new(1, 0)
    configBtn.Position = UDim2.new(1, -10, 0, 10)
    configBtn.Size = UDim2.fromOffset(110, 24)
    configBtn.ZIndex = 15
    configBtn.Parent = frame
    local cbCorner = Instance.new('UICorner')
    cbCorner.CornerRadius = UDim.new(0, 5)
    cbCorner.Parent = configBtn

    local cbIcon = Instance.new('TextLabel')
    cbIcon.BackgroundTransparency = 1
    cbIcon.FontFace = Nexus.Icons.Bold
    cbIcon.Text = 'floppy-disk'
    cbIcon.TextColor3 = Nexus.Palette.Muted
    cbIcon.TextSize = 14
    cbIcon.AnchorPoint = Vector2.new(0, 0.5)
    cbIcon.Position = UDim2.fromOffset(8, 0)
    cbIcon.Size = UDim2.fromOffset(16, 16)
    cbIcon.ZIndex = 16
    cbIcon.Parent = configBtn

    local cbName = Instance.new('TextLabel')
    cbName.BackgroundTransparency = 1
    cbName.Font = Enum.Font.GothamMedium
    cbName.Text = 'Default'
    cbName.TextColor3 = Nexus.Palette.Text
    cbName.TextSize = 11
    cbName.TextXAlignment = Enum.TextXAlignment.Left
    cbName.Position = UDim2.fromOffset(28, 0)
    cbName.Size = UDim2.new(1, -36, 1, 0)
    cbName.ZIndex = 16
    cbName.Parent = configBtn

    -- config data helpers
    local function collectFlags()
        local out = {}
        for flag, el in pairs(Nexus.Flags) do
            if el and el.GetValue then
                local v = el:GetValue()
                if typeof(v) == 'Color3' then
                    table.insert(out, {Idx = flag, Value = v:ToHex()})
                else
                    table.insert(out, {Idx = flag, Value = v})
                end
            end
        end
        return out
    end

    local function serialize()
        local payload = {Flags = collectFlags()}
        return Nexus.b64encode(Obf.encrypt(HttpService:JSONEncode(payload)))
    end

    local function deserialize(str)
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(Obf.decrypt(Nexus.b64decode(str)))
        end)
        if not ok or not decoded then return end
        local flags = decoded.Flags or decoded
        for _, v in ipairs(flags) do
            local el = Nexus.Flags[v.Idx]
            if el and el.SetValue then
                pcall(function() el:SetValue(v.Value) end)
            end
        end
    end

    local function refreshList()
        for _, c in ipairs(configMenu.Root:GetChildren()) do
            if c:GetAttribute('CfgEntry') then c:Destroy() end
        end
        local files = {}
        for _, p in ipairs(listfiles(configFolder)) do
            table.insert(files, string.sub(p, #configFolder + 2))
        end
        table.sort(files)
        for _, fname in ipairs(files) do
            local row = Instance.new('Frame')
            row.BackgroundColor3 = Nexus.Palette.Surface2
            row.BackgroundTransparency = 0.6
            row.BorderSizePixel = 0
            row.Size = UDim2.new(1, -8, 0, 24)
            row.ZIndex = 22
            row.Parent = configMenu.Root
            row:SetAttribute('CfgEntry', true)
            local rc = Instance.new('UICorner')
            rc.CornerRadius = UDim.new(0, 4)
            rc.Parent = row

            local lbl = Instance.new('TextLabel')
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.Text = fname
            lbl.TextColor3 = Nexus.Palette.Text
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Position = UDim2.fromOffset(8, 0)
            lbl.Size = UDim2.new(1, -50, 1, 0)
            lbl.ZIndex = 23
            lbl.Parent = row

            local loadBtn = Instance.new('TextButton')
            loadBtn.BackgroundTransparency = 1
            loadBtn.Text = ''
            loadBtn.Size = UDim2.fromOffset(20, 20)
            loadBtn.Position = UDim2.fromOffset(row.Size.X.Offset - 46, 2)
            loadBtn.ZIndex = 23
            loadBtn.Parent = row
            local loadIcon = Instance.new('TextLabel')
            loadIcon.BackgroundTransparency = 1
            loadIcon.FontFace = Nexus.Icons.Bold
            loadIcon.Text = 'arrow-right-from-portrait-rectangle'
            loadIcon.TextColor3 = Nexus.Palette.Muted
            loadIcon.TextSize = 12
            loadIcon.Size = UDim2.fromScale(1, 1)
            loadIcon.ZIndex = 24
            loadIcon.Parent = loadBtn
            track(loadBtn.MouseButton1Click:Connect(function()
                local path = configFolder .. '/' .. fname
                if isfile(path) then
                    deserialize(readfile(path))
                    cbName.Text = fname
                end
            end))

            local delBtn = Instance.new('TextButton')
            delBtn.BackgroundTransparency = 1
            delBtn.Text = ''
            delBtn.Size = UDim2.fromOffset(20, 20)
            delBtn.Position = UDim2.fromOffset(row.Size.X.Offset - 22, 2)
            delBtn.ZIndex = 23
            delBtn.Parent = row
            local delIcon = Instance.new('TextLabel')
            delIcon.BackgroundTransparency = 1
            delIcon.FontFace = Nexus.Icons.Bold
            delIcon.Text = 'trash-can'
            delIcon.TextColor3 = Nexus.Palette.Bad
            delIcon.TextSize = 12
            delIcon.Size = UDim2.fromScale(1, 1)
            delIcon.ZIndex = 24
            delIcon.Parent = row
            track(delBtn.MouseButton1Click:Connect(function()
                if fname ~= 'Default' then
                    delfile(configFolder .. '/' .. fname)
                    refreshList()
                end
            end))
        end
    end

    track(configBtn.MouseButton1Click:Connect(function()
        refreshList()
        configMenu.Signal:set(not configMenu.Signal:get())
    end))

    -- Save on click icon
    local saveBtn = Instance.new('TextButton')
    saveBtn.BackgroundColor3 = Nexus.Palette.Surface2
    saveBtn.BackgroundTransparency = 1
    saveBtn.BorderSizePixel = 0
    saveBtn.AutoButtonColor = false
    saveBtn.Text = ''
    saveBtn.Size = UDim2.fromScale(1, 1)
    saveBtn.ZIndex = 17
    saveBtn.Parent = cbIcon
    track(saveBtn.MouseButton1Click:Connect(function()
        writefile(configFolder .. '/' .. cbName.Text, serialize())
    end))

    return window
end

-- === Notification (toast) ===
function Nexus:Notify(title, content, duration, color)
    duration = duration or 4
    color = color or Nexus.Palette.Accent
    local toast = Instance.new('Frame')
    toast.BackgroundColor3 = Nexus.Palette.Surface
    toast.BackgroundTransparency = 1
    toast.BorderSizePixel = 0
    toast.ClipsDescendants = true
    toast.Size = UDim2.fromOffset(0, 40)
    toast.Position = UDim2.fromOffset(20, 20)
    toast.ZIndex = 960
    toast.Parent = Nexus.Screen
    local tCorner = Instance.new('UICorner')
    tCorner.CornerRadius = UDim.new(0, 6)
    tCorner.Parent = toast
    local tStroke = Instance.new('UIStroke')
    tStroke.Color = Nexus.Palette.Stroke
    tStroke.Transparency = 1
    tStroke.Parent = toast
    local tShadow = Nexus:shadow(toast)

    local bar = Instance.new('Frame')
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    bar.AnchorPoint = Vector2.new(0, 0.5)
    bar.Position = UDim2.fromOffset(6, 0)
    bar.Size = UDim2.fromOffset(3, 28)
    bar.ZIndex = 961
    bar.Parent = toast
    local bCorner = Instance.new('UICorner')
    bCorner.CornerRadius = UDim.new(1, 0)
    bCorner.Parent = bar

    local tl = Instance.new('TextLabel')
    tl.BackgroundTransparency = 1
    tl.Font = Enum.Font.GothamBold
    tl.Text = title
    tl.TextColor3 = Nexus.Palette.Text
    tl.TextSize = 13
    tl.TextTransparency = 1
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Position = UDim2.fromOffset(16, 5)
    tl.Size = UDim2.new(1, -22, 0, 16)
    tl.ZIndex = 961
    tl.Parent = toast

    local cl = Instance.new('TextLabel')
    cl.BackgroundTransparency = 1
    cl.Font = Enum.Font.GothamMedium
    cl.Text = content
    cl.TextColor3 = Nexus.Palette.Muted
    cl.TextSize = 11
    cl.TextTransparency = 1
    cl.TextXAlignment = Enum.TextXAlignment.Left
    cl.Position = UDim2.fromOffset(16, 21)
    cl.Size = UDim2.new(1, -22, 0, 14)
    cl.ZIndex = 961
    cl.Parent = toast

    local w = math.max(
        TextService:GetTextSize(title, 13, Enum.Font.GothamBold, Vector2.new(9e4, 9e4)).X,
        TextService:GetTextSize(content, 11, Enum.Font.GothamMedium, Vector2.new(9e4, 9e4)).X
    ) + 32

    tweens(toast, Nexus.Tween.Med, {BackgroundTransparency = 0.05, Size = UDim2.fromOffset(w, 40)})
    tweens(tStroke, Nexus.Tween.Med, {Transparency = 0.7})
    tweens(tl, Nexus.Tween.Med, {TextTransparency = 0})
    tweens(cl, Nexus.Tween.Med, {TextTransparency = 0.35})
    tShadow:render(true)

    task.delay(duration, function()
        tweens(toast, Nexus.Tween.Med, {BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 40)})
        tweens(tStroke, Nexus.Tween.Med, {Transparency = 1})
        tweens(tl, Nexus.Tween.Med, {TextTransparency = 1})
        tweens(cl, Nexus.Tween.Med, {TextTransparency = 1})
        tShadow:render(false)
        task.wait(0.25)
        toast:Destroy()
    end)
end

-- === Unload ===
function Nexus:Unload()
    for _, c in ipairs(Nexus.Connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(Nexus.Connections)
    pcall(function() Nexus.Screen:Destroy() end)
end

getgenv().__NEXUS = Nexus

return Nexus
