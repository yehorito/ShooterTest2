local PathFindingService = require(script.Parent.Parent.Libs.PathFindingService)
local libs = script.Parent.Parent.Libs
local pathService = PathFindingService.new()
local CircularSelector = require(libs.CircularSelector)
local BulletController = require(script.Parent.Bullet)
local AI = {}

AI.VERSION = "1.0.0"
AI.__index = AI
local PathFinding = game:GetService("PathfindingService")

function AI.new(rig, team)
    local self = setmetatable({
    rig = rig,
    rootPart = rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart,
     humanoid = rig:FindFirstChildOfClass("Humanoid"),
     team = team or "Team1",  -- Встановлюємо команду NPC
    }, AI)

    self.raycastParams = RaycastParams.new()
    self.raycastParams.FilterDescendantsInstances = {self.rig}
    self.raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    self.raycastParams.IgnoreWater = true
    self.basePosition = self.rootPart.Position
   

    self.movementDistance = 5 
    self.visibilityCheckDistance = 5
    self.directions = {
        left = {
            angle = 0,
            vector = Vector3.new(-1, 0, 0), 
            name = "left"
        },
        front = {
            angle = 90,
            vector = Vector3.new(0, 0, -1), 
            name = "front"
        },
        right = {
            angle = 180,
            vector = Vector3.new(1, 0, 0), 
            name = "right"
        },
        back = {
            angle = 270,
            vector = Vector3.new(0, 0, 1),
            name = "back"
        }
    }
    self.CurrentDirection = self.directions.front

 -- Встановлюємо початковий напрямок після визначення directions
    self.CurrentDirection = self.directions.front
    
    -- Створюємо CircularSelector для циклічного перемикання напрямків
    local directionOrder = {"front", "right", "back", "left"}
    self.directionSelector = CircularSelector.new(directionOrder)
	self.directionSelector.index = 1 -- Починаємо з "front"
	
	-- Ініціалізуємо систему кулі
    self.AttachmentForBullet = self:GetAttachment(rig:WaitForChild("Tool",3))-- 


	self.bulletController = BulletController.new(workspace, false, "Enemy")
	self.bulletController:SetOwner(rig)
	
	-- Налаштування стрільби
	self.shootCooldown = 1.0 -- Кулдаун між пострілами (секунди)
	self.lastShootTime = 0
	self.bulletDamage = 25

    
  
    return self
  
end


function AI:GetAttachment(tool)
    local AttachmentForBullet =  tool:WaitForChild("AttachmentForBullet")
    if AttachmentForBullet then
       
        return AttachmentForBullet
    else
        
        warn("Not found attachment")
    end
    

end


-- Функція для зміни напрямку руху вправо (циклічно: front → right → back → left → front)
-- ф-ція для зміни напрямку руху вправо

function AI:TurnRight()
    local nextDirectionName = self.directionSelector:Step(1)
    self.CurrentDirection = self.directions[nextDirectionName]
    
    print("Turned right. New direction: " .. self.CurrentDirection.name)
	return self.CurrentDirection

end

-- змінити назву
function AI:ChoosePath(countRecursion)
    local countRecursion =  countRecursion or 0
    if countRecursion > 4 then
        warn("Максимум досягнут, вихід не знайдено")
        self:ReturnToBase()
        return
    end
    -- Обчислюємо цільову точку для перевірки

    local targetPosition = self.basePosition + (self.CurrentDirection.vector * self.movementDistance)
    
    -- Перевірка видимості точки перед рухом (використовуємо IsPointVisible)
    local isVisible, reason = self:IsPointVisible(targetPosition, self.visibilityCheckDistance)
    
    if not isVisible then
        print("Point is not visible (" .. reason .. "). Changing direction...")
        self:TurnRight()
        -- Рекурсивно пробуємо новий напрямок
        -- додати крок рекурсії, якщо більше допустимої кількості, тоді відправляємо на базу 
        self:ChoosePath(countRecursion+1)
        return
    end
    
    print("Point is visible. Moving " .. self.CurrentDirection.name)
    
    task.spawn(function()
        pathService:FollowPath(self.rig, self.CurrentDirection.vector, function(success, reason)
            if success and reason == "Reached" then
                print("NPC reached the target position.")
            else
                print("NPC failed to reach the target position. Reason: " .. reason)
                self:TurnRight()
                self:ChoosePath()
            end
        end)
    end)
end




function AI:MoveTo(speed:number, targetPosition:Vector3)
    -- Встановити швидкість руху NPC

  local path = PathFinding:FindPathAsync(self.rootPart.Position, targetPosition)
    local waypoints = path:GetWaypoints()
    for _, waypoint in ipairs(waypoints) do
        self.humanoid:MoveTo(waypoint.Position)
        local reached = self.humanoid.MoveToFinished:Wait()
        
    end
    
end

-- Вставновити швидкість руху NPC
-- додати до конструктору швидкість руху для кожного стану
function AI:Walk(targetPosition:Vector3 )
  self:MoveTo(16, targetPosition)
end

function AI:Run(targetPosition:Vector3)
    self:MoveTo(26, targetPosition)
end




function AI:Patrol(deltaTime)
    -- Якщо вже патрулюємо, не запускаємо новий потік
    if self.isPatrolling then
        return
    end
    
    -- Ініціалізуємо налаштування патруля
    self.patrolWaitTime = self.patrolWaitTime or 2
    self.currentPatrolIndex = self.currentPatrolIndex or 1
    self.isPatrolling = true
    
    -- Створюємо точки патруля на основі напрямків (від базової позиції)
    if not self.patrolPoints then
        self.patrolPoints = {}
        for _, directionName in ipairs({"front", "right", "back", "left"}) do
            local targetPos = self:GetDirectionalTarget(directionName)
            table.insert(self.patrolPoints, {
                position = targetPos,
                direction = directionName
            })
        end
      
    end
    
    -- Запускаємо безкінечний цикл патруля
    task.spawn(function()
       
        
        while self.isPatrolling do
            local currentPoint = self.patrolPoints[self.currentPatrolIndex]
            
            if not currentPoint then
                warn("[Patrol] Invalid patrol point at index " .. self.currentPatrolIndex)
                self.currentPatrolIndex = 1
                task.wait(0.5)
                continue
            end
            
            
            
            -- Рухаємося до точки (без перевірки видимості - pathfinding сам знайде шлях)
            local success = self:MoveToPatrolPoint(currentPoint.position)
            
            if success then
              
                task.wait(self.patrolWaitTime)
            else
                print("[Patrol] Could not reach " .. currentPoint.direction .. ", moving to next point")
                task.wait(0.5)
            end
            
            -- Переходимо до наступної точки (циклічно)
            self.currentPatrolIndex = (self.currentPatrolIndex % #self.patrolPoints) + 1
           
        
        end
        
        print("[Patrol] Patrol loop ended")
    end)
end

-- Допоміжна функція для руху до точки патруля
function AI:MoveToPatrolPoint(targetPosition)
    if not self.rootPart or not self.humanoid then
        warn("[Patrol] No rootPart or humanoid")
        return false
    end
    
    -- Перевіряємо, чи вже близько до цілі
    local distanceToTarget = (self.rootPart.Position - targetPosition).Magnitude
    if distanceToTarget < 2 then
        print("[Patrol] Already at target position")
        return true
    end
    
    local path = PathFinding:FindPathAsync(self.rootPart.Position, targetPosition)
    
    if path.Status == Enum.PathStatus.NoPath then
        warn("[Patrol] No path found to target")
        return false
    end
    
    local waypoints = path:GetWaypoints()
    
    for i, waypoint in ipairs(waypoints) do
        -- Перевіряємо, чи патруль все ще активний
        if not self.isPatrolling then
            print("[Patrol] Patrol stopped during movement")
            return false
        end
        
        -- Якщо NPC помер або застряг
        if self.humanoid.Health <= 0 then
            return false
        end
        
        self.humanoid:MoveTo(waypoint.Position)
        
        -- Чекаємо завершення руху з таймаутом (8 секунд на кожен waypoint)
        local reached = self.humanoid.MoveToFinished:Wait(8)
        
        if not reached then
            print("[Patrol] Timeout on waypoint " .. i)
            -- Не повертаємо false, продовжуємо до наступного waypoint
        end
    end
    
    return true
end

-- Зупинити патруль
function AI:StopPatrol()
    self.isPatrolling = false
    if self.humanoid then
        self.humanoid:MoveTo(self.rootPart.Position)
    end
end


function AI:Attack(target:Vector3)
    
    
end


function AI:Flee(deltaTime, threat)

end


function AI:Follow(deltaTime, target)

end


function AI:ReturnToBase(deltaTime)

end


function AI:Alert(deltaTime, alertSource)

end


function AI:Dead(deltaTime)

end


-- зліва від НІП - 0, спереду - 90, справа - 180, ззаду - 270
-- додати відстань 

-- 1) Вона повинна брати повертати напрямок куди ідти взалежності від навклолищньої локації
function AI:SetupDirectionalMovement()
    self.basePosition = basePosition or Vector3.new(105, 0.5, -89.1)
   

end


function AI:GetDirectionalTarget(directionName)
    if not self.directions or not self.directions[directionName] then
        warn("Invalid direction: " .. tostring(directionName))
        return self.basePosition
    end
    
    local direction = self.directions[directionName]
    local targetPosition = self.basePosition + (direction.vector * self.movementDistance)
    return targetPosition
end

function AI:MoveToDirection(directionName,targetPosition, speed)
    speed = speed or 16
    --local targetPosition =  self:GetDirectionalTarget(directionName)
    
    print("Moving NPC to " .. directionName .. " direction")
    print("Target position: " .. tostring(targetPosition))
    print("Angle: " .. self.directions[directionName].angle .. "°")
    print("Distance: " .. self.movementDistance .. " studs")
    
    self:Walk(targetPosition)
end


function AI:MoveLeft(speed) 
    self:MoveToDirection("left", speed)
end


function AI:MoveFront(speed)
    self:MoveToDirection("front", speed)
end


function AI:MoveRight(speed)
    self:MoveToDirection("right", speed)
end


function AI:MoveBack(speed)
    self:MoveToDirection("back", speed)
end

-- Безперервний патруль по напрямках (зациклений)
function AI:PatrolDirections(speed, waitTime)
    speed = speed or 16
    waitTime = waitTime or 3
    
    local patrolOrder = {"left", "front", "right", "back"}
    local patrolIndex = 1
    
    print("[PatrolDirections] Starting continuous patrol")
    
    while self.isPatrolling do
        local direction = patrolOrder[patrolIndex]
        local targetPosition = self:GetDirectionalTarget(direction)
        
        print("[PatrolDirections] Moving to " .. direction .. " (" .. patrolIndex .. "/" .. #patrolOrder .. ")")
        
        -- Рухаємося до точки
        self:MoveToDirection(direction, targetPosition, speed)
        
        -- Чекаємо на точці
        task.wait(waitTime)
        
        -- Переходимо до наступного напрямку (циклічно)
        patrolIndex = (patrolIndex % #patrolOrder) + 1
    end
    
    print("[PatrolDirections] Patrol ended")
end


function AI:ReturnToBase(speed)
    speed = speed or 16
    self:MoveTo(speed, self.basePosition)
end


--Приймає позицю цілі, дистанцію
-- Повертає fasle, якщо є перешкода на шляху
-- Повертаэ true, якщо немає перешкод між цілью і НІП на відповідній дистанції
function AI:IsPathClear(targetPosition:Vector3, checkDistance:number)
    local npcPosition = self.rootPart.Position
    local directionToTarget = (targetPosition - npcPosition).Unit
    local fullDistance = (targetPosition - self.rootPart.Position).Magnitude
    
  
    local distance = self:GetDistance(targetPosition, npcPosition)
    
    local raycastParams = self.raycastParams
    
    local result = workspace:Raycast(npcPosition, directionToTarget * distance, raycastParams)
    if result and result.Instance then
        return false, "obstructed"
    end
    return true, "clear"
    
end


function AI:IsPointVisible(targetPosition: Vector3, checkDistance: number)
    if not self.rootPart then
        return false, "no_root_part"
    end

    local npcPosition = self.rootPart.Position
    local directionToTarget = (targetPosition - npcPosition).Unit
    local fullDistance = (targetPosition - npcPosition).Magnitude
    local distance = checkDistance or fullDistance

    local raycastParams = self.raycastParams
    raycastParams.FilterDescendantsInstances = {self.rootPart.Parent}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

 
    local startPos = npcPosition + directionToTarget * 1

    local result = workspace:Raycast(startPos, directionToTarget * (distance - 1), raycastParams)
    -- print("Hit object:", result.Instance)
    -- print("Hit position:", result.Position)
    -- print("Surface normal:", result.Normal)
    -- print("Material:", result.Material)


    if result then
        -- Перевірка команди об'єкта, в який потрапив промінь
        local hitInstance = result.Instance
        local hitParent = hitInstance.Parent
        local hitGrandParent = hitParent and hitParent.Parent
        
        -- Визначаємо команду NPC (можна налаштувати через self.team)
        local npcTeam = self.team or "Team1"
        
        -- Перевіряємо ієрархію об'єкта на приналежність до команди
        local function isSameTeam(instance)
            if not instance then return false end
            
            -- Перевіряємо ім'я об'єкта
            if instance.Name == npcTeam then
                return true
            end
            
            -- Перевіряємо атрибут команди, якщо він існує
            local teamAttribute = instance:GetAttribute("Team")
            if teamAttribute and teamAttribute == npcTeam then
                return true
            end
            
            -- Рекурсивно перевіряємо батьківські об'єкти
            if instance.Parent and instance.Parent ~= workspace then
                return isSameTeam(instance.Parent)
            end
            
            return false
        end
        
        -- Перевіряємо чи об'єкт належить до тієї ж команди, що і NPC
        local isObstructedBySameTeam = isSameTeam(hitInstance) or isSameTeam(hitParent) or isSameTeam(hitGrandParent)
        
        if isObstructedBySameTeam then
            return false, "obstructed_by_same_team"
        else
            return true, "visible"
        end
    end

    return false, "no_hit"
end

local function getPositionRig(rig)
    local targetRootPart = rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart
    if not targetRootPart then
        return false
    end
    return targetRootPart.Position
    
end



-- працює тільки з Humanoid
function AI:IsTargetVisible(target:Vector3, fovAngle:number)
    
    local npcPosition = getPositionRig(self.rig)
    local targetPosition = target
    local directionToTarget = (targetPosition - npcPosition).Unit
    local distance = self:GetDistance(targetPosition, npcPosition)
    local raycastParams = self.raycastParams
    
    
    -- перенести логіку в ф-цію AI:IsinFOV()
    fovAngle = fovAngle or 70 
    local lookDirection = self.rootPart.CFrame.LookVector
    local dotProduct = lookDirection:Dot(directionToTarget)
    local angleToTarget = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))
    
   
    if angleToTarget > fovAngle / 2 then
        return false, "out_of_fov"
    end
    return self:IsPointVisible(targetPosition)
    
    -- local result = workspace:Raycast(npcPosition, directionToTarget * distance, raycastParams)
    
    -- if result and result.Instance then
    --     local hitParent = result.Instance.Parent
    --     while hitParent and hitParent ~= workspace do
    --         if hitParent == target then
    --             return true, "visible"
    --         end
    --         hitParent = hitParent.Parent
    --     end
    --     return false, "obstructed"
    -- end
    
    -- return true, "visible"
end  
-- 





--Ф-ція приймає позицію цілі
-- повертає дистанцію до цієї цілі від НІП чи false
function AI:GetDistance(targetPosition, npcPosition)
    if not targetPosition then
        return false, "target doesnt exists"
    end
   
   
    local distance = (targetPosition - npcPosition).Magnitude
    return distance
end

--
--2)  є список ворогів усіх і ми тільки знаходимо найближчого, або інший критерій 
--3) Вибирає найближчого та повертає 
--@Return target Vector3

function AI:FindNearestTarget(Enemys)
    local targetPosition
    local isVisible,reason  
    for _, Enemy in ipairs(Enemys) do
        targetPosition = getPositionRig(Enemy)

        isVisible , reason = self:IsTargetVisible(targetPosition)
        if isVisible then
            return targetPosition,reason
            
        end
    
    end
    return false, reason
end

-- Функція для пострілу в ціль
-- target - Model або Vector3 позиція цілі
-- Повертає true, якщо постріл відбувся, false якщо ні
function AI:Shoot(target)
    -- Перевірка кулдауну
    local currentTime = tick()
    if currentTime - self.lastShootTime < self.shootCooldown then
        return false, "cooldown"
    end
    
    -- Отримуємо позицію цілі
    local targetCFrame
    if typeof(target) == "Vector3" then
        targetCFrame = target
    elseif typeof(target) == "Instance" then
        local targetRootPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
        if not targetRootPart then
            return false, "no_target_root"
        end
        targetCFrame = targetRootPart.CFrame
    else
        return false, "invalid_target"
    end
    
    -- Перевіряємо чи ціль видим
    local isVisible, reason = self:IsTargetVisible(target)
    if not isVisible then
        return false, "not_visible: " .. reason
    end
    
    -- Отримуємо позицію зброї або використовуємо rootPart
    local weapon = self.rig:FindFirstChild("AK-47")
    local spawnPosition
    
    if weapon then
        spawnPosition = weapon.CFrame * CFrame.new(0, 0, -4)
    else
        -- Якщо немає зброї, створюємо кулю перед NPC
        spawnPosition = self.rootPart.CFrame * CFrame.new(0, 1, -3)
    end
    
    -- Створюємо та запускаємо кулю
    --Shoot(fromCFrame, victimPosition, countDamage, offset)
    local bullet = self.bulletController:Shoot(self.AttachmentForBullet.WorldCFrame, targetCFrame, self.bulletDamage)
    
    if bullet then
        self.lastShootTime = currentTime
        print("[AI] " .. self.rig.Name .. " shot at " .. tostring(targetCFrame))
        return true, "success"
    else
        return false, "bullet_creation_failed"
    end
end

-- Функція для автоматичної стрільби по найближчій цілі
function AI:ShootNearestTarget(enemyTeam)
    local nearestTarget,reason = self:FindNearestTarget(enemyTeam)
    if nearestTarget then

        return self:Shoot(nearestTarget), reason
    end
    
    return false, reason
end

-- Функція для встановлення налаштувань стрільби
function AI:SetShootSettings(cooldown, damage, friendlyFire, team)
    self.shootCooldown = cooldown or self.shootCooldown
    self.bulletDamage = damage or self.bulletDamage
    
    if friendlyFire ~= nil then
        self.bulletController.friendlyFire = friendlyFire
    end
    
    if team then
        self.bulletController:SetTeam(team)
    end
end


return AI
