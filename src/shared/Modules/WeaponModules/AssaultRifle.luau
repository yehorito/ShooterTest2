local LocalPlayer = game.Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Camera = workspace.CurrentCamera

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Shared:WaitForChild("Modules")
local WeaponData = Modules:WaitForChild("WeaponData")
local Viewmodels = ReplicatedStorage:WaitForChild("Viewmodels")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DamageEvent = Remotes:WaitForChild("Damage")

local Data = require(WeaponData:FindFirstChild(script.Name))
local GunModel = Viewmodels:FindFirstChild(script.Name)
if not Data or not GunModel then return end

local Module = {}
Module.__index = Module
-- 
local gun = GunModel.M16A4
--local MuzzleEffect = gun.MuzzleFlash.MuzzleEffect

local function ShowEffect()
  
    
 
    
    --wait(0.025)
    --MuzzleEffect.Texture = "rbxassetid://421803006"
    --wait(0.05)
    --MuzzleEffect.Texture = "rbxassetid://421803091"
    --wait(0.025)
    --MuzzleEffect.Texture = "rbxassetid://421803134"
	
end


function Module:Fire()
local Origin = Camera.CFrame.Position
local Direction = Camera.CFrame.LookVector * 500

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
Params.FilterDescendantsInstances = {Character} or {workspace:FindFirstChild(LocalPlayer.Name)}

local Raycast = workspace:Raycast(Origin, Direction, Params)

if Raycast and Raycast.Instance then
	local Hit = Raycast.Instance

    task.spawn(function()ShowEffect()
    end)

	if Hit.Parent:FindFirstChild("Humanoid") then
		if Hit.Name == "Head" then
			local Damage = Data.Headshot
			
			DamageEvent:FireServer(Hit.Parent, Damage)			

		else
			local Damage = Data.Damage
			
			DamageEvent:FireServer(Hit.Parent, Damage)	
			end
		end
	end
end



return Module