local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Shared:WaitForChild("Modules")


local Utility = require(Modules:WaitForChild("Utility"))

local LocalPlayer = game.Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Camera = workspace.CurrentCamera

local Module = {}
Module.__index = Module

function Module.Construct(Name: string, ConnectionArray: {any})
	local self = setmetatable({}, Module)
	
	self.Model = Utility.FindViewmodel(Name)
	if self.Model then
		self.Model = self.Model:Clone()
		self.Model.Parent = workspace
		
		self.AttachmentEffect = self.Model:FindFirstChild("AttachmentEffect")
        if self.AttachmentEffect then
            self.AttachmentEffect.Parent = Camera
        end 
		
		self.Animator = self.Model.AnimationController.Animator
		self.Animations = self.Model.Animations
		self.Sounds = self.Model.Sounds
		self.BobTimer = 0
		self.BobSpeed = 8
		self.BobAmount = Vector3.new(.05, .1, 0)
		
		ConnectionArray["ViewmodelPositioning"] = RunService.RenderStepped:Connect(function(deltaTime)
			local BasePosition = CFrame.new(0, 0, 0)
			local WalkingSpeed = Humanoid.MoveDirection.Magnitude
			
			if WalkingSpeed > 0 then
				self.BobTimer = self.BobTimer + WalkingSpeed * self.BobSpeed * deltaTime
				
				local BobOffsetX = math.sin(self.BobTimer) * self.BobAmount.X
				local BobOffsetY = math.sin(self.BobTimer) * self.BobAmount.Y
				local BobOffset = Vector3.new(BobOffsetX, BobOffsetY, 0)
				
				self.Model:PivotTo(Camera.CFrame * BasePosition + BobOffset)
			else
				self.BobTimer = 0
				self.Model:PivotTo(Camera.CFrame)
			end
		end)
	end
	
	return self
end


function Module:PlayAnSound(Name: string)
	local Sound : Sound = self.Sounds:FindFirstChild(Name)
	if Sound then	
	    Sound:Play()
	end
end
		


function Module:PlayAnimation(Name: string)
	 local Animation: Animation = self.Animations:FindFirstChild(Name)
	 if Animation then
		local Track: AnimationTrack = self.Animator:LoadAnimation(Animation)
		
		Track.Looped = false 
		self:PlayAnSound(Animation.Name)
		Track:Play()
		
		return Track
	 end
end

function Module:Destroy(name)
	if self.Model then
		self.Model:Destroy()
	end
	
end
return Module