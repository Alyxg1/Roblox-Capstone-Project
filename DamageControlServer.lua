local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local humanoid = char:WaitForChild("Humanoid")
		local lastHealth = humanoid.Health

		humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < lastHealth then
				local tag = humanoid:FindFirstChild("LastDamager")

				-- Only allow damage if LastDamager is a monster
				if not tag 
					or not tag.Value 
					or not tag.Value:IsA("Model") 
					or not tag.Value:FindFirstChild("Humanoid") 
					or tag.Value.Name ~= "NewMonsterTest" 
				then
					-- Revert unauthorized damage
					humanoid.Health = lastHealth
				else
					-- Accept monster damage
					lastHealth = newHealth
				end
			else
				-- Healing or same health
				lastHealth = newHealth
			end
		end)
	end)
end)
