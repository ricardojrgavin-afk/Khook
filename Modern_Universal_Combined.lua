--[[ Modern Universal - Standalone Combined Bundle
     Assembled, cleaned, and fully fixed.
     Includes: EntityLib, Prediction, and Universal Features
--]]

-- Environment & Executor Compatibility
local cloneref = cloneref or function(obj) return obj end
if identifyexecutor then
	local name = ({identifyexecutor()})[1]
	if table.find({'Argon', 'Wave'}, name) then
		if getgenv then getgenv().setthreadidentity = nil end
	end
end

-- Initialize Modern Table & Core Storage
shared.Modern = shared.Modern or {}
local Modern = shared.Modern
Modern.Libraries = Modern.Libraries or {}
Modern.Catalogs = Modern.Catalogs or {}
Modern.Modules = Modern.Modules or {}
Modern.ClickGuiStatus = Modern.ClickGuiStatus or { Enabled = false }
Modern.Loaded = true

-- Fallback UI Target
local CoreGui = cloneref(game:GetService('CoreGui'))
Modern.MainScreenGui = Modern.MainScreenGui or CoreGui:FindFirstChild('ModernGui') or Instance.new('ScreenGui', CoreGui)

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
end

-- Modern Modular Catalog Fallback
local function createCatalogShim(name)
	return {
		Name = name,
		AddModule = function(self, opts)
			local mod = {
				Name = opts.Name or 'Module',
				Enabled = false,
				Clean = function(s, obj) Modern:Clean(obj) end,
				AddToggle = function(s, topts)
					local tog = { 
						Value = topts.Default or false, 
						Enabled = topts.Default or false, 
						Frame = { Visible = topts.Visible ~= false } 
					}
					return tog
				end,
				AddSlider = function(s, sopts)
					local sld = { 
						Value = sopts.Default or 1, 
						Frame = { Visible = sopts.Visible ~= false } 
					}
					return sld
				end,
				AddDropdown = function(s, dopts)
					local drp = { 
						Value = dopts.Default or (dopts.List and dopts.List[1]) or '', 
						Frame = { Visible = dopts.Visible ~= false } 
					}
					return drp
				end,
				AddColorPicker = function(s, copts)
					local clr = { 
						Value = copts.Default or Color3.new(1, 1, 1), 
						Frame = { Visible = copts.Visible ~= false } 
					}
					return clr
				end,
				AddKeybind = function(s, kopts)
					local kbd = { 
						Value = kopts.Default or Enum.KeyCode.Unknown, 
						Frame = { Visible = kopts.Visible ~= false } 
					}
					return kbd
				end,
				ToggleButton = function(s, state)
					s.Enabled = (state ~= nil) and state or not s.Enabled
					if opts.Function then opts.Function(s.Enabled) end
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

-- Embedded In-Memory Module Loader
shared.ModernFile = shared.ModernFile or {}
local ModernFile = shared.ModernFile
local embeddedModules = {}

ModernFile.loadfile = function(path)
	if embeddedModules[path] then
		return embeddedModules[path]()
	end
	if isfile and isfile(path) then
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
						for _, v in rself.Connections do
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

	local cloneref = cloneref or function(obj) return obj end
	local playersService = cloneref(game:GetService('Players'))
	local inputService = cloneref(game:GetService('UserInputService'))
	local lplr = playersService.LocalPlayer
	local gameCamera = workspace.CurrentCamera

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end

	local function loopClean(tbl)
		for i, v in tbl do
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
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
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
			local ignorelist = {gameCamera, lplr.Character}
			for _, v in entitylib.List do
				if v.Targetable then
					table.insert(ignorelist, v.Character)
				end
			end
			if typeof(ignoreobject) == 'table' then
				for _, v in ignoreobject do
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
			for _, v in entitylib.List do
				if not entitysettings.Players and v.Player then continue end
				if not entitysettings.NPCs and v.NPC then continue end
				if not v.Targetable then continue end
				local position, vis = gameCamera:WorldToViewportPoint(v[entitysettings.Part].Position)
				if not vis then continue end
				local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
				if mag > entitysettings.Range then continue end
				if entitysettings.ignoreVulnerable or entitylib.isVulnerable(v) then
					table.insert(sortingTable, {
						Entity = v,
						Magnitude = v.Target and -1 or mag
					})
				end
			end
			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)
			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(entitysettings.Origin, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.EntityPosition = function(entitysettings)
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, v in entitylib.List do
				if not entitysettings.Players and v.Player then continue end
				if not entitysettings.NPCs and v.NPC then continue end
				if not v.Targetable then continue end
				local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(v) then
					table.insert(sortingTable, {
						Entity = v,
						Magnitude = v.Target and -1 or mag
					})
				end
			end
			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)
			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.AllPosition = function(entitysettings)
		local returned = {}
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, v in entitylib.List do
				if not entitysettings.Players and v.Player then continue end
				if not entitysettings.NPCs and v.NPC then continue end
				if not v.Targetable then continue end
				local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				table.insert(sortingTable, {Entity = v, Magnitude = v.Target and -1 or mag})
			end
			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)
			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) and entitylib.isVulnerable(v.Entity) then continue end
				end
				table.insert(returned, v.Entity)
				if #returned >= (entitysettings.Limit or math.huge) then break end
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
		return returned
	end

	entitylib.getEntity = function(char)
		for i, v in entitylib.List do
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
					for _, v in entitylib.getUpdateConnections(entity) do
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
				for _, v in entitylib.character.Connections do
					v:Disconnect()
				end
				table.clear(entitylib.character.Connections)
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
				for _, v in entity.Connections do
					v:Disconnect()
				end
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
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetPropertyChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end
				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.removePlayer = function(plr)
		if entitylib.PlayerConnections[plr] then
			for _, v in entitylib.PlayerConnections[plr] do
				v:Disconnect()
			end
			table.clear(entitylib.PlayerConnections[plr])
			entitylib.PlayerConnections[plr] = nil
		end
		entitylib.removeEntity(plr)
	end

	entitylib.start = function()
		if entitylib.Running then
			entitylib.stop()
		end
		table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
			entitylib.addPlayer(v)
		end))
		table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
			entitylib.removePlayer(v)
		end))
		for _, v in playersService:GetPlayers() do
			entitylib.addPlayer(v)
		end
		table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end))
		entitylib.Running = true
	end

	entitylib.stop = function()
		for _, v in entitylib.Connections do
			v:Disconnect()
		end
		for _, v in entitylib.PlayerConnections do
			for _, v2 in v do
				v2:Disconnect()
			end
			table.clear(v)
		end
		entitylib.removeEntity(nil, true)
		local cloned = table.clone(entitylib.List)
		for _, v in cloned do
			entitylib.removeEntity(v.Character)
		end
		for _, v in entitylib.EntityThreads do
			task.cancel(v)
		end
		table.clear(entitylib.PlayerConnections)
		table.clear(entitylib.EntityThreads)
		table.clear(entitylib.Connections)
		table.clear(cloned)
		entitylib.Running = false
	end

	entitylib.kill = function()
		if entitylib.Running then
			entitylib.stop()
		end
		for _, v in entitylib.Events do
			v:Destroy()
		end
		entitylib.IgnoreObject:Destroy()
		loopClean(entitylib)
	end

	entitylib.refresh = function()
		local cloned = table.clone(entitylib.List)
		for _, v in cloned do
			entitylib.refreshEntity(v.Character, v.Player)
		end
		table.clear(cloned)
	end

	entitylib.start()
	return entitylib
end

----------------------------------------------------------------
-- MODULE: Modern/Library/Prediction.lua
----------------------------------------------------------------
embeddedModules['Modern/Library/Prediction.lua'] = function()
	--!optimize 2
	local module = {}
	local eps = 1e-9

	local function isZero(d)
		return (d > -eps and d < eps)
	end

	local function cuberoot(x)
		return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
	end

	local function solveQuadric(c0, c1, c2)
		local s0, s1
		local p, q, D
		p = c1 / (2 * c0)
		q = c2 / c0
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
		local s0, s1, s2
		local num, sub
		local A, B, C
		local sq_A, p, q
		local cb_p, D
		A = c1 / c0
		B = c2 / c0
		C = c3 / c0
		sq_A = A * A
		p = (1 / 3) * (-(1 / 3) * sq_A + B)
		q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)
		cb_p = p * p * p
		D = q * q + cb_p
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
		local z, u, v, sub
		local A, B, C, D
		local sq_A, p, q, r
		local num
		A = c1 / c0
		B = c2 / c0
		C = c3 / c0
		D = c4 / c0
		sq_A = A * A
		p = -0.375 * sq_A + B
		q = 0.125 * sq_A * A - 0.5 * A * B + C
		r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D
		if isZero(r) then
			coeffs[3] = q
			coeffs[2] = p
			coeffs[1] = 0
			coeffs[0] = 1
			local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
			num = #results
			s0, s1, s2 = results[1], results[2], results[3]
		else
			coeffs[3] = 0.5 * r * p - 0.125 * q * q
			coeffs[2] = -r
			coeffs[1] = -0.5 * p
			coeffs[0] = 1
			s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
			z = s0
			u = z * z - r
			v = 2 * z - p
			if isZero(u) then
				u = 0
			elseif (u > 0) then
				u = math.sqrt(u)
			else
				return
			end
			if isZero(v) then
				v = 0
			elseif (v > 0) then
				v = math.sqrt(v)
			else
				return
			end
			coeffs[2] = z - u
			coeffs[1] = q < 0 and -v or v
			coeffs[0] = 1
			do
				local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
				num = #results
				s0, s1 = results[1], results[2]
			end
			coeffs[2] = z + u
			coeffs[1] = q < 0 and v or -v
			coeffs[0] = 1
			if (num == 0) then
				local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
				num = num + #results
				s0, s1 = results[1], results[2]
			end
			if (num == 1) then
				local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
				num = num + #results
				s1, s2 = results[1], results[2]
			end
			if (num == 2) then
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
			local posRoots = table.create(2)
			for _, v in solutions do
				if v > 0 then
					table.insert(posRoots, v)
				end
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
-- MODULE: Modern/Games/Universal.lua
----------------------------------------------------------------
local Modern = shared.Modern
local cloneref = cloneref or function(obj) return obj end

if identifyexecutor then
	if table.find({'Argon', 'Wave'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local Players = cloneref(game:GetService('Players'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local RunService = cloneref(game:GetService('RunService'))
local GuiService = cloneref(game:GetService('GuiService'))
local CoreGui = cloneref(game:GetService('CoreGui'))
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = Players.LocalPlayer

local run = function(func) func() end

local ModernFile = shared.ModernFile
local entitylib = ModernFile.loadfile("Modern/Library/Entity.lua")
local prediction = ModernFile.loadfile("Modern/Library/Prediction.lua")
local getfontsize = Modern.Libraries.getfontsize
local addGradient = Modern.Libraries.addGradient
local Targetinfo = Modern.Libraries.Targetinfo

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
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
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
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

run(function()
	Modern:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	Modern:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

entitylib.start()
repeat task.wait() until game:IsLoaded()

local TargetStrafeVector

-- Aim Assist
run(function()
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
			if CircleObject then
				CircleObject.Visible = callback
			end
			if callback then
				local ent
				local rightClicked = not RightClick.Enabled or UserInputService:IsMouseButtonPressed(1)
				AimAssist:Clean(RunService.RenderStepped:Connect(function(dt)
					if CircleObject then
						CircleObject.Position = UserInputService:GetMouseLocation()
					end

					if rightClicked and not Modern.ClickGuiStatus then
						ent = entitylib.EntityMouse({
							Range = FOV.Value,
							Part = Part.Value,
							Players = true,
							NPCs = false,
							Wallcheck = true,
							Origin = gameCamera.CFrame.Position
						})

						if ent then
							local facing = gameCamera.CFrame.LookVector
							local new = (ent[Part.Value].Position - gameCamera.CFrame.Position).Unit
							new = new == new and new or Vector3.zero
							if ShowTarget.Enabled then
								Targetinfo.Targets[ent] = tick() + 1
							end
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
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							ent = nil
							rightClicked = true
						end
					end))

					AimAssist:Clean(UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							rightClicked = false
						end
					end))
				end
			end
		end
	})

	Part = AimAssist:AddDropdown({ Name = 'Part', List = {'RootPart', 'Head'} })
	FOV = AimAssist:AddSlider({
		Name = 'FOV',
		Min = 0,
		Max = 1000,
		Default = 100,
		Function = function(val)
			if CircleObject then CircleObject.Radius = val end
		end
	})
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
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleFilled.Frame.Visible = callback
		end
	})
	CircleFilled = AimAssist:AddToggle({ Name = 'Circle Filled', Function = function(callback) if CircleObject then CircleObject.Filled = callback end end, Visible = false })
	RightClick = AimAssist:AddToggle({ Name = 'Require right click', Function = function() if AimAssist.Enabled then AimAssist:Toggle(); AimAssist:Toggle() end end })
	ShowTarget = AimAssist:AddToggle({ Name = 'Show Target', Function = function() if AimAssist.Enabled then AimAssist:Toggle(); AimAssist:Toggle() end end })
end)

-- Auto Clicker
run(function()
	local AutoClicker, Mode, CPS

	AutoClicker = Modern.Catalogs.Combat:AddModule({
		Name = 'Auto Clicker',
		Function = function(callback)
			if callback then
				repeat
					if Mode.Value == 'Tool' then
						local tool = getTool()
						if tool and UserInputService:IsMouseButtonPressed(0) then
							tool:Activate()
						end
					else
						if mouse1click and (isrbxactive or iswindowactive)() then
							if not Modern.ClickGuiStatus then
								(Mode.Value == 'Click' and mouse1click or mouse2click)()
							end
						end
					end
					task.wait(1 / CPS.Value)
				until not AutoClicker.Enabled
			end
		end
	})
	Mode = AutoClicker:AddDropdown({ Name = 'Mode', List = {'Tool', 'Click', 'RightClick'} })
	CPS = AutoClicker:AddSlider({ Name = 'CPS', Min = 1, Max = 20, Default = 10 })
end)

-- Reach
run(function()
	local Reach, Mode, Value, Chance
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local modified = {}

	Reach = Modern.Catalogs.Combat:AddModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				repeat
					local tool = getTool()
					tool = tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true)
					if tool then
						if Mode.Value == 'TouchInterest' then
							local entites = {}
							for _, v in entitylib.List do
								if v.Targetable and v.Player then
									table.insert(entites, v.Character)
								end
							end

							Overlay.FilterDescendantsInstances = entites
							local parts = workspace:GetPartBoundsInBox(tool.Parent.CFrame * CFrame.new(0, 0, Value.Value / 2), tool.Parent.Size + Vector3.new(0, 0, Value.Value), Overlay)

							for _, v in parts do
								if Random.new():NextNumber(0, 100) > Chance.Value then
									task.wait(0.2)
									break
								end

								firetouchinterest(tool.Parent, v, 1)
								firetouchinterest(tool.Parent, v, 0)
							end
						else
							if not modified[tool.Parent] then
								modified[tool.Parent] = tool.Parent.Size
							end
							tool.Parent.Size = modified[tool.Parent] + Vector3.new(0, 0, Value.Value)
							tool.Parent.Massless = true
						end
					end

					task.wait()
				until not Reach.Enabled
			else
				for i, v in modified do
					i.Size = v
					i.Massless = false
				end
				table.clear(modified)
			end
		end
	})
	Mode = Reach:AddDropdown({
		Name = 'Mode',
		List = {'TouchInterest', 'Resize'},
		Function = function(val) Chance.Frame.Visible = val == 'TouchInterest' end
	})
	Value = Reach:AddSlider({ Name = 'Range', Min = 0, Max = 2, Decimal = 10 })
	Chance = Reach:AddSlider({ Name = 'Chance', Min = 0, Max = 100, Default = 100 })
end)

-- Killaura
run(function()
	local Killaura, CPS, SwingRange, AttackRange, AngleSlider, Max, Mouse
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Boxes, AttackDelay = {}, tick()

	local function getAttackData()
		if Mouse.Enabled and not UserInputService:IsMouseButtonPressed(0) then return false end
		local tool = getTool()
		return tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true) or nil, tool
	end

	Killaura = Modern.Catalogs.Combat:AddModule({
		Name = 'Aura',
		Function = function(callback)
			if callback then
				repeat
					local interest, tool = getAttackData()
					local attacked = {}
					if interest then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = nil,
							Part = 'RootPart',
							Players = true,
							NPCs = false,
							Limit = Max.Value
						})

						if #plrs > 0 then
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, v)
								Targetinfo.Targets[v] = tick() + 1

								if AttackDelay < tick() then
									AttackDelay = tick() + (1 / CPS.Value)
									tool:Activate()
								end

								if delta.Magnitude > AttackRange.Value then continue end

								Overlay.FilterDescendantsInstances = {v.Character}
								for _, part in workspace:GetPartBoundsInBox(v.RootPart.CFrame, Vector3.new(4, 4, 4), Overlay) do
									firetouchinterest(interest.Parent, part, 1)
									firetouchinterest(interest.Parent, part, 0)
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(0.6, 0.6, 0.6)
							v.Transparency = 0.5
						end
					end

					task.wait()
				until not Killaura.Enabled
			else
				for _, v in Boxes do
					v.Adornee = nil
				end
			end
		end
	})
	CPS = Killaura:AddSlider({ Name = 'Attacks per Second', Min = 1, Max = 20, Default = 10 })
	SwingRange = Killaura:AddSlider({ Name = 'Swing range', Min = 1, Max = 30, Default = 13 })
	AttackRange = Killaura:AddSlider({ Name = 'Attack range', Min = 1, Max = 30, Default = 13 })
	AngleSlider = Killaura:AddSlider({ Name = 'Max angle', Min = 1, Max = 360, Default = 90 })
	Max = Killaura:AddSlider({ Name = 'Max targets', Min = 1, Max = 10, Default = 10 })
	Mouse = Killaura:AddToggle({ Name = 'Require Click' })
	Killaura:AddToggle({
		Name = 'Show target',
		Function = function(callback)
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = Modern.MainScreenGui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do v:Destroy() end
				table.clear(Boxes)
			end
		end
	})
end)

-- Movement Methods
local SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck and options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end
}

local SpeedMethodList = {'Velocity', 'Impulse', 'CFrame', 'TP', 'WalkSpeed'}

-- Fly
run(function()
	local Fly, Mode, FloatMode, State, MoveMethod, Keys, VerticalValue, BounceLength, BounceDelay, FloatTPGround, FloatTPAir, CustomProperties, WallCheck, PlatformStanding
	local Options = { TPTiming = tick() }
	local Platform, YLevel, OldYLevel
	local w, s, a, d, up, down = 0, 0, 0, 0, 0, 0
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	Options.rayCheck = rayCheck

	local Functions = {
		Velocity = function()
			entitylib.character.RootPart.AssemblyLinearVelocity = (entitylib.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)) + Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0)
		end,
		Impulse = function()
			local root = entitylib.character.RootPart
			local diff = (Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0) - root.AssemblyLinearVelocity) * Vector3.new(0, 1, 0)
			if diff.Magnitude > 2 then root:ApplyImpulse(diff * root.AssemblyMass) end
		end,
		CFrame = function(dt)
			local root = entitylib.character.RootPart
			if not YLevel then YLevel = root.Position.Y end
			YLevel = YLevel + ((up + down) * VerticalValue.Value * dt)
			if WallCheck.Enabled then
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				rayCheck.CollisionGroup = root.CollisionGroup
				local ray = workspace:Raycast(root.Position, Vector3.new(0, YLevel - root.Position.Y, 0), rayCheck)
				if ray then YLevel = ray.Position.Y + entitylib.character.HipHeight end
			end
			root.CFrame += Vector3.new(0, YLevel - root.Position.Y, 0)
		end,
		Floor = function()
			if Platform then
				Platform.CFrame = down ~= 0 and CFrame.identity or entitylib.character.RootPart.CFrame + Vector3.new(0, -(entitylib.character.HipHeight + 0.5), 0)
			end
		end
	}

	Fly = Modern.Catalogs.Movement:AddModule({
		Name = 'Fly',
		Function = function(callback)
			if Platform then Platform.Parent = callback and gameCamera or nil end
			frictionTable.Fly = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Fly:Clean(RunService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if PlatformStanding.Enabled then
							entitylib.character.Humanoid.PlatformStand = true
							entitylib.character.RootPart.RotVelocity = Vector3.zero
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(entitylib.character.RootPart.CFrame.Position, gameCamera.CFrame.LookVector)
						end
						if State.Value ~= 'None' then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType[State.Value])
						end
						SpeedMethods[Mode.Value](Options, TargetStrafeVector or MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection, dt)
						if Functions[FloatMode.Value] then Functions[FloatMode.Value](dt) end
					else
						YLevel = nil; OldYLevel = nil
					end
				end))

				w, s, a, d = UserInputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				up, down = 0, 0

				for _, v in {'InputBegan', 'InputEnded'} do
					Fly:Clean(UserInputService[v]:Connect(function(input)
						if not UserInputService:GetFocusedTextBox() then
							local divided = Keys.Value:split('/')
							if input.KeyCode == Enum.KeyCode.W then w = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.S then s = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.A then a = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.D then d = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[1]] then up = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[2]] then down = v == 'InputBegan' and -1 or 0
							end
						end
					end))
				end
			else
				YLevel, OldYLevel = nil, nil
				if entitylib.isAlive and PlatformStanding.Enabled then entitylib.character.Humanoid.PlatformStand = false end
			end
		end
	})

	Mode = Fly:AddDropdown({ Name = 'Speed Mode', List = SpeedMethodList })
	FloatMode = Fly:AddDropdown({ Name = 'Float Mode', List = {'Velocity', 'Impulse', 'CFrame', 'Floor'} })
	State = Fly:AddDropdown({ Name = 'Humanoid State', List = {'None', 'Freefall', 'Flying'} })
	MoveMethod = Fly:AddDropdown({ Name = 'Move Mode', List = {'MoveDirection', 'Direct'} })
	Keys = Fly:AddDropdown({ Name = 'Keys', List = {'Space/LeftControl', 'Space/LeftShift', 'E/Q'} })
	Options.Value = Fly:AddSlider({ Name = 'Speed', Min = 1, Max = 150, Default = 50 })
	VerticalValue = Fly:AddSlider({ Name = 'Vertical Speed', Min = 1, Max = 150, Default = 50 })
	WallCheck = Fly:AddToggle({ Name = 'Wall Check', Default = true })
	Options.WallCheck = WallCheck
	PlatformStanding = Fly:AddToggle({ Name = 'PlatformStand' })
	CustomProperties = Fly:AddToggle({ Name = 'Custom Properties', Default = true })
end)

-- Speed
run(function()
	local Speed, Mode, Options, AutoJump, CustomProperties
	local w, s, a, d = 0, 0, 0, 0

	Speed = Modern.Catalogs.Movement:AddModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Speed:Clean(RunService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not Modern.Modules.Fly.Enabled then
						local movevec = TargetStrafeVector or Options.MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection
						SpeedMethods[Mode.Value](Options, movevec, dt)
						if AutoJump.Enabled and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and movevec ~= Vector3.zero then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end))

				w, s, a, d = UserInputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				for _, v in {'InputBegan', 'InputEnded'} do
					Speed:Clean(UserInputService[v]:Connect(function(input)
						if not UserInputService:GetFocusedTextBox() then
							if input.KeyCode == Enum.KeyCode.W then w = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.S then s = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.A then a = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.D then d = v == 'InputBegan' and 1 or 0
							end
						end
					end))
				end
			else
				if Options.WalkSpeed and entitylib.isAlive then
					entitylib.character.Humanoid.WalkSpeed = Options.WalkSpeed
				end
				Options.WalkSpeed = nil
			end
		end
	})

	Mode = Speed:AddDropdown({ Name = 'Mode', List = SpeedMethodList })
	Options = {
		MoveMethod = Speed:AddDropdown({ Name = 'Move Mode', List = {'MoveDirection', 'Direct'} }),
		Value = Speed:AddSlider({ Name = 'Speed', Min = 1, Max = 150, Default = 50 }),
		WallCheck = Speed:AddToggle({ Name = 'Wall Check', Default = true }),
		TPTiming = tick(),
		rayCheck = RaycastParams.new()
	}
	Options.rayCheck.RespectCanCollide = true
	CustomProperties = Speed:AddToggle({ Name = 'Custom Properties', Default = true })
	AutoJump = Speed:AddToggle({ Name = 'AutoJump' })
end)

-- NameTags
run(function()
	local NameTags, Scale, Background, GlowEffect, Health, Distance, DisplayName, DrawingToggle, Teammates, DistanceCheck, DistanceLimit
	local Strings, Sizes, Reference, Gradients = {}, {}, {}, {}
	local Folder = Instance.new('Folder')
	Folder.Name = 'NameTagsFolder'
	Folder.Parent = Modern.MainScreenGui
	local methodused

	local Added = {
		Normal = function(ent)
			if ent.NPC then return end
			if Teammates and Teammates.Enabled and (not ent.Targetable) then return end

			Strings[ent] = ent.Player and (DisplayName and DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
			if Health and Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..math.floor(healthColor.R * 255)..','..math.floor(healthColor.G * 255)..','..math.floor(healthColor.B * 255)..')">'..math.round(ent.Health)..'</font>'
			end
			if Distance and Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end

			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * (Scale and Scale.Value or 1)
			nametag.FontFace = Modern.Libraries.uipallet.Font
			nametag.ZIndex = -1
			local ize = getfontsize(removeTags(Strings[ent]), nametag.TextSize, Modern.Libraries.uipallet.Font, Vector2.new(100000, 100000))
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = Background and Background.Value or 0.5
			nametag.BorderSizePixel = 0
			if GlowEffect and GlowEffect.Enabled then
				addGradient(addRoundedShadow(nametag))
			end
			addCorner(nametag, UDim.new(0, 5))
			nametag.Visible = false
			nametag.Text = Strings[ent]
			if entitylib.getEntityColor(ent) then
				nametag.TextColor3 = entitylib.getEntityColor(ent)
			else
				nametag.TextColor3 = Color3.fromRGB(255, 255, 255)
				Gradients[ent] = addGradient(nametag)
			end
			nametag.RichText = true
			nametag.Parent = Folder
			Reference[ent] = nametag
		end,
		Drawing = function(ent)
			if Teammates and Teammates.Enabled and (not ent.Targetable) then return end

			local nametag = {}
			nametag.BG = Drawing.new('Square')
			nametag.BG.Filled = true
			nametag.BG.Transparency = 1 - (Background and Background.Value or 0.5)
			nametag.BG.Color = Color3.new()
			nametag.BG.ZIndex = 1

			nametag.Text = Drawing.new('Text')
			nametag.Text.Size = 15 * (Scale and Scale.Value or 1)
			nametag.Text.Font = 0
			nametag.Text.ZIndex = 2

			Strings[ent] = ent.Player and (DisplayName and DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
			if Health and Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end
			if Distance and Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
			end

			nametag.Text.Text = Strings[ent]
			nametag.Text.Color = entitylib.getEntityColor(ent) or Modern.Libraries.uipallet.FinalColor
			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			Reference[ent] = nametag
		end
	}

	local Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, v2 in v do
					pcall(function()
						v2.Visible = false
						v2:Remove()
					end)
				end
			end
		end
	}

	local Loop = {
		Normal = function()
			for ent, nametag in Reference do
				if DistanceCheck and DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance > (DistanceLimit and DistanceLimit.Value or 200) then
						nametag.Visible = false
						continue
					end
				end

				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Visible = headVis
				if not headVis then continue end

				if Distance and Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text = string.format(Strings[ent], mag)
						local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end,
		Drawing = function()
			for ent, nametag in Reference do
				if DistanceCheck and DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance > (DistanceLimit and DistanceLimit.Value or 200) then
						nametag.Text.Visible = false
						nametag.BG.Visible = false
						continue
					end
				end

				local headPos, headVis = gameCamera:WorldToScreenPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Text.Visible = headVis
				nametag.BG.Visible = headVis
				if not headVis then continue end

				if Distance and Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text.Text = string.format(Strings[ent], mag)
						nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y + (nametag.BG.Size.Y / 2))
				nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 2.5)
			end
		end
	}

	NameTags = Modern.Catalogs.Render:AddModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = (DrawingToggle and DrawingToggle.Enabled) and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then Removed[methodused](v) end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then Removed[methodused](ent) end
						Added[methodused](ent)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(RunService.RenderStepped:Connect(Loop[methodused]))
				end
			else
				if Removed[methodused] then
					for i in Reference do Removed[methodused](i) end
				end
			end
		end
	})

	Scale = NameTags:AddSlider({ Name = 'Scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10 })
	Background = NameTags:AddSlider({ Name = 'Transparency', Default = 0.5, Min = 0, Max = 1, Decimal = 10 })
	GlowEffect = NameTags:AddToggle({ Name = 'Glow Effect', Default = true })
	Health = NameTags:AddToggle({ Name = 'Health', Default = true })
	Distance = NameTags:AddToggle({ Name = 'Distance', Default = true })
	DisplayName = NameTags:AddToggle({ Name = 'Display Name', Default = true })
	DrawingToggle = NameTags:AddToggle({ Name = 'Use Drawing API', Default = false })
	Teammates = NameTags:AddToggle({ Name = 'Show Teammates', Default = false })
	DistanceCheck = NameTags:AddToggle({ Name = 'Distance Check', Default = false })
	DistanceLimit = NameTags:AddSlider({ Name = 'Distance Limit', Min = 10, Max = 1000, Default = 200 })
end)
