local DSS = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local playerStore = DSS:GetDataStore("PlayerStats")

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder") stats.Name = "leaderstats" stats.Parent = player
	local wins = Instance.new("IntValue") wins.Name = "Wins" wins.Parent = stats
	local equipped = Instance.new("StringValue") equipped.Name = "EquippedGun" equipped.Parent = player

	local success, data = pcall(function()
		return playerStore:GetAsync(player.UserId)
	end)
	if success and data then
		wins.Value = data.Wins or 0
		equipped.Value = data.EquippedGun or ""
	else
		wins.Value = 0 equipped.Value = ""
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local wins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Wins")
	local equipped = player:FindFirstChild("EquippedGun")
	if wins and equipped then
		pcall(function()
			playerStore:SetAsync(player.UserId, {
				Wins = wins.Value,
				EquippedGun = equipped.Value
			})
		end)
	end
end)