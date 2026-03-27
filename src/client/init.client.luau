
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local humanoid = character.Humanoid


local Modules = ReplicatedStorage.Shared:WaitForChild("Modules")
local Constructors = Modules:WaitForChild("Constructers")

local WeaponConstructors = require(Constructors:WaitForChild("WeaponConstructor"))
local inventory = { "Knife", "M1911", "AssaultRifle" }
local currentGun = inventory[3]
local Weapon = nil
local WeaponData = Modules.WeaponData
local Data = nil
local inventory = {'Knife','M1911','AssaultRifle' }
local currentGun = inventory[3]
local Weapon = WeaponConstructors.Construct(currentGun) -- CHANGE TO ANY WEAPON U WANNA USE
local WeaponData = Modules.WeaponData
local Data = require(WeaponData:FindFirstChild(currentGun)) -- CHANGE TO ANY WEAPON U WANNA USE

local Shooting = false
local Oncooldown = false
local Reloading = false

local IsAlive = true

local function OnCharacterAdded(newCharacter)
	IsAlive = true

	Weapon = WeaponConstructors.Construct(currentGun)
	Data = require(WeaponData:FindFirstChild(currentGun))
	character = newCharacter
	humanoid = newCharacter.Humanoid
	humanoid.Died:Connect(function()
		Weapon:Hide()
		IsAlive = false
	end)
end
player.CharacterAdded.Wait()

-- UserInputService.InputBegan:Connect(function(input, processed)
-- 	if processed then
-- 		return
-- 	end

-- 	if IsAlive == false then
-- 		return
-- 	end


-- винести в окрему ф-цію зміну зброї 

UserInputService.InputBegan:Connect(function(input, processed)
	
	if processed then
		return
	end
	

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if Data.Firemode == "Automatic" and Reloading == false then
			Shooting = true
		else
			if Oncooldown == false and Reloading == false then
				Oncooldown = true
				Weapon:Fire()


				task.delay(Data.FireCooldown, function()
					Oncooldown = false
				end)
			end
		end

		
	elseif input.KeyCode == Enum.KeyCode.R then
		
		if Reloading == true then return end
		Weapon:Reload()
		
		Shooting = false
		Reloading = true
		
		task.delay(2.5, function()
			Reloading = false
		end)
		
	elseif input.KeyCode ==  Enum.KeyCode.One then
		Weapon:Hide()
		
		currentGun = inventory[1]
		Weapon = WeaponConstructors.Construct(currentGun)
		Data = require(WeaponData:FindFirstChild(currentGun))
		
	elseif input.KeyCode ==  Enum.KeyCode.Two then

		Weapon:Hide()
		currentGun = inventory[2]
		Weapon = WeaponConstructors.Construct(currentGun)
		Data = require(WeaponData:FindFirstChild(currentGun))

	

		
	elseif input.KeyCode ==  Enum.KeyCode.Three then

		Weapon:Hide()
		currentGun = inventory[3]
		Weapon = WeaponConstructors.Construct(currentGun)
		Data = require(WeaponData:FindFirstChild(currentGun))


	
		

	end
end)

UserInputService.InputEnded:Connect(function(input, processed)

	if processed then
		return
	end


	
	if processed then return end
	

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if Data.Firemode == "Automatic" then
			Shooting = false
		end
	end


	

end)

RunService.RenderStepped:Connect(function()
	if Data.Firemode == "Automatic" then
		if Shooting and Oncooldown == false and Reloading == false then

			Weapon:Fire()
			Oncooldown = true

			task.delay(Data.FireCooldown, function()
				Oncooldown = false
			end)
		end
	end
end)

			

