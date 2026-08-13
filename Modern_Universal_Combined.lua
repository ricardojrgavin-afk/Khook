--[[ Modern Universal - Standalone Combined Bundle with Functional Test GUI
     Assembled, cleaned, executor-safe, and outfitted with an interactive GUI interface.
     Toggle Menu Key: RightShift or Insert
--]]

-- Executor API Safety Wrappers
local cloneref = cloneref or function(obj) return obj end
local mousemoverel = mousemoverel or function(x, y) end
local firetouchinterest = firetouchinterest or function(part1, part2, state) end
local isrbxactive = isrbxactive or iswindowactive or function() return true end
local mouse1click = mouse1click or function() end
local mouse2click = mouse2click or function() end

if identifyexecutor then
	local name = ({identifyexecutor()})[1]
	if table.find({'Argon', 'Wave'}, name) then
		if getgenv then getgenv().setthreadidentity = nil end
	end
end

-- Global Drawing Fallback
if not Drawing then
	getgenv().Drawing = {
		new = function()
			return setmetatable({}, {
				__newindex = function() end,
				__index = function(t, k)
					if k == "Remove" or k == "Destroy" then
						return function() end
					end
					return Vector2.zero
				end
			})
		end
	}
end

-- Initialize Core Storage
shared.Modern = shared.Modern or {}
local Modern = shared.Modern
Modern.Libraries = Modern.Libraries or {}
Modern.Catalogs = Modern.Catalogs or {}
Modern.Modules = Modern.Modules or {}
Modern.ClickGuiStatus = Modern.ClickGuiStatus or { Enabled = false }
Modern.Loaded = true

-- UI Target Setup
local Players = cloneref(game:GetService('Players'))
local CoreGui = cloneref(game:GetService('CoreGui'))
local LocalPlayer = Players.LocalPlayer
local TargetGuiParent = CoreGui or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui"))

if Modern.MainScreenGui then
	Modern.MainScreenGui:Destroy()
end

Modern.MainScreenGui = Instance.new('ScreenGui')
Modern.MainScreenGui.Name = 'ModernGui'
Modern.MainScreenGui.ResetOnSpawn = false
Modern.MainScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Modern.MainScreenGui.Parent = TargetGuiParent

-- Fallback UI Palette & Helper Shims
Modern.Libraries.uipallet = Modern.Libraries.uipallet or {
	FinalColor = Color3.fromRGB(115, 130, 255),
	Font = Font.fromEnum(Enum.Font.Gotham),
}

Modern.Libraries.getfontsize = Modern.Libraries.getfontsize or function(text, size, font, bounds)
	local TextService = cloneref(game:GetService('TextService'))
	return TextService:GetTextSize(text, size, Enum.Font.Gotham, bounds or Vector2.new(10000, 10000))
end

Modern.Libraries.addGradient = Modern.Libraries.addGradient or function(parent)
	local grad = Instance.new('UIGradient')
	grad.Color = ColorSequence.new(Color3.fromRGB(115, 130, 255), Color3.fromRGB(175, 120, 255))
	grad.Parent = parent
	return grad
end

Modern.Libraries.Targetinfo = Modern.Libraries.Targetinfo or { Targets = {} }

Modern.Clean = Modern.Clean or function(self, obj)
	if typeof(obj) == 'RBXScriptConnection' then
		obj:Disconnect()
	elseif typeof(obj) == 'Instance' then
		obj:Destroy()
	end
end

Modern.Uninject = Modern.Uninject or function(self)
	Modern.Loaded = false
	if Modern.MainScreenGui then
		Modern.MainScreenGui:Destroy()
	end
end

-- Module Catalog System
local moduleUpdateCallbacks = {}

local function createCatalogShim(name)
	return {
		Name = name,
		AddModule = function(self, opts)
			local mod = {
				Name = opts.Name or 'Module',
				Category = name,
				Enabled = false,
				Clean = function(s, obj) Modern:Clean(obj) end,
				AddToggle = function(s, topts)
					return { Value = topts.Default or false, Enabled = topts.Default or false, Frame = { Visible = topts.Visible ~= false } }
				end,
				AddSlider = function(s, sopts)
					return { Value = sopts.Default or 1, Frame = { Visible = sopts.Visible ~= false } }
				end,
				AddDropdown = function(s, dopts)
					return { Value = dopts.Default or (dopts.List and dopts.List[1]) or '', Frame = { Visible = dopts.Visible ~= false } }
				end,
				AddColorPicker = function(s, copts)
					return { Value = copts.Default or Color3.new(1, 1, 1), Frame = { Visible = copts.Visible ~= false } }
				end,
				AddKeybind = function(s, kopts)
					return { Value = kopts.Default or Enum.KeyCode.Unknown, Frame = { Visible = kopts.Visible ~= false } }
				end,
				ToggleButton = function(s, state)
					s.Enabled = (state ~= nil) and state or not s.Enabled
					if opts.Function then 
						task.spawn(opts.Function, s.Enabled)
					end
					if moduleUpdateCallbacks[s.Name] then
						moduleUpdateCallbacks[s.Name](s.Enabled)
					end
				end,
				Toggle = function(s)
					s:ToggleButton()
				end
			}
			Modern.Modules[opts.Name] = mod
			return mod
		end
	}
end

for _, cat in ipairs({'Combat', 'Movement', 'Render', 'Player', 'Other', 'World', 'Minigames'}) do
	if not Modern.Catalogs[cat] then
		Modern.Catalogs[cat] = createCatalogShim(cat)
	end
end

-- Modular File Loader
shared.ModernFile = shared.ModernFile or {}
local ModernFile = shared.ModernFile
local embeddedModules = {}

ModernFile.loadfile = function(path)
	if embeddedModules[path] then
		return embeddedModules[path]()
	end
	if isfile and readfile and isfile(path) then
		return loadstring(readfile(path))()
	end
	error('[Modern] Module not found: ' .. tostring(path))
end

----------------------------------------------------------------
-- MODULE: Modern/Library/Entity.lua
----------------------------------------------------------------
embeddedModules['Modern/Library/Entity.lua'] = function()
	local entitylib = {
		isAlive = false,
		character = {},
		List = {},
		Connections = {},
		PlayerConnections = {},
		EntityThreads = {},
		Running = false,
		Events = setmetatable({}, {
			__index = function(self, ind)
				self[ind] = {
					Connections = {},
					Connect = function(rself, func)
						table.insert(rself.Connections, func)
						return {
							Disconnect = function()
								local rind = table.find(rself.Connections, func)
								if rind then
									table.remove(rself.Connections, rind)
								end
							end
						}
					end,
					Fire = function(rself, ...)
						for _, v in ipairs(rself.Connections) do
							task.spawn(v, ...)
						end
					end,
					Destroy = function(rself)
						table.clear(rself.Connections)
						table.clear(rself)
					end
				}
				return self[ind]
			end
		})
	}

	local playersService = cloneref(game:GetService('Players'))
	local inputService = cloneref(game:GetService('UserInputService'))
	local lplr = playersService.LocalPlayer
	local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end

	local function loopClean(tbl)
		for i, v in pairs(tbl) do
			if type(v) == 'table' then
				loopClean(v)
			end
			tbl[i] = nil
		end
	end

	local function waitForChildOfType(obj, name, timeout, prop)
		local checktick = tick() + timeout
		local returned
		repeat
			returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
			if returned or checktick < tick() then break end
			task.wait()
		until false
		return returned
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then return ent:TeamCheck() end
		if ent.NPC then return true end
		if not lplr.Team then return true end
		if not ent.Player.Team then return true end
		if ent.Player.Team ~= lplr.Team then return true end
		return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
	end

	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth')
		}
	end

	entitylib.isVulnerable = function(ent)
		return ent.Health > 0 and not ent.Character:FindFirstChildWhichIsA('ForceField')
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		return ent and tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	entitylib.IgnoreObject = RaycastParams.new()
	entitylib.IgnoreObject.RespectCanCollide = true

	entitylib.Wallcheck = function(origin, position, ignoreobject)
		if typeof(ignoreobject) ~= 'Instance' then
			local ignorelist = {gameCamera, lplr and lplr.Character}
			for _, v in ipairs(entitylib.List) do
				if v.Targetable then
					table.insert(ignorelist, v.Character)
				end
			end
			if typeof(ignoreobject) == 'table' then
				for _, v in ipairs(ignoreobject) do
					table.insert(ignorelist, v)
				end
			end
			ignoreobject = entitylib.IgnoreObject
			ignoreobject.FilterDescendantsInstances = ignorelist
		end
		return workspace:Raycast(origin, (position - origin), ignoreobject)
	end

	entitylib.EntityMouse = function(entitysettings)
		if entitylib.isAlive then
			local mouseLocation, sortingTable = entitysettings.MouseOrigin or getMousePosition(), {}
			for _, v in ipairs(entitylib.List) do
				if not entitysettings.Players and v.Player then continue end
				if not entitysettings.NPCs and v.NPC then continue end
				if not v.Targetable then continue end
				local position, vis = gameCamera:WorldToViewportPoint(v[entitysettings.Part].Position)
				if not vis then continue end
				local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
				if mag > entitysettings.Range then continue end
				if entitysettings.ignoreVulnerable or entitylib.isVulnerable(v) then
					table.insert(sortingTable, { Entity = v, Magnitude = v.Target and -1 or mag })
				end
			end
			table.sort(sortingTable, entitysettings.Sort or function(a, b) return a.Magnitude < b.Magnitude end)
			for _, v in ipairs(sortingTable) do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(entitysettings.Origin, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
				end
				return v.Entity
			end
		end
	end

	entitylib.EntityPosition = function(entitysettings)
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, v in ipairs(entitylib.List) do
				if not entitysettings.Players and v.Player then continue end
				if not entitysettings.NPCs and v.NPC then continue end
				if not v.Targetable then continue end
				local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(v) then
					table.insert(sortingTable, { Entity = v, Magnitude = v.Target and -1 or mag })
				end
			end
			table.sort(sortingTable, entitysettings.Sort or function(a, b) return a.Magnitude < b.Magnitude end)
			for _, v in ipairs(sortingTable) do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
				end
				return v.Entity
			end
		end
	end

	entitylib.AllPosition = function(entitysettings)
		local returned = {}
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, v in ipairs(entitylib.List) do
				if not entitysettings.Players and v.Player then continue end
				if not entitysettings.NPCs and v.NPC then continue end
				if not v.Targetable then continue end
				local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				table.insert(sortingTable, {Entity = v, Magnitude = v.Target and -1 or mag})
			end
			table.sort(sortingTable, entitysettings.Sort or function(a, b) return a.Magnitude < b.Magnitude end)
			for _, v in ipairs(sortingTable) do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) and entitylib.isVulnerable(v.Entity) then continue end
				end
				table.insert(returned, v.Entity)
				if #returned >= (entitysettings.Limit or math.huge) then break end
			end
		end
		return returned
	end

	entitylib.getEntity = function(char)
		for i, v in ipairs(entitylib.List) do
			if v.Player == char or v.Character == char then
				return v, i
			end
		end
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum = waitForChildOfType(char, 'Humanoid', 10)
			local humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
			local head = char:WaitForChild('Head', 10) or humrootpart
			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = hum.Health,
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					MaxHealth = hum.MaxHealth,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}
				if plr == lplr then
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
				else
					entity.Targetable = entitylib.targetCheck(entity)
					for _, v in ipairs(entitylib.getUpdateConnections(entity)) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = hum.Health
							entity.MaxHealth = hum.MaxHealth
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.removeEntity = function(char, localcheck)
		if localcheck then
			if entitylib.isAlive then
				entitylib.isAlive = false
				for _, v in ipairs(entitylib.character.Connections or {}) do
					v:Disconnect()
				end
				table.clear(entitylib.character.Connections or {})
				entitylib.Events.LocalRemoved:Fire(entitylib.character)
			end
			return
		end
		if char then
			if entitylib.EntityThreads[char] then
				task.cancel(entitylib.EntityThreads[char])
				entitylib.EntityThreads[char] = nil
			end
			local entity, ind = entitylib.getEntity(char)
			if ind then
				for _, v in ipairs(entity.Connections) do v:Disconnect() end
				table.clear(entity.Connections)
				table.remove(entitylib.List, ind)
				entitylib.Events.EntityRemoved:Fire(entity)
			end
		end
	end

	entitylib.refreshEntity = function(char, plr)
		entitylib.removeEntity(char)
		entitylib.addEntity(char, plr)
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then entitylib.refreshEntity(plr.Character, plr) end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char) entitylib.refreshEntity(char, plr) end),
			plr.CharacterRemoving:Connect(function(char) entitylib.removeEntity(char, plr == lplr) end),
			plr:GetPropertyChangedSignal('Team'):Connect(function()
				for _, v in ipairs(entitylib.List) do
					if v.Targetable ~= entitylib.targetCheck(v) then entitylib.refreshEntity(v.Character, v.Player) end
				end
				if plr == lplr then entitylib.start() else entitylib.refreshEntity(plr.Character, plr) end
			end)
		}
	end

	entitylib.removePlayer = function(plr)
		if entitylib.PlayerConnections[plr] then
			for _, v in ipairs(entitylib.PlayerConnections[plr]) do v:Disconnect() end
			table.clear(entitylib.PlayerConnections[plr])
			entitylib.PlayerConnections[plr] = nil
		end
		entitylib.removeEntity(plr)
	end

	entitylib.start = function()
		if entitylib.Running then entitylib.stop() end
		table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v) entitylib.addPlayer(v) end))
		table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v) entitylib.removePlayer(v) end))
		for _, v in ipairs(playersService:GetPlayers()) do entitylib.addPlayer(v) end
		table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end))
		entitylib.Running = true
	end

	entitylib.stop = function()
		for _, v in ipairs(entitylib.Connections) do v:Disconnect() end
		for _, v in pairs(entitylib.PlayerConnections) do
			for _, v2 in ipairs(v) do v2:Disconnect() end
			table.clear(v)
		end
		entitylib.removeEntity(nil, true)
		local cloned = table.clone(entitylib.List)
		for _, v in ipairs(cloned) do entitylib.removeEntity(v.Character) end
		for _, v in pairs(entitylib.EntityThreads) do task.cancel(v) end
		table.clear(entitylib.PlayerConnections)
		table.clear(entitylib.EntityThreads)
		table.clear(entitylib.Connections)
		table.clear(cloned)
		entitylib.Running = false
	end

	entitylib.kill = function()
		if entitylib.Running then entitylib.stop() end
		for _, v in pairs(entitylib.Events) do v:Destroy() end
		entitylib.IgnoreObject:Destroy()
		loopClean(entitylib)
	end

	entitylib.start()
	return entitylib
end

----------------------------------------------------------------
-- MODULE: Modern/Library/Prediction.lua
----------------------------------------------------------------
embeddedModules['Modern/Library/Prediction.lua'] = function()
	local module = {}
	local eps = 1e-9

	local function isZero(d) return (d > -eps and d < eps) end
	local function cuberoot(x) return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3)) end

	local function solveQuadric(c0, c1, c2)
		local s0, s1
		local p, q, D = c1 / (2 * c0), c2 / c0, nil
		D = p * p - q
		if isZero(D) then
			s0 = -p
			return s0
		elseif (D < 0) then
			return
		else
			local sqrt_D = math.sqrt(D)
			s0 = sqrt_D - p
			s1 = -sqrt_D - p
			return s0, s1
		end
	end

	local function solveCubic(c0, c1, c2, c3)
		local s0, s1, s2, num, sub
		local A, B, C = c1 / c0, c2 / c0, c3 / c0
		local sq_A = A * A
		local p = (1 / 3) * (-(1 / 3) * sq_A + B)
		local q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)
		local cb_p = p * p * p
		local D = q * q + cb_p
		if isZero(D) then
			if isZero(q) then
				s0 = 0
				num = 1
			else
				local u = cuberoot(-q)
				s0 = 2 * u
				s1 = -u
				num = 2
			end
		elseif (D < 0) then
			local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
			local t = 2 * math.sqrt(-p)
			s0 = t * math.cos(phi)
			s1 = -t * math.cos(phi + math.pi / 3)
			s2 = -t * math.cos(phi - math.pi / 3)
			num = 3
		else
			local sqrt_D = math.sqrt(D)
			local u = cuberoot(sqrt_D - q)
			local v = -cuberoot(sqrt_D + q)
			s0 = u + v
			num = 1
		end
		sub = (1 / 3) * A
		if (num > 0) then s0 = s0 - sub end
		if (num > 1) then s1 = s1 - sub end
		if (num > 2) then s2 = s2 - sub end
		return s0, s1, s2
	end

	function module.solveQuartic(c0, c1, c2, c3, c4)
		local s0, s1, s2, s3
		local coeffs = {}
		local z, u, v, sub, num
		local A, B, C, D = c1 / c0, c2 / c0, c3 / c0, c4 / c0
		local sq_A = A * A
		local p = -0.375 * sq_A + B
		local q = 0.125 * sq_A * A - 0.5 * A * B + C
		local r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

		if isZero(r) then
			coeffs[3], coeffs[2], coeffs[1], coeffs[0] = q, p, 0, 1
			local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
			num = #results
			s0, s1, s2 = results[1], results[2], results[3]
		else
			coeffs[3], coeffs[2], coeffs[1], coeffs[0] = 0.5 * r * p - 0.125 * q * q, -r, -0.5 * p, 1
			s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
			z = s0
			u = z * z - r
			v = 2 * z - p
			if isZero(u) then u = 0 elseif (u > 0) then u = math.sqrt(u) else return end
			if isZero(v) then v = 0 elseif (v > 0) then v = math.sqrt(v) else return end
			coeffs[2], coeffs[1], coeffs[0] = z - u, q < 0 and -v or v, 1
			do
				local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
				num = #results
				s0, s1 = results[1], results[2]
			end
			coeffs[2], coeffs[1], coeffs[0] = z + u, q < 0 and v or -v, 1
			if (num == 0) then
				local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
				num = num + #results
				s0, s1 = results[1], results[2]
			elseif (num == 1) then
				local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
				num = num + #results
				s1, s2 = results[1], results[2]
			elseif (num == 2) then
				local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
				num = num + #results
				s2, s3 = results[1], results[2]
			end
		end
		sub = 0.25 * A
		if (num > 0) then s0 = s0 - sub end
		if (num > 1) then s1 = s1 - sub end
		if (num > 2) then s2 = s2 - sub end
		if (num > 3) then s3 = s3 - sub end
		return {s3, s2, s1, s0}
	end

	function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
		local disp = targetPos - origin
		local p, q, r = targetVelocity.X, targetVelocity.Y, targetVelocity.Z
		local h, j, k = disp.X, disp.Y, disp.Z
		local l = -.5 * gravity

		if math.abs(q) > 0.01 and playerGravity and playerGravity > 0 then
			local estTime = (disp.Magnitude / projectileSpeed)
			for i = 1, 100 do
				q -= (.5 * playerGravity) * estTime
				local velo = targetVelocity * 0.016
				local ray = workspace:Raycast(Vector3.new(targetPos.X, targetPos.Y, targetPos.Z), Vector3.new(velo.X, (q * estTime) - playerHeight, velo.Z), params)
				if ray then
					local newTarget = ray.Position + Vector3.new(0, playerHeight, 0)
					estTime -= math.sqrt(((targetPos - newTarget).Magnitude * 2) / playerGravity)
					targetPos = newTarget
					j = (targetPos - origin).Y
					q = 0
					break
				else
					break
				end
			end
		end

		local solutions = module.solveQuartic(
			l*l,
			-2*q*l,
			q*q - 2*j*l - projectileSpeed*projectileSpeed + p*p + r*r,
			2*j*q + 2*h*p + 2*k*r,
			j*j + h*h + k*k
		)

		if solutions then
			local posRoots = {}
			for _, v in ipairs(solutions) do
				if v > 0 then table.insert(posRoots, v) end
			end
			if posRoots[1] then
				local t = posRoots[1]
				local d = (h + p*t)/t
				local e = (j + q*t - l*t*t)/t
				local f = (k + r*t)/t
				return origin + Vector3.new(d, e, f)
			end
		elseif gravity == 0 then
			local t = (disp.Magnitude / projectileSpeed)
			local d = (h + p*t)/t
			local e = (j + q*t - l*t*t)/t
			local f = (k + r*t)/t
			return origin + Vector3.new(d, e, f)
		end
	end

	return module
end

----------------------------------------------------------------
-- MODULE INITIALIZATION & UNIVERSAL FEATURES
----------------------------------------------------------------
local UserInputService = cloneref(game:GetService('UserInputService'))
local RunService = cloneref(game:GetService('RunService'))
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = Players.LocalPlayer

local entitylib = ModernFile.loadfile("Modern/Library/Entity.lua")
local prediction = ModernFile.loadfile("Modern/Library/Prediction.lua")

Modern.Libraries.entitylib = entitylib
Modern.Libraries.prediction = prediction

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function getTool()
	return lplr and lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function addRoundedShadow(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Shadow'
	blur.Size = UDim2.new(1, 18, 1, 18)
	blur.AnchorPoint = Vector2.new(0.5, 0.5)
	blur.Position = UDim2.fromScale(0.5, 0.5)
	blur.BackgroundTransparency = 1
	blur.Image = "rbxassetid://85528155206269"
	blur.ScaleType = Enum.ScaleType.Slice
	blur.ImageTransparency = 0.5
	blur.SliceCenter = Rect.new(36, 36, 900, 50)
	blur.SliceScale = 0.5
	blur.ZIndex = -100
	blur.Parent = parent
	return blur
end

local function addCorner(parent, radius)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = radius or UDim.new(0, 5)
	corner.Parent = parent
	return corner
end

local frictionTable, oldfrict = {}, {}
local function updateVelocity()
	if next(frictionTable) then
		if entitylib.isAlive then
			for _, v in ipairs(entitylib.character.Character:GetChildren()) do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in pairs(oldfrict) do
			if i and i.Parent then
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
		end
		table.clear(oldfrict)
	end
end

Modern:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
Modern:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
	gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
end))

-- Register Modules (Aim Assist, Auto Clicker, Reach, Aura, Fly, Speed, NameTags)
-- Aim Assist
task.spawn(function()
	local AimAssist, Part, FOV, Speed, RightClick, ShowTarget, CircleFilled, CircleObject
	local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)

	local function wrapAngle(num)
		num = num % math.pi
		num -= num >= (math.pi / 2) and math.pi or 0
		num += num < -(math.pi / 2) and math.pi or 0
		return num
	end

	AimAssist = Modern.Catalogs.Combat:AddModule({
		Name = 'Aim Assist',
		Function = function(callback)
			if CircleObject then CircleObject.Visible = callback end
			if callback then
				local ent
				local rightClicked = not RightClick.Enabled or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
				AimAssist:Clean(RunService.RenderStepped:Connect(function(dt)
					if CircleObject then CircleObject.Position = UserInputService:GetMouseLocation() end
					if rightClicked and not Modern.ClickGuiStatus.Enabled then
						ent = entitylib.EntityMouse({
							Range = FOV.Value, Part = Part.Value, Players = true, NPCs = false, Wallcheck = true, Origin = gameCamera.CFrame.Position
						})
						if ent then
							local facing = gameCamera.CFrame.LookVector
							local new = (ent[Part.Value].Position - gameCamera.CFrame.Position).Unit
							new = new == new and new or Vector3.zero
							if ShowTarget.Enabled then Modern.Libraries.Targetinfo.Targets[ent] = tick() + 1 end
							if new ~= Vector3.zero then
								local diffYaw = wrapAngle(math.atan2(facing.X, facing.Z) - math.atan2(new.X, new.Z))
								local diffPitch = math.asin(facing.Y) - math.asin(new.Y)
								local angle = Vector2.new(diffYaw, diffPitch) / (moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity)
								angle *= math.min(Speed.Value * dt, 1)
								mousemoverel(angle.X, angle.Y)
							end
						end
					end
				end))

				if RightClick.Enabled then
					AimAssist:Clean(UserInputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then ent = nil; rightClicked = true end
					end))
					AimAssist:Clean(UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then rightClicked = false end
					end))
				end
			end
		end
	})

	Part = AimAssist:AddDropdown({ Name = 'Part', List = {'RootPart', 'Head'} })
	FOV = AimAssist:AddSlider({ Name = 'FOV', Min = 0, Max = 1000, Default = 100, Function = function(val) if CircleObject then CircleObject.Radius = val end end })
	Speed = AimAssist:AddSlider({ Name = 'Speed', Min = 0, Max = 80, Default = 15 })
	AimAssist:AddToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromRGB(255, 255, 255)
				CircleObject.Position = Modern.MainScreenGui.AbsoluteSize / 2
				CircleObject.Radius = FOV.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 0.9
				CircleObject.Visible = AimAssist.Enabled
			else
				pcall(function() CircleObject.Visible = false; CircleObject:Remove() end)
			end
			CircleFilled.Frame.Visible = callback
		end
	})
	CircleFilled = AimAssist:AddToggle({ Name = 'Circle Filled', Function = function(callback) if CircleObject then CircleObject.Filled = callback end end, Visible = false })
	RightClick = AimAssist:AddToggle({ Name = 'Require right click' })
	ShowTarget = AimAssist:AddToggle({ Name = 'Show Target' })
end)

-- Auto Clicker
task.spawn(function()
	local AutoClicker, Mode, CPS
	AutoClicker = Modern.Catalogs.Combat:AddModule({
		Name = 'Auto Clicker',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat
						if Mode.Value == 'Tool' then
							local tool = getTool()
							if tool and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then tool:Activate() end
						else
							if isrbxactive() and not Modern.ClickGuiStatus.Enabled then
								(Mode.Value == 'Click' and mouse1click or mouse2click)()
							end
						end
						task.wait(1 / CPS.Value)
					until not AutoClicker.Enabled
				end)
			end
		end
	})
	Mode = AutoClicker:AddDropdown({ Name = 'Mode', List = {'Tool', 'Click', 'RightClick'} })
	CPS = AutoClicker:AddSlider({ Name = 'CPS', Min = 1, Max = 20, Default = 10 })
end)

-- Reach
task.spawn(function()
	local Reach, Mode, Value, Chance
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local modified = {}

	Reach = Modern.Catalogs.Combat:AddModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat
						local tool = getTool()
						tool = tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true)
						if tool and tool.Parent then
							if Mode.Value == 'TouchInterest' then
								local entities = {}
								for _, v in ipairs(entitylib.List) do
									if v.Targetable and v.Player then table.insert(entities, v.Character) end
								end
								Overlay.FilterDescendantsInstances = entities
								local parts = workspace:GetPartBoundsInBox(tool.Parent.CFrame * CFrame.new(0, 0, Value.Value / 2), tool.Parent.Size + Vector3.new(0, 0, Value.Value), Overlay)
								for _, v in ipairs(parts) do
									if Random.new():NextNumber(0, 100) > Chance.Value then task.wait(0.2); break end
									firetouchinterest(tool.Parent, v, 1)
									firetouchinterest(tool.Parent, v, 0)
								end
							else
								if not modified[tool.Parent] then modified[tool.Parent] = tool.Parent.Size end
								tool.Parent.Size = modified[tool.Parent] + Vector3.new(0, 0, Value.Value)
								tool.Parent.Massless = true
							end
						end
						task.wait(0.1)
					until not Reach.Enabled
				end)
			else
				for i, v in pairs(modified) do
					if i and i.Parent then i.Size = v; i.Massless = false end
				end
				table.clear(modified)
			end
		end
	})
	Mode = Reach:AddDropdown({ Name = 'Mode', List = {'TouchInterest', 'Resize'}, Function = function(val) Chance.Frame.Visible = val == 'TouchInterest' end })
	Value = Reach:AddSlider({ Name = 'Range', Min = 0, Max = 10, Default = 3 })
	Chance = Reach:AddSlider({ Name = 'Chance', Min = 0, Max = 100, Default = 100 })
end)

-- Aura
task.spawn(function()
	local Killaura, CPS, SwingRange, AttackRange, AngleSlider, Max, Mouse
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Boxes, AttackDelay = {}, tick()

	local function getAttackData()
		if Mouse.Enabled and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return false end
		local tool = getTool()
		return tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true) or nil, tool
	end

	Killaura = Modern.Catalogs.Combat:AddModule({
		Name = 'Aura',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat
						local interest, tool = getAttackData()
						local attacked = {}
						if interest and tool then
							local plrs = entitylib.AllPosition({
								Range = SwingRange.Value, Wallcheck = nil, Part = 'RootPart', Players = true, NPCs = false, Limit = Max.Value
							})
							if #plrs > 0 then
								local selfpos = entitylib.character.RootPart.Position
								local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

								for _, v in ipairs(plrs) do
									local delta = (v.RootPart.Position - selfpos)
									local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
									if angle > (math.rad(AngleSlider.Value) / 2) then continue end

									table.insert(attacked, v)
									Modern.Libraries.Targetinfo.Targets[v] = tick() + 1

									if AttackDelay < tick() then
										AttackDelay = tick() + (1 / CPS.Value)
										tool:Activate()
									end

									if delta.Magnitude > AttackRange.Value then continue end

									Overlay.FilterDescendantsInstances = {v.Character}
									for _, part in ipairs(workspace:GetPartBoundsInBox(v.RootPart.CFrame, Vector3.new(4, 4, 4), Overlay)) do
										firetouchinterest(interest.Parent, part, 1)
										firetouchinterest(interest.Parent, part, 0)
									end
								end
							end
						end
						task.wait(0.05)
					until not Killaura.Enabled
				end)
			end
		end
	})
	CPS = Killaura:AddSlider({ Name = 'Attacks per Second', Min = 1, Max = 20, Default = 10 })
	SwingRange = Killaura:AddSlider({ Name = 'Swing range', Min = 1, Max = 30, Default = 13 })
	AttackRange = Killaura:AddSlider({ Name = 'Attack range', Min = 1, Max = 30, Default = 13 })
	AngleSlider = Killaura:AddSlider({ Name = 'Max angle', Min = 1, Max = 360, Default = 90 })
	Max = Killaura:AddSlider({ Name = 'Max targets', Min = 1, Max = 10, Default = 10 })
	Mouse = Killaura:AddToggle({ Name = 'Require Click' })
end)

-- Movement Methods Helper
local SpeedMethods = {
	Velocity = function(options, moveDirection)
		if entitylib.isAlive and entitylib.character.RootPart then
			local root = entitylib.character.RootPart
			root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
	end,
	Impulse = function(options, moveDirection)
		if entitylib.isAlive and entitylib.character.RootPart then
			local root = entitylib.character.RootPart
			local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
			if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
				root:ApplyImpulse(diff * root.AssemblyMass)
			end
		end
	end,
	CFrame = function(options, moveDirection, dt)
		if entitylib.isAlive and entitylib.character.RootPart then
			local root = entitylib.character.RootPart
			local dest = (moveDirection * math.max(options.Value.Value - (entitylib.character.Humanoid and entitylib.character.Humanoid.WalkSpeed or 16), 0) * (dt or 0.016))
			root.CFrame += dest
		end
	end,
	WalkSpeed = function(options)
		if entitylib.isAlive and entitylib.character.Humanoid then
			entitylib.character.Humanoid.WalkSpeed = options.Value.Value
		end
	end
}

-- Fly
task.spawn(function()
	local Fly, Mode, Options, CustomProperties
	Fly = Modern.Catalogs.Movement:AddModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Fly:Clean(RunService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and entitylib.character.RootPart then
						local movevec = calculateMoveVector(Vector3.new(
							(UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0),
							0,
							(UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
						))
						local upDown = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 1 or 0)
						local velocity = (movevec * Options.Value.Value) + Vector3.new(0, upDown * Options.Value.Value, 0)
						entitylib.character.RootPart.AssemblyLinearVelocity = velocity
					end
				end))
			else
				if entitylib.isAlive and entitylib.character.RootPart then
					entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	})
	Options = { Value = Fly:AddSlider({ Name = 'Speed', Min = 1, Max = 150, Default = 50 }) }
	CustomProperties = Fly:AddToggle({ Name = 'Custom Properties', Default = true })
end)

-- Speed
task.spawn(function()
	local Speed, Mode, Options, AutoJump, CustomProperties
	Speed = Modern.Catalogs.Movement:AddModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Speed:Clean(RunService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not Modern.Modules.Fly.Enabled then
						local movevec = entitylib.character.Humanoid.MoveDirection
						if SpeedMethods[Mode.Value] then
							SpeedMethods[Mode.Value](Options, movevec, dt)
						end
						if AutoJump.Enabled and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and movevec ~= Vector3.zero then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end))
			else
				if entitylib.isAlive and entitylib.character.Humanoid then
					entitylib.character.Humanoid.WalkSpeed = 16
				end
			end
		end
	})

	Mode = Speed:AddDropdown({ Name = 'Mode', List = {'Velocity', 'Impulse', 'CFrame', 'WalkSpeed'} })
	Options = { Value = Speed:AddSlider({ Name = 'Speed', Min = 1, Max = 150, Default = 50 }) }
	CustomProperties = Speed:AddToggle({ Name = 'Custom Properties', Default = true })
	AutoJump = Speed:AddToggle({ Name = 'AutoJump' })
end)

-- NameTags
task.spawn(function()
	local NameTags, Scale, Background, Health, Distance
	local Reference = {}

	local function addTag(ent)
		if ent.NPC or Reference[ent] then return end
		local tag = Instance.new('TextLabel')
		tag.TextSize = 14 * (Scale and Scale.Value or 1)
		tag.FontFace = Modern.Libraries.uipallet.Font
		tag.Size = UDim2.fromOffset(120, 24)
		tag.AnchorPoint = Vector2.new(0.5, 1)
		tag.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
		tag.BackgroundTransparency = Background and Background.Value or 0.4
		tag.TextColor3 = Color3.fromRGB(255, 255, 255)
		tag.RichText = true
		tag.Parent = Modern.MainScreenGui
		addCorner(tag, UDim.new(0, 4))
		Reference[ent] = tag
	end

	local function removeTag(ent)
		if Reference[ent] then
			Reference[ent]:Destroy()
			Reference[ent] = nil
		end
	end

	NameTags = Modern.Catalogs.Render:AddModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				for _, ent in ipairs(entitylib.List) do addTag(ent) end
				NameTags:Clean(entitylib.Events.EntityAdded:Connect(addTag))
				NameTags:Clean(entitylib.Events.EntityRemoved:Connect(removeTag))
				NameTags:Clean(RunService.RenderStepped:Connect(function()
					for ent, tag in pairs(Reference) do
						if ent and ent.RootPart and ent.RootPart.Parent then
							local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
							tag.Visible = headVis
							if headVis then
								local str = (ent.Player and ent.Player.Name or 'Entity')
								if Health.Enabled then str = str .. string.format(' <font color="rgb(100,255,100)">[%d]</font>', math.round(ent.Health)) end
								if Distance.Enabled and entitylib.isAlive then
									local mag = math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)
									str = string.format('<font color="rgb(175,175,255)">%dm</font> ', mag) .. str
								end
								tag.Text = str
								tag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
							end
						else
							removeTag(ent)
						end
					end
				end))
			else
				for ent in pairs(Reference) do removeTag(ent) end
			end
		end
	})

	Scale = NameTags:AddSlider({ Name = 'Scale', Default = 1, Min = 0.5, Max = 1.5 })
	Background = NameTags:AddSlider({ Name = 'Transparency', Default = 0.4, Min = 0, Max = 1 })
	Health = NameTags:AddToggle({ Name = 'Health', Default = true })
	Distance = NameTags:AddToggle({ Name = 'Distance', Default = true })
end)

----------------------------------------------------------------
-- INTERACTIVE TEST GUI BUILDER
----------------------------------------------------------------
local function buildInteractiveGUI()
	local MainFrame = Instance.new('Frame')
	MainFrame.Name = 'ModernTestWindow'
	MainFrame.Size = UDim2.fromOffset(580, 360)
	MainFrame.Position = UDim2.new(0.5, -290, 0.5, -180)
	MainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	MainFrame.BorderSizePixel = 0
	MainFrame.Active = true
	MainFrame.Draggable = true
	MainFrame.Parent = Modern.MainScreenGui

	addCorner(MainFrame, UDim.new(0, 8))
	addRoundedShadow(MainFrame)

	-- Header Title Bar
	local Header = Instance.new('Frame')
	Header.Name = 'Header'
	Header.Size = UDim2.new(1, 0, 0, 40)
	Header.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
	Header.BorderSizePixel = 0
	Header.Parent = MainFrame
	addCorner(Header, UDim.new(0, 8))

	local Title = Instance.new('TextLabel')
	Title.Size = UDim2.new(1, -20, 1, 0)
	Title.Position = UDim2.fromOffset(12, 0)
	Title.BackgroundTransparency = 1
	Title.Text = "<b>MODERN UNIVERSAL</b> <font color='rgb(115,130,255)'>[Test GUI]</font>"
	Title.RichText = true
	Title.TextColor3 = Color3.fromRGB(240, 240, 240)
	Title.TextSize = 16
	Title.FontFace = Modern.Libraries.uipallet.Font
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = Header

	local KeyHint = Instance.new('TextLabel')
	KeyHint.Size = UDim2.new(0, 180, 1, 0)
	KeyHint.Position = UDim2.new(1, -190, 0, 0)
	KeyHint.BackgroundTransparency = 1
	KeyHint.Text = "[Press RightShift / Insert to Toggle]"
	KeyHint.TextColor3 = Color3.fromRGB(140, 145, 160)
	KeyHint.TextSize = 12
	KeyHint.FontFace = Modern.Libraries.uipallet.Font
	KeyHint.TextXAlignment = Enum.TextXAlignment.Right
	KeyHint.Parent = Header

	-- Sidebar Category Tabs
	local Sidebar = Instance.new('Frame')
	Sidebar.Size = UDim2.new(0, 130, 1, -40)
	Sidebar.Position = UDim2.fromOffset(0, 40)
	Sidebar.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
	Sidebar.BorderSizePixel = 0
	Sidebar.Parent = MainFrame

	local SidebarLayout = Instance.new('UIListLayout')
	SidebarLayout.Padding = UDim.new(0, 4)
	SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	SidebarLayout.Parent = Sidebar

	local SidebarPadding = Instance.new('UIPadding')
	SidebarPadding.PaddingTop = UDim.new(0, 8)
	SidebarPadding.Parent = Sidebar

	-- Container for Category Pages
	local ContentArea = Instance.new('Frame')
	ContentArea.Size = UDim2.new(1, -140, 1, -50)
	ContentArea.Position = UDim2.fromOffset(135, 45)
	ContentArea.BackgroundTransparency = 1
	ContentArea.Parent = MainFrame

	local categoryPages = {}
	local categoryButtons = {}

	local categories = {'Combat', 'Movement', 'Render', 'Player', 'Other', 'World', 'Minigames'}

	for i, catName in ipairs(categories) do
		-- Create Category Page Frame
		local page = Instance.new('ScrollingFrame')
		page.Name = catName .. 'Page'
		page.Size = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 4
		page.ScrollBarImageColor3 = Color3.fromRGB(115, 130, 255)
		page.Visible = (i == 1)
		page.Parent = ContentArea

		local grid = Instance.new('UIGridLayout')
		grid.CellSize = UDim2.fromOffset(205, 42)
		grid.CellPadding = UDim2.fromOffset(8, 8)
		grid.SortOrder = Enum.SortOrder.Name
		grid.Parent = page

		categoryPages[catName] = page

		-- Create Sidebar Tab Button
		local tabBtn = Instance.new('TextButton')
		tabBtn.Size = UDim2.new(0, 115, 0, 32)
		tabBtn.BackgroundColor3 = (i == 1) and Color3.fromRGB(115, 130, 255) or Color3.fromRGB(32, 35, 45)
		tabBtn.Text = catName
		tabBtn.TextColor3 = (i == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 175, 190)
		tabBtn.TextSize = 13
		tabBtn.FontFace = Modern.Libraries.uipallet.Font
		tabBtn.Parent = Sidebar
		addCorner(tabBtn, UDim.new(0, 5))

		categoryButtons[catName] = tabBtn

		tabBtn.MouseButton1Click:Connect(function()
			for cName, pFrame in pairs(categoryPages) do
				pFrame.Visible = (cName == catName)
			end
			for cName, bBtn in pairs(categoryButtons) do
				bBtn.BackgroundColor3 = (cName == catName) and Color3.fromRGB(115, 130, 255) or Color3.fromRGB(32, 35, 45)
				bBtn.TextColor3 = (cName == catName) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 175, 190)
			end
		end)
	end

	-- Populate Module Toggle Buttons dynamically
	for modName, mod in pairs(Modern.Modules) do
		local catPage = categoryPages[mod.Category] or categoryPages['Other']
		if catPage then
			local btn = Instance.new('TextButton')
			btn.Name = modName
			btn.Size = UDim2.fromOffset(205, 42)
			btn.BackgroundColor3 = mod.Enabled and Color3.fromRGB(50, 180, 100) or Color3.fromRGB(34, 37, 48)
			btn.Text = "  " .. modName .. (mod.Enabled and " [ON]" or " [OFF]")
			btn.TextColor3 = Color3.fromRGB(240, 240, 240)
			btn.TextSize = 13
			btn.FontFace = Modern.Libraries.uipallet.Font
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.Parent = catPage
			addCorner(btn, UDim.new(0, 6))

			-- Accent line indicator
			local accent = Instance.new('Frame')
			accent.Size = UDim2.new(0, 4, 1, -12)
			accent.Position = UDim2.fromOffset(6, 6)
			accent.BackgroundColor3 = mod.Enabled and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(80, 85, 100)
			accent.BorderSizePixel = 0
			accent.Parent = btn
			addCorner(accent, UDim.new(0, 2))

			local function updateVisuals(state)
				btn.BackgroundColor3 = state and Color3.fromRGB(45, 140, 85) or Color3.fromRGB(34, 37, 48)
				accent.BackgroundColor3 = state and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(80, 85, 100)
				btn.Text = "      " .. modName .. (state and " [ENABLED]" or " [OFF]")
			end

			moduleUpdateCallbacks[modName] = updateVisuals
			updateVisuals(mod.Enabled)

			btn.MouseButton1Click:Connect(function()
				mod:Toggle()
			end)
		end
	end

	-- Open/Close Menu Keybind Handler
	Modern.ClickGuiStatus.Enabled = true
	UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert) then
			MainFrame.Visible = not MainFrame.Visible
			Modern.ClickGuiStatus.Enabled = MainFrame.Visible
		end
	end)
end

-- Initialize Test Interface
task.defer(buildInteractiveGUI)
