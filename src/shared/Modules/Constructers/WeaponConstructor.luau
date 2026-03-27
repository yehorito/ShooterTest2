local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Shared:WaitForChild("Modules")
local Constructors = Modules:WaitForChild("Constructers")

local ViewmodelConstructor = require(Constructors:WaitForChild("ViewmodeConstructor"))
local Utility = require(Modules:WaitForChild("Utility"))

local Module = {}
Module.__index = Module

function Module.Construct(Name: string)
	
	local self = setmetatable({
		Connections = {},
	}, Module)
	
	self.Viewmodel = ViewmodelConstructor.Construct(Name, self.Connections)
	self.Weapon = require(Utility.FindWeaponModule(Name))
	self.Data = require(Utility.FindWeaponData(Name))
	
	return self
end

function Module:Fire()
	if self.Data.Ammo > 0 then
		self.Data.Ammo -= 1
		
		self.Weapon:Fire()
		self.Viewmodel:PlayAnimation("Fire")
	end
end

function Module:Reload()
	if self.Data.Ammo < self.Data.MaxAmmo then
		local Animation: AnimationTrack = self.Viewmodel:PlayAnimation("Reload")
		Animation.Ended:Connect(function()
			self.Data.Ammo = self.Data.MaxAmmo
		end)
	end
end

function Module:Hide()
    self.Viewmodel:Destroy()
	-- for _, connection in pairs(self.Connections) do
	-- 	if connection then
	-- 		connection:Disconnect()
	-- 	end
	-- end
	
	-- self.Connections = {}
	

	-- if self.Viewmodel then
	-- 	self.Viewmodel:Destroy()
	-- end
end

return Module