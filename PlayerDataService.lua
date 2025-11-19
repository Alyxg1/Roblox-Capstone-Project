-- ServerScriptService/PlayerDataService.server.lua (GAME PLACE)
-- Only loads EquippedGun; HighestRound is handled by GameManager.

local DSS = game:GetService("DataStoreService")
local PlayerStats = DSS:GetDataStore("PlayerStats")

game.Players.PlayerAdded:Connect(function(plr)
	-- Keep EquippedGun as a simple value on the player (NOT in leaderstats)
	local equipped = Instance.new("StringValue")
	equipped.Name = "EquippedGun"
	equipped.Parent = plr

	local ok, data = pcall(function() return PlayerStats:GetAsync(plr.UserId) end)
	if ok and type(data) == "table" then
		equipped.Value = data.EquippedGun or ""
	end
end)
