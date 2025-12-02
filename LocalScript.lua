-- StarterGui/PointsHud/LocalScript

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local label  = script.Parent:WaitForChild("PointsLabel")

local function hook()
	-- leaderstats from server
	local ls     = player:WaitForChild("leaderstats")
	local points = ls:WaitForChild("Points")
	local round  = ls:WaitForChild("Round")

	-- shared "ZombiesLeft" counter from ReplicatedStorage
	local zombiesLeftValue = ReplicatedStorage:WaitForChild("ZombiesLeft")

	local function redraw()
		label.Text = string.format(
			"Round %d | Points: %s | Zombies Left: %d",
			round.Value,
			points.Value,
			zombiesLeftValue.Value
		)
	end

	points:GetPropertyChangedSignal("Value"):Connect(redraw)
	round:GetPropertyChangedSignal("Value"):Connect(redraw)
	zombiesLeftValue:GetPropertyChangedSignal("Value"):Connect(redraw)

	redraw()
end

if player:FindFirstChild("leaderstats") then
	hook()
else
	player.ChildAdded:Connect(function(c)
		if c.Name == "leaderstats" then
			hook()
		end
	end)
end
