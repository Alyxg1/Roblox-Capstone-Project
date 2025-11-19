-- StarterGui/PointsHud/LocalScript
local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local label   = script.Parent:WaitForChild("PointsLabel")

local function hook()
	local ls = player:WaitForChild("leaderstats")
	local points = ls:WaitForChild("Points")
	local round  = ls:WaitForChild("Round")

	local function redraw()
		label.Text = string.format("Round %d  |  Points: %s", round.Value, points.Value)
	end
	points:GetPropertyChangedSignal("Value"):Connect(redraw)
	round:GetPropertyChangedSignal("Value"):Connect(redraw)
	redraw()
end

if player:FindFirstChild("leaderstats") then hook() else
	player.ChildAdded:Connect(function(c) if c.Name=="leaderstats" then hook() end end)
end
