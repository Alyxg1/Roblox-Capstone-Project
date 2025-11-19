-- ServerScriptService/GameManager.server.lua
-- Rounds + paced spawns + boss rounds + points + spectate/teleport flow + dashboard mirror

local RS                = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local DataStoreService  = game:GetService("DataStoreService")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------

local LOBBY_PLACE_ID      = 93132446111005   -- lobby place id
local HEALTH_PER_ROUND    = 75               -- extra MaxHealth per round
local PER_SPAWNER_TOTAL   = 6                -- how many each spawner makes per round
local CHUNK_MIN, CHUNK_MAX= 1, 2             -- small bursts
local CHUNK_PERIOD        = 10               -- seconds between bursts
local BOSS_EVERY          = 5                -- 5,10,15...
local POINTS_PER_DAMAGE   = 1                -- per damage tick if you use HitZombie Remote

----------------------------------------------------------------------
-- Remotes / plumbing
----------------------------------------------------------------------

local ROUND_EVENT = RS:FindFirstChild("RoundUpdate") or Instance.new("RemoteEvent", RS)
ROUND_EVENT.Name  = "RoundUpdate"

local HIT_EVENT   = RS:FindFirstChild("HitZombie") or Instance.new("RemoteEvent", RS)
HIT_EVENT.Name    = "HitZombie"
 
local START_SPECTATE_EVENT = RS:FindFirstChild("StartSpectating") or Instance.new("RemoteEvent", RS)
START_SPECTATE_EVENT.Name = "StartSpectating"

local UPDATE_SPECTATE_LIST_EVENT = RS:FindFirstChild("UpdateSpectateList") or Instance.new("RemoteEvent", RS)
UPDATE_SPECTATE_LIST_EVENT.Name = "UpdateSpectateList"

-- Optional tiny bus some other scripts (e.g., ReturntoLobby) can listen to
local RoundBus = RS:FindFirstChild("RoundBus") or Instance.new("BindableEvent", RS)
RoundBus.Name = "RoundBus"

----------------------------------------------------------------------
-- Folders
----------------------------------------------------------------------

local ACTIVE_FOLDER = workspace:FindFirstChild("ActiveZombies") or Instance.new("Folder", workspace)
ACTIVE_FOLDER.Name  = "ActiveZombies"

local SPAWNERS_FOLDER = workspace:WaitForChild("Spawners")

----------------------------------------------------------------------
-- DataStore (HighestRound) + Dashboard mirror (Node/SQLite)
----------------------------------------------------------------------

local HighestRoundStore = DataStoreService:GetDataStore("HighestRound_v1")

-- If you're running the local Node server (server.js) on your PC:
local DASHBOARD_URL    = "http://127.0.0.1:3020/api/event"
local DASHBOARD_SECRET = "dev-secret"  -- must match STATS_SECRET in server.js

local function mirrorHighestRound(player: Player, newHighest: number)
	local payload = {
		userId       = player.UserId,
		username     = player.Name,
		highestRound = tonumber(newHighest) or 0,
	}
	task.spawn(function()
		local ok, err = pcall(function()
			HttpService:PostAsync(
				DASHBOARD_URL,
				HttpService:JSONEncode(payload),
				Enum.HttpContentType.ApplicationJson,
				false,
				{ ["x-stats-secret"] = DASHBOARD_SECRET }
			)
		end)
		if not ok then
			warn("[Mirror] POST failed:", err)
		end
	end)
end

----------------------------------------------------------------------
-- Spawner discovery
----------------------------------------------------------------------

local function isSpawnerContainer(obj)
	return obj:IsA("Folder") or obj:IsA("Model")
end

local REGULAR_SPAWNERS = {}
local BOSS_SPAWNER     = nil

for _, obj in ipairs(SPAWNERS_FOLDER:GetChildren()) do
	if isSpawnerContainer(obj) then
		local nameLower = obj.Name:lower()
		if nameLower:find("boss") then
			BOSS_SPAWNER = obj
		else
			table.insert(REGULAR_SPAWNERS, obj)
		end
	end
end

----------------------------------------------------------------------
-- Leaderstats (Round + HighestRound + Points/Kills shell)
----------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name  = "leaderstats"
	ls.Parent= player

	local kills  = Instance.new("IntValue"); kills.Name="Kills";  kills.Parent=ls
	local points = Instance.new("IntValue"); points.Name="Points"; points.Parent=ls
	local roundv = Instance.new("IntValue"); roundv.Name="Round"; roundv.Parent=ls
	local hr     = Instance.new("IntValue"); hr.Name="HighestRound"; hr.Parent=ls

	task.spawn(function()
		local ok, saved = pcall(function() return HighestRoundStore:GetAsync(player.UserId) end)
		if ok and type(saved) == "number" then
			hr.Value = saved
		end
	end)
	
	player.CharacterAdded:Connect(function(character)
		-- Tell all spectators there's a new living player
		UPDATE_SPECTATE_LIST_EVENT:FireAllClients(getLivingPlayerList())

		local humanoid = character:WaitForChild("Humanoid")

		--
		-- ??? THIS IS THE TRIGGER LOCATION ???
		--
		humanoid.Died:Connect(function()
			
			START_SPECTATE_EVENT:FireClient(player) -- tell speecific player to begin spectatting after death

			UPDATE_SPECTATE_LIST_EVENT:FireAllClients(getLivingPlayerList())
		end)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local ls = player:FindFirstChild("leaderstats")
	local hr = ls and ls:FindFirstChild("HighestRound")
	if hr then
		pcall(function() HighestRoundStore:SetAsync(player.UserId, hr.Value) end)
	end
end)

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

-- Turn off auto-respawn; we revive intentionally at ROUND_START
Players.CharacterAutoLoads = false
Players.PlayerAdded:Connect(function(plr) plr:LoadCharacter() end)

local function tagAsEnemy(m: Instance)
	if not CollectionService:HasTag(m, "Enemy") then
		CollectionService:AddTag(m, "Enemy")
	end
end

local function getZombieTemplateFromSpawner(spawnerModel: Instance) -- -> Model?
	if not spawnerModel then return nil end

	-- common layouts: Folder/Model -> Model -> Zombie
	local holder = spawnerModel:FindFirstChild("Model")
	if holder and holder:FindFirstChild("Zombie") then return holder.Zombie end

	-- direct descendant named Zombie
	local z = spawnerModel:FindFirstChild("Zombie", true)
	if z and z:IsA("Model") then return z end

	-- otherwise any descendant model that looks like a zombie (has Humanoid)
	for _, d in ipairs(spawnerModel:GetDescendants()) do
		if d:IsA("Model") and d.Name:lower():find("zombie") and d:FindFirstChildOfClass("Humanoid") then
			return d
		end
	end
	for _, d in ipairs(spawnerModel:GetDescendants()) do
		if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
			return d
		end
	end
	return nil
end

local function getSpawnCFrame(spawnerModel: Model)
	local p = spawnerModel:FindFirstChild("Spawn Location", true)
	if p and p:IsA("BasePart") then return p.CFrame + Vector3.new(0,2,0) end
	if spawnerModel.PrimaryPart then return spawnerModel.PrimaryPart.CFrame end
	return spawnerModel:GetPivot()
end

-- scrub the one bad animation id you found
local DEFAULT_R15 = { RunAnim="rbxassetid://507767714", WalkAnim="rbxassetid://507777826" }
local function scrubAnimations(model: Instance)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("Animation") then
			local id = inst.AnimationId or ""
			if id:find("2136782735", 1, true) then inst.AnimationId = "" end
			if inst.AnimationId == "" and DEFAULT_R15[inst.Name] then
				inst.AnimationId = DEFAULT_R15[inst.Name]
			end
		end
	end
end

-- live counter (models parented under ActiveZombies and with a Humanoid)
local aliveCount = 0

local function scaleZombieHealth(zombieModel: Model, roundNumber: number)
	local hum = zombieModel:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local bonus = HEALTH_PER_ROUND * roundNumber
	hum.MaxHealth = math.max(1, (hum.MaxHealth or 100) + bonus)
	hum.Health    = hum.MaxHealth
end

local function afterSpawnHook(zombieModel: Model, roundNumber: number)
	tagAsEnemy(zombieModel)
	zombieModel:SetAttribute("SpawnRound", roundNumber)
	zombieModel.Parent = ACTIVE_FOLDER

	local hum = zombieModel:FindFirstChildOfClass("Humanoid")
	if hum then
		aliveCount += 1
		hum.Died:Connect(function()
			aliveCount -= 1
			if aliveCount < 0 then aliveCount = 0 end
		end)
	end
end

local function spawnOneFromSpawner(spawnerModel: Model, roundNumber: number)
	local template = getZombieTemplateFromSpawner(spawnerModel)
	if not template then
		warn("No spawnable template for spawner:", spawnerModel:GetFullName())
		return
	end

	local clone = template:Clone()
	scrubAnimations(clone)
	clone:PivotTo(getSpawnCFrame(spawnerModel))
	clone.Name = template.Name

	-- flavor speed per spawner
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		if spawnerModel.Name:upper():find("FAST") then
			hum.WalkSpeed = 8
		else
			hum.WalkSpeed = 6
		end
	end

	scaleZombieHealth(clone, roundNumber)
	afterSpawnHook(clone, roundNumber)
end

-- small bursts
local function runSpawnerForRound(spawner: Model, roundNumber: number, totalToSpawn: number)
	task.spawn(function()
		local spawned = 0
		while spawned < totalToSpawn do
			local n = math.random(CHUNK_MIN, CHUNK_MAX)
			for _ = 1, math.min(n, totalToSpawn - spawned) do
				spawnOneFromSpawner(spawner, roundNumber)
				spawned += 1
			end
			task.wait(CHUNK_PERIOD)
		end
	end)
	return totalToSpawn
end

local function spawnWave(roundNumber: number)
	local expected = 0
	for _, spawner in ipairs(REGULAR_SPAWNERS) do
		expected += runSpawnerForRound(spawner, roundNumber, PER_SPAWNER_TOTAL)
	end
	-- Boss only on multiples of BOSS_EVERY (never round 1)
	if BOSS_SPAWNER and roundNumber >= BOSS_EVERY and (roundNumber % BOSS_EVERY == 0) then
		expected += runSpawnerForRound(BOSS_SPAWNER, roundNumber, 1)
	end
	return expected
end

-- any living players left?
local function anyPlayerAlive()
	for _, plr in ipairs(Players:GetPlayers()) do
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then return true end
	end
	return false
end

local function getLivingPlayerList()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			table.insert(list, plr)
		end
	end
	return list
end
----------------------------------------------------------------------
-- Optional: client-reported damage -> points and server damage apply
----------------------------------------------------------------------

HIT_EVENT.OnServerEvent:Connect(function(player, targetHumanoid, damage)
	if typeof(targetHumanoid) ~= "Instance" or not targetHumanoid:IsA("Humanoid") then return end
	if typeof(damage) ~= "number" or damage <= 0 or damage > 250 then return end
	local model = targetHumanoid.Parent
	if not model or not CollectionService:HasTag(model, "Enemy") then return end

	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Points") then
		ls.Points.Value += math.floor(damage * POINTS_PER_DAMAGE)
	end

	targetHumanoid:TakeDamage(damage) -- server-authoritative
end)

----------------------------------------------------------------------
-- MAIN ROUND LOOP
----------------------------------------------------------------------

task.spawn(function()
	local round = 0
	while true do
		round += 1

		-- intermission
		ROUND_EVENT:FireAllClients("INTERMISSION", round)
		task.wait(2)

		-- clean previous round
		for _, m in ipairs(ACTIVE_FOLDER:GetChildren()) do
			if m:IsA("Model") then m:Destroy() end
		end
		aliveCount = 0

		-- update leaderstats.Round
		for _, plr in ipairs(Players:GetPlayers()) do
			local ls = plr:FindFirstChild("leaderstats")
			if ls and ls:FindFirstChild("Round") then
				ls.Round.Value = round
			end
		end

		-- start round
		ROUND_EVENT:FireAllClients("ROUND_START", round)

		-- revive everyone for the new round
		for _, plr in ipairs(Players:GetPlayers()) do
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				pcall(function() plr:LoadCharacter() end)
			end
		end
		-- let spectate script know, if present
		RoundBus:Fire("ROUND_START", round)

		-- spawn enemies
		local expected = spawnWave(round)

		-- ensure at least something spawns before we consider ending
		if expected > 0 then
			local t, timeout = 0, CHUNK_PERIOD + 5
			while aliveCount == 0 and t < timeout do
				task.wait(0.1); t += 0.1
			end
		end

		-- wait for end-of-wave OR all players dead -> teleport to lobby
		local allDeadConfirm = 0
		while aliveCount > 0 do
			if not anyPlayerAlive() then
				allDeadConfirm += 1
				if allDeadConfirm >= 8 then -- ~2s at 0.25 step
					local ok, err = pcall(function()
						TeleportService:TeleportAsync(LOBBY_PLACE_ID, Players:GetPlayers())
					end)
					if not ok then warn("Teleport to lobby failed:", err) end
					return
				end
			else
				allDeadConfirm = 0
			end
			task.wait(0.25)
		end

		-- update HighestRound (and mirror to dashboard)
		for _, plr in ipairs(Players:GetPlayers()) do
			local ls = plr:FindFirstChild("leaderstats")
			if ls then
				local hr = ls:FindFirstChild("HighestRound")
				if hr and round > hr.Value then
					hr.Value = round
					pcall(function() HighestRoundStore:SetAsync(plr.UserId, hr.Value) end)
					mirrorHighestRound(plr, hr.Value)
				end
			end
		end

		ROUND_EVENT:FireAllClients("ROUND_COMPLETE", round)
		task.wait(3)
	end
end)
