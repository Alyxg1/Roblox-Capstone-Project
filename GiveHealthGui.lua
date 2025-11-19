local rs    = game:GetService("ReplicatedStorage")
local gui   = rs:WaitForChild("HUDContainer")
local clone = gui:Clone()
clone.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
