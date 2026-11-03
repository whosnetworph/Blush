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

-- Only one copy may run at a time: loading again unloads the previous one.
do
	local env = (typeof(getgenv) == "function" and getgenv()) or _G
	local old = env.__BlushActive
	if old and old ~= Blush and type(old.Unload) == "function" then pcall(function() old:Unload() end) end
	env.__BlushActive = Blush
end

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

-- Full-width top accent (Create only — avoids Frame local-order issues)
local function EngravedLine(parent, thickness)
	thickness = thickness or 2
	-- Flush top accent; parent must ClipsDescendants so UICorner clips the bar
	local line = Create("Frame", {
		Size = UDim2.new(1, 0, 0, thickness),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = parent,
	})
	AccentGradient(line)
	-- soft accent glow bleeding down from the line
	local glow = Create("Frame", {
		Position = UDim2.fromOffset(0, thickness),
		Size = UDim2.new(1, 0, 0, 9),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
	})
	local gg = Create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
		Transparency = NumberSequence.new(.84, 1), Parent = glow })
	table.insert(Blush.AccentObjects, gg)
	return line
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

local Icons = { Molto = nil, MoltoFailed = false }
-- Map common / lucide names → material symbols (and a few lucide keep-as-is)
local IconAlias = {
	["mouse-pointer-2"] = "mouse", ["mouse-pointer"] = "mouse", mouse = "mouse",
	aim = "ads_click", crosshair = "ads_click", target = "my_location",
	visuals = "visibility", eye = "visibility", visibility = "visibility",
	colors = "palette", colours = "palette", palette = "palette",
	settings = "settings", gear = "settings",
	misc = "tune", sliders = "tune", ["sliders-horizontal"] = "tune", tune = "tune",
	search = "search", combat = "swords", player = "person", players = "group", users = "group", group = "group",
}

local function EnsureMolto()
	if Icons.Molto or Icons.MoltoFailed then return Icons.Molto end
	local ok, m = pcall(function()
		return loadstring(game:HttpGet("https://molto.pages.dev/source.lua"))()
	end)
	if ok and type(m) == "table" then
		Icons.Molto = m
		-- Prefer lucide (matches Astral icon names), fall back to material
		pcall(function()
			if m.SetProvider then
				local okL = pcall(m.SetProvider, "lucide")
				if not okL then m.SetProvider("material") end
			end
		end)
	else
		Icons.MoltoFailed = true
	end
	return Icons.Molto
end

local function SetMoltoIcon(inst, name)
	local raw = tostring(name or "")
	if raw == "" then return false end
	if tonumber(raw) or raw:find("rbx", 1, true) == 1 then
		if inst:IsA("ImageLabel") then
			inst.Image = tonumber(raw) and ("rbxassetid://" .. raw) or raw
			return true
		end
		return false
	end
	if Blush.IconProvider then
		local ok, r = pcall(Blush.IconProvider, raw)
		if ok and r and type(r) == "string" and inst:IsA("ImageLabel") then
			inst.Image = r
			return true
		end
	end
	local reg = EnsureMolto()
	if not reg then return false end
	local candidates = { raw, IconAlias[raw:lower()], IconAlias[raw], raw:lower() }
	for _, n in ipairs(candidates) do
		if n and n ~= "" then
			local ok = pcall(function()
				if reg.SetIcon then
					reg.SetIcon(inst, n)
				else
					local asset = reg.GetAsset(n)
					assert(asset, "missing")
					if inst:IsA("TextLabel") and asset.FontFace then
						inst.Text = asset.Text
						inst.FontFace = asset.FontFace
					elseif inst:IsA("ImageLabel") then
						inst.Image = asset.Url or ""
						if asset.ImageRectSize then
							inst.ImageRectSize = asset.ImageRectSize
							inst.ImageRectOffset = asset.ImageRectOffset or Vector2.zero
						end
					end
				end
			end)
			if ok then return true end
		end
	end
	return false
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
-- "Auto save loaded config" is remembered between sessions (separate from the configs themselves)
function Config:GetAutoSavePref()
	if not self:Ensure() then return false end
	local p = self:Root() .. "/autosave.txt"
	return isfile(p) and readfile(p) == "1" or false
end
function Config:SetAutoSavePref(b)
	self.AutoSave = b and true or false
	if self:Ensure() then pcall(writefile, self:Root() .. "/autosave.txt", self.AutoSave and "1" or "0") end
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
	-- also sweep any leftover Blush gui from a copy that had no registry (older versions)
	do
		local ok, parent = pcall(GetGuiParent)
		if ok and parent then
			for _, c in ipairs(parent:GetChildren()) do
				if c:IsA("ScreenGui") and c.Name:sub(1, 6) == "Blush_" then pcall(function() c:Destroy() end) end
			end
		end
	end
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
		-- Close open dropdowns when scrolling the menu (keep open if scrolling the dropdown list itself)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			for _, w in ipairs(self.Windows) do
				if w.Popup and w.Popup.Frame then
					local pop = w.Popup.Frame
					local mouse = UserInputService:GetMouseLocation()
					local guiObj = nil
					pcall(function()
						local objs = Players.LocalPlayer:GetMouse()
						-- Prefer AbsolutePosition hit test
					end)
					local overList = false
					for _, d in ipairs(pop:GetDescendants()) do
						if d:IsA("GuiObject") and d:GetAttribute("IsDropdownList") then
							local p, s = d.AbsolutePosition, d.AbsoluteSize
							if mouse.X >= p.X and mouse.X <= p.X + s.X and mouse.Y >= p.Y and mouse.Y <= p.Y + s.Y then
								overList = true
								break
							end
						end
					end
					if not overList then
						w:ClosePopup()
					end
				end
			end
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
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(0, 276, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	})
	local nl = List(self.NotifHolder, 8)
	nl.VerticalAlignment = Enum.VerticalAlignment.Top
	self.NotifList = nl
	self.NotifyPos = self.NotifyPos or "Top Left"
	nl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	self:_BuildHUD()
	self:_PlaceNotif()
end

function Blush:_BuildHUD()
	local gui = self.Gui
	local lp = Players.LocalPlayer

	-- CanvasGroup clips children to the rounded corners, so the accent line is
	-- cut into the watermark's shape (engraved) instead of sitting on top of it.
	local wm = Make("CanvasGroup", {
		Name = "Watermark",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Panel,
		Parent = gui,
	})
	Corner(wm, 8)
	Stroke(wm, Theme.Stroke, 1, .45)
	EngravedLine(wm, 2)
	local row = Frame({
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = wm,
	})
	local rl = List(row, 10, Enum.FillDirection.Horizontal)
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	Pad(row, 0, 0, 14, 14)

	local order = 0
	-- fps / ping / time get fixed widths so the bar never changes size as numbers change
	local function seg(text, bold, fixedW)
		order += 1
		local props = {
			Text = text,
			FontFace = bold and Fonts.Bold or Fonts.Medium,
			TextSize = 13,
			TextColor3 = bold and WHITE or Theme.Text,
			Size = UDim2.fromOffset(fixedW or 0, 24),
			LayoutOrder = order,
			Parent = row,
		}
		if fixedW then props.TextXAlignment = Enum.TextXAlignment.Center else props.AutomaticSize = Enum.AutomaticSize.X end
		return Label(props)
	end
	local function sep()
		order += 1
		Frame({
			Size = UDim2.fromOffset(1, 14),
			BackgroundColor3 = Color3.fromRGB(96, 103, 124),
			BackgroundTransparency = .35,
			LayoutOrder = order,
			Parent = row,
		})
	end
	local title = seg("Blush", true)
	AccentGradient(title)
	sep()
	local nameLbl = seg(lp and lp.Name or "player")
	sep()
	local fpsLbl = seg("000fps", false, 50)
	sep()
	local pingLbl = seg("0000 ms", false, 58)
	sep()
	local timeLbl = seg("00:00", false, 38)
	self.WatermarkFrame, self.WatermarkTitle = wm, title
	self.WatermarkName = nameLbl
	self.HideIdentity = false

	local function maskName(s)
		s = tostring(s or "")
		if #s <= 2 then return s .. "****" end
		return s:sub(1, 2) .. string.rep("*", math.max(4, #s - 2))
	end
	function Blush:SetHideIdentity(b)
		self:_Init()
		self.HideIdentity = b and true or false
		local name = Players.LocalPlayer and Players.LocalPlayer.Name or "player"
		if self.WatermarkName then
			self.WatermarkName.Text = self.HideIdentity and maskName(name) or name
		end
		if self.FooterUser then
			local dn = Players.LocalPlayer and Players.LocalPlayer.DisplayName or name
			if self.HideIdentity then
				self.FooterUser.Text = string.format("%s <font color=\"rgb(120,127,146)\">/ %s</font>", maskName(name), maskName(dn))
			else
				self.FooterUser.Text = string.format("%s <font color=\"rgb(120,127,146)\">/ %s</font>", name, dn)
			end
		end
	end

	local frames, acc, fps, ping = 0, 0, 60, 0
	local function refresh()
		pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + .5) end)
		local t = os.date("*t")
		fpsLbl.Text = fps .. "fps"
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

	-- Bind list UI removed
	self.BindListFrame, self.BindRows, self.BindListEnabled = nil, nil, false
end

function Blush:_RefreshBinds() end

function Blush:SetWatermark(b)
	self:_Init()
	self.WatermarkFrame.Visible = b
	self:_PlaceNotif()
end

Blush.NotifyPositions = { "Top Left", "Top Center", "Top Right", "Bottom Left", "Bottom Center", "Bottom Right" }
-- Where notifications appear. One of Blush.NotifyPositions.
function Blush:SetNotifyPosition(pos)
	if not table.find(self.NotifyPositions, pos) then return end
	self.NotifyPos = pos
	if self.Gui then self:_PlaceNotif() end
end
function Blush:_PlaceNotif()
	local h = self.NotifHolder
	if not h then return end
	local pos = self.NotifyPos or "Top Left"
	local top = pos:find("Top", 1, true) ~= nil
	local ax = pos:find("Left", 1, true) and 0 or (pos:find("Right", 1, true) and 1 or .5)
	-- the watermark lives top-right, so keep top-right notifications clear of it
	local y = 16
	if top and ax == 1 and self.WatermarkFrame and self.WatermarkFrame.Visible then y = 62 end
	h.AnchorPoint = Vector2.new(ax, top and 0 or 1)
	h.Position = UDim2.new(ax, ax == 0 and 16 or (ax == 1 and -16 or 0), top and 0 or 1, top and y or -16)
	if self.NotifList then
		self.NotifList.VerticalAlignment = top and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
	end
end
function Blush:SetWatermarkTitle(t)
	self:_Init()
	self.WatermarkTitle.Text = t
end
function Blush:SetBindList(_b) end -- bind list UI removed

function Blush:Notify(o)
	if not self.Notifications then return end
	self:_Init()
	if type(o) == "string" then o = { Content = o } end
	o = o or {}
	local title, content, dur = o.Title or "Blush", o.Content or o.Text or "", o.Duration or 4

	local npos = self.NotifyPos or "Top Left"
	local sx = npos:find("Left", 1, true) and -24 or (npos:find("Right", 1, true) and 24 or 0)
	local sy = sx == 0 and (npos:find("Top", 1, true) and -16 or 16) or 0
	local slideOff = UDim2.fromOffset(sx, sy)
	local hasBody = content ~= ""
	local h = hasBody and 62 or 44
	local wrap = Frame({
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.NotifHolder,
	})
	local card = Make("CanvasGroup", {
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Panel,
		GroupTransparency = 1,
		Position = slideOff,
		Size = UDim2.new(1, 0, 0, h),
		ClipsDescendants = true,
		Parent = wrap,
	})
	Corner(card, 8)
	Stroke(card, Theme.Stroke, 1, .45)
	EngravedLine(card, 2)
	Label({
		Text = title,
		FontFace = Fonts.Bold,
		TextSize = 13,
		Position = UDim2.fromOffset(14, hasBody and 11 or 14),
		Size = UDim2.new(1, -28, 0, 16),
		Parent = card,
	})
	if hasBody then
		Label({
			Text = content,
			FontFace = Fonts.Medium,
			TextSize = 12,
			TextColor3 = Theme.SubText,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(14, 31),
			Size = UDim2.new(1, -28, 0, 16),
			Parent = card,
		})
	end
	local track = Frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 3),
		Parent = card,
	})
	local fill = Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = track })
	AccentGradient(fill)
	local pglow = Frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = WHITE, Parent = fill })
	table.insert(Blush.AccentObjects, Create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
		Transparency = NumberSequence.new(1, .82), Parent = pglow }))
	local click = Button({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = card })

	local closed = false
	local function close()
		if closed then return end
		closed = true
		Tween(card, { GroupTransparency = 1, Position = slideOff }, .25)
		Tween(wrap, { Size = UDim2.new(1, 0, 0, 0) }, .22)
		task.wait(.26)
		if wrap.Parent then wrap:Destroy() end
	end
	click.MouseButton1Click:Connect(close)
	-- Slide up + fade in
	Tween(wrap, { Size = UDim2.new(1, 0, 0, h) }, .28, Quint)
	Tween(card, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, .4, Back)
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
	Pad(btn, 0, 0, 8, 8)
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
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = K.Mode == m and Theme.Accent or Theme.Text, Parent = lst })
			Corner(b, 4) Pad(b, 0, 0, 6, 6)
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
	Press(swatch)

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
		Corner(hex, 5)

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
	local bscale = Create("UIScale", { Parent = box })
	local fill = Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = box })
	Corner(fill, 5)
	AccentGradient(fill, 45)
	-- Millenium-style tick icon (slightly smaller)
	local tick = Create("ImageLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "rbxassetid://111862698467575",
		ImageColor3 = WHITE,
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(12, 12),
		Parent = box,
	})
	local tscale = Create("UIScale", { Scale = 0, Parent = tick })
	local lbl = Label({
		Text = o.Name or "",
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -26, 1, 0),
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
		Tween(lbl, { TextColor3 = v and Theme.Text or Theme.SubText }, .2)
		Tween(tick, { ImageTransparency = v and 0 or 1 }, .15)
		Tween(tscale, { Scale = v and 1 or 0 }, v and .28 or .12, v and Back or Quint)
		if self.Flag then Blush.Flags[self.Flag] = v end
		if self.Keybind then self.Keybind:_Sync(v) end
		if changed and not silent then self:_Fire(v) end
	end
	function T:Save() return self.Value end
	function T:Load(v) self:SetValue(v == true) end
	hit.MouseEnter:Connect(function() if not T.Value then Tween(box, { BackgroundColor3 = Color3.fromRGB(58, 65, 82) }, .15) end end)
	hit.MouseLeave:Connect(function() Tween(box, { BackgroundColor3 = Theme.Element }, .15) end)
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
	-- Value label is tight to the text only — wide hit area was opening edit from far left
	local val = Button({
		Text = "",
		TextSize = 12,
		FontFace = Fonts.Medium,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(56, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = row,
	})
	local edit = Input({
		Visible = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -1),
		Size = UDim2.fromOffset(56, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Element,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = row,
	})
	Corner(edit, 4)
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
	Corner(b, 5) Pad(b, 0, 0, 8, 8)
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
	local row = Frame({ Size = UDim2.new(1, 0, 0, o.Name and 52 or 30), Parent = self.Inner })
	if o.Name then Label({ Text = o.Name, FontFace = Fonts.Bold, Size = UDim2.new(1, 0, 0, 18), Parent = row }) end
	local box = Button({ Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Element, Parent = row })
	Corner(box, 5)
	-- Text is centred between equal 30px gutters (the right gutter holds the arrow)
	local txt = Label({ Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -60, 1, 0), TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = box })
	-- Arrow is drawn from bars (not a font glyph) so it is exactly centered on the button
	local arrow = Frame({ AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(1, -16, .5, 0), Size = UDim2.fromOffset(12, 12), Parent = box })
	local function bar(w, h, x, y, rot)
		local f = Frame({ AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = Theme.SubText, Rotation = rot or 0, Parent = arrow })
		Corner(f, 1)
	end
	if o.Multi then bar(10, 2, 6, 6) bar(2, 10, 6, 6) else bar(7, 2, 3.2, 6, 45) bar(7, 2, 8.8, 6, -45) end
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
		local count = math.max(#D.Values, 1)
		local maxVis = o.MaxVisible or 8
		local rows = math.min(count, maxVis)
		local searchH = o.Search and 32 or 0
		local itemH = 26
		local padH = 8
		local h = searchH + rows * itemH + padH
		-- No empty space when few options
		if count < maxVis then
			h = searchH + count * itemH + padH
		end
		local sc = math.max(window.Scale.Scale, .01)
		local popW = 0 -- real width is taken from the button when the popup is placed
		local pop = window:OpenPopup(box, UDim2.fromOffset(popW, h), function()
			D.IsOpen = false
			Tween(arrow, { Rotation = 0 }, .2)
			Tween(box, { BackgroundColor3 = Theme.Element }, .12)
		end)
		Tween(arrow, { Rotation = o.Multi and 45 or 180 }, .2)
		local sb
		if o.Search then
			sb = Input({
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.new(1, -8, 0, 24),
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.Element,
				PlaceholderText = "Search...",
				PlaceholderColor3 = Theme.SubText,
				TextSize = 12,
				Parent = pop,
			})
			Corner(sb, 4) Pad(sb, 0, 0, 8, 8)
		end
		local lst = Make("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, searchH + 4),
			Size = UDim2.new(1, 0, 1, -(searchH + 8)),
			ScrollBarThickness = 0, -- enabled after the open animation so it never flashes
			ScrollBarImageTransparency = .4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Parent = pop,
		})
		task.delay(.26, function() if lst.Parent then lst.ScrollBarThickness = 2 end end)
		List(lst, 0) Pad(lst, 0, 0, 4, 4)
		-- Mark so wheel scroll over the list doesn't close the popup
		pop:SetAttribute("IsDropdown", true)
		lst:SetAttribute("IsDropdownList", true)
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
			local shown = 0
			for i, v in ipairs(D.Values) do
				if not filter or filter == "" or tostring(v):lower():find(filter:lower(), 1, true) then
					shown += 1
					local b = Button({
						Size = UDim2.new(1, 0, 0, itemH),
						Text = tostring(v),
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Center,
						BackgroundColor3 = Theme.Element,
						BackgroundTransparency = 1,
						LayoutOrder = i,
						Parent = lst,
					})
					Corner(b, 4) Pad(b, 0, 0, 7, 7)
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
			-- Resize popup height to match filtered results (no empty space)
			local vis = math.min(shown, maxVis)
			local newH = searchH + math.max(vis, 1) * itemH + padH
			pop.Size = UDim2.fromOffset(popW, newH)
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
			local n = Label({ Text = it.Name, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(.55, -10, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = f })
			local rightText = it.Right or ""
			if it.Tag then rightText = it.Tag .. (rightText ~= "" and ("  " .. rightText) or "") end
			local r = Label({
				Text = rightText,
				FontFace = Fonts.Medium,
				TextSize = 11,
				TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(.55, 0),
				Size = UDim2.new(.45, -8, 1, 0),
				Parent = f,
			})
			f.MouseEnter:Connect(function() if L.Value ~= it.Name then Tween(f, { BackgroundTransparency = .6 }, .12) end end)
			f.MouseLeave:Connect(function() if L.Value ~= it.Name then Tween(f, { BackgroundTransparency = 1 }, .12) end end)
			f.MouseButton1Click:Connect(function()
				local now = os.clock()
				if lastName == it.Name and now - lastClick < .35 and L.OnDoubleClick then task.spawn(L.OnDoubleClick, it.Name) end
				lastName, lastClick = it.Name, now
				L:Select(it.Name)
			end)
			btns[it.Name] = { Frame = f, Name = n }
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
	local frame = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Panel, ZIndex = 2, Parent = wrap })
	Corner(frame, 7)
	Stroke(frame, Theme.Stroke, 1, .78)
	-- Soft depth: stacked rounded layers that spread out a little further each time and
	-- sit slightly lower than the panel, so the edge fades out gently (never a hard outline).
	for i = 1, 7 do
		local layer = Frame({
			Position = UDim2.new(0, -i, 0, -i),
			Size = UDim2.new(1, i * 2, 1, i * 2),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = .984,
			ZIndex = 1,
			Parent = wrap,
		})
		Corner(layer, 7 + i)
	end
	List(frame, 0)
	local named = S.Name ~= ""
	-- Title is display-only — sections cannot be collapsed
	local title = Label({
		Size = UDim2.new(1, 0, 0, named and 34 or 6),
		Text = S.Name,
		FontFace = Fonts.Bold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = frame,
	})
	if named then
		local lineRow = Frame({ Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, Parent = frame })
		local line = Frame({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = .35, Parent = lineRow })
		Create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(.2, 0),
				NumberSequenceKeypoint.new(.8, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = line,
		})
	end
	local content = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = frame })
	local inner = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	List(inner, 9) Pad(inner, named and 12 or 4, 14, 14, 14)
	S.Frame, S.Wrap, S.Inner = frame, wrap, inner
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
	for _, s in ipairs(self.Sections) do if s.Collapse then s.Collapse:Refresh() end end
	if self._UpdateCanvas then task.defer(self._UpdateCanvas) end
	task.defer(function() w:_MoveIndicator(self, prev == nil) end)
	task.delay(.05, function() if w.ActiveTab == self then w:_MoveIndicator(self, true) end end)
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
	local h = size.Y.Offset
	local gap = 8 -- space between trigger and list
	local function place()
		local sc = math.max(self.Scale.Scale, .01)
		local ap = (anchor.AbsolutePosition - ov.AbsolutePosition) / sc
		local as = anchor.AbsoluteSize / sc
		local ovs = ov.AbsoluteSize / sc
		-- Popup spans the full width of its trigger (wider popups right-align to it)
		local w = math.max(as.X > 1 and as.X or 0, size.X.Offset, 60)
		local x = ap.X + as.X - w
		x = math.clamp(x, 2, math.max(2, ovs.X - w - 2))
		local y = ap.Y + as.Y + gap
		if y + h > ovs.Y - 2 then y = math.max(2, ap.Y - h - gap) end
		return x, y, w
	end
	local x, y, w = place()
	local pop = Frame({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, 0),
		BackgroundColor3 = Theme.Panel,
		ClipsDescendants = true,
		Parent = ov,
	})
	Corner(pop, 6)
	Stroke(pop, Theme.Stroke, 1, .6)
	task.defer(function()
		if not pop.Parent then return end
		local nx, ny, nw = place()
		pop.Position = UDim2.fromOffset(nx, ny)
		pop.Size = UDim2.fromOffset(nw, 0)
		Tween(pop, { Size = UDim2.fromOffset(nw, h) }, .2)
	end)
	self.Popup = { Blocker = blocker, Frame = pop, OnClose = onClose }
	return pop
end

function Window:_MoveIndicator(tab, instant)
	if not tab or not tab.Button or not self.Indicator then return end
	local btn = tab.Button
	local sc = math.max(self.Scale.Scale, .01)
	local hdr = self.Header
	-- Screen-space center of button → local X inside header
	local midX = (btn.AbsolutePosition.X + btn.AbsoluteSize.X * 0.5 - hdr.AbsolutePosition.X) / sc
	local pos = UDim2.fromOffset(midX, HEADER_H - 2)
	self.Indicator.Size = UDim2.fromOffset(math.clamp(btn.AbsoluteSize.X / sc * 0.55, 12, 22), 3)
	if self._indTw then self._indTw:Cancel() self._indTw = nil end
	if instant then
		self.Indicator.Position = pos
	else
		self._slideUntil = os.clock() + .38
		self._indTw = Tween(self.Indicator, { Position = pos }, .35)
		-- re-sync once the slide ends in case the layout moved (e.g. pinned Settings tab)
		task.delay(.4, function()
			if self.ActiveTab == tab then self:_MoveIndicator(tab, true) end
		end)
	end
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
	-- Soft glow behind the selected tab: stacked rounded layers (biggest first) that fade in when active
	local glowLayers = {}
	local glowAlpha = { .82, .88, .93, .965 }
	for i = 4, 1, -1 do
		local g = Frame({
			AnchorPoint = Vector2.new(.5, .5),
			Position = UDim2.fromScale(.5, .5),
			Size = UDim2.fromOffset(26 + i * 4, 21 + i * 3),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = btn,
		})
		Corner(g, 99)
		glowLayers[i] = g
	end
	-- Molto material icons render as TextLabel font ligatures
	local img = Label({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(20, 20),
		TextSize = 18,
		TextColor3 = WHITE,
		TextTransparency = .5,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
		ZIndex = 2,
		Parent = btn,
	})
	local scale = Create("UIScale", { Parent = img })
	local fallback = Label({
		Text = Tab.Name:sub(1, 1):upper(),
		FontFace = Fonts.Bold,
		TextSize = 15,
		TextColor3 = WHITE,
		TextTransparency = .5,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = btn,
	})
	task.spawn(function()
		if SetMoltoIcon(img, o.Icon or Tab.Name) then
			fallback.Visible = false
		end
	end)
	Tab.Button = btn
	Tab.SetIcon = function(active)
		local t = active and 0 or .5
		Tween(img, { TextTransparency = t }, .25)
		Tween(fallback, { TextTransparency = t }, .25)
		Tween(scale, { Scale = active and 1.12 or 1 }, .35, Back)
		for i, g in ipairs(glowLayers) do
			Tween(g, { BackgroundTransparency = active and glowAlpha[i] or 1 }, .3)
		end
	end
	btn.MouseEnter:Connect(function()
		if self.ActiveTab ~= Tab then
			Tween(img, { TextTransparency = .2 }, .15)
			Tween(scale, { Scale = 1.08 }, .2, Back)
		end
	end)
	btn.MouseLeave:Connect(function() if self.ActiveTab ~= Tab then Tab.SetIcon(false) end end)
	btn.MouseButton1Click:Connect(function() Tab:Select() end)
	-- Keep the underline glued to the active tab whenever its button moves/resizes
	local function follow()
		if self.ActiveTab == Tab and os.clock() >= (self._slideUntil or 0) then
			self:_MoveIndicator(Tab, true)
		end
	end
	btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(follow)
	btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(follow)

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
	-- any page scroll (even fast wheel spins) closes an open dropdown / picker
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if self.Popup then self:ClosePopup() end
	end)
	local padTop, padBot, padSide = 16, 20, 16
	local scrollList = List(scroll, 16)
	Pad(scroll, padTop, padBot, padSide, padSide)
	Tab.Top = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
	List(Tab.Top, 16)
	local cols = Frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	List(cols, 16, Enum.FillDirection.Horizontal)
	Tab.Left = Frame({ Size = UDim2.new(.5, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = cols })
	Tab.Right = Frame({ Size = UDim2.new(.5, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = cols })
	List(Tab.Left, 16) List(Tab.Right, 16)
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
	if not o.Pinned and not self._HasUserTab then
		self._HasUserTab = true
		Tab:Select()
	end
	return Tab
end

function Window:CreateSettingsTab()
	if self._SettingsTab then return self._SettingsTab end
	local tab = self:AddTab({ Name = "Settings", Icon = "settings", Pinned = true })
	-- Pin settings to the far right of the tab bar
	tab.Button.LayoutOrder = 9999
	tab.Index = 9999
	self._SettingsTab = tab
	local menu = tab:AddSection({ Name = "Menu", Side = "Left" })
	menu:AddKeybind({ Name = "Menu key", Default = self.Keybind, Mode = "Always", NoList = true, NoState = true, NoSave = true,
		KeyChanged = function(k) self.Keybind = k end })
	menu:AddToggle({ Name = "Watermark", Default = true, Callback = function(v) Blush:SetWatermark(v) end })
	menu:AddToggle({ Name = "Notifications", Default = true, Callback = function(v) Blush.Notifications = v end })
	menu:AddDropdown({
		Name = "Notification position",
		Values = Blush.NotifyPositions,
		Default = Blush.NotifyPos or "Top Left",
		Callback = function(v) Blush:SetNotifyPosition(v) end,
	})
	menu:AddToggle({
		Name = "Hide username",
		Default = false,
		Callback = function(v) Blush:SetHideIdentity(v) end,
	})
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
			table.insert(items, { Name = n, Right = info and info.saved and os.date("%d/%m %H:%M", info.saved) or "" })
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
	Config.AutoSave = Config:GetAutoSavePref()
	cfg:AddToggle({ Name = "Auto save loaded config", NoSave = true, Default = Config.AutoSave, Callback = function(v)
		Config:SetAutoSavePref(v)
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


-- ---------------------------------------------------------------------------
-- Players tab: Username / Team / Status list + selected-player card
-- ---------------------------------------------------------------------------
Blush.PlayerStatus = {}
local STATUS_COLORS = {
	Neutral = nil, -- falls back to SubText
	Enemy = Color3.fromRGB(255, 99, 116),
	Friendly = Color3.fromRGB(94, 224, 144),
}
local LOCAL_COLOR = Color3.fromRGB(70, 235, 150)

function Blush:GetPlayerStatus(plr)
	if not plr then return "Neutral" end
	if plr == Players.LocalPlayer then return "LocalPlayer" end
	return self.PlayerStatus[tostring(plr.UserId)] or "Neutral"
end
function Blush:IsEnemy(plr) return self:GetPlayerStatus(plr) == "Enemy" end
function Blush:IsFriendly(plr) return self:GetPlayerStatus(plr) == "Friendly" end
function Blush:SetPlayerStatus(plr, status)
	if not plr or plr == Players.LocalPlayer then return end
	if status ~= "Enemy" and status ~= "Friendly" then status = "Neutral" end
	self.PlayerStatus[tostring(plr.UserId)] = status ~= "Neutral" and status or nil
	if self.OnPlayerStatusChanged then task.spawn(self.OnPlayerStatusChanged, plr, status) end
	if self._PlayersRefresh then self._PlayersRefresh() end
	Config:_Dirty()
end

-- opts: { Status = true, Teleport = true, Spectate = true } -- set any to false to remove that button
function Window:CreatePlayersTab(opts)
	if self._PlayersTab then return self._PlayersTab end
	opts = type(opts) == "table" and opts or {}
	local tab = self:AddTab({ Name = "Players", Icon = "users", Pinned = true })
	-- sit just left of the pinned Settings tab
	tab.Button.LayoutOrder = 9998
	tab.Index = 9998
	self._PlayersTab, self.PlayersTab = tab, tab
	tab.Actions = {}
	tab.Scroll.Visible = false

	local enabled = { Status = opts.Status ~= false, Teleport = opts.Teleport ~= false, Spectate = opts.Spectate ~= false }
	local FOOT_MIN = 78
	local BTN_W, BTN_H, BTN_GAP = 86, 26, 6

	local root = Frame({ Size = UDim2.fromScale(1, 1), Parent = tab.Page })
	Pad(root, 16, 16, 16, 16)

	-- list card ---------------------------------------------------------------
	local card = Frame({ Size = UDim2.new(1, 0, 1, -(FOOT_MIN + 16)), BackgroundColor3 = Theme.Panel, ClipsDescendants = true, Parent = root })
	Corner(card, 7)
	Stroke(card, Theme.Stroke, 1, .78)

	local head = Frame({ Size = UDim2.new(1, 0, 0, 36), Parent = card })
	local function col(text, x, w)
		return Label({ Text = text, FontFace = Fonts.Bold, TextSize = 13, TextColor3 = Theme.SubText,
			Position = UDim2.new(x, x == 0 and 16 or 0, 0, 0), Size = UDim2.new(w, x == 0 and -16 or -8, 1, 0), Parent = head })
	end
	col("Username", 0, .36) col("Team", .36, .28) col("Status", .64, .3)
	Frame({ Position = UDim2.new(0, 10, 1, -1), Size = UDim2.new(1, -20, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = .45, Parent = head })

	local sbtn = Button({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -8, .5, 0), Size = UDim2.fromOffset(26, 26), Parent = head })
	local sicon = Label({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(16, 16),
		TextSize = 15, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Parent = sbtn })
	local sfall = Label({ Text = "⌕", FontFace = Fonts.Bold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.SubText, Size = UDim2.fromScale(1, 1), Parent = sbtn })
	task.spawn(function() if SetMoltoIcon(sicon, "search") then sfall.Visible = false end end)
	local sbox = Input({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -40, .5, 0), Size = UDim2.fromOffset(0, 24), BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Element, PlaceholderText = "Search players...", PlaceholderColor3 = Theme.SubText, TextSize = 12,
		ClipsDescendants = true, Visible = false, ZIndex = 3, Parent = head })
	Corner(sbox, 5) Pad(sbox, 0, 0, 10, 10)
	local sopen = false
	sbtn.MouseEnter:Connect(function() Tween(sicon, { TextColor3 = Theme.Text }, .15) Tween(sfall, { TextColor3 = Theme.Text }, .15) end)
	sbtn.MouseLeave:Connect(function()
		local c = sopen and Theme.Accent or Theme.SubText
		Tween(sicon, { TextColor3 = c }, .15) Tween(sfall, { TextColor3 = c }, .15)
	end)

	local scroll = Make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40),
		ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke, ScrollBarImageTransparency = .35,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never, Parent = card,
	})
	List(scroll, 2) Pad(scroll, 0, 6, 6, 6)

	-- selected player card ------------------------------------------------------
	local foot = Frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, FOOT_MIN), BackgroundColor3 = Theme.Panel, Parent = root })
	Corner(foot, 7)
	Stroke(foot, Theme.Stroke, 1, .78)
	local avatar = Create("ImageLabel", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 15, .5, 0), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = Theme.Element, BorderSizePixel = 0, Parent = foot })
	Corner(avatar, 6)
	local info = Frame({ AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 75, .5, 0), Size = UDim2.new(1, -75 - 290, 0, 50), Parent = foot })
	local fName = Label({ Text = "No player selected", FontFace = Fonts.Bold, TextSize = 13, Size = UDim2.new(1, 0, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = info })
	local fId = Label({ Text = "Click a player in the list", FontFace = Fonts.Medium, TextSize = 12, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, 0, 0, 16), Parent = info })
	local fAge = Label({ Text = "", FontFace = Fonts.Medium, TextSize = 12, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 16), Parent = info })

	local holder = Frame({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -15, .5, 0), Size = UDim2.fromOffset(BTN_W * 3 + BTN_GAP * 2, 0), Parent = foot })
	local hl = List(holder, BTN_GAP, Enum.FillDirection.Horizontal)
	hl.Wraps = true
	hl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	hl.VerticalAlignment = Enum.VerticalAlignment.Top

	-- state ------------------------------------------------------------------------
	local selected, rows, filter = nil, {}, ""
	local entries, statusBtns = {}, {}
	local nextCustom = 0
	local paintFooter, paintSpectate

	local function isOn(e)
		if e.Group == "Custom" then return e.Enabled end
		return enabled[e.Group]
	end
	local function relayout()
		local n = 0
		for _, e in ipairs(entries) do if isOn(e) then n += 1 end end
		local nrows = math.ceil(n / 3)
		local bh = nrows > 0 and (nrows * BTN_H + (nrows - 1) * BTN_GAP) or 0
		local fh = math.max(FOOT_MIN, bh + 34)
		foot.Size = UDim2.new(1, 0, 0, fh)
		card.Size = UDim2.new(1, 0, 1, -(fh + 16))
		holder.Size = UDim2.fromOffset(BTN_W * 3 + BTN_GAP * 2, bh)
	end

	local function newEntry(group, name, order)
		local b = Button({ Size = UDim2.fromOffset(BTN_W, BTN_H), BackgroundColor3 = Theme.Element, Text = "", LayoutOrder = order, Visible = false, Parent = holder })
		Corner(b, 5)
		local fillF = Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = b })
		Corner(fillF, 5) AccentGradient(fillF)
		local lbl = Label({ Text = name, FontFace = Fonts.Semi, TextSize = 13, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), ZIndex = 2, Parent = b })
		Press(b)
		b.MouseEnter:Connect(function() if b:GetAttribute("On") ~= true then Tween(b, { BackgroundColor3 = Color3.fromRGB(56, 62, 78) }, .12) end end)
		b.MouseLeave:Connect(function() Tween(b, { BackgroundColor3 = Theme.Element }, .12) end)
		local e = { Btn = b, Fill = fillF, Label = lbl, Group = group, Enabled = true }
		table.insert(entries, e)
		return e
	end
	local function paintOn(e, on, dim)
		e.Btn:SetAttribute("On", on)
		Tween(e.Fill, { BackgroundTransparency = on and 0 or 1 }, .18)
		Tween(e.Label, { TextColor3 = on and WHITE or Theme.SubText, TextTransparency = dim and .55 or 0 }, .18)
	end

	for i, name in ipairs({ "Neutral", "Enemy", "Friendly" }) do statusBtns[name] = newEntry("Status", name, i) end
	local tpBtn = newEntry("Teleport", "Teleport", 10)
	local specBtn = newEntry("Spectate", "Spectate", 11)

	local function dispName(p) return p.DisplayName ~= p.Name and (p.Name .. " (" .. p.DisplayName .. ")") or p.Name end
	local function statusColor(p)
		local st = Blush:GetPlayerStatus(p)
		if st == "LocalPlayer" then return LOCAL_COLOR end
		return STATUS_COLORS[st] or Theme.SubText
	end

	-- spectate / teleport -------------------------------------------------------------
	local spectating, specConn = nil, nil
	paintSpectate = function()
		local isLocal = selected == Players.LocalPlayer
		local active = spectating ~= nil and (selected == spectating or isLocal)
		specBtn.Label.Text = active and "Unspectate" or "Spectate"
		paintOn(specBtn, active, isLocal and spectating == nil)
	end
	local function humOf(p) local c = p and p.Character return c and c:FindFirstChildOfClass("Humanoid") end
	local function stopSpectate(silent)
		if specConn then specConn:Disconnect() specConn = nil end
		local was = spectating
		spectating = nil
		local cam, hum = workspace.CurrentCamera, humOf(Players.LocalPlayer)
		if cam and hum then cam.CameraSubject = hum end
		paintSpectate()
		if was and not silent then Blush:Notify({ Title = "Spectate", Content = "Stopped spectating", Duration = 2 }) end
	end
	local function startSpectate(p)
		local cam, hum = workspace.CurrentCamera, humOf(p)
		if not cam or not hum then
			return Blush:Notify({ Title = "Spectate", Content = p.Name .. " has no character", Type = "Warning", Duration = 3 })
		end
		if specConn then specConn:Disconnect() specConn = nil end
		spectating = p
		cam.CameraSubject = hum
		specConn = p.CharacterAdded:Connect(function(c)
			local h = c:WaitForChild("Humanoid", 5)
			if spectating == p and h then workspace.CurrentCamera.CameraSubject = h end
		end)
		paintSpectate()
		Blush:Notify({ Title = "Spectate", Content = "Spectating " .. p.Name, Duration = 2 })
	end
	specBtn.Btn.MouseButton1Click:Connect(function()
		if spectating then stopSpectate() return end -- clicking while spectating stops
		if selected and selected ~= Players.LocalPlayer then startSpectate(selected) end
	end)
	tpBtn.Btn.MouseButton1Click:Connect(function()
		local p = selected
		if not p or p == Players.LocalPlayer then return end
		local myRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local theirRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not (myRoot and theirRoot) then
			return Blush:Notify({ Title = "Teleport", Content = "Missing character or root part", Type = "Warning", Duration = 3 })
		end
		myRoot.CFrame = theirRoot.CFrame * CFrame.new(0, 0, 3)
		Blush:Notify({ Title = "Teleport", Content = "Teleported to " .. p.Name, Duration = 2 })
	end)
	Connect(Players.LocalPlayer.CharacterAdded, function() if spectating then stopSpectate(true) end end)
	Blush._StopSpectate = stopSpectate

	-- footer ---------------------------------------------------------------------------
	paintFooter = function()
		relayout()
		local p = selected
		if not p or not p.Parent then
			selected = nil
			fName.Text, fId.Text, fAge.Text = "No player selected", "Click a player in the list", ""
			avatar.Image = ""
			for _, e in ipairs(entries) do e.Btn.Visible = false end
			return
		end
		fName.Text = dispName(p)
		fId.Text = tostring(p.UserId)
		fAge.Text = p.AccountAge .. " days old"
		local isLocal = p == Players.LocalPlayer
		local cur = Blush:GetPlayerStatus(p)
		for _, e in ipairs(entries) do e.Btn.Visible = isOn(e) end
		for name, e in pairs(statusBtns) do paintOn(e, name == cur, isLocal) end
		tpBtn.Label.TextTransparency = isLocal and .55 or 0
		paintSpectate()
		for _, A in ipairs(tab.Actions) do
			paintOn(A.Entry, A.Toggle == true and A.State == true, isLocal and not A.AllowLocal)
		end
		task.spawn(function()
			local ok, img = pcall(function() return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
			if ok and selected == p then avatar.Image = img end
		end)
	end

	for name, e in pairs(statusBtns) do
		e.Btn.MouseButton1Click:Connect(function()
			if selected and selected ~= Players.LocalPlayer then Blush:SetPlayerStatus(selected, name) end
		end)
	end

	-- list ----------------------------------------------------------------------------------
	local function paintRow(r)
		local on = selected == r.Player
		Tween(r.Frame, { BackgroundTransparency = on and .32 or 1 }, .15)
		Tween(r.User, { TextColor3 = on and WHITE or Theme.Text }, .15)
		Tween(r.Team, { TextColor3 = on and WHITE or Theme.SubText }, .15)
		r.Status.TextColor3 = on and (Blush:GetPlayerStatus(r.Player) == "Neutral" and WHITE or statusColor(r.Player)) or statusColor(r.Player)
	end

	local function rebuild()
		for _, r in pairs(rows) do r.Frame:Destroy() end
		rows = {}
		local list = Players:GetPlayers()
		local lp = Players.LocalPlayer
		table.sort(list, function(a, b)
			if a == lp then return true elseif b == lp then return false end
			return a.Name:lower() < b.Name:lower()
		end)
		local q = filter:lower()
		local idx = 0
		for _, p in ipairs(list) do
			if q == "" or p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
				idx += 1
				local f = Button({ Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = WHITE, BackgroundTransparency = 1, LayoutOrder = idx, Text = "", Parent = scroll })
				Corner(f, 5) AccentGradient(f)
				local u = Label({ Text = dispName(p), TextSize = 13, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(.36, -10, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = f })
				local t = Label({ Text = p.Team and p.Team.Name or "None", FontFace = Fonts.Medium, TextSize = 13, TextColor3 = Theme.SubText,
					Position = UDim2.new(.36, 0, 0, 0), Size = UDim2.new(.28, -8, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = f })
				local st = Label({ Text = Blush:GetPlayerStatus(p), FontFace = Fonts.Medium, TextSize = 13,
					Position = UDim2.new(.64, 0, 0, 0), Size = UDim2.new(.36, -8, 1, 0), ZIndex = 2, Parent = f })
				local r = { Frame = f, User = u, Team = t, Status = st, Player = p }
				rows[p] = r
				f.MouseEnter:Connect(function() if selected ~= p then Tween(f, { BackgroundTransparency = .86 }, .1) end end)
				f.MouseLeave:Connect(function() if selected ~= p then Tween(f, { BackgroundTransparency = 1 }, .1) end end)
				f.MouseButton1Click:Connect(function()
					selected = p
					for _, rr in pairs(rows) do paintRow(rr) end
					paintFooter()
				end)
				paintRow(r)
			end
		end
		if selected and not selected.Parent then selected = nil end
		paintFooter()
	end
	Blush._PlayersRefresh = rebuild

	sbtn.MouseButton1Click:Connect(function()
		sopen = not sopen
		local c = sopen and Theme.Accent or Theme.SubText
		Tween(sicon, { TextColor3 = c }, .2) Tween(sfall, { TextColor3 = c }, .2)
		if sopen then
			sbox.Visible = true
			Tween(sbox, { Size = UDim2.fromOffset(190, 24) }, .3)
			task.delay(.1, function() sbox:CaptureFocus() end)
		else
			sbox.Text = ""
			Tween(sbox, { Size = UDim2.fromOffset(0, 24) }, .22)
			task.delay(.23, function() if not sopen then sbox.Visible = false end end)
		end
	end)
	sbox:GetPropertyChangedSignal("Text"):Connect(function() filter = sbox.Text rebuild() end)

	local function watch(p) Connect(p:GetPropertyChangedSignal("Team"), rebuild) end
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
	Connect(Players.PlayerAdded, function(p) watch(p) rebuild() end)
	Connect(Players.PlayerRemoving, function(p)
		if spectating == p then stopSpectate(true) end
		if selected == p then selected = nil end
		task.defer(rebuild)
	end)

	-- public API ---------------------------------------------------------------------------
	-- tab:SetDefaultEnabled("Status" | "Teleport" | "Spectate", bool)
	function tab:SetDefaultEnabled(name, on)
		local k = tostring(name):lower()
		if k == "neutral" or k == "enemy" or k == "friendly" or k == "status" then k = "Status"
		elseif k == "teleport" then k = "Teleport"
		elseif k == "spectate" then k = "Spectate"
		else return end
		enabled[k] = on and true or false
		if k == "Spectate" and not on then stopSpectate(true) end
		paintFooter()
	end
	-- tab:AddAction({ Name = "Bring", Callback = function(player, state) end, Toggle = false, AllowLocal = false })
	function tab:AddAction(o)
		if type(o) == "string" then o = { Name = o } end
		o = o or {}
		nextCustom += 1
		local A = { Name = o.Name or "Action", Callback = o.Callback, Toggle = o.Toggle == true, AllowLocal = o.AllowLocal == true, State = o.Default == true }
		local e = newEntry("Custom", A.Name, 100 + nextCustom)
		A.Entry = e
		e.Btn.MouseButton1Click:Connect(function()
			local p = selected
			if not p then return end
			if p == Players.LocalPlayer and not A.AllowLocal then return end
			if A.Toggle then
				A.State = not A.State
				paintOn(e, A.State, false)
			end
			if A.Callback then task.spawn(A.Callback, p, A.State) end
		end)
		function A:SetName(n) self.Name = n e.Label.Text = n end
		function A:SetEnabled(b) e.Enabled = b and true or false paintFooter() end
		function A:Remove()
			local i = table.find(tab.Actions, self)
			if i then table.remove(tab.Actions, i) end
			local j = table.find(entries, e)
			if j then table.remove(entries, j) end
			e.Btn:Destroy()
			paintFooter()
		end
		table.insert(tab.Actions, A)
		paintFooter()
		return A
	end
	function tab:RemoveAction(name)
		for _, A in ipairs(tab.Actions) do
			if A.Name == name then A:Remove() return true end
		end
		return false
	end

	rebuild()

	-- statuses are saved / loaded with configs: { [userId] = "Enemy" | "Friendly" }
	local store = { Type = "PlayerStatus" }
	function store:Save()
		local out = {}
		for uid, st in pairs(Blush.PlayerStatus) do
			if st == "Enemy" or st == "Friendly" then out[tostring(uid)] = st end
		end
		return out
	end
	function store:Load(d)
		local new = {}
		if type(d) == "table" then
			for k, v in pairs(d) do
				if v == "Enemy" or v == "Friendly" then new[tostring(k)] = v end
			end
		end
		Blush.PlayerStatus = new
		rebuild()
		if Blush.OnPlayerStatusChanged then
			for _, p in ipairs(Players:GetPlayers()) do task.spawn(Blush.OnPlayerStatusChanged, p, Blush:GetPlayerStatus(p)) end
		end
	end
	function store:Reset() self:Load({}) end
	store.Default = { {} }
	Blush:_Flag(store, "Players: Status")
	return tab
end

-- Window:AddPlayerAction({ Name = "...", Callback = function(player) end }) adds a button to the Players tab
function Window:AddPlayerAction(o)
	local t = self._PlayersTab or self:CreatePlayersTab()
	return t:AddAction(o)
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
	-- Layered flowing wave: a soft glow band, a crisp line and a fainter echo line. Each line is a
	-- chain of rotated segments sized to meet end to end, so it reads as one smooth curve. The lines
	-- taper out towards both edges, and the amplitude itself slowly swells and relaxes.
	local waveGroup = Make("CanvasGroup", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = .08,
		Parent = header,
	})
	local N, Wpx, midY = 48, size.X, HEADER_H / 2
	local waveDefs = {
		{ thick = 9,   alpha = .93, amp = 6.5, shift = 0,   yoff = 0,   overlap = 1,   color = Color3.fromRGB(255, 205, 255) },
		{ thick = 2.2, alpha = .1,  amp = 6.5, shift = 0,   yoff = 0,   overlap = 1.5, color = Color3.fromRGB(255, 244, 255) },
		{ thick = 1.4, alpha = .6,  amp = 4.5, shift = 1.1, yoff = 2.5, overlap = 1.5, color = Color3.fromRGB(255, 226, 255) },
	}
	for _, d in ipairs(waveDefs) do
		d.segs, d.px, d.py = {}, table.create(N + 1, 0), table.create(N + 1, 0)
		for i = 1, N do
			local env = math.sin(math.pi * (i - .5) / N) ^ .6
			d.segs[i] = Frame({
				AnchorPoint = Vector2.new(.5, .5),
				BackgroundColor3 = d.color,
				BackgroundTransparency = 1 - (1 - d.alpha) * env,
				Parent = waveGroup,
			})
		end
	end
	local TAU = math.pi * 2
	local function waveY(d, x, t)
		local a = d.amp * (.7 + .3 * math.sin(x * TAU * .8 - t * .6 + d.shift))
		local y = math.sin(x * TAU * 1.15 + t * 1.0 + d.shift) * a
			+ math.sin(x * TAU * 2.6 - t * 1.5 + d.shift * 2) * a * .28
		return midY + d.yoff + y
	end
	local function stepWave(t)
		for _, d in ipairs(waveDefs) do
			local px, py = d.px, d.py
			for i = 0, N do
				local x = i / N
				px[i + 1], py[i + 1] = x * Wpx, waveY(d, x, t)
			end
			for i = 1, N do
				local x0, y0, x1, y1 = px[i], py[i], px[i + 1], py[i + 1]
				local dx, dy = x1 - x0, y1 - y0
				local seg = d.segs[i]
				seg.Position = UDim2.fromOffset((x0 + x1) / 2, (y0 + y1) / 2)
				seg.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + d.overlap, d.thick)
				seg.Rotation = math.deg(math.atan2(dy, dx))
			end
		end
	end
	stepWave(0)
	local waveT = 0
	Connect(RunService.RenderStepped, function(dt)
		if not W.Open then return end
		waveT += dt
		stepWave(waveT)
	end)
	TweenService:Create(waveGroup, TweenInfo.new(2.8, Sine, Enum.EasingDirection.InOut, -1, true), { GroupTransparency = .42 }):Play()
	local rng = Random.new(7)
	for i = 1, 18 do
		local star = Label({
			Text = "★",
			TextSize = rng:NextInteger(7, 14),
			TextColor3 = Color3.fromRGB(255, 240, 255),
			TextTransparency = rng:NextNumber(.1, .55),
			Position = UDim2.new(.1 + (i / 18) * .55, rng:NextInteger(-6, 6), rng:NextNumber(.12, .72), 0),
			Size = UDim2.fromOffset(14, 14),
			TextXAlignment = Enum.TextXAlignment.Center,
			Rotation = rng:NextInteger(-20, 20),
			Parent = header,
		})
		TweenService:Create(star, TweenInfo.new(rng:NextNumber(1.4, 3), Sine, Enum.EasingDirection.InOut, -1, true, rng:NextNumber(0, 1.2)), {
			TextTransparency = .92,
			Rotation = star.Rotation + 18,
		}):Play()
	end
	Label({ Text = W.Name, FontFace = Fonts.Bold, TextSize = 17, TextColor3 = Color3.fromRGB(252, 222, 255),
		Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0, 120, 1, 0), Parent = header })
	W.TabHolder = Frame({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -10, .5, 0), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Parent = header })
	local tl = List(W.TabHolder, 6, Enum.FillDirection.Horizontal)
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	W.Indicator = Frame({
		AnchorPoint = Vector2.new(.5, 1),
		Size = UDim2.fromOffset(18, 3),
		BackgroundColor3 = WHITE,
		Position = UDim2.fromOffset(0, HEADER_H - 2),
		ZIndex = 6,
		Parent = header,
	})
	Corner(W.Indicator, 2)
	W.TabHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if W.ActiveTab then W:_MoveIndicator(W.ActiveTab, true) end
	end)
	W.TabHolder:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		if W.ActiveTab then W:_MoveIndicator(W.ActiveTab, true) end
	end)
	Draggable(header, main)

	W.Body = Frame({ Position = UDim2.fromOffset(0, HEADER_H), Size = UDim2.new(1, 0, 1, -(HEADER_H + FOOTER_H)), ClipsDescendants = true, Parent = main })
	local footer = Frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, FOOTER_H), BackgroundColor3 = Theme.Footer, Parent = main })
	Frame({ Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = .3, Parent = footer })
	W.Overlay = Frame({ Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = main })

	local lp = Players.LocalPlayer
	local avatar = Create("ImageLabel", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 16, .5, 0), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Theme.Element, BorderSizePixel = 0, Parent = footer })
	Corner(avatar, 13)
	task.spawn(function()
		pcall(function() avatar.Image = Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
	end)
	self.FooterUser = Label({
		RichText = true,
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(.5, 0, 1, 0),
		TextSize = 14,
		Text = string.format("%s <font color=\"rgb(120,127,146)\">/ %s</font>", lp.Name, lp.DisplayName),
		Parent = footer,
	})
	W.FooterUser = self.FooterUser

	local sbtn = Button({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -10, .5, 0), Size = UDim2.fromOffset(30, 30), Parent = footer })
	local sicon = Label({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(18, 18),
		TextSize = 16,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
		Parent = sbtn,
	})
	local sfall = Label({ Text = "⌕", FontFace = Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.SubText, Size = UDim2.fromScale(1, 1), Parent = sbtn })
	task.spawn(function()
		if SetMoltoIcon(sicon, "search") then sfall.Visible = false end
	end)
	local sbox = Input({ AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -46, .5, 0), Size = UDim2.fromOffset(0, 26),
		BackgroundTransparency = 0, BackgroundColor3 = Theme.Element, PlaceholderText = "Search...", PlaceholderColor3 = Theme.SubText,
		TextSize = 13, ClipsDescendants = true, Visible = false, Parent = footer })
	Corner(sbox, 5) Pad(sbox, 0, 0, 10, 10)
	local sopen = false
	sbtn.MouseEnter:Connect(function() Tween(sicon, { TextColor3 = Theme.Text }, .15) Tween(sfall, { TextColor3 = Theme.Text }, .15) end)
	sbtn.MouseLeave:Connect(function()
		local c = sopen and Theme.Accent or Theme.SubText
		Tween(sicon, { TextColor3 = c }, .15) Tween(sfall, { TextColor3 = c }, .15)
	end)
	sbtn.MouseButton1Click:Connect(function()
		sopen = not sopen
		local c = sopen and Theme.Accent or Theme.SubText
		Tween(sicon, { TextColor3 = c }, .2) Tween(sfall, { TextColor3 = c }, .2)
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

	-- Settings / config tab is always built-in
	if cfg.SettingsTab ~= false then
		W:CreateSettingsTab()
	end
	if cfg.PlayersTab ~= false then
		W:CreatePlayersTab(type(cfg.PlayersTab) == "table" and cfg.PlayersTab or nil)
	end
	-- if no regular tab ever gets added, fall back to the first one that exists
	task.delay(.4, function()
		if not W.ActiveTab and W.Tabs[1] then W.Tabs[1]:Select() end
	end)

	table.insert(self.Windows, W)
	W:SetOpen(cfg.Open ~= false)
	if cfg.AutoLoad ~= false then task.defer(function() Config:AutoLoad() end) end
	if cfg.Watermark == false then self:SetWatermark(false) end
	if cfg.LoadNotify ~= false then
		self:Notify({ Title = "Loaded " .. W.Name, Content = "Press " .. KeyName(W.Keybind) .. " to open and close the menu.", Duration = 5 })
	end
	return W
end

function Blush:Unload()
	if self._StopSpectate then pcall(self._StopSpectate, true) end
	self._StopSpectate = nil
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	if self.Gui then self.Gui:Destroy() end
	self.Gui, self.Windows, self.Keybinds, self.Flags, self.Options, self.AccentObjects, self.Connections, self._BindMap =
		nil, {}, {}, {}, {}, {}, {}, {}
	self.MenuOpen, self.Listening, self._drag, self._dragEnd = false, nil, nil, nil
	Config.Current = nil
	if self.OnUnload then pcall(self.OnUnload) end
end

return Blush
