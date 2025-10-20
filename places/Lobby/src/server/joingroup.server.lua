-- Replace with your group ID
local groupId = 35986795

game.Players.PlayerAdded:Connect(function(player)
	-- Check if the player is a group member
	if player:GetRankInGroup(groupId) >= 0 then -- Replace '1' with the minimum rank required
		local item = game.ServerStorage.Scar:Clone() -- Replace 'Scar' with the actual name if this needs to be changed
		item.Parent = player:WaitForChild("Backpack")
	end
end)