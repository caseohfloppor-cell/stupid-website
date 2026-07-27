local tool = script.Parent
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemModule = require(ReplicatedStorage:WaitForChild("ItemModule"))
local ItemTools = ReplicatedStorage:WaitForChild("ItemTools")

-- Prevent spam clicking while a fish is being reeled in
local isReeling = false

local function cleanup(model, attachments, velocityForce)
	for _, att in ipairs(attachments) do
		if att then att:Destroy() end
	end
	if velocityForce then velocityForce:Destroy() end
	if model then model:SetAttribute("BeingReeled", nil) end
	isReeling = false
end

tool.Activated:Connect(function()
	if isReeling then return end

	local targetPart = mouse.Target
	if not targetPart then return end

	-- Find if the target is part of a Model and check for the "Fishable" attribute
	local model = targetPart:FindFirstAncestorOfClass("Model")

	if model and model:GetAttribute("Fishable") == true then
		local fishPart = tool:FindFirstChild("Fish")

		if fishPart then
			isReeling = true
			model:SetAttribute("BeingReeled", true) -- tells the loot spawner not to despawn this mid-catch

			-- Attachment + LinearVelocity to pull the item smoothly toward the rod
			local attachment0 = Instance.new("Attachment")
			attachment0.Parent = targetPart

			local velocityForce = Instance.new("LinearVelocity")
			velocityForce.Attachment0 = attachment0
			velocityForce.MaxForce = math.huge
			velocityForce.VectorVelocity = Vector3.new(0, 0, 0)
			velocityForce.RelativeTo = Enum.ActuatorRelativeTo.World
			velocityForce.Parent = targetPart

			local attachments = {attachment0}

			-- Smoothly pull the model toward the player's fish part over time
			local connection
			connection = game:GetService("RunService").Heartbeat:Connect(function()
				if not targetPart or not targetPart.Parent or not fishPart or not fishPart.Parent then
					if connection then connection:Disconnect() end
					cleanup(model, attachments, velocityForce)
					return
				end

				local direction = (fishPart.Position - targetPart.Position)
				local distance = direction.Magnitude

				if distance > 4 then
					-- Pull smoothly towards the tool
					velocityForce.VectorVelocity = direction.Unit * 35
				else
					-- Close enough: stop pulling, give the item's Tool version, and clean up
					connection:Disconnect()

					local toolTemplate = ItemTools:FindFirstChild(model.Name)
					if toolTemplate then
						local success, err = pcall(function()
							ItemModule.GiveItem(player, model.Name, toolTemplate)
						end)
						if not success then
							warn("[Fishing rod] Failed to give item:", err)
						end
					else
						warn("[Fishing rod] No ItemTools entry for caught item:", model.Name)
					end

					-- Clean up world instances
					model:Destroy()
					cleanup(nil, attachments, velocityForce)
				end
			end)

			print("Reeling in: " .. model.Name)
		else
			warn("A part named 'Fish' could not be found inside the Tool!")
		end
	end
end)