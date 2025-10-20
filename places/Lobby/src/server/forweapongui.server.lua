local replicated = game:GetService("ReplicatedStorage")
local equipEvent = replicated:WaitForChild("EquipWeaponEvent")
local guns = game.ServerStorage:WaitForChild("Guns")

equipEvent.OnServerEvent:Connect(function(player, weaponName)
	local gun = guns:FindFirstChild(weaponName)
	if gun and gun:IsA("Tool") then
		-- Clear old tools
		for _, t in pairs(player.Backpack:GetChildren()) do
			if t:IsA("Tool") then t:Destroy() end
		end

		local clone = gun:Clone()
		clone.Parent = player.Backpack
	end
end)
