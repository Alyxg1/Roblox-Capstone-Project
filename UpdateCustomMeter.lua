local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Reference to local player, character, and humanoid
local player = Players.LocalPlayer
local character = player.Character
local humanoid = character:WaitForChild("Humanoid")

-- Tween properties
local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

-- Reference to meter bar inner frame
local playerGui = player:WaitForChild("PlayerGui")
local meterBarInner = playerGui.HUDContainer.HealthMeter.InnerFill

-- Gradient sequence colors (red, orange, yellow, lime, green)
local gradient = {
	Color3.fromRGB(225, 50, 0),
	Color3.fromRGB(255, 100, 0),
	Color3.fromRGB(255, 200, 0),
	Color3.fromRGB(150, 225, 0),
	Color3.fromRGB(0, 225, 50)
}

-- Function to get color in gradient sequence from fractional point
local function getColorFromSequence(fraction: number): Color3
	-- Each color in gradient defines the beginning and/or end of a section
	local numSections = #gradient - 1

	-- Each section represents a portion of 1
	local sectionSize = 1 / numSections

	-- Determine which section the requested fraction falls into
	local sectionStartIndex = 1 + math.clamp(fraction, 0, 1) // sectionSize

	-- Get the colors at the start and end of the section
	local sectionColorStart = gradient[sectionStartIndex]
	local sectionColorEnd = gradient[sectionStartIndex + 1] or sectionColorStart

	-- Normalize fraction to be a number from 0 to 1 within the section
	local fractionOfSection = math.clamp(fraction, 0, 1) % sectionSize / sectionSize

	-- Lerp between beginning and end based on the normalized fraction
	return sectionColorStart:Lerp(sectionColorEnd, fractionOfSection)
end

local function onHealthChanged()
	-- Calculate new health as percentage of max
	local healthFraction = math.max(0, humanoid.Health / humanoid.MaxHealth)

	-- Tween the bar to new size/color targets
	local tweenGoal = {
		Size = UDim2.new(healthFraction, 0, 1, 0),
		BackgroundColor3 = getColorFromSequence(healthFraction)
	}
	local meterBarTween = TweenService:Create(meterBarInner, tweenInfo, tweenGoal)
	meterBarTween:Play()
end

-- Listen for changes to humanoid health
humanoid.HealthChanged:Connect(onHealthChanged)

-- Initially set (or reset) bar size/color to current health
onHealthChanged()