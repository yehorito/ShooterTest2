local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Shared:WaitForChild("Modules")
local Viewmodels = ReplicatedStorage:WaitForChild("Viewmodels")

local WeaponModules = Modules:WaitForChild("WeaponModules")
local WeaponData = Modules:WaitForChild("WeaponData")

local Module = {}

function Module.FindWeaponModule(Name: string)
	if WeaponModules:FindFirstChild(Name) then
		return WeaponModules:FindFirstChild(Name)
	end
end

function Module.FindWeaponData(Name: string)
	if WeaponData:FindFirstChild(Name) then
		return WeaponData:FindFirstChild(Name)
	end
end

function Module.FindViewmodel(Name: string)
	if Viewmodels:FindFirstChild(Name) then
		return Viewmodels:FindFirstChild(Name)
	end
end

return Module