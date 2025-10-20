local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local teleportID = 112332570506048
local queuesFolder = workspace:WaitForChild("Queues")
local bindableEvents = ReplicatedStorage:WaitForChild("Queue"):WaitForChild("BindableEvents - Server")
local joinRemote = ReplicatedStorage.Queue.Join
local leaveRemote = ReplicatedStorage.Queue.Leave

local Shared = {}
local Local = {}

function Shared.OnStart()
	for _, room in ipairs(queuesFolder:GetChildren()) do
		local enterHitBox = room.Refs.Enter
		local enterPos = room.Refs.EnterPos
		local exitPos = room.Refs.ExitPos
		local config = room.Configuration
		local camPos = room.Refs.CamPos.CFrame

		local reservedServer

		local function ReserveNewServer()
			local targetID = config.TeleportID.Value ~= 0 and config.TeleportID.Value or teleportID
			reservedServer = TeleportService:ReserveServer(targetID)
		end

		ReserveNewServer()

		local playerLimit = config.MaximumPlayers.Value ~= 0 and config.MaximumPlayers.Value or tonumber(room.Name)
		local countDownTime = config.CountDownTime.Value > 0 and config.CountDownTime.Value or (playerLimit <= 2 and 10 or playerLimit <= 4 and 20 or 25)
		local inQueue = room.InQueue

		local playersUI = room.Refs.UI.BillboardGui.Players
		local timerUI = room.Refs.UI.BillboardGui.Time
		timerUI.Text = countDownTime .. " Seconds"

		local canQueue, counting, db = true, false, false

		-- Queue join
		enterHitBox.Touched:Connect(function(other)
			if not canQueue or db then return end
			if not other.Parent:FindFirstChild("Humanoid") then return end
			if inQueue:FindFirstChild(other.Parent.Name) then return end
			if #inQueue:GetChildren() >= playerLimit then return end

			db = true
			local player = Players:GetPlayerFromCharacter(other.Parent)
			if not player then return end

			other.Parent:PivotTo(enterPos.CFrame)

			local tag = Instance.new("IntValue")
			tag.Name = other.Parent.Name
			tag.Value = player.UserId
			tag.Parent = inQueue

			bindableEvents.PlayerJoinedQueue:Fire(room, #inQueue:GetChildren())
			if #inQueue:GetChildren() >= playerLimit then
				bindableEvents.QueueFull:Fire(room)
			end

			playersUI.Text = #inQueue:GetChildren() .. "/" .. playerLimit
			joinRemote:FireClient(player, camPos)

			-- Begin countdown
			if not counting and config.MinimumPlayers.Value <= #inQueue:GetChildren() then
				task.spawn(function()
					counting = true
					local t = countDownTime

					while config.MinimumPlayers.Value <= #inQueue:GetChildren() do
						task.wait(1)
						t -= 1
						timerUI.Text = t .. " Seconds"

						if #inQueue:GetChildren() == 0 then
							timerUI.Text = countDownTime .. " Seconds"
							counting = false
							return
						end

						if t <= 0 or (#inQueue:GetChildren() == playerLimit and config.InstantTeleport.Value) then
							Local.TeleportQueue(room, inQueue, reservedServer)
							canQueue = false
							timerUI.Text = "Teleporting..."
							bindableEvents.StartedTeleport:Fire(room)

							repeat task.wait() until #inQueue:GetChildren() == 0
							canQueue = true
							bindableEvents.TeleportEnded:Fire(room)
							ReserveNewServer()
							timerUI.Text = countDownTime .. " Seconds"
							counting = false
							return
						end
					end

					counting = false
				end)
			end

			task.wait(0.5)
			db = false
		end)

		leaveRemote.OnServerEvent:Connect(function(player)
			Local.LeaveQueue(player)
			playersUI.Text = #inQueue:GetChildren() .. "/" .. playerLimit
		end)
	end

	Players.PlayerRemoving:Connect(Local.LeaveQueue)
end

-- Remove player from queue
function Local.LeaveQueue(player)
	for _, room in ipairs(queuesFolder:GetChildren()) do
		local queue = room.InQueue
		local tag = queue:FindFirstChild(player.Name)
		if tag then
			tag:Destroy()
			bindableEvents.PlayerLeftQueue:Fire(room, #queue:GetChildren())

			if player.Character and player.Character.PrimaryPart then
				player.Character.PrimaryPart:PivotTo(room.Refs.ExitPos.CFrame)
			end
		end
	end
end

-- Teleport and carry equipped gun/tool
function Local.TeleportQueue(room, queueFolder, reservedServer)
	local party = {}
	local teleportData = {}

	print("Starting teleport process....")

	for _, obj in ipairs(queueFolder:GetChildren()) do
		local player = Players:GetPlayerByUserId(obj.Value)
		if player then
			table.insert(party, player)

			local char = player.Character
			local equipped = char and char:FindFirstChildOfClass("Tool")
			local inBackpack = player:FindFirstChild("Backpack") and player.Backpack:FindFirstChildOfClass("Tool")

			local toolName = equipped and equipped.Name or inBackpack and inBackpack.Name or nil
			local hasArmor = char and char:FindFirstChild("ACSvest") ~= nil

			print("Preparing to teleport player:", player.Name, "with tool:", toolName, " | Armor:", hasArmor)

			teleportData[tostring(player.UserId)] = {
				tool = toolName,
				hasArmor = hasArmor
			}
		end
	end

	print("Teleporting", #party, "players to reserved server:", reservedServer)

	TeleportService:TeleportToPrivateServer(
		teleportID,
		reservedServer,
		party,
		nil,
		teleportData
	)

	print("TeleportData:", teleportData)
end


return Shared
