-- Connects to the TweenService to handle animations
local TweenService = game:GetService("TweenService")

-- Variablas for the door, prompt, hinge, and tween goals
local door = script.Parent.LeftDoor
local prompt = door.ProximityPrompt
local hinge = script.Parent.LDoorHinge

local goalOpen = {}
goalOpen.CFrame = hinge.CFrame * CFrame.Angles(0, math.rad(90), 0)

local goalClose = {}
goalClose.CFrame = hinge.CFrame * CFrame.Angles(0, 0, 0)

local tweenInfo = TweenInfo.new(1)
local tweenOpen = TweenService:Create(hinge, tweenInfo, goalOpen)
local tweenClose = TweenService:Create(hinge, tweenInfo, goalClose)

--Function for when the proximity prompt is triggered, plays the open or close animation depending on the current state of the door
prompt.Triggered:Connect (function()
	if prompt.ActionText == "Close" then
		tweenClose:Play()
		prompt.ActionText = "Open"
	else
		tweenOpen:Play()
		prompt.ActionText = "Close"
	end
end)