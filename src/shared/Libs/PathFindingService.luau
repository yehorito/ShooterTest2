local PathFindingService = game:GetService("PathfindingService")

local Service = {}
Service.__index = Service
function Service.new(args)
	local self = setmetatable({}, Service)
	return self
end

function Service:FollowPath(rig,destination, callback)
	local finished = false
	local active = true

	local reachedConnection
	local blockedConnection
	local diedConnection

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("No Humanoid found in rig")
		if callback then
			callback("NoHumanoid")
		end
		return
	end

	if not rig.PrimaryPart then
		warn("No PrimaryPart set in rig")
		if callback then
			callback("NoPrimaryPart")
		end
		return
	end

	local path = PathFindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		Costs = { Climb = 2, Water = 20 },
		UsePartialPaths = true,
	})

	local function finish(success, reason)
		if finished then
			return
		end
		finished = true
		active = false

		if reachedConnection then
			reachedConnection:Disconnect()
		end
		if blockedConnection then
			blockedConnection:Disconnect()
		end
		if diedConnection then
			diedConnection:Disconnect()
		end

		if callback then
			callback(success, reason)
		end
	end

	
	local success, errorMessage = pcall(function()
		path:ComputeAsync(rig.PrimaryPart.Position, destination)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		warn("Path not computed!", errorMessage)
		finish(false, "NoPath")
		return
	end

	local waypoints = path:GetWaypoints()
	if #waypoints < 2 then
		finish(true, "Reached")
		return
	end

	local nextWaypointIndex = 2

	-- Смерть НІПа
	diedConnection = humanoid.Died:Connect(function()
		finish(false, "Dead")
	end)

	-- Блокування шляху
	blockedConnection = path.Blocked:Connect(function()
		if not active then
			return
		end
		finish(false, "Blocked")
	end)

	-- Опрацювання руху
	reachedConnection = humanoid.MoveToFinished:Connect(function(reached)
    if not active then return end

    if reached and nextWaypointIndex < #waypoints then
        nextWaypointIndex += 1
        humanoid:MoveTo(waypoints[nextWaypointIndex].Position)
    elseif reached then
        finish(true, "Reached")
    else
        finish(false, "MoveFailed")
    end
end)


	-- Запуск руху
	humanoid:MoveTo(waypoints[nextWaypointIndex].Position)
end

return Service
