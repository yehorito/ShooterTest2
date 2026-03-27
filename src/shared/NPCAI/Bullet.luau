local Debris = game:GetService("Debris")
local BulletController = {}

BulletController.__index = BulletController

function BulletController.new(parent, friendlyFire: bool, team)
    local self = setmetatable({ 
        Part = "Part",
        Size = Vector3.new(0.3, 0.3, 3.5),
        parent = parent,
        friendlyFire = friendlyFire or false,
        team = team or "Default",
        owner = nil,
    }, BulletController)

    return self
end

function BulletController:Create(CFrame)
    local bullet = Instance.new(self.Part,self.parent)
    bullet.Size = self.Size
    bullet.Material = "Neon"
   
    bullet.CFrame = CFrame
    return bullet
end

-- Функція для пострілу кулею
-- npc - NPC, від якого вилітає куля (опціонально, якщо передано - позиція береться від NPC)
-- victimPosition - цільова позиція (куди летіти)
-- countDamage - кількість урону (опціонально)
-- offset - зміщення від позиції NPC (опціонально, за замовчуванням Vector3.new(0, 0, -4))
function BulletController:Shoot(fromCFrame, victimPosition, countDamage, offset)
    -- Визначаємо початкову позицію кулі
 
    
    -- Створюємо кулю
    local bullet = self:Create(fromCFrame)
    bullet.CanCollide = false
    bullet.Anchored = false
    
    -- Додаємо BodyVelocity для руху кулі
    local velocity = Instance.new("BodyVelocity", bullet)
    velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    velocity.Velocity = Vector3.new(0, 0, 0)
    
    -- Орієнтуємо кулю в напрямку цілі
    if victimPosition then
        bullet.CFrame = CFrame.new(bullet.Position, victimPosition)
        -- Встановлюємо швидкість у напрямку цілі з невеликим розкидом
        velocity.Velocity = bullet.CFrame.LookVector * 500 + Vector3.new(
            math.random(-25, 25), 
            math.random(-25, 25), 
            0
        )
    end
    
    -- Підключаємо систему урону
    self:ConnectDamage(bullet, countDamage)
    
    -- Візуальний ефект пострілу (опціонально)
    local pointLight = Instance.new("PointLight", bullet)
    pointLight.Brightness = 2
    pointLight.Range = 5
    pointLight.Color = Color3.fromRGB(255, 200, 50)
    Debris:AddItem(pointLight, 0.1)
    
    return bullet
end


-- Функція для перевірки можливості нанесення урону
-- Повертає true, якщо можна нанести урон, та false з причиною, якщо ні
function BulletController:CanDamage(VictimPart)
    -- Перевірка чи існує частина
    if not VictimPart then
        return false, "no_part"
    end
    
    -- Перевірка чи не є частина Accessory (аксесуаром)
    if VictimPart.ClassName == "Accessory" then
        return false, "is_accessory"
    end
    
    if VictimPart.Parent and VictimPart.Parent.ClassName == "Accessory" then
        return false, "parent_is_accessory"
    end
    
    if VictimPart.Parent and VictimPart.Parent.Parent and VictimPart.Parent.Parent.ClassName == "Accessory" then
        return false, "grandparent_is_accessory"
    end
    
    -- Перевірка чи може частина колізії (ігноруємо не колізійні об'єкти)
    if VictimPart.CanCollide == false then
        return false, "no_collision"
    end
    
    -- Перевірка чи не є власником кулі
    if self.owner and VictimPart.Parent and VictimPart.Parent.Name == self.owner.Name then
        return false, "is_owner"
    end
    
    -- Перевірка наявності Humanoid у жертви
    local victimHumanoid = VictimPart.Parent:FindFirstChildOfClass("Humanoid")
    if not victimHumanoid then
        -- Перевіряємо на рівень вище (для випадків коли частина глибше в ієрархії)
        if VictimPart.Parent and VictimPart.Parent.Parent then
            victimHumanoid = VictimPart.Parent.Parent:FindFirstChildOfClass("Humanoid")
        end
    end
    
    if not victimHumanoid then
        return false, "no_humanoid"
    end
    
    -- Перевірка чи жертва жива
    if victimHumanoid.Health <= 0 then
        return false, "already_dead"
    end
    
    -- Перевірка friendly fire (дружнього вогню)
    if not self.friendlyFire then
        -- Перевіряємо команду жертви
        local victimTeam = VictimPart.Parent:FindFirstChild("Team")
        if victimTeam and victimTeam.Value == self.team then
            return false, "friendly_fire_disabled"
        end
        
        -- Альтернативна перевірка через атрибут
        local victimTeamAttribute = VictimPart.Parent:GetAttribute("Team")
        if victimTeamAttribute and victimTeamAttribute == self.team then
            return false, "friendly_fire_disabled"
        end
    end
    
    return true, "can_damage", victimHumanoid
end

-- Функція для підключення нанесення урону до кулі
-- Створює обробник події Touched для кулі
function BulletController:ConnectDamage(bullet, countDamage: number)
    if not bullet then
        warn("[BulletController] Cannot connect damage: bullet is nil")
        return
    end
    
    local damage = countDamage or math.random(10, 50)
    local debounce = false
    
    -- Створюємо обробник події Touched
    local connection
    connection = bullet.Touched:Connect(function(hitPart)
        -- Debounce для уникнення множинних спрацьовань
        if debounce then
            return
        end
        
        -- Перевіряємо чи можна нанести урон
        local canDamage, reason, victimHumanoid = self:CanDamage(hitPart)
        
        if canDamage and victimHumanoid then
            debounce = true
            
            -- Наносимо урон
            victimHumanoid:TakeDamage(damage)
            
            print(string.format("[BulletController] Dealt %d damage to %s (Health: %.1f)", 
                damage, hitPart.Parent.Name, victimHumanoid.Health))
            
            -- Знищуємо кулю
            game:GetService("Debris"):AddItem(bullet, 0.1)
            
            -- Відключаємо з'єднання
            if connection then
                connection:Disconnect()
            end
        elseif reason and reason ~= "no_humanoid" and reason ~= "no_collision" then
            -- Логуємо тільки важливі причини відмови
            if reason == "is_owner" or reason == "friendly_fire_disabled" then
                print("[BulletController] Damage blocked: " .. reason)
            end
        end
    end)
    
    -- Автоматичне знищення кулі через 5 секунд
    Debris:AddItem(bullet, 5)
    
    return connection
end

-- Встановлює власника кулі (для уникнення self-damage)
function BulletController:SetOwner(owner)
    self.owner = owner
end

-- Встановлює команду кулі (для friendly fire перевірки)
function BulletController:SetTeam(teamName)
    self.team = teamName
end

return BulletController
