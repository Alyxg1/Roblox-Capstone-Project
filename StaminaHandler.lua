-- StarterGui ? LocalScript “StaminaHandler”

local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")

local playerGui     = player:WaitForChild("PlayerGui")
local staminaGui    = playerGui:WaitForChild("StaminaGui")
local frame         = staminaGui:WaitForChild("StaminaFrame")
local bar           = frame:WaitForChild("StaminaBar")
local percentageTxt = frame:WaitForChild("Percentage")

-- Settings
local maxStamina   = 100
local stamina      = maxStamina
local normalSpeed  = humanoid.WalkSpeed
local sprintBoost  = 8
local drainRate    = 20   -- stamina per second
local regenRate    = 10   -- stamina per second
local regenThresh  = 20   -- only exit exhausted once above this

-- State
local sprintHeld   = false
local sprinting    = false
local exhausted    = false

-- Update the bar UI
local function updateUI()
	local pct = math.clamp(stamina / maxStamina, 0, 1)
	bar.Size     = UDim2.new(pct, 0, 1, 0)
	percentageTxt.Text = ("%d/%d"):format(math.floor(stamina), maxStamina)
end

-- Turn sprint on/off
local function setSprint(on)
	if on and not exhausted then
		humanoid.WalkSpeed = normalSpeed + sprintBoost
		sprinting = true
	else
		humanoid.WalkSpeed = normalSpeed
		sprinting = false
	end
end

-- Input handlers
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard
		and input.KeyCode == Enum.KeyCode.LeftShift then
		sprintHeld = true
		setSprint(true)
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard
		and input.KeyCode == Enum.KeyCode.LeftShift then
		sprintHeld = false
		setSprint(false)
	end
end)

-- Drain / regen loop
RunService.Heartbeat:Connect(function(dt)
	if sprinting then
		stamina = stamina - drainRate * dt
		if stamina <= 0 then
			stamina = 0
			exhausted = true
			setSprint(false)
		end
		updateUI()
	else
		if stamina < maxStamina then
			stamina = stamina + regenRate * dt
			if stamina >= regenThresh then
				exhausted = false
				if sprintHeld then
					setSprint(true)
				end
			end
			stamina = math.min(stamina, maxStamina)
			updateUI()
		end
	end
end)

-- initial UI
updateUI()
