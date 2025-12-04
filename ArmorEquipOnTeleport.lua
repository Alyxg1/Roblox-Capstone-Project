local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local armorTemplate = ServerStorage:WaitForChild("Armory"):WaitForChild("ACSvest")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local joinData = player:GetJoinData()
		local teleportData = joinData and joinData.TeleportData
		if teleportData and teleportData[tostring(player.UserId)] and teleportData[tostring(player.UserId)].hasArmor then
			repeat wait() until char:FindFirstChild("Humanoid")

			-- Equip Armor
			local armor = armorTemplate:Clone()
			armor.Parent = char

			for _, part in ipairs(armor:GetChildren()) do
				if part:IsA("BasePart") then
					local weld = Instance.new("Weld")
					weld.Part0 = armor.Middle
					weld.Part1 = part
					weld.C0 = CFrame.new()
					weld.C1 = part.CFrame:inverse() * armor.Middle.CFrame
					weld.Parent = armor.Middle
				end
			end

			local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
			if torso then
				local bodyWeld = Instance.new("Weld")
				bodyWeld.Part0 = torso
				bodyWeld.Part1 = armor.Middle
				bodyWeld.C0 = CFrame.new()
				bodyWeld.Parent = torso
			end

			for _, part in ipairs(armor:GetChildren()) do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.CanCollide = false
				end
			end

			-- ?? Give bonus health
			local humanoid = char:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.MaxHealth = 175
				humanoid.Health = 175
			end

			print("Armor and bonus health applied for", player.Name)
		end
	end)
end)
