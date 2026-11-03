local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local Config = { Folder = "Blush", PerGame = false, Current = nil, AutoSave = false, Loading = false, Version = 2 }

local Blush = {
	Flags = {}, Options = {}, Connections = {}, AccentObjects = {}, Keybinds = {}, Windows = {},
	MenuOpen = false, Notifications = true, Config = Config, IconProvider = nil, _BindMap = {},
}

local Theme = {
	Background = Color3.fromRGB(34, 38, 48),
	Panel = Color3.fromRGB(39, 44, 56),
	Element = Color3.fromRGB(48, 54, 68),
	Stroke = Color3.fromRGB(58, 64, 80),
	Footer = Color3.fromRGB(29, 32, 41),
	Text = Color3.fromRGB(238, 239, 246),
	SubText = Color3.fromRGB(139, 146, 166),
	Accent = Color3.fromRGB(232, 92, 252),
	Accent2 = Color3.fromRGB(138, 52, 214),
}
Blush.Theme = Theme

-- BuilderSans reads cleaner than Gotham for UI chrome
local FontPath = "rbxasset://fonts/families/BuilderSans.json"
local Fonts = {
	Medium = Font.new(FontPath, Enum.FontWeight.Medium),
	Semi = Font.new(FontPath, Enum.FontWeight.SemiBold),
	Bold = Font.new(FontPath, Enum.FontWeight.Bold),
}
Blush.Fonts = Fonts

-- Full-width top accent bar that inherits the parent's corner radius (engraved look)
local function EngravedLine(parent, thickness)
	thickness = thickness or 2
	local line = Frame({
		Size = UDim2.new(1, 0, 0, thickness),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = parent,
	})
	AccentGradient(line)
	-- Soft under-shadow for the engraved inset feel
	local shade = Frame({
		Position = UDim2.fromOffset(0, thickness),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = .68,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = parent,
	})
	return line, shade
end

local WHITE = Color3.new(1, 1, 1)
local HEADER_H, FOOTER_H = 38, 42
local Quint, Back, Linear, Sine = Enum.EasingStyle.Quint, Enum.EasingStyle.Back, Enum.EasingStyle.Linear, Enum.EasingStyle.Sine

local function Create(class, props)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	inst.Parent = parent
	return inst
end

local function Make(class, defaults, p)
	local props = table.clone(defaults)
	for k, v in pairs(p or {}) do props[k] = v end
	return Create(class, props)
end

local function Frame(p)
	local d = { BorderSizePixel = 0 }
	if not (p and p.BackgroundColor3) then d.BackgroundTransparency = 1 end
	return Make("Frame", d, p)
end

local TextDefaults = {
	BackgroundTransparency = 1, BorderSizePixel = 0, FontFace = Fonts.Semi, TextSize = 13,
	TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}
local function Label(p) return Make("TextLabel", TextDefaults, p) end
local function Input(p)
	local d = table.clone(TextDefaults)
	d.ClearTextOnFocus = false
	return Make("TextBox", d, p)
end
local function Button(p)
	local d = table.clone(TextDefaults)
	d.AutoButtonColor = false
	if p and p.BackgroundColor3 then d.BackgroundTransparency = 0 end
	return Make("TextButton", d, p)
end

local function Corner(p, r) return Create("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = p }) end
local function Stroke(p, c, t, tr)
	return Create("UIStroke", { Color = c or Theme.Stroke, Thickness = t or 1, Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p })
end
local function List(p, pad, dir)
	return Create("UIListLayout", { Padding = UDim.new(0, pad or 0), FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = p })
end
local function Pad(p, t, b, l, r)
	return Create("UIPadding", { PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
		PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), Parent = p })
end

local function Tween(o, props, t, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t or .2, style or Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function Connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Blush.Connections, c)
	return c
end

local function AccentGradient(parent, rotation)
	local g = Create("UIGradient", { Rotation = rotation or 0, Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Parent = parent })
	table.insert(Blush.AccentObjects, g)
	return g
end

local function Press(btn)
	local s = Create("UIScale", { Parent = btn })
	btn.MouseButton1Down:Connect(function() Tween(s, { Scale = .965 }, .08) end)
	local function release() Tween(s, { Scale = 1 }, .35, Back) end
	btn.MouseButton1Up:Connect(release)
	btn.MouseLeave:Connect(release)
end

function Blush:SetAccent(c1, c2)
	Theme.Accent, Theme.Accent2 = c1, c2 or c1
	local seq = ColorSequence.new(Theme.Accent, Theme.Accent2)
	for i = #self.AccentObjects, 1, -1 do
		local g = self.AccentObjects[i]
		if self.Gui and g:IsDescendantOf(self.Gui) then g.Color = seq else table.remove(self.AccentObjects, i) end
	end
end

local function GetGuiParent()
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok then
		local t = Instance.new("ScreenGui")
		local ok2 = pcall(function() t.Parent = cg end)
		t:Destroy()
		if ok2 then return cg end
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local KeyAlias = {
	MouseButton1 = "M1", MouseButton2 = "M2", MouseButton3 = "M3", LeftShift = "LShift", RightShift = "RShift",
	LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt", RightAlt = "RAlt", Return = "Enter",
	Backspace = "Bksp", Escape = "Esc", Insert = "Ins", Delete = "Del", One = "1", Two = "2", Three = "3",
	Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
}
local function KeyName(k) if not k then return "None" end return KeyAlias[k.Name] or k.Name end
local function InputMatches(input, key)
	if not key then return false end
	if key.EnumType == Enum.KeyCode then return input.KeyCode == key end
	return input.UserInputType == key
end
local function SerializeKey(k)
	if not k then return nil end
	return (k.EnumType == Enum.KeyCode and "KeyCode:" or "UserInputType:") .. k.Name
end
local function ParseKey(s)
	if type(s) ~= "string" then return nil end
	local t, n = s:match("^(%w+):(%w+)$")
	if not t then return nil end
	local ok, v = pcall(function() return Enum[t][n] end)
	return ok and v or nil
end
local function IsPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end

local function MakeDrag(obj, fn, onEnd)
	obj.InputBegan:Connect(function(i)
		if IsPress(i) then
			Blush._drag, Blush._dragEnd = fn, onEnd
			fn(i.Position)
		end
	end)
end

local function Draggable(handle, target, needMenu)
	handle.InputBegan:Connect(function(i)
		if IsPress(i) and (not needMenu or Blush.MenuOpen) then
			local start = Vector2.new(i.Position.X, i.Position.Y)
			local o = target.Position
			Blush._drag = function(p)
				local d = Vector2.new(p.X, p.Y) - start
				target.Position = UDim2.new(o.X.Scale, o.X.Offset + d.X, o.Y.Scale, o.Y.Offset + d.Y)
			end
		end
	end)
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function B64Encode(s)
	return ((s:gsub(".", function(x)
		local r, b = "", x:byte()
		for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
		if #x < 6 then return "" end
		local c = 0
		for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
		return B64:sub(c + 1, c + 1)
	end) .. ({ "", "==", "=" })[#s % 3 + 1])
end
local function B64Decode(s)
	s = s:gsub("[^" .. B64 .. "=]", "")
	return (s:gsub(".", function(x)
		if x == "=" then return "" end
		local r, f = "", (B64:find(x, 1, true) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then return "" end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end))
end

local Element = {}
Element.__index = Element
function Element:OnChanged(f) table.insert(self.Changed, f) return self end
function Element:_Fire(...)
	if self.Callback then task.spawn(self.Callback, ...) end
	for _, f in ipairs(self.Changed) do task.spawn(f, ...) end
	Config:_Dirty()
end
function Element:UpdateVisible() if self.Frame then self.Frame.Visible = not (self.Hidden or self.SearchHidden) end end
function Element:SetVisible(b) self.Hidden = not b self:UpdateVisible() end
function Element:Reset() if self.Default and self.Load then self:Load(self.Default[1]) end end

local function Done(el)
	if el.Save then el.Default = { el:Save() } end
	return el
end

function Blush:_Flag(el, flag)
	if not flag then return end
	local base, n = flag, 1
	while self.Options[flag] do n += 1 flag = base .. "#" .. n end
	el.Flag = flag
	self.Options[flag] = el
end

local Icons = { Module = nil, Failed = false, Molto = nil, MoltoFailed = false }
local IconAlias = {
	mouse = "mouse-pointer-2", aim = "crosshair", visuals = "eye", colors = "palette", colours = "palette",
	settings = "settings", gear = "settings", misc = "sliders-horizontal", sliders = "sliders-horizontal",
	search = "search", rifle = "crosshair", pistol = "target", sniper = "crosshair", smg = "zap",
}

local function ResolveIcon(name)
	local n = tostring(name)
	if tonumber(n) then return "rbxassetid://" .. n end
	if n:find("rbx", 1, true) == 1 then return n end
	n = IconAlias[n:lower()] or n
	if Blush.IconProvider then
		local ok, r = pcall(Blush.IconProvider, n)
		if ok and r then return r end
	end
	-- Prefer Molto icon registry (lucide / tabler / heroicons / solar / material / fluent / phosphor)
	if not Icons.Molto and not Icons.MoltoFailed then
		local ok, m = pcall(function()
			return loadstring(game:HttpGet("https://molto.pages.dev/source.lua"))()
		end)
		if ok and type(m) == "table" then
			Icons.Molto = m
			pcall(function()
				if m.SetProvider then m.SetProvider("lucide") end
			end)
		else
			Icons.MoltoFailed = true
		end
	end
	if Icons.Molto then
		local ok, asset = pcall(function()
			if Icons.Molto.GetAsset then
				return Icons.Molto.GetAsset(n)
			elseif Icons.Molto.get then
				return Icons.Molto.get(n)
			end
		end)
		if ok and asset then
			if type(asset) == "table" then return asset end
			if type(asset) == "string" then return asset end
		end
	end
	-- Fallback: melatonin lucide-luau
	if not Icons.Module and not Icons.Failed then
		local ok, m = pcall(function()
			return loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/melatonin-rs/lucide-luau@main/src/init.luau"))()
		end)
		if ok and type(m) == "table" then Icons.Module = m else Icons.Failed = true end
	end
	if Icons.Module then
		local ok, r = pcall(Icons.Module.get, n, 96)
		if ok and r then return r end
	end
end

local function ApplyIcon(img, res)
	if type(res) == "table" then
		img.Image = res.Image or res.Url or ""
		if res.ImageRectSize then
			img.ImageRectSize = res.ImageRectSize
			img.ImageRectOffset = res.ImageRectOffset or Vector2.zero
		end
	else
		img.Image = res
	end
end

function Blush:SetIconProvider(fn) self.IconProvider = fn end

local ConfigFS = {}
function Config:Supported()
	return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfolder) == "function"
		and typeof(makefolder) == "function" and typeof(isfile) == "function"
end
function Config:Root()
	local r = self.Folder
	if self.PerGame then r = r .. "/" .. tostring(game.GameId) end
	return r
end
function Config:Ensure()
	if not self:Supported() then return false end
	local paths = { self.Folder }
	if self.PerGame then table.insert(paths, self:Root()) end
	table.insert(paths, self:Root() .. "/configs")
	for _, p in ipairs(paths) do
		if not isfolder(p) then makefolder(p) end
	end
	return true
end
function Config:Sanitize(name)
	name = tostring(name or ""):gsub("[^%w%-_%s%.]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	return name:sub(1, 40)
end
function Config:Path(name) return self:Root() .. "/configs/" .. name .. ".json" end
function Config:Exists(name)
	return self:Ensure() and name and name ~= "" and isfile(self:Path(name))
end
function Config:List()
	local out = {}
	if not self:Ensure() or typeof(listfiles) ~= "function" then return out end
	for _, p in ipairs(listfiles(self:Root() .. "/configs")) do
		local n = p:match("([^/\\]+)%.json$")
		if n then table.insert(out, n) end
	end
	table.sort(out, function(a, b) return a:lower() < b:lower() end)
	return out
end
function Config:Info(name)
	if not self:Exists(name) then return nil end
	local ok, d = pcall(function() return HttpService:JSONDecode(readfile(self:Path(name))) end)
	if ok and type(d) == "table" then return d end
end
function Config:Snapshot()
	local data = {}
	for flag, opt in pairs(Blush.Options) do
		if opt.Save and not opt.NoSave then data[flag] = opt:Save() end
	end
	return data
end
function Config:Apply(flags)
	self.Loading = true
	local applied, missing = 0, 0
	for flag, v in pairs(flags) do
		local opt = Blush.Options[flag]
		if opt and opt.Load and not opt.NoSave then
			if pcall(opt.Load, opt, v) then applied += 1 end
		else
			missing += 1
		end
	end
	self.Loading = false
	return applied, missing
end
function Config:Save(name, silent)
	name = self:Sanitize(name or self.Current)
	if name == "" then return false, "Invalid name" end
	if not self:Ensure() then return false, "Executor has no file access" end
	local path = self:Path(name)
	if isfile(path) then pcall(writefile, path .. ".bak", readfile(path)) end
	local payload = { version = self.Version, name = name, saved = os.time(), place = game.PlaceId, flags = self:Snapshot() }
	local ok, err = pcall(writefile, path, HttpService:JSONEncode(payload))
	if not ok then return false, tostring(err) end
	self.Current = name
	return true
end
function Config:Load(name)
	name = self:Sanitize(name)
	local d = self:Info(name)
	if not d then return false, "Config not found or corrupted" end
	local flags = d.flags or d
	local applied, missing = self:Apply(flags)
	self.Current = name
	return true, { applied = applied, missing = missing }
end
function Config:Delete(name)
	if not self:Exists(name) or typeof(delfile) ~= "function" then return false end
	pcall(delfile, self:Path(name))
	pcall(function() if isfile(self:Path(name) .. ".bak") then delfile(self:Path(name) .. ".bak") end end)
	if self:GetAutoLoad() == name then self:ClearAutoLoad() end
	if self.Current == name then self.Current = nil end
	return true
end
function Config:Rename(old, new)
	new = self:Sanitize(new)
	if not self:Exists(old) or new == "" or self:Exists(new) then return false end
	writefile(self:Path(new), readfile(self:Path(old)))
	local wasAuto = self:GetAutoLoad() == old
	self:Delete(old)
	if wasAuto then self:SetAutoLoad(new) end
	if self.Current == old then self.Current = new end
	return true
end
function Config:Duplicate(name, new)
	new = self:Sanitize(new)
	if not self:Exists(name) or new == "" or self:Exists(new) then return false end
	writefile(self:Path(new), readfile(self:Path(name)))
	return true
end
function Config:Export(name)
	local flags = self:Snapshot()
	if name then
		local d = self:Info(name)
		if d then flags = d.flags or d end
	end
	return B64Encode(HttpService:JSONEncode({ version = self.Version, saved = os.time(), flags = flags }))
end
function Config:Decode(code)
	local ok, d = pcall(function() return HttpService:JSONDecode(B64Decode((code or ""):gsub("%s", ""))) end)
	if ok and type(d) == "table" and type(d.flags) == "table" then return d end
end
function Config:Import(code, name)
	local d = self:Decode(code)
	if not d then return false, "Invalid config code" end
	name = self:Sanitize(name)
	if name == "" then return false, "Enter a name for the imported config" end
	if not self:Ensure() then return false, "Executor has no file access" end
	d.name, d.saved = name, os.time()
	writefile(self:Path(name), HttpService:JSONEncode(d))
	return self:Load(name)
end
function Config:Reset()
	self.Loading = true
	for _, opt in pairs(Blush.Options) do
		if opt.Reset and not opt.NoSave then pcall(opt.Reset, opt) end
	end
	self.Loading = false
end
function Config:SetAutoLoad(name)
	if self:Ensure() then pcall(writefile, self:Root() .. "/autoload.txt", name or "") return true end
	return false
end
function Config:GetAutoLoad()
	if not self:Ensure() then return nil end
	local p = self:Root() .. "/autoload.txt"
	if isfile(p) then
		local n = readfile(p)
		if n ~= "" and self:Exists(n) then return n end
	end
end
function Config:ClearAutoLoad() return self:SetAutoLoad("") end
function Config:AutoLoad()
	local n = self:GetAutoLoad()
	if not n then return false end
	local ok, stats = self:Load(n)
	if ok then
		Blush:Notify({ Title = "Auto load", Content = string.format("Loaded \"%s\" (%d options)", n, stats.applied), Type = "Success", Duration = 3 })
	end
	return ok
end
function Config:_Dirty()
	if not self.AutoSave or not self.Current or self.Loading then return end
	self._token = (self._token or 0) + 1
	local t = self._token
	task.delay(1.5, function()
		if self._token == t and self.AutoSave and self.Current then self:Save(self.Current, true) end
	end)
end

local function Pct(n) return string.format("%02d", n) end

function Blush:_Init()
	if self.Gui then return end
	local gui = Create("ScreenGui", {
		Name = "Blush_" .. HttpService:GenerateGUID(false):sub(1, 6), ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10000,
	})
	gui.Parent = GetGuiParent()
	self.Gui = gui

	Connect(UserInputService.InputBegan, function(input, gp)
		local K = self.Listening
		if K then
			local t = input.UserInputType
			if t == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
				if input.KeyCode == Enum.KeyCode.Escape then K:_Bind(nil) else K:_Bind(input.KeyCode) end
			elseif t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3 then
				K:_Bind(t)
			end
			return
		end
		if gp then return end
		for _, w in ipairs(self.Windows) do
			if w.Keybind and InputMatches(input, w.Keybind) then w:SetOpen(not w.Open) end
		end
		for _, k in ipairs(self.Keybinds) do
			if not k.NoState and k.Key and InputMatches(input, k.Key) then
				if k.Mode == "Toggle" then k:SetState(not k.State)
				elseif k.Mode == "Hold" then k:SetState(true) end
			end
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if self._drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			self._drag(input.Position)
		end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if IsPress(input) then
			local e = self._dragEnd
			self._drag, self._dragEnd = nil, nil
			if e then e() end
		end
		for _, k in ipairs(self.Keybinds) do
			if k.Mode == "Hold" and not k.NoState and k.Key and InputMatches(input, k.Key) then k:SetState(false) end
		end
	end)

	self.NotifHolder = Frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0, 310, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	})
	local nl = List(self.NotifHolder, 8)
	nl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	nl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	self:_BuildHUD()
end

function Blush:_BuildHUD()
	local gui = self.Gui
	local lp = Players.LocalPlayer

	local wm = Frame({
		Name = "Watermark",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Panel,
		ClipsDescendants = true,
		Parent = gui,
	})
	Corner(wm, 8)
	Stroke(wm, Theme.Stroke, 1, .4)
	-- Full-width curved accent (clipped by parent corner)
	EngravedLine(wm, 2)
	local row = Frame({ Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Parent = wm })
	local rl = List(row, 9, Enum.FillDirection.Horizontal)
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	Pad(row, 4, 0, 14, 14)

	local order = 0
	local function seg(text, bold)
		order += 1
		return Label({
			Text = text,
			FontFace = bold and Fonts.Bold or Fonts.Medium,
			TextSize = bold and 13 or 12,
			TextColor3 = bold and WHITE or Theme.Text,
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = order,
			Parent = row,
		})
	end
	local function sep()
		order += 1
		Frame({
			Size = UDim2.fromOffset(1, 12),
			BackgroundColor3 = Theme.Stroke,
			BackgroundTransparency = .25,
			LayoutOrder = order,
			Parent = row,
		})
	end
	local title = seg("Blush", true)
	AccentGradient(title)
	sep()
	local nameLbl = seg(lp and lp.Name or "player")
	sep()
	local fpsLbl = seg("0 fps")
	sep()
	local pingLbl = seg("0 ms")
	sep()
	local timeLbl = seg("00:00")
	self.WatermarkFrame, self.WatermarkTitle = wm, title
	Draggable(wm, wm, true)

	local frames, acc, fps, ping = 0, 0, 60, 0
	local function refresh()
		pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + .5) end)
		local t = os.date("*t")
		fpsLbl.Text = fps .. " fps"
		pingLbl.Text = ping .. " ms"
		timeLbl.Text = Pct(t.hour) .. ":" .. Pct(t.min)
	end
	refresh()
	Connect(RunService.RenderStepped, function(dt)
		frames += 1 acc += dt
		if acc >= .5 then
			fps = math.floor(frames / acc + .5)
			frames, acc = 0, 0
			refresh()
		end
	end)

	local bl = Frame({
		Name = "Binds",
		Position = UDim2.fromOffset(16, 320),
		Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		ClipsDescendants = true,
		Visible = false,
		Parent = gui,
	})
	Corner(bl, 8)
	Stroke(bl, Theme.Stroke, 1, .4)
	List(bl, 0)
	EngravedLine(bl, 2)
	Label({
		Text = "Binds",
		FontFace = Fonts.Bold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
		Parent = bl,
	})
	local rows = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = bl })
	List(rows, 1)
	Pad(rows, 2, 10, 12, 12)
	self.BindListFrame, self.BindRows = bl, rows
	Draggable(bl, bl, true)
	self.BindListEnabled = false
end

function Blush:_RefreshBinds()
	local rows = self.BindRows
	if not rows then return end
	local want = {}
	for i, k in ipairs(self.Keybinds) do
		-- Show every bind that has a key assigned (always visible, not only when active)
		if k.Key and not k.NoList then want[k] = i end
	end
	for k, r in pairs(self._BindMap) do
		if not want[k] then
			self._BindMap[k] = nil
			r.Frame.ClipsDescendants = true
			Tween(r.Name, { TextTransparency = 1 }, .15)
			Tween(r.Mode, { TextTransparency = 1 }, .15)
			Tween(r.Key, { TextTransparency = 1 }, .15)
			Tween(r.Frame, { Size = UDim2.new(1, 0, 0, 0) }, .2)
			task.delay(.22, function() if r.Frame then r.Frame:Destroy() end end)
		end
	end
	for k, order in pairs(want) do
		local r = self._BindMap[k]
		local keyText = KeyName(k.Key)
		local modeText = k.Mode or "Toggle"
		local active = k.State
		if not r then
			local f = Frame({ Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order, ClipsDescendants = true, Parent = rows })
			local n = Label({
				Text = k.Name,
				FontFace = Fonts.Semi,
				TextSize = 12,
				TextTransparency = 1,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(.46, 0, 1, 0),
				Parent = f,
			})
			local m = Label({
				Text = modeText,
				FontFace = Fonts.Medium,
				TextColor3 = Theme.SubText,
				TextSize = 11,
				TextTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(.46, 0),
				Size = UDim2.fromScale(.28, 1),
				Parent = f,
			})
			local keyLbl = Label({
				Text = keyText,
				FontFace = Fonts.Semi,
				TextColor3 = Theme.Accent,
				TextSize = 11,
				TextTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(.74, 0),
				Size = UDim2.fromScale(.26, 1),
				Parent = f,
			})
			r = { Frame = f, Name = n, Mode = m, Key = keyLbl }
			self._BindMap[k] = r
			Tween(f, { Size = UDim2.new(1, 0, 0, 22) }, .25)
			Tween(n, { TextTransparency = 0 }, .25)
			Tween(m, { TextTransparency = 0 }, .25)
			Tween(keyLbl, { TextTransparency = 0 }, .25)
		end
		r.Frame.LayoutOrder = order
		r.Mode.Text = modeText
		r.Key.Text = keyText
		-- Dim inactive binds slightly so active ones stand out
		local nameCol = active and Theme.Text or Theme.SubText
		local modeCol = active and Theme.SubText or Color3.fromRGB(100, 106, 124)
		local keyCol = active and Theme.Accent or Color3.fromRGB(160, 90, 180)
		r.Name.TextColor3 = nameCol
		r.Mode.TextColor3 = modeCol
		r.Key.TextColor3 = keyCol
	end
end

function Blush:SetWatermark(b)
	self:_Init()
	self.WatermarkFrame.Visible = b
end
function Blush:SetWatermarkTitle(t)
	self:_Init()
	self.WatermarkTitle.Text = t
end
function Blush:SetBindList(b)
	self:_Init()
	self.BindListEnabled = b
	self.BindListFrame.Visible = b
	self:_RefreshBinds()
end

local NotifyColors = {
	Success = { Color3.fromRGB(90, 230, 150), Color3.fromRGB(40, 170, 110) },
	Warning = { Color3.fromRGB(255, 205, 90), Color3.fromRGB(235, 140, 50) },
	Error = { Color3.fromRGB(255, 100, 120), Color3.fromRGB(200, 50, 80) },
}

function Blush:Notify(o)
	if not self.Notifications then return end
	self:_Init()
	if type(o) == "string" then o = { Content = o } end
	o = o or {}
	local title, content, dur = o.Title or "Blush", o.Content or o.Text or "", o.Duration or 4
	local wrap = Frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = false,
		Parent = self.NotifHolder,
	})
	local card = Make("CanvasGroup", {
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Panel,
		GroupTransparency = 1,
		Position = UDim2.fromOffset(-360, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Parent = wrap,
	})
	Corner(card, 8)
	Stroke(card, Theme.Stroke, 1, .45)
	List(card, 0)
	local pal = NotifyColors[o.Type]
	local function tint(p)
		if pal then
			Create("UIGradient", { Color = ColorSequence.new(pal[1], pal[2]), Parent = p })
		else
			AccentGradient(p)
		end
	end
	-- Full-width curved top accent (clipped by card corner)
	local top = Frame({
		Size = UDim2.new(1, 0, 0, 2),
		LayoutOrder = 1,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = card,
	})
	tint(top)
	local topShade = Frame({
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 2,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = .68,
		BorderSizePixel = 0,
		Parent = card,
	})
	local text = Frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = card,
	})
	List(text, 3)
	Pad(text, 10, 12, 16, 16)
	Label({
		Text = title,
		FontFace = Fonts.Bold,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = text,
	})
	if content ~= "" then
		Label({
			Text = content,
			FontFace = Fonts.Medium,
			TextSize = 12,
			TextColor3 = Theme.SubText,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = text,
		})
	end
	local track = Frame({ Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 4, Parent = card })
	local fill = Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = track })
	tint(fill)
	local click = Button({ Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })

	local closed = false
	local function close()
		if closed then return end
		closed = true
		Tween(card, { Position = UDim2.fromOffset(-360, 0), GroupTransparency = 1 }, .35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(.28)
		if not wrap.Parent then return end
		wrap.ClipsDescendants = true
		wrap.AutomaticSize = Enum.AutomaticSize.None
		wrap.Size = UDim2.new(1, 0, 0, wrap.AbsoluteSize.Y)
		Tween(wrap, { Size = UDim2.new(1, 0, 0, 0) }, .2)
		task.wait(.22)
		wrap:Destroy()
	end
	click.MouseButton1Click:Connect(close)
	Tween(card, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, .45, Back)
	Tween(fill, { Size = UDim2.new(0, 0, 1, 0) }, dur, Linear)
	task.delay(dur, close)
end

local function MakeCollapse(content, inner, startOpen, onToggle)
	local Col = { Open = startOpen ~= false }
	local function target() return Col.Open and math.max(0, inner.AbsoluteSize.Y) or 0 end
	function Col:Refresh()
		content.Size = UDim2.new(1, 0, 0, target())
	end
	function Col:Set(open, animate)
		Col.Open = open
		local h = target()
		if animate then
			Tween(content, { Size = UDim2.new(1, 0, 0, h) }, .3)
			-- Keep parent scroll canvas in sync while collapsing/expanding
			task.spawn(function()
				local tab = Col._Tab
				for _ = 1, 12 do
					task.wait(0.03)
					if tab and tab._UpdateCanvas then tab._UpdateCanvas() end
				end
				if tab and tab._UpdateCanvas then tab._UpdateCanvas() end
			end)
		else
			Col:Refresh()
		end
		if onToggle then onToggle(open) end
	end
	inner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if Col.Open then Col:Refresh() end
	end)
	Col:Refresh()
	return Col
end

local Container = {}
Container.__index = Container

function Container:_Add(el, frame, name, o)
	o = o or {}
	setmetatable(el, Element)
	el.Frame, el.Name, el.Hidden, el.SearchHidden = frame, name or "", false, false
	el.Changed = {}
	el.Callback = o.Callback
	el.NoSave = o.NoSave
	local sec = self.Section
	Blush:_Flag(el, o.Flag or (sec.Tab.Name .. ": " .. sec.Name .. " / " .. (el.Name ~= "" and el.Name or el.Type)))
	table.insert(sec.Elements, el)
	return el
end

local function MakeRight(row)
	local r = Frame({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, 0, .5, 0), Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X, Parent = row })
	local l = List(r, 7, Enum.FillDirection.Horizontal)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	return r
end

local function MakeKeybind(container, parent, o, name, owner)
	local window = container.Window
	local K = setmetatable({ Type = "Keybind", Changed = {}, Callback = o.Callback, Name = o.Name or name or "Bind", Key = o.Default,
		Mode = o.Mode or "Toggle", State = false, NoList = o.NoList, NoState = o.NoState, Owner = owner, NoSave = o.NoSave,
		KeyChanged = o.KeyChanged }, Element)
	local btn = Button({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), BackgroundColor3 = Theme.Element,
		Text = KeyName(K.Key), TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center, Parent = parent })
	Corner(btn, 5)
	local st = Stroke(btn, Theme.Stroke, 1)
	Pad(btn, 0, 0, 7, 7)
	Create("UISizeConstraint", { MinSize = Vector2.new(26, 20), Parent = btn })
	Press(btn)
	btn.MouseEnter:Connect(function() if not K.Listening then Tween(btn, { BackgroundColor3 = Color3.fromRGB(54, 60, 76) }, .12) end end)
	btn.MouseLeave:Connect(function() if not K.Listening then Tween(btn, { BackgroundColor3 = Theme.Element }, .12) end end)
	table.insert(Blush.Keybinds, K)

	function K:_Bind(key)
		self.Listening = false
		Blush.Listening = nil
		Tween(btn, { BackgroundColor3 = Theme.Element }, .15)
		self:SetKey(key)
	end
	function K:SetKey(key)
		self.Key = key
		btn.Text = KeyName(key)
		Tween(btn, { TextColor3 = Theme.SubText }, .2)
		if not key and self.Mode ~= "Always" then self:SetState(false) end
		if self.KeyChanged then task.spawn(self.KeyChanged, key) end
		Config:_Dirty()
		Blush:_RefreshBinds()
	end
	function K:SetState(b)
		if self.State == b then return end
		self.State = b
		if self.Flag then Blush.Flags[self.Flag] = b end
		if self.Owner then self.Owner:SetValue(b) end
		self:_Fire(b)
		Blush:_RefreshBinds()
	end
	function K:_Sync(b)
		if self.State ~= b then
			self.State = b
			Blush:_RefreshBinds()
		end
	end
	function K:SetMode(m)
		local was = self.Mode
		self.Mode = m
		if m == "Always" then self:SetState(true) elseif was == "Always" then self:SetState(false) end
		Config:_Dirty()
		Blush:_RefreshBinds()
	end
	function K:Save() return { Key = SerializeKey(self.Key), Mode = self.Mode } end
	function K:Load(d)
		self:SetMode(d.Mode or self.Mode)
		self:SetKey(ParseKey(d.Key))
	end

	btn.MouseButton1Click:Connect(function()
		if Blush.Listening then return end
		K.Listening = true
		Blush.Listening = K
		btn.Text = "..."
		Tween(btn, { TextColor3 = Theme.Accent, BackgroundColor3 = Color3.fromRGB(54, 60, 76) }, .15)
	end)
	btn.MouseButton2Click:Connect(function()
		if K.NoState then return end
		local modes = { "Toggle", "Hold", "Always" }
		local pop = window:OpenPopup(btn, UDim2.fromOffset(96, #modes * 26 + 8))
		local lst = Frame({ Size = UDim2.fromScale(1, 1), Parent = pop })
		List(lst, 0) Pad(lst, 4, 4, 4, 4)
		for _, m in ipairs(modes) do
			local b = Button({ Size = UDim2.new(1, 0, 0, 26), Text = m, TextSize = 13, BackgroundColor3 = Theme.Element, BackgroundTransparency = 1,
				TextColor3 = K.Mode == m and Theme.Accent or Theme.Text, Parent = lst })
			Corner(b, 4) Pad(b, 0, 0, 9, 0)
			b.MouseEnter:Connect(function() Tween(b, { BackgroundTransparency = .35 }, .1) end)
			b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = 1 }, .1) end)
			b.MouseButton1Click:Connect(function() K:SetMode(m) window:ClosePopup() end)
		end
	end)
	if K.Mode == "Always" and not K.NoState then K.State = true end
	return K
end

local function MakeColorpicker(container, parent, o)
	local window = container.Window
	local C = setmetatable({ Type = "Colorpicker", Changed = {}, Callback = o.Callback, NoSave = o.NoSave }, Element)
	C.H, C.S, C.V = Color3.toHSV(o.Default or Color3.fromRGB(255, 255, 255))
	C.A = o.Alpha or 1
	local useAlpha = o.Transparency == true or o.UseAlpha == true
	C.Value = Color3.fromHSV(C.H, C.S, C.V)

	local swatch = Button({ Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.Value, Parent = parent })
	Corner(swatch, 9)
	local sst = Stroke(swatch, WHITE, 1, .6)
	Press(swatch)
	swatch.MouseEnter:Connect(function() Tween(sst, { Transparency = .1 }, .15) end)
	swatch.MouseLeave:Connect(function() Tween(sst, { Transparency = .6 }, .15) end)

	function C:_Apply(silent)
		self.Value = Color3.fromHSV(self.H, self.S, self.V)
		Tween(swatch, { BackgroundColor3 = self.Value }, .08)
		if self.Flag then Blush.Flags[self.Flag] = self.Value end
		if self._refresh then self._refresh() end
		if not silent then self:_Fire(self.Value, self.A) end
	end
	function C:SetValue(c, a, silent)
		self.H, self.S, self.V = Color3.toHSV(c)
		if a then self.A = a end
		self:_Apply(silent)
	end
	function C:Save() return { Hex = self.Value:ToHex(), A = self.A } end
	function C:Load(d) self:SetValue(Color3.fromHex(d.Hex), d.A) end

	swatch.MouseButton1Click:Connect(function()
		local hexY = useAlpha and 164 or 146
		local pop = window:OpenPopup(swatch, UDim2.fromOffset(204, hexY + 32), function() C._refresh = nil end)
		local sv = Frame({ Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(184, 110), BackgroundColor3 = WHITE, Parent = pop })
		Corner(sv, 5)
		local wh = Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = sv })
		Corner(wh, 5) Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = wh })
		local bk = Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
		Corner(bk, 5) Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = bk })
		local svCur = Frame({ AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = sv })
		Corner(svCur, 6) Stroke(svCur, WHITE, 2)

		local hue = Frame({ Position = UDim2.fromOffset(10, 128), Size = UDim2.fromOffset(184, 10), BackgroundColor3 = WHITE, Parent = pop })
		Corner(hue, 5)
		local kps = {}
		for i = 0, 6 do table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))) end
		Create("UIGradient", { Color = ColorSequence.new(kps), Parent = hue })
		local hueCur = Frame({ AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(0, .5), Size = UDim2.fromOffset(4, 14), BackgroundColor3 = WHITE, Parent = hue })
		Corner(hueCur, 2) Stroke(hueCur, Color3.new(0, 0, 0), 1, .5)

		local alphaBar, alphaCur
		if useAlpha then
			alphaBar = Frame({ Position = UDim2.fromOffset(10, 146), Size = UDim2.fromOffset(184, 10), BackgroundColor3 = C.Value, Parent = pop })
			Corner(alphaBar, 5) Create("UIGradient", { Transparency = NumberSequence.new(1, 0), Parent = alphaBar })
			Stroke(alphaBar, Theme.Stroke, 1)
			alphaCur = Frame({ AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(4, 14), BackgroundColor3 = WHITE, Parent = alphaBar })
			Corner(alphaCur, 2) Stroke(alphaCur, Color3.new(0, 0, 0), 1, .5)
		end
		local hex = Input({ Position = UDim2.fromOffset(10, hexY), Size = UDim2.fromOffset(184, 24), BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Element, TextXAlignment = Enum.TextXAlignment.Center, Parent = pop })
		Corner(hex, 5) Stroke(hex, Theme.Stroke, 1)

		C._refresh = function()
			sv.BackgroundColor3 = Color3.fromHSV(C.H, 1, 1)
			svCur.Position = UDim2.fromScale(C.S, 1 - C.V)
			hueCur.Position = UDim2.fromScale(C.H, .5)
			if alphaBar then alphaBar.BackgroundColor3 = C.Value alphaCur.Position = UDim2.fromScale(C.A, .5) end
			if not hex:IsFocused() then hex.Text = "#" .. C.Value:ToHex():upper() end
		end
		MakeDrag(sv, function(p)
			C.S = math.clamp((p.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			C.V = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
			C:_Apply()
		end)
		MakeDrag(hue, function(p)
			C.H = math.clamp((p.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, .999)
			C:_Apply()
		end)
		if alphaBar then
			MakeDrag(alphaBar, function(p)
				C.A = math.clamp((p.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
				C:_Apply()
			end)
		end
		hex.FocusLost:Connect(function()
			local ok, c = pcall(Color3.fromHex, hex.Text)
			if ok and c then C:SetValue(c) end
			if C._refresh then C._refresh() end
		end)
		C._refresh()
	end)

	C:_Apply(true)
	return C
end

local function Attachable(el, row, container)
	local right
	function el:AddKeybind(o)
		o = o or {}
		right = right or MakeRight(row)
		o.Name = o.Name or self.Name
		local k = MakeKeybind(container, right, o, self.Name, self.Type == "Toggle" and self or nil)
		Blush:_Flag(k, o.Flag or (self.Flag and self.Flag .. "_Key"))
		if self.Type == "Toggle" then self.Keybind = k end
		return Done(k)
	end
	function el:AddColorpicker(o)
		o = o or {}
		right = right or MakeRight(row)
		local c = MakeColorpicker(container, right, o)
		Blush:_Flag(c, o.Flag or (self.Flag and self.Flag .. "_Color"))
		return Done(c)
	end
end

function Container:AddLabel(o)
	if type(o) == "string" then o = { Text = o } end
	o = o or {}
	local L = { Type = "Label" }
	local row = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Inner })
	local lbl = Label({ Text = o.Text or "", TextColor3 = o.Color or Theme.Text, TextWrapped = true, Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
	self:_Add(L, row, o.Text, { NoSave = true, Flag = o.Flag })
	function L:SetText(t) lbl.Text = t self.Name = t end
	Attachable(L, row, self)
	return L
end

function Container:AddDivider()
	return Frame({ Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = .4, Parent = self.Inner })
end

function Container:AddToggle(o)
	o = o or {}
	local T = { Type = "Toggle", Value = false }
	local row = Frame({ Size = UDim2.new(1, 0, 0, 24), Parent = self.Inner })
	local box = Frame({
		AnchorPoint = Vector2.new(0, .5),
		Position = UDim2.fromScale(0, .5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Theme.Element,
		Parent = row,
	})
	Corner(box, 5)
	local bs = Stroke(box, Theme.Stroke, 1)
	local bscale = Create("UIScale", { Parent = box })
	local fill = Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = box })
	Corner(fill, 5)
	AccentGradient(fill, 45)
	-- Clean checkmark glyph (avoids awkward two-frame geometry)
	local tick = Label({
		Text = "✓",
		FontFace = Fonts.Bold,
		TextSize = 13,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(18, 18),
		Parent = box,
	})
	local tscale = Create("UIScale", { Scale = 0, Parent = tick })
	local lbl = Label({
		Text = o.Name or "",
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -28, 1, 0),
		TextColor3 = Theme.SubText,
		Parent = row,
	})
	local hit = Button({ Size = UDim2.fromScale(1, 1), Parent = row })
	self:_Add(T, row, o.Name, o)

	function T:SetValue(v, silent)
		v = v and true or false
		local changed = self.Value ~= v
		self.Value = v
		Tween(fill, { BackgroundTransparency = v and 0 or 1 }, .2)
		Tween(bs, { Transparency = v and 1 or 0 }, .2)
		Tween(lbl, { TextColor3 = v and Theme.Text or Theme.SubText }, .2)
		Tween(tscale, { Scale = v and 1 or 0 }, v and .35 or .12, v and Back or Quint)
		if self.Flag then Blush.Flags[self.Flag] = v end
		if self.Keybind then self.Keybind:_Sync(v) end
		if changed and not silent then self:_Fire(v) end
	end
	function T:Save() return self.Value end
	function T:Load(v) self:SetValue(v == true) end
	hit.MouseEnter:Connect(function() if not T.Value then Tween(bs, { Color = Theme.Accent2 }, .15) end end)
	hit.MouseLeave:Connect(function() Tween(bs, { Color = Theme.Stroke }, .15) end)
	hit.MouseButton1Down:Connect(function() Tween(bscale, { Scale = .88 }, .08) end)
	local function up() Tween(bscale, { Scale = 1 }, .3, Back) end
	hit.MouseButton1Up:Connect(up)
	hit.MouseLeave:Connect(up)
	hit.MouseButton1Click:Connect(function() T:SetValue(not T.Value) end)
	Attachable(T, row, self)
	T:SetValue(o.Default, true)
	return Done(T)
end

function Container:AddSlider(o)
	o = o or {}
	local S = { Type = "Slider", Min = o.Min or 0, Max = o.Max or 100, Rounding = o.Rounding or 0 }
	local row = Frame({ Size = UDim2.new(1, 0, 0, 38), Parent = self.Inner })
	Label({ Text = o.Name or "", Size = UDim2.new(.6, 0, 0, 18), Parent = row })
	local val = Button({ Text = "", TextSize = 12, FontFace = Fonts.Medium, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(110, 18), Parent = row })
	local edit = Input({ Visible = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -1), Size = UDim2.fromOffset(70, 20),
		BackgroundTransparency = 0, BackgroundColor3 = Theme.Element, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
	Corner(edit, 4)
	Stroke(edit, Theme.Stroke, 1)
	local track = Frame({ Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Theme.Element, Parent = row })
	Corner(track, 2)
	local fill = Frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = track })
	Corner(fill, 2) AccentGradient(fill)
	local knob = Frame({ AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(0, .5), Size = UDim2.fromOffset(0, 0), BackgroundColor3 = WHITE, Parent = track })
	Corner(knob, 6)
	local hit = Button({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 20), Parent = row })
	self:_Add(S, row, o.Name, o)

	local function fmt(v)
		if o.Format then return o.Format(v) end
		if o.Custom and o.Custom[v] ~= nil then return o.Custom[v] end
		return (o.Prefix or "") .. tostring(v) .. (o.Suffix or "")
	end
	function S:SetValue(v, silent)
		v = math.clamp(tonumber(v) or self.Min, self.Min, self.Max)
		local m = 10 ^ self.Rounding
		v = math.floor(v * m + .5) / m
		local changed = self.Value ~= v
		self.Value = v
		local pct = (v - self.Min) / math.max(self.Max - self.Min, 1e-9)
		Tween(fill, { Size = UDim2.fromScale(pct, 1) }, .12, Sine)
		Tween(knob, { Position = UDim2.fromScale(pct, .5) }, .12, Sine)
		val.Text = fmt(v)
		if self.Flag then Blush.Flags[self.Flag] = v end
		if changed and not silent then self:_Fire(v) end
	end
	function S:Save() return self.Value end
	function S:Load(v) self:SetValue(v) end

	local hover, dragging = false, false
	local function knobState() Tween(knob, { Size = (hover or dragging) and UDim2.fromOffset(12, 12) or UDim2.fromOffset(0, 0) }, .2, Back) end
	hit.MouseEnter:Connect(function() hover = true knobState() end)
	hit.MouseLeave:Connect(function() hover = false knobState() end)
	MakeDrag(hit, function(p)
		dragging = true
		knobState()
		local pct = math.clamp((p.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		S:SetValue(S.Min + (S.Max - S.Min) * pct)
	end, function() dragging = false knobState() end)

	val.MouseEnter:Connect(function() Tween(val, { TextColor3 = Theme.Text }, .15) end)
	val.MouseLeave:Connect(function() Tween(val, { TextColor3 = Theme.SubText }, .15) end)
	val.MouseButton1Click:Connect(function()
		val.Visible = false
		edit.Visible = true
		edit.Text = tostring(S.Value)
		edit:CaptureFocus()
		edit.SelectionStart, edit.CursorPosition = 1, #edit.Text + 1
	end)
	edit.FocusLost:Connect(function()
		local txt = edit.Text
		local n = tonumber(txt:match("-?%d+%.?%d*"))
		if o.Custom then
			for v, t in pairs(o.Custom) do
				if tostring(t):lower() == txt:lower() then n = v end
			end
		end
		if n then S:SetValue(n) end
		edit.Visible = false
		val.Visible = true
	end)
	S:SetValue(o.Default or S.Min, true)
	return Done(S)
end

local function MakeButton(parent, o, size)
	local b = Button({ Size = size or UDim2.new(1, 0, 0, 28), BackgroundColor3 = Theme.Element, Text = o.Name or "Button",
		TextXAlignment = Enum.TextXAlignment.Center, Parent = parent })
	Corner(b, 5)
	local st = Stroke(b, Theme.Stroke, 1)
	Press(b)
	b.MouseEnter:Connect(function()
		Tween(b, { BackgroundColor3 = Color3.fromRGB(56, 62, 78) }, .15)
	end)
	b.MouseLeave:Connect(function()
		Tween(b, { BackgroundColor3 = Theme.Element }, .15)
	end)
	local armed = false
	b.MouseButton1Click:Connect(function()
		if o.Confirm and not armed then
			armed = true
			b.Text = "Confirm?"
			Tween(b, { TextColor3 = Theme.Accent }, .15)
			task.delay(2.5, function()
				if armed then
					armed = false
					b.Text = o.Name
					Tween(b, { TextColor3 = Theme.Text }, .2)
				end
			end)
			return
		end
		armed = false
		b.Text = o.Name
		b.TextColor3 = Theme.Text
		b.BackgroundColor3 = Theme.Accent2
		Tween(b, { BackgroundColor3 = Theme.Element }, .45)
		if o.Callback then task.spawn(o.Callback) end
	end)
	return b
end

function Container:AddButton(o)
	o = o or {}
	local B = { Type = "Button" }
	local b = MakeButton(self.Inner, o)
	self:_Add(B, b, o.Name, { Callback = o.Callback, Flag = o.Flag, NoSave = true })
	function B:SetText(t) b.Text = t end
	return B
end

function Container:AddButtonRow(buttons)
	local n = #buttons
	local row = Frame({ Size = UDim2.new(1, 0, 0, 28), Parent = self.Inner })
	List(row, 6, Enum.FillDirection.Horizontal)
	local names = {}
	for i, o in ipairs(buttons) do
		table.insert(names, o.Name or "")
		MakeButton(row, o, UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0)).LayoutOrder = i
	end
	local B = { Type = "ButtonRow" }
	self:_Add(B, row, table.concat(names, " "), { NoSave = true })
	return B
end

function Container:AddTextbox(o)
	o = o or {}
	local T = { Type = "Textbox", Value = "" }
	local row = Frame({ Size = UDim2.new(1, 0, 0, o.Name and 50 or 28), Parent = self.Inner })
	if o.Name then Label({ Text = o.Name, FontFace = Fonts.Bold, Size = UDim2.new(1, 0, 0, 18), Parent = row }) end
	local box = Input({ Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Element, PlaceholderText = o.Placeholder or "", PlaceholderColor3 = Theme.SubText, ClipsDescendants = true, Parent = row })
	Corner(box, 5) Pad(box, 0, 0, 10, 10)
	Stroke(box, Theme.Stroke, 1)
	-- No purple border on focus — slight background lift only
	box.Focused:Connect(function() Tween(box, { BackgroundColor3 = Color3.fromRGB(54, 60, 76) }, .15) end)
	self:_Add(T, row, o.Name, o)
	function T:SetValue(v, silent)
		v = tostring(v or "")
		if o.Numeric then v = v:gsub("[^%d%.%-]", "") end
		self.Value = v
		box.Text = v
		if self.Flag then Blush.Flags[self.Flag] = v end
		if not silent then self:_Fire(v) end
	end
	function T:Save() return self.Value end
	function T:Load(v) self:SetValue(v) end
	box.FocusLost:Connect(function()
		Tween(box, { BackgroundColor3 = Theme.Element }, .15)
		T:SetValue(box.Text)
	end)
	T:SetValue(o.Default, true)
	return Done(T)
end

function Container:AddKeybind(o)
	o = o or {}
	local row = Frame({ Size = UDim2.new(1, 0, 0, 24), Parent = self.Inner })
	Label({ Text = o.Name or "Keybind", TextColor3 = Theme.SubText, Size = UDim2.new(1, 0, 1, 0), Parent = row })
	local right = MakeRight(row)
	o.Mode = o.Mode or "Hold"
	local K = MakeKeybind(self, right, o, o.Name or "Keybind")
	self:_Add(K, row, o.Name or "Keybind", o)
	return Done(K)
end

function Container:AddColorpicker(o)
	o = o or {}
	local row = Frame({ Size = UDim2.new(1, 0, 0, 24), Parent = self.Inner })
	Label({ Text = o.Name or "Color", TextColor3 = Theme.SubText, Size = UDim2.new(1, 0, 1, 0), Parent = row })
	local right = MakeRight(row)
	local C = MakeColorpicker(self, right, o)
	self:_Add(C, row, o.Name or "Color", o)
	return Done(C)
end

function Container:AddDropdown(o)
	o = o or {}
	local window = self.Window
	local D = { Type = "Dropdown", Values = o.Values or {}, Multi = o.Multi, Value = o.Multi and {} or nil }
	local row = Frame({ Size = UDim2.new(1, 0, 0, o.Name and 50 or 30), Parent = self.Inner })
	if o.Name then Label({ Text = o.Name, FontFace = Fonts.Bold, Size = UDim2.new(1, 0, 0, 18), Parent = row }) end
	local box = Button({ Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Element, Parent = row })
	Corner(box, 5)
	local st = Stroke(box, Theme.Stroke, 1)
	Press(box)
	local txt = Label({ Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -36, 1, 0), TextColor3 = Theme.SubText, TextTruncate = Enum.TextTruncate.AtEnd, Parent = box })
	local arrow = Label({ Text = o.Multi and "+" or "▼", TextSize = o.Multi and 18 or 8, TextColor3 = Theme.SubText, AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.new(1, -15, .5, 0), Size = UDim2.fromOffset(14, 14), TextXAlignment = Enum.TextXAlignment.Center, Parent = box })
	self:_Add(D, row, o.Name, o)

	local function selected()
		local out = {}
		for _, v in ipairs(D.Values) do if D.Value[v] then table.insert(out, v) end end
		return out
	end
	local function paintText()
		local t
		if D.Multi then
			local s = selected()
			t = #s > 0 and table.concat(s, ", ") or "None"
		else
			t = D.Value and tostring(D.Value) or "None"
		end
		txt.Text = t
		Tween(txt, { TextColor3 = t == "None" and Theme.SubText or Theme.Text }, .2)
	end
	function D:SetValue(v, silent)
		if self.Multi then
			local map = {}
			if type(v) == "table" then
				for k, val in pairs(v) do
					if type(k) == "number" then map[val] = true elseif val then map[k] = true end
				end
			end
			self.Value = map
		else
			self.Value = v
		end
		paintText()
		if self.Flag then Blush.Flags[self.Flag] = self.Value end
		if not silent then self:_Fire(self.Value) end
	end
	function D:SetValues(list)
		self.Values = list
		if self.Multi then
			local m = {}
			for _, v in ipairs(list) do if self.Value[v] then m[v] = true end end
			self.Value = m
		elseif not table.find(list, self.Value) then
			self.Value = nil
		end
		paintText()
	end
	function D:GetList() return self.Multi and selected() or { self.Value } end
	function D:Save() if self.Multi then return selected() end return self.Value end
	function D:Load(v) self:SetValue(v) end

	-- No purple/accent border on hover or selection — keep neutral stroke always
	box.MouseEnter:Connect(function() Tween(box, { BackgroundColor3 = Color3.fromRGB(54, 60, 76) }, .12) end)
	box.MouseLeave:Connect(function() Tween(box, { BackgroundColor3 = Theme.Element }, .12) end)
	box.MouseButton1Click:Connect(function()
		if D.IsOpen then window:ClosePopup() return end
		D.IsOpen = true
		-- Size tightly to actual option count (no empty space)
		local count = math.max(#D.Values, 1)
		local rows = math.min(count, o.MaxVisible or 8)
		local searchH = o.Search and 34 or 0
		local itemH = 26
		local padH = 10
		local h = searchH + rows * itemH + padH
		local popW = box.AbsoluteSize.X / math.max(window.Scale.Scale, .01)
		local pop = window:OpenPopup(box, UDim2.fromOffset(popW, h), function()
			D.IsOpen = false
			Tween(arrow, { Rotation = 0 }, .25)
			Tween(box, { BackgroundColor3 = Theme.Element }, .12)
		end)
		Tween(arrow, { Rotation = o.Multi and 45 or 180 }, .25)
		local sb
		if o.Search then
			sb = Input({ Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 0, 24), BackgroundTransparency = 0, BackgroundColor3 = Theme.Element,
				PlaceholderText = "Search...", PlaceholderColor3 = Theme.SubText, TextSize = 12, Parent = pop })
			Corner(sb, 4) Pad(sb, 0, 0, 9, 9)
		end
		local lst = Make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, searchH + 5),
			Size = UDim2.new(1, 0, 1, -(searchH + 10)), ScrollBarThickness = 0, ScrollBarImageTransparency = 1,
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = pop })
		List(lst, 0) Pad(lst, 0, 0, 5, 5)
		local btns = {}
		local function paint()
			for v, b in pairs(btns) do
				local on = D.Multi and D.Value[v] or D.Value == v
				Tween(b, { TextColor3 = on and Theme.Accent or Theme.Text }, .15)
			end
		end
		local function populate(filter)
			for _, c in pairs(btns) do c:Destroy() end
			btns = {}
			for i, v in ipairs(D.Values) do
				if not filter or filter == "" or tostring(v):lower():find(filter:lower(), 1, true) then
					local b = Button({ Size = UDim2.new(1, 0, 0, 26), Text = tostring(v), TextSize = 13, BackgroundColor3 = Theme.Element, BackgroundTransparency = 1, LayoutOrder = i, Parent = lst })
					Corner(b, 4) Pad(b, 0, 0, 9, 0)
					b.MouseEnter:Connect(function() Tween(b, { BackgroundTransparency = .4 }, .1) end)
					b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = 1 }, .1) end)
					b.MouseButton1Click:Connect(function()
						if D.Multi then
							local m = table.clone(D.Value)
							m[v] = not m[v] or nil
							D:SetValue(m)
							paint()
						else
							D:SetValue(v)
							window:ClosePopup()
						end
					end)
					btns[v] = b
				end
			end
			for v, b in pairs(btns) do
				local on = D.Multi and D.Value[v] or D.Value == v
				b.TextColor3 = on and Theme.Accent or Theme.Text
			end
		end
		populate()
		if sb then sb:GetPropertyChangedSignal("Text"):Connect(function() populate(sb.Text) end) end
	end)
	if o.Multi then D:SetValue(o.Default or {}, true) else D:SetValue(o.Default, true) end
	return Done(D)
end

function Container:AddList(o)
	o = o or {}
	local rowsN = o.Rows or 5
	local L = { Type = "List", Items = {}, Value = nil, OnDoubleClick = o.OnDoubleClick }
	local nameH = o.Name and 20 or 0
	local row = Frame({ Size = UDim2.new(1, 0, 0, nameH + rowsN * 26 + 10), Parent = self.Inner })
	if o.Name then Label({ Text = o.Name, FontFace = Fonts.Bold, Size = UDim2.new(1, 0, 0, 18), Parent = row }) end
	local box = Frame({ Position = UDim2.fromOffset(0, nameH), Size = UDim2.new(1, 0, 1, -nameH), BackgroundColor3 = Theme.Element, ClipsDescendants = true, Parent = row })
	Corner(box, 5) Stroke(box, Theme.Stroke, 1)
	local scroll = Make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = box })
	List(scroll, 2) Pad(scroll, 5, 5, 5, 5)
	local empty = Label({ Text = o.Empty or "Nothing here yet", TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = box })
	self:_Add(L, row, o.Name, { NoSave = true, Flag = o.Flag })
	local btns, lastClick, lastName = {}, 0, nil

	local function paint()
		for n, b in pairs(btns) do
			local on = n == L.Value
			Tween(b.Frame, { BackgroundTransparency = on and 0 or 1 }, .15)
			Tween(b.Bar, { BackgroundTransparency = on and 0 or 1 }, .15)
			Tween(b.Name, { TextColor3 = on and Theme.Text or Theme.SubText }, .15)
		end
	end
	function L:Select(name, silent)
		self.Value = name
		paint()
		if not silent and self.Callback then task.spawn(self.Callback, name) end
	end
	function L:SetItems(items)
		for _, b in pairs(btns) do b.Frame:Destroy() end
		btns = {}
		self.Items = items
		empty.Visible = #items == 0
		local keep = false
		for i, it in ipairs(items) do
			if type(it) == "string" then it = { Name = it } end
			local f = Button({ Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.fromRGB(62, 69, 88), BackgroundTransparency = 1, LayoutOrder = i, Text = "", Parent = scroll })
			Corner(f, 4)
			local bar = Frame({ AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 0, .5, 0), Size = UDim2.fromOffset(2, 12), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = f })
			Corner(bar, 1) AccentGradient(bar, 90)
			local n = Label({ Text = it.Name, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(.6, -10, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = f })
			local r = Label({ Text = it.Right or "", FontFace = Fonts.Medium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(.6, 0), Size = UDim2.new(.4, -8, 1, 0), Parent = f })
			if it.Tag then
				local tag = Label({ Text = it.Tag, FontFace = Fonts.Bold, TextSize = 10, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center,
					BackgroundTransparency = 0, BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -8, .5, 0), Size = UDim2.fromOffset(38, 14), Parent = f })
				Corner(tag, 7) AccentGradient(tag)
				r.Size = UDim2.new(.4, -52, 1, 0)
				r.Position = UDim2.new(.6, 0, 0, 0)
			end
			f.MouseEnter:Connect(function() if L.Value ~= it.Name then Tween(f, { BackgroundTransparency = .6 }, .12) end end)
			f.MouseLeave:Connect(function() if L.Value ~= it.Name then Tween(f, { BackgroundTransparency = 1 }, .12) end end)
			f.MouseButton1Click:Connect(function()
				local now = os.clock()
				if lastName == it.Name and now - lastClick < .35 and L.OnDoubleClick then task.spawn(L.OnDoubleClick, it.Name) end
				lastName, lastClick = it.Name, now
				L:Select(it.Name)
			end)
			btns[it.Name] = { Frame = f, Bar = bar, Name = n }
			if it.Name == self.Value then keep = true end
		end
		if not keep then self.Value = nil end
		paint()
	end
	function L:GetSelected() return self.Value end
	L:SetItems(o.Items or {})
	return L
end

function Container:AddColumns(n, pad)
	n, pad = n or 2, pad or 10
	local row = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Inner })
	List(row, pad, Enum.FillDirection.Horizontal)
	local cols = {}
	for i = 1, n do
		local f = Frame({ Size = UDim2.new(1 / n, -pad * (n - 1) / n, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = row })
		List(f, 8)
		cols[i] = setmetatable({ Inner = f, Window = self.Window, Section = self.Section, Tab = self.Tab }, Container)
	end
	return table.unpack(cols)
end

function Container:AddFold(o)
	o = o or {}
	local row = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Inner })
	List(row, 4)
	local head = Button({ Size = UDim2.new(1, 0, 0, 22), Parent = row })
	local arrow = Label({ Text = "▼", TextSize = 8, TextColor3 = Theme.SubText, AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 0, .5, 0),
		Size = UDim2.fromOffset(12, 12), TextXAlignment = Enum.TextXAlignment.Center, Parent = head })
	local nm = Label({ Text = o.Name or "Group", FontFace = Fonts.Bold, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -18, 1, 0), Parent = head })
	head.MouseEnter:Connect(function() Tween(nm, { TextColor3 = Theme.Text }, .15) end)
	head.MouseLeave:Connect(function() Tween(nm, { TextColor3 = Theme.SubText }, .15) end)
	local content = Frame({ Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, LayoutOrder = 2, Parent = row })
	local inner = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	List(inner, 8) Pad(inner, 2, 4, 14, 0)
	Frame({ Position = UDim2.fromOffset(4, 2), Size = UDim2.new(0, 1, 1, -6), BackgroundColor3 = Theme.Stroke, Parent = inner })
	local fold = setmetatable({ Inner = inner, Window = self.Window, Section = self.Section, Tab = self.Tab }, Container)
	local open = o.Open ~= false
	fold.Collapse = MakeCollapse(content, inner, open, function(v) Tween(arrow, { Rotation = v and 0 or -90 }, .25) end)
	fold.Collapse._Tab = self.Tab or self.Window and self.Window.ActiveTab
	arrow.Rotation = open and 0 or -90
	head.MouseButton1Click:Connect(function() fold.Collapse:Set(not fold.Collapse.Open, true) end)
	return fold
end

local TabMethods = {}
TabMethods.__index = TabMethods

function TabMethods:AddSection(o)
	o = o or {}
	local side = (o.Side or "Left"):lower()
	local parent = side == "right" and self.Right or side == "full" and self.Top or self.Left
	local S = setmetatable({ Name = o.Name or "", Tab = self, Window = self.Window, Elements = {} }, Container)
	S.Section = S
	local wrap = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent })
	local frame = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Panel, Parent = wrap })
	Corner(frame, 7)
	Stroke(frame, Theme.Stroke, 1, .75)
	-- Soft bottom gradient shadow (small, clean — fades out instead of a hard box)
	local sh = Frame({
		AnchorPoint = Vector2.new(.5, 0),
		Position = UDim2.new(.5, 0, 1, 0),
		Size = UDim2.new(1, -10, 0, 7),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = .55,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = wrap,
	})
	Corner(sh, 5)
	Create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, .25),
			NumberSequenceKeypoint.new(.55, .7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = sh,
	})
	List(frame, 0)
	local named = S.Name ~= ""
	local title = Button({ Size = UDim2.new(1, 0, 0, named and 36 or 8), Text = S.Name, FontFace = Fonts.Bold, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = frame })
	local arrow
	if named then
		arrow = Label({ Text = "▼", TextSize = 8, TextColor3 = Theme.SubText, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -14, .5, 0),
			Size = UDim2.fromOffset(12, 12), TextXAlignment = Enum.TextXAlignment.Center, Parent = title })
		local lineRow = Frame({ Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, Parent = frame })
		local line = Frame({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = .35, Parent = lineRow })
		Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.2, 0), NumberSequenceKeypoint.new(.8, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = line })
		title.MouseEnter:Connect(function() Tween(title, { TextColor3 = WHITE }, .15) Tween(arrow, { TextColor3 = Theme.Text }, .15) end)
		title.MouseLeave:Connect(function() Tween(title, { TextColor3 = Theme.Text }, .15) Tween(arrow, { TextColor3 = Theme.SubText }, .15) end)
	end
	local content = Frame({ Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, LayoutOrder = 3, Parent = frame })
	local inner = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	List(inner, 9) Pad(inner, named and 10 or 2, 14, 14, 14)
	S.Frame, S.Wrap, S.Inner = frame, wrap, inner
	S.Collapse = MakeCollapse(content, inner, o.Open ~= false, function(v) if arrow then Tween(arrow, { Rotation = v and 0 or -90 }, .25) end end)
	S.Collapse._Tab = self
	if arrow and o.Open == false then arrow.Rotation = -90 end
	if named and o.Collapsible ~= false then
		title.MouseButton1Click:Connect(function() S.Collapse:Set(not S.Collapse.Open, true) end)
	end
	table.insert(self.Sections, S)
	return S
end

function TabMethods:Select()
	local w = self.Window
	local prev = w.ActiveTab
	if prev == self then return end
	w:ClosePopup()
	local dir = prev and (self.Index > prev.Index and 1 or -1) or 0
	if prev then
		prev.SetIcon(false)
		local pg = prev.Page
		Tween(pg, { GroupTransparency = 1, Position = UDim2.fromOffset(-18 * dir, 0) }, .2)
		task.delay(.21, function() if w.ActiveTab ~= prev then pg.Visible = false end end)
	end
	w.ActiveTab = self
	self.SetIcon(true)
	self.Page.Visible = true
	self.Page.GroupTransparency = 1
	self.Page.Position = UDim2.fromOffset(18 * dir, 0)
	Tween(self.Page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, .4)
	for _, s in ipairs(self.Sections) do s.Collapse:Refresh() end
	if self._UpdateCanvas then task.defer(self._UpdateCanvas) end
	w:_MoveIndicator(self, prev == nil)
end

local Window = {}
Window.__index = Window

function Window:ClosePopup()
	local p = self.Popup
	if not p then return end
	self.Popup = nil
	p.Blocker:Destroy()
	if p.OnClose then task.spawn(p.OnClose) end
	local f = p.Frame
	Tween(f, { Size = UDim2.new(0, f.Size.X.Offset, 0, 0) }, .16)
	task.delay(.18, function() f:Destroy() end)
end

function Window:OpenPopup(anchor, size, onClose)
	self:ClosePopup()
	local ov = self.Overlay
	local blocker = Button({ Size = UDim2.fromScale(1, 1), Parent = ov })
	blocker.MouseButton1Click:Connect(function() self:ClosePopup() end)
	blocker.MouseButton2Click:Connect(function() self:ClosePopup() end)
	local sc = math.max(self.Scale.Scale, .01)
	local ap = (anchor.AbsolutePosition - ov.AbsolutePosition) / sc
	local as = anchor.AbsoluteSize / sc
	local ovs = ov.AbsoluteSize / sc
	local w, h = size.X.Offset, size.Y.Offset
	-- Center the popup horizontally under the anchor
	local x = math.clamp(ap.X + (as.X - w) / 2, 4, math.max(4, ovs.X - w - 4))
	local y = ap.Y + as.Y + 5
	if y + h > ovs.Y - 4 then y = math.max(4, ap.Y - h - 5) end
	local pop = Frame({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, 0),
		BackgroundColor3 = Theme.Panel,
		ClipsDescendants = true,
		Parent = ov,
	})
	Corner(pop, 6)
	Stroke(pop, Theme.Stroke, 1, .2)
	Tween(pop, { Size = UDim2.fromOffset(w, h) }, .22)
	self.Popup = { Blocker = blocker, Frame = pop, OnClose = onClose }
	return pop
end

function Window:_MoveIndicator(tab, instant)
	if not tab or not tab.Button then return end
	local btn = tab.Button
	local rel = (btn.AbsolutePosition + btn.AbsoluteSize / 2 - self.Header.AbsolutePosition) / math.max(self.Scale.Scale, .01)
	local pos = UDim2.fromOffset(rel.X, HEADER_H - 3)
	if instant then self.Indicator.Position = pos else Tween(self.Indicator, { Position = pos }, .45) end
end

function Window:SetOpen(open)
	self.Open = open
	Blush.MenuOpen = false
	for _, w in ipairs(Blush.Windows) do if w.Open then Blush.MenuOpen = true end end
	self.Modal.Modal = open
	if open then
		self.Main.Visible = true
		self.Scale.Scale = .9
		Tween(self.Scale, { Scale = 1 }, .5, Back)
		Tween(self.Main, { GroupTransparency = 0 }, .3)
		task.delay(.52, function() if self.ActiveTab then self:_MoveIndicator(self.ActiveTab, true) end end)
	else
		self:ClosePopup()
		Tween(self.Scale, { Scale = .94 }, .25)
		Tween(self.Main, { GroupTransparency = 1 }, .25).Completed:Connect(function()
			if not self.Open then self.Main.Visible = false end
		end)
	end
end
function Window:Toggle() self:SetOpen(not self.Open) end
function Window:AutoLoad() Config:AutoLoad() end

function Window:Search(q)
	q = (q or ""):lower()
	local first
	for _, tab in ipairs(self.Tabs) do
		local tabHas = false
		for _, sec in ipairs(tab.Sections) do
			local secHas = false
			local titleMatch = q == "" or sec.Name:lower():find(q, 1, true) ~= nil
			for _, el in ipairs(sec.Elements) do
				local m = titleMatch or el.Name:lower():find(q, 1, true) ~= nil
				el.SearchHidden = not m
				el:UpdateVisible()
				if m then secHas = true end
			end
			sec.Wrap.Visible = q == "" or secHas
			if secHas then tabHas = true end
		end
		tab.HasMatch = tabHas
		if tabHas and not first then first = tab end
	end
	if q ~= "" and first and not (self.ActiveTab and self.ActiveTab.HasMatch) then first:Select() end
end

function Window:AddTab(o)
	o = o or {}
	local Tab = setmetatable({ Name = o.Name or "Tab", Sections = {}, Window = self, Index = #self.Tabs + 1 }, TabMethods)
	local btn = Button({ Size = UDim2.fromOffset(32, 30), Parent = self.TabHolder, LayoutOrder = Tab.Index })
	local img = Create("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(20, 20), ImageColor3 = WHITE, ImageTransparency = .5, Parent = btn })
	local scale = Create("UIScale", { Parent = img })
	local fallback = Label({ Text = Tab.Name:sub(1, 1):upper(), FontFace = Fonts.Bold, TextSize = 15, TextColor3 = WHITE, TextTransparency = .5,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = btn })
	task.spawn(function()
		local res = ResolveIcon(o.Icon or Tab.Name)
		if res then
			ApplyIcon(img, res)
			fallback.Visible = false
		end
	end)
	Tab.Button = btn
	Tab.SetIcon = function(active)
		local t = active and 0 or .5
		Tween(img, { ImageTransparency = t }, .25)
		Tween(fallback, { TextTransparency = t }, .25)
		Tween(scale, { Scale = active and 1.12 or 1 }, .35, Back)
	end
	btn.MouseEnter:Connect(function()
		if self.ActiveTab ~= Tab then
			Tween(img, { ImageTransparency = .2 }, .15)
			Tween(scale, { Scale = 1.08 }, .2, Back)
		end
	end)
	btn.MouseLeave:Connect(function() if self.ActiveTab ~= Tab then Tab.SetIcon(false) end end)
	btn.MouseButton1Click:Connect(function() Tab:Select() end)

	local page = Make("CanvasGroup", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, GroupTransparency = 1, Parent = self.Body })
	local scroll = Make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		ScrollBarImageTransparency = .35,
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = page,
	})
	local padTop, padBot, padSide = 14, 20, 14
	local scrollList = List(scroll, 12)
	Pad(scroll, padTop, padBot, padSide, padSide)
	Tab.Top = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	List(Tab.Top, 12)
	local cols = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	List(cols, 12, Enum.FillDirection.Horizontal)
	Tab.Left = Frame({ Size = UDim2.new(.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = cols })
	Tab.Right = Frame({ Size = UDim2.new(.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = cols })
	List(Tab.Left, 12) List(Tab.Right, 12)
	Tab.Page = page
	Tab.Scroll = scroll

	-- Manual canvas size so content is never cut off and you can't scroll past the end
	local function updateCanvas()
		local h = scrollList.AbsoluteContentSize.Y + padTop + padBot
		local view = scroll.AbsoluteWindowSize.Y
		if view <= 0 then return end
		-- Canvas height is content height; if content fits, keep canvas at viewport so no extra scroll
		local canvasH = math.max(h, view)
		scroll.CanvasSize = UDim2.new(0, 0, 0, canvasH)
		-- Clamp position if we shrank (e.g. section collapsed)
		local maxY = math.max(0, canvasH - view)
		if scroll.CanvasPosition.Y > maxY then
			scroll.CanvasPosition = Vector2.new(0, maxY)
		end
	end
	scrollList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
	scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateCanvas)
	Tab._UpdateCanvas = updateCanvas
	task.defer(updateCanvas)

	table.insert(self.Tabs, Tab)
	if #self.Tabs == 1 then Tab:Select() end
	return Tab
end

function Window:CreateSettingsTab()
	local tab = self:AddTab({ Name = "Settings", Icon = "settings" })
	local menu = tab:AddSection({ Name = "Menu", Side = "Left" })
	menu:AddKeybind({ Name = "Menu key", Default = self.Keybind, Mode = "Always", NoList = true, NoState = true, NoSave = true,
		KeyChanged = function(k) self.Keybind = k end })
	menu:AddToggle({ Name = "Watermark", Default = true, Callback = function(v) Blush:SetWatermark(v) end })
	menu:AddToggle({ Name = "Keybind list", Default = false, Callback = function(v) Blush:SetBindList(v) end })
	menu:AddToggle({ Name = "Notifications", Default = true, Callback = function(v) Blush.Notifications = v end })
	menu:AddButton({ Name = "Unload", Callback = function() Blush:Unload() end })

	local cfg = tab:AddSection({ Name = "Configs", Side = "Right" })
	local list = cfg:AddList({ Rows = 5, Empty = "No configs saved" })
	local nameBox = cfg:AddTextbox({ Placeholder = "Config name", NoSave = true })
	local codeBox = cfg:AddTextbox({ Placeholder = "Paste config code to import", NoSave = true })
	local autoLbl = cfg:AddLabel({ Text = "Autoload: none", Color = Theme.SubText })

	local function note(t, c, ty) Blush:Notify({ Title = t, Content = c, Type = ty, Duration = 3 }) end
	local function refresh(select)
		local auto = Config:GetAutoLoad()
		local items = {}
		for _, n in ipairs(Config:List()) do
			local info = Config:Info(n)
			table.insert(items, { Name = n, Right = info and info.saved and os.date("%d/%m %H:%M", info.saved) or "", Tag = n == auto and "AUTO" or nil })
		end
		list:SetItems(items)
		if select then list:Select(select, true) end
		autoLbl:SetText("Autoload: " .. (auto or "none"))
	end
	local function selected() return list.Value end
	local function typed() return Config:Sanitize(nameBox.Value) end

	local function doLoad(n)
		n = n or selected()
		if not n then return note("Config", "Select a config first", "Warning") end
		local ok, r = Config:Load(n)
		if ok then
			note("Config loaded", string.format("\"%s\" applied %d options", n, r.applied), "Success")
		else
			note("Config", tostring(r), "Error")
		end
	end
	list.OnDoubleClick = doLoad
	list.Callback = function(n) nameBox:SetValue(n, true) end

	cfg:AddButtonRow({
		{ Name = "Create", Callback = function()
			local n = typed()
			if n == "" then return note("Config", "Enter a name first", "Warning") end
			if Config:Exists(n) then return note("Config", "That name already exists, use Save", "Warning") end
			local ok, e = Config:Save(n)
			if ok then note("Config created", "\"" .. n .. "\"", "Success") refresh(n) else note("Config", tostring(e), "Error") end
		end },
		{ Name = "Save", Callback = function()
			local n = selected() or typed()
			if not n or n == "" then return note("Config", "Select or name a config", "Warning") end
			local ok, e = Config:Save(n)
			if ok then note("Config saved", "\"" .. n .. "\"", "Success") refresh(n) else note("Config", tostring(e), "Error") end
		end },
	})
	cfg:AddButtonRow({
		{ Name = "Load", Callback = function() doLoad() end },
		{ Name = "Delete", Confirm = true, Callback = function()
			local n = selected()
			if not n then return note("Config", "Select a config first", "Warning") end
			if Config:Delete(n) then note("Config deleted", "\"" .. n .. "\"", "Success") refresh() else note("Config", "Could not delete", "Error") end
		end },
	})
	cfg:AddButtonRow({
		{ Name = "Rename", Callback = function()
			local n, new = selected(), typed()
			if not n or new == "" then return note("Config", "Select a config and type the new name", "Warning") end
			if Config:Rename(n, new) then note("Config renamed", n .. " > " .. new, "Success") refresh(new) else note("Config", "Name taken or invalid", "Error") end
		end },
		{ Name = "Duplicate", Callback = function()
			local n = selected()
			if not n then return note("Config", "Select a config first", "Warning") end
			local new = typed()
			if new == "" or new == n then new = n .. " copy" end
			if Config:Duplicate(n, new) then note("Config duplicated", "\"" .. new .. "\"", "Success") refresh(new) else note("Config", "Name taken or invalid", "Error") end
		end },
	})
	cfg:AddButtonRow({
		{ Name = "Export", Callback = function()
			local code = Config:Export(selected())
			codeBox:SetValue(code, true)
			if typeof(setclipboard) == "function" then
				setclipboard(code)
				note("Config exported", "Copied to clipboard", "Success")
			else
				note("Config exported", "Code placed in the import box", "Success")
			end
		end },
		{ Name = "Import", Callback = function()
			local code = codeBox.Value
			if code == "" and typeof(getclipboard) == "function" then code = getclipboard() end
			local n = typed()
			if n == "" then n = "imported" end
			local ok, r = Config:Import(code, n)
			if ok then note("Config imported", "Saved as \"" .. n .. "\"", "Success") refresh(n) else note("Config", tostring(r), "Error") end
		end },
	})
	cfg:AddToggle({ Name = "Auto save loaded config", NoSave = true, Callback = function(v)
		Config.AutoSave = v
		if v and not Config.Current then note("Auto save", "Load or save a config first", "Warning") end
	end })
	cfg:AddButtonRow({
		{ Name = "Set autoload", Callback = function()
			local n = selected()
			if not n then return note("Config", "Select a config first", "Warning") end
			Config:SetAutoLoad(n)
			note("Autoload set", "\"" .. n .. "\"", "Success")
			refresh(n)
		end },
		{ Name = "Clear autoload", Callback = function() Config:ClearAutoLoad() refresh(selected()) note("Autoload cleared", "", "Info") end },
	})
	cfg:AddButton({ Name = "Reset all to defaults", Confirm = true, Callback = function()
		Config:Reset()
		note("Reset", "All options restored to defaults", "Success")
	end })
	refresh()
	return tab
end

function Blush:CreateWindow(cfg)
	cfg = cfg or {}
	if cfg.Folder then Config.Folder = cfg.Folder end
	if cfg.PerGame ~= nil then Config.PerGame = cfg.PerGame end
	self:_Init()
	local size = cfg.Size or Vector2.new(660, 580)
	local W = setmetatable({ Tabs = {}, Open = false, Keybind = cfg.Keybind or Enum.KeyCode.LeftAlt, Name = cfg.Name or "Blush" }, Window)

	local main = Make("CanvasGroup", { Name = "Main", BorderSizePixel = 0, BackgroundColor3 = Theme.Background, AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(size.X, size.Y), GroupTransparency = 1, Visible = false, Parent = self.Gui })
	Corner(main, 9)
	local scale = Create("UIScale", { Scale = .9, Parent = main })
	W.Main, W.Scale = main, scale
	W.Modal = Create("TextButton", { Size = UDim2.new(), BackgroundTransparency = 1, Text = "", Modal = false, Parent = main })

	local header = Frame({ Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundColor3 = WHITE, ClipsDescendants = true, Parent = main })
	AccentGradient(header, 0)
	W.Header = header
	local sheen = Frame({ Size = UDim2.new(0, 120, 4, 0), Position = UDim2.new(-.3, 0, -1, 0), Rotation = 20, BackgroundColor3 = WHITE, Parent = header })
	Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.5, .86), NumberSequenceKeypoint.new(1, 1) }), Parent = sheen })
	TweenService:Create(sheen, TweenInfo.new(7, Linear, Enum.EasingDirection.Out, -1), { Position = UDim2.new(1.2, 0, -1, 0) }):Play()
	local rng = Random.new(7)
	for i = 1, 16 do
		local star = Label({ Text = "★", TextSize = rng:NextInteger(8, 15), TextColor3 = Color3.fromRGB(255, 235, 255), TextTransparency = rng:NextNumber(.05, .5),
			Position = UDim2.new(.12 + (i / 16) * .5, rng:NextInteger(-8, 8), rng:NextNumber(.1, .7), 0), Size = UDim2.fromOffset(16, 16),
			TextXAlignment = Enum.TextXAlignment.Center, Rotation = rng:NextInteger(-25, 25), Parent = header })
		TweenService:Create(star, TweenInfo.new(rng:NextNumber(1.2, 2.8), Sine, Enum.EasingDirection.InOut, -1, true, rng:NextNumber(0, 1.5)), { TextTransparency = .9, Rotation = star.Rotation + 20 }):Play()
	end
	Label({ Text = W.Name, FontFace = Fonts.Bold, TextSize = 17, TextColor3 = Color3.fromRGB(252, 222, 255),
		Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0, 120, 1, 0), Parent = header })
	W.TabHolder = Frame({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -14, .5, -1), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Parent = header })
	local tl = List(W.TabHolder, 6, Enum.FillDirection.Horizontal)
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	W.Indicator = Frame({ AnchorPoint = Vector2.new(.5, 1), Size = UDim2.fromOffset(16, 3), BackgroundColor3 = WHITE, Position = UDim2.fromOffset(0, HEADER_H - 3), Parent = header })
	Corner(W.Indicator, 2)
	W.TabHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if W.ActiveTab then W:_MoveIndicator(W.ActiveTab, true) end end)
	Draggable(header, main)

	W.Body = Frame({ Position = UDim2.fromOffset(0, HEADER_H), Size = UDim2.new(1, 0, 1, -(HEADER_H + FOOTER_H)), ClipsDescendants = true, Parent = main })
	local footer = Frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, FOOTER_H), BackgroundColor3 = Theme.Footer, Parent = main })
	Frame({ Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = .3, Parent = footer })
	W.Overlay = Frame({ Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = main })

	local lp = Players.LocalPlayer
	local avatar = Create("ImageLabel", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 14, .5, 0), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Theme.Element, BorderSizePixel = 0, Parent = footer })
	Corner(avatar, 13)
	task.spawn(function()
		pcall(function() avatar.Image = Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
	end)
	Label({ RichText = true, Position = UDim2.fromOffset(50, 0), Size = UDim2.new(.5, 0, 1, 0), TextSize = 14,
		Text = string.format("%s <font color=\"rgb(120,127,146)\">/ %s</font>", lp.Name, lp.DisplayName), Parent = footer })

	local sbtn = Button({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -12, .5, 0), Size = UDim2.fromOffset(30, 30), Parent = footer })
	local sicon = Create("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(18, 18), ImageColor3 = Theme.SubText, Parent = sbtn })
	local sfall = Label({ Text = "?", FontFace = Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.SubText, Size = UDim2.fromScale(1, 1), Parent = sbtn })
	task.spawn(function()
		local res = ResolveIcon("search")
		if res then ApplyIcon(sicon, res) sfall.Visible = false end
	end)
	local sbox = Input({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -50, .5, 0), Size = UDim2.fromOffset(0, 26),
		BackgroundTransparency = 0, BackgroundColor3 = Theme.Element, PlaceholderText = "Search...", PlaceholderColor3 = Theme.SubText,
		TextSize = 13, ClipsDescendants = true, Visible = false, Parent = footer })
	Corner(sbox, 5) Pad(sbox, 0, 0, 10, 10)
	local sst = Stroke(sbox, Theme.Stroke, 1)
	local sopen = false
	sbtn.MouseEnter:Connect(function() Tween(sicon, { ImageColor3 = Theme.Text }, .15) Tween(sfall, { TextColor3 = Theme.Text }, .15) end)
	sbtn.MouseLeave:Connect(function()
		local c = sopen and Theme.Accent or Theme.SubText
		Tween(sicon, { ImageColor3 = c }, .15) Tween(sfall, { TextColor3 = c }, .15)
	end)
	sbtn.MouseButton1Click:Connect(function()
		sopen = not sopen
		local c = sopen and Theme.Accent or Theme.SubText
		Tween(sicon, { ImageColor3 = c }, .2) Tween(sfall, { TextColor3 = c }, .2)
		if sopen then
			sbox.Visible = true
			Tween(sbox, { Size = UDim2.fromOffset(210, 26) }, .35)
			task.delay(.12, function() sbox:CaptureFocus() end)
		else
			sbox.Text = ""
			Tween(sbox, { Size = UDim2.fromOffset(0, 26) }, .25)
			task.delay(.26, function() if not sopen then sbox.Visible = false end end)
		end
	end)
	-- Keep neutral stroke when focused — no purple selection border
	sbox.Focused:Connect(function() Tween(sbox, { BackgroundColor3 = Color3.fromRGB(54, 60, 76) }, .15) end)
	sbox.FocusLost:Connect(function() Tween(sbox, { BackgroundColor3 = Theme.Element }, .15) end)
	sbox:GetPropertyChangedSignal("Text"):Connect(function() W:Search(sbox.Text) end)

	table.insert(self.Windows, W)
	W:SetOpen(cfg.Open ~= false)
	if cfg.AutoLoad ~= false then task.defer(function() Config:AutoLoad() end) end
	if cfg.Watermark == false then self:SetWatermark(false) end
	if cfg.BindList then self:SetBindList(true) end
	return W
end

function Blush:Unload()
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	if self.Gui then self.Gui:Destroy() end
	self.Gui, self.Windows, self.Keybinds, self.Flags, self.Options, self.AccentObjects, self.Connections, self._BindMap =
		nil, {}, {}, {}, {}, {}, {}, {}
	self.MenuOpen, self.Listening, self._drag, self._dragEnd = false, nil, nil, nil
	Config.Current = nil
	if self.OnUnload then pcall(self.OnUnload) end
end

return Blush
