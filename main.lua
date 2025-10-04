-- Combat Game Variables
local player = {
    health = 100,
    maxHealth = 100,
    damage = 20
}

local enemy = {
    health = 80,
    maxHealth = 80,
    damage = 15
}

local gameState = "playing" -- "playing", "gameOver", "enemyDefeated", or "itemChoice"
local enemyLevel = 1

-- Inventory system
local inventory = {}
local itemAdjectives = {"Ancient", "Mystic", "Blessed", "Cursed", "Radiant", "Dark", "Crystal", "Golden", "Silver", "Iron", "Magic", "Divine", "Infernal", "Frozen", "Burning", "Lightning", "Shadow", "Holy", "Demonic", "Ethereal"}
local itemNouns = {"Sword", "Shield", "Ring", "Amulet", "Potion", "Scroll", "Gem", "Crystal", "Orb", "Staff", "Dagger", "Armor", "Helmet", "Boots", "Gloves", "Belt", "Cape", "Wand", "Book", "Key"}
-- Function to generate description based on item stats
function generateItemDescription(trigger, condition, conditionNumber, effect)
    local desc = ""

    -- Trigger description
    if trigger == "on_attack" then
        desc = desc .. "• on attack\n"
    elseif trigger == "on_block" then
        desc = desc .. "• on block\n"
    end

    -- Condition description
    if condition == "no_condition" then
        desc = desc .. "• always works\n"
    elseif condition == "attack_has_x" then
        desc = desc .. "• when damage contains " .. tostring(conditionNumber) .. "\n"
    elseif condition == "player_health_has_x" then
        desc = desc .. "• when health contains " .. tostring(conditionNumber) .. "\n"
    elseif condition == "enemy_health_has_x" then
        desc = desc .. "• when enemy health contains " .. tostring(conditionNumber) .. "\n"
    end

    -- Effect description (will be updated with random numbers in createRandomItem)
    if effect == "increase_player_damage" then
        desc = desc .. "• damage +X"
    elseif effect == "heal_player" then
        desc = desc .. "• heal by X"
    elseif effect == "decrease_enemy_damage" then
        desc = desc .. "• enemy damage -X"
    end

    return desc
end

-- Item system data
local triggers = {"on_attack", "on_block"}
local conditions = {"no_condition", "attack_has_x", "player_health_has_x", "enemy_health_has_x"}
local effects = {"increase_player_damage", "heal_player", "decrease_enemy_damage"}

-- Mouseover tracking
local mouseX = 0
local mouseY = 0
local hoveredItem = nil

-- Item choice system
local itemChoices = {} -- Array of 3 items to choose from
local choiceBoxes = {} -- UI boxes for the 3 choices

-- Item animation system
local itemAnimations = {} -- Track animations for each inventory item
local attributePopAnimations = {} -- Track pop animations for affected attributes
local pendingItemTriggers = {} -- Queue of triggers to process after animations finish
local itemAnimationPauseTimer = 0 -- Timer for pause after item animations finish

-- Animation system
local animationState = "idle" -- "idle", "playerAttack", "enemyAttack"
local animationTimer = 0
local animationDuration = 0.8 -- How long each animation takes
local playerAttackOffset = 0
local enemyAttackOffset = 0
local damageFlashTimer = 0
local playerDamageApplied = false -- Flag to ensure damage is only applied once
local enemyDamageApplied = false -- Flag to ensure damage is only applied once

-- Animation constants
local GLOBAL_ANIMATION_SPEED = 2.0 -- Global speed multiplier for all animations
local FLOATING_DAMAGE_SPEED = 3 -- Speed of floating damage numbers

-- Floating damage system
local floatingDamages = {} -- Table to store floating damage numbers
local attackBlockText = "" -- Text to show in center ("ATTACK" or "BLOCK")
local attackBlockTimer = 0 -- Timer for attack/block text display

-- Function to add floating damage
function addFloatingDamage(amount, targetX, targetY, startX, startY, damageType)
    table.insert(floatingDamages, {
        amount = amount,
        currentX = startX,
        currentY = startY,
        targetX = targetX,
        targetY = targetY,
        timer = 0,
        duration = 2.0, -- Total duration: 1 second pause + 1 second movement
        pauseDuration = 1.0, -- How long to stay in place before moving
        alpha = 1.0,
        isMoving = false, -- Whether the number has started moving
        damageType = damageType, -- "player" or "enemy"
        damageApplied = false -- Whether damage has been applied when reaching target
    })
end
local attackButton = {
    x = 350,
    y = 450,
    width = 120,
    height = 50,
    text = "ATTACK"
}

local nextEnemyButton = {
    x = 500,
    y = 450,
    width = 120,
    height = 50,
    text = "NEXT ENEMY"
}

-- Function to create a new enemy with stronger stats
function createNewEnemy()
    enemyLevel = enemyLevel + 1
    -- Each enemy is stronger than the last
    enemy.maxHealth = 80 + (enemyLevel - 1) * 20  -- Increases by 20 each level
    enemy.health = enemy.maxHealth
    enemy.damage = 15 + (enemyLevel - 1) * 3      -- Increases by 3 each level
end

-- Function to create a random item
function createRandomItem()
    local adjective = itemAdjectives[math.random(1, #itemAdjectives)]
    local noun = itemNouns[math.random(1, #itemNouns)]

    -- Generate random trigger, condition, and effect
    local trigger = triggers[math.random(1, #triggers)]
    local condition = conditions[math.random(1, #conditions)]
    local effect = effects[math.random(1, #effects)]

    -- Generate random number (0-9) for has_x conditions
    local conditionNumber = nil
    if condition:find("has_x") then
        conditionNumber = math.random(0, 9)
    end

    -- Generate random number (0-9) for effects
    local effectNumber = math.random(0, 9)

    -- Generate description based on stats
    local description = generateItemDescription(trigger, condition, conditionNumber, effect)

    -- Replace X with actual effect number in description
    description = description:gsub("X", tostring(effectNumber))

    return {
        name = adjective .. " " .. noun,
        description = description,
        trigger = trigger,
        condition = condition,
        conditionNumber = conditionNumber, -- Store the random number for has_x conditions
        effect = effect,
        effectNumber = effectNumber, -- Store the random number for effects
        color = {0.8, 0.8, 0.8} -- All items have same gray color
    }
end

-- Function to add random item to inventory
function addRandomItem()
    table.insert(inventory, createRandomItem())
end

-- Function to generate item choices
function generateItemChoices()
    itemChoices = {}
    for i = 1, 3 do
        table.insert(itemChoices, createRandomItem())
    end

    -- Set up choice box positions
    choiceBoxes = {}
    local boxWidth = 200
    local boxHeight = 120
    local spacing = 220
    local startX = 100
    local startY = 200

    for i = 1, 3 do
        table.insert(choiceBoxes, {
            x = startX + (i - 1) * spacing,
            y = startY,
            width = boxWidth,
            height = boxHeight
        })
    end
end

-- Function to check if a condition is met
function checkCondition(condition, conditionNumber)
    if condition == "no_condition" then
        return true
    elseif condition == "attack_has_x" then
        return tostring(player.damage):find(tostring(conditionNumber)) ~= nil
    elseif condition == "player_health_has_x" then
        return tostring(player.health):find(tostring(conditionNumber)) ~= nil
    elseif condition == "enemy_health_has_x" then
        return tostring(enemy.health):find(tostring(conditionNumber)) ~= nil
    end
    return false
end

-- Function to apply an effect
function applyEffect(effect, effectNumber)
    if effect == "increase_player_damage" then
        player.damage = player.damage + effectNumber
    elseif effect == "heal_player" then
        player.health = math.min(player.health + effectNumber, player.maxHealth)
    elseif effect == "decrease_enemy_damage" then
        enemy.damage = math.max(enemy.damage - effectNumber, 1) -- Don't go below 1
    end
end

-- Function to add item animation
function addItemAnimation(itemIndex, animationType, duration)
    itemAnimations[itemIndex] = {
        type = animationType, -- "enlarge", "condition_check", "pop", "shrink"
        timer = 0,
        duration = duration,
        scale = 1.0
    }
end

-- Function to add attribute pop animation
function addAttributePopAnimation(attributeType)
    table.insert(attributePopAnimations, {
        type = attributeType, -- "player_damage", "player_health", "enemy_damage"
        timer = 0,
        duration = 0.3,
        scale = 1.0
    })
end

-- Function to format condition display with actual number
function formatConditionDisplay(condition, conditionNumber)
    if conditionNumber then
        return condition:gsub("_x", "_" .. tostring(conditionNumber))
    else
        return condition
    end
end

-- Function to queue item triggers (to be processed after animations finish)
function queueItemTriggers(triggerType)
    table.insert(pendingItemTriggers, triggerType)
end

-- Function to process queued item triggers with animations
function processItemTriggers(triggerType)
    for i, item in ipairs(inventory) do
        if item.trigger == triggerType then
            -- Start enlarge animation for matching items
            addItemAnimation(i, "enlarge", 0.3)
        end
    end
end

-- Function to process all pending item triggers
function processPendingItemTriggers()
    for _, triggerType in ipairs(pendingItemTriggers) do
        processItemTriggers(triggerType)
    end
    pendingItemTriggers = {} -- Clear the queue
end

-- Function to check conditions with animations
function checkConditionWithAnimation(itemIndex, condition)
    local item = inventory[itemIndex]
    if not item then return false end

    -- Start condition check animation
    itemAnimations[itemIndex].type = "condition_check"
    itemAnimations[itemIndex].timer = 0
    itemAnimations[itemIndex].duration = 0.2

    local result = checkCondition(condition, item.conditionNumber)

    if result then
        -- Condition passed - start pop animation
        itemAnimations[itemIndex].type = "pop"
        itemAnimations[itemIndex].timer = 0
        itemAnimations[itemIndex].duration = 0.4

        -- Apply effect and add attribute pop
        applyEffectWithAnimation(item.effect, item.effectNumber)
    else
        -- Condition failed - start shrink animation
        itemAnimations[itemIndex].type = "shrink"
        itemAnimations[itemIndex].timer = 0
        itemAnimations[itemIndex].duration = 0.3
    end

    return result
end

-- Function to apply effect with animation
function applyEffectWithAnimation(effect, effectNumber)
    if effect == "increase_player_damage" then
        player.damage = player.damage + effectNumber
        addAttributePopAnimation("player_damage")
    elseif effect == "heal_player" then
        player.health = math.min(player.health + effectNumber, player.maxHealth)
        addAttributePopAnimation("player_health")
    elseif effect == "decrease_enemy_damage" then
        enemy.damage = math.max(enemy.damage - effectNumber, 1)
        addAttributePopAnimation("enemy_damage")
    end
end

-- Initialize the game
function love.load()
    love.window.setTitle("Combat Game")
    love.graphics.setFont(love.graphics.newFont(16))

    -- Seed random number generator for true randomness
    math.randomseed(os.time())

    -- Start with 1 random item
    addRandomItem()
end

-- Handle mouse movement
function love.mousemoved(x, y)
    mouseX = x
    mouseY = y

    -- Check if mouse is over any inventory item box
    hoveredItem = nil
    local boxSize = 60
    local boxSpacing = 70
    local itemsPerRow = 3

    for i, item in ipairs(inventory) do
        local row = math.floor((i - 1) / itemsPerRow)
        local col = (i - 1) % itemsPerRow
        local boxX = 50 + col * boxSpacing
        local boxY = 520 + row * boxSpacing

        -- Check if mouse is within this item box
        if x >= boxX and x <= boxX + boxSize and y >= boxY and y <= boxY + boxSize then
            hoveredItem = item
            break
        end
    end
end

-- Update game logic
function love.update(dt)
    -- Apply global animation speed to delta time
    local adjustedDt = dt * GLOBAL_ANIMATION_SPEED

    -- Update animation timer
    if animationState ~= "idle" then
        animationTimer = animationTimer + adjustedDt

        -- Handle different animation phases
        if animationState == "playerAttack" then
            -- Player attack animation: move forward then back
            if animationTimer < animationDuration * 0.3 then
                playerAttackOffset = (animationTimer / (animationDuration * 0.3)) * 30
            elseif animationTimer < animationDuration * 0.6 then
                playerAttackOffset = 30 - ((animationTimer - animationDuration * 0.3) / (animationDuration * 0.3)) * 30
            else
                playerAttackOffset = 0
            end

            -- Player attack animation continues (damage applied when floating number reaches target)

            -- Start enemy attack after player damage number has had time to pause and move
            if animationTimer >= animationDuration + 1.5 then -- Wait for damage number to pause (1 sec) and move (0.5 sec)
                -- Process player attack item triggers first (only attack triggers, not block triggers)
                if #pendingItemTriggers > 0 then
                    -- Only process attack triggers, not block triggers
                    local attackTriggers = {}
                    for _, triggerType in ipairs(pendingItemTriggers) do
                        if triggerType == "on_attack" then
                            table.insert(attackTriggers, triggerType)
                        end
                    end
                    -- Process only attack triggers
                    for _, triggerType in ipairs(attackTriggers) do
                        processItemTriggers(triggerType)
                    end
                    -- Remove processed attack triggers from pending list
                    local newPending = {}
                    for _, triggerType in ipairs(pendingItemTriggers) do
                        if triggerType ~= "on_attack" then
                            table.insert(newPending, triggerType)
                        end
                    end
                    pendingItemTriggers = newPending
                end
            end

            -- Start pause timer when item animations finish
            if animationTimer >= animationDuration + 1.5 and #itemAnimations == 0 and itemAnimationPauseTimer == 0 then
                itemAnimationPauseTimer = 0.5 -- 0.5 second pause after item animations finish
            end

            -- Update pause timer
            if itemAnimationPauseTimer > 0 then
                itemAnimationPauseTimer = itemAnimationPauseTimer - adjustedDt
            end

            -- Start enemy attack only after item animations finish AND pause is complete
            if animationTimer >= animationDuration + 1.5 and #itemAnimations == 0 and itemAnimationPauseTimer <= 0 then
                animationState = "enemyAttack"
                animationTimer = 0
                enemyDamageApplied = false -- Reset enemy damage flag
                itemAnimationPauseTimer = 0 -- Reset pause timer

                -- Queue item triggers for block (will process after animation finishes)
                queueItemTriggers("on_block")

                -- Show block text and damage number for enemy counter-attack
                attackBlockText = "BLOCK"
                attackBlockTimer = 0.5

                addFloatingDamage(enemy.damage, 260, 145, 400, 250, "enemy") -- Move to player health bar
            end
        elseif animationState == "enemyAttack" then
            -- Enemy attack animation: move forward then back
            if animationTimer < animationDuration * 0.3 then
                enemyAttackOffset = (animationTimer / (animationDuration * 0.3)) * 30
            elseif animationTimer < animationDuration * 0.6 then
                enemyAttackOffset = 30 - ((animationTimer - animationDuration * 0.3) / (animationDuration * 0.3)) * 30
            else
                enemyAttackOffset = 0
            end

            -- End enemy attack animation
            if animationTimer >= animationDuration then
                animationState = "idle"
                animationTimer = 0
                -- Process block item triggers after enemy attack finishes (only block triggers)
                if #pendingItemTriggers > 0 then
                    -- Only process block triggers
                    local blockTriggers = {}
                    for _, triggerType in ipairs(pendingItemTriggers) do
                        if triggerType == "on_block" then
                            table.insert(blockTriggers, triggerType)
                        end
                    end
                    -- Process only block triggers
                    for _, triggerType in ipairs(blockTriggers) do
                        processItemTriggers(triggerType)
                    end
                    -- Remove processed block triggers from pending list
                    local newPending = {}
                    for _, triggerType in ipairs(pendingItemTriggers) do
                        if triggerType ~= "on_block" then
                            table.insert(newPending, triggerType)
                        end
                    end
                    pendingItemTriggers = newPending
                end
            end
        end
    end

    -- Update damage flash effect
    if damageFlashTimer > 0 then
        damageFlashTimer = damageFlashTimer - dt
    end

    -- Update floating damages
    for i = #floatingDamages, 1, -1 do
        local damage = floatingDamages[i]
        damage.timer = damage.timer + adjustedDt

        -- Check if pause period is over and start moving
        if damage.timer >= damage.pauseDuration and not damage.isMoving then
            damage.isMoving = true
        end

        local progress = damage.timer / damage.duration
        if progress < 1 then
            -- Only move if the pause period is over
            if damage.isMoving then
                -- Move towards target
                damage.currentX = damage.currentX + (damage.targetX - damage.currentX) * adjustedDt * FLOATING_DAMAGE_SPEED
                damage.currentY = damage.currentY + (damage.targetY - damage.currentY) * adjustedDt * FLOATING_DAMAGE_SPEED

                -- Apply damage when close to target (within 30 pixels)
                local distanceToTarget = math.sqrt((damage.currentX - damage.targetX)^2 + (damage.currentY - damage.targetY)^2)
                if distanceToTarget < 30 and not damage.damageApplied then
                    damage.damageApplied = true
                    if damage.damageType == "player" then
                        -- Player damage to enemy (when player damage number reaches enemy health bar)
                        enemy.health = enemy.health - damage.amount
                        damageFlashTimer = 0.3
                        -- Check if enemy is dead
                        if enemy.health <= 0 then
                            gameState = "itemChoice"
                            animationState = "idle"
                            -- Process any remaining pending item triggers after animations finish
                            if #pendingItemTriggers > 0 then
                                processPendingItemTriggers()
                            end
                            -- Generate item choices for player to pick from
                            generateItemChoices()
                        end
                    elseif damage.damageType == "enemy" then
                        -- Enemy damage to player (when enemy damage number reaches player health bar)
                        player.health = player.health - damage.amount
                        damageFlashTimer = 0.6
                        -- Check if player is dead
                        if player.health <= 0 then
                            gameState = "gameOver"
                            animationState = "idle"
                        end
                    end
                end
            end

            -- Fade out only during movement phase
            if damage.isMoving then
                local movementProgress = (damage.timer - damage.pauseDuration) / (damage.duration - damage.pauseDuration)
                damage.alpha = 1 - movementProgress
            end
        else
            -- Remove completed damage
            table.remove(floatingDamages, i)
        end
    end

    -- Update attack/block text timer
    if attackBlockTimer > 0 then
        attackBlockTimer = attackBlockTimer - adjustedDt
        if attackBlockTimer <= 0 then
            attackBlockText = ""
        end
    end

    -- Update item animations
    for i, anim in pairs(itemAnimations) do
        anim.timer = anim.timer + adjustedDt
        local progress = anim.timer / anim.duration

        if anim.type == "enlarge" then
            anim.scale = 1.0 + (progress * 0.3) -- Grow to 1.3x size
            if progress >= 1 then
                -- Start condition check for this item
                local item = inventory[i]
                if item then
                    checkConditionWithAnimation(i, item.condition)
                end
            end
        elseif anim.type == "condition_check" then
            anim.scale = 1.3 -- Stay enlarged during condition check
            if progress >= 1 then
                -- Condition check complete, animation handled by checkConditionWithAnimation
            end
        elseif anim.type == "pop" then
            if progress < 0.5 then
                -- Quick increase
                anim.scale = 1.3 + (progress * 2 * 0.4) -- Grow to 1.7x
            else
                -- Quick decrease
                local shrinkProgress = (progress - 0.5) * 2
                anim.scale = 1.7 - (shrinkProgress * 0.7) -- Shrink back to 1.0
            end
            if progress >= 1 then
                itemAnimations[i] = nil -- Remove animation
            end
        elseif anim.type == "shrink" then
            anim.scale = 1.3 - (progress * 0.3) -- Shrink back to 1.0
            if progress >= 1 then
                itemAnimations[i] = nil -- Remove animation
            end
        end
    end

    -- Update attribute pop animations
    for i = #attributePopAnimations, 1, -1 do
        local anim = attributePopAnimations[i]
        anim.timer = anim.timer + adjustedDt
        local progress = anim.timer / anim.duration

        if progress < 0.5 then
            -- Quick increase
            anim.scale = 1.0 + (progress * 2 * 0.5) -- Grow to 1.5x
        else
            -- Quick decrease
            local shrinkProgress = (progress - 0.5) * 2
            anim.scale = 1.5 - (shrinkProgress * 0.5) -- Shrink back to 1.0
        end

        if progress >= 1 then
            table.remove(attributePopAnimations, i)
        end
    end
end

-- Handle mouse clicks
function love.mousepressed(x, y, button_pressed)
    if gameState == "gameOver" then
        -- Restart game
        player.health = player.maxHealth
        player.damage = 20 -- Reset player damage to base value
        enemyLevel = 1
        -- Reset enemy to first level stats
        enemy.maxHealth = 80
        enemy.health = enemy.maxHealth
        enemy.damage = 15
        -- Clear inventory
        inventory = {}
        gameState = "playing"
    elseif gameState == "itemChoice" and button_pressed == 1 then
        -- Check if click is on any of the choice boxes
        for i, box in ipairs(choiceBoxes) do
            if x >= box.x and x <= box.x + box.width and
               y >= box.y and y <= box.y + box.height then
                -- Add selected item to inventory
                table.insert(inventory, itemChoices[i])

                -- Heal player to full HP and create new enemy
                player.health = player.maxHealth
                createNewEnemy()
                gameState = "playing"
                break
            end
        end
    elseif gameState == "playing" and button_pressed == 1 and animationState == "idle" then -- Left mouse button, only when not animating
        -- Check if click is on attack button
        if x >= attackButton.x and x <= attackButton.x + attackButton.width and
           y >= attackButton.y and y <= attackButton.y + attackButton.height then
            -- Start player attack animation
            animationState = "playerAttack"
            animationTimer = 0
            playerAttackOffset = 0
            enemyAttackOffset = 0

            -- Queue item triggers for attack (will process after animation finishes)
            queueItemTriggers("on_attack")
            playerDamageApplied = false -- Reset damage flag
            enemyDamageApplied = false -- Reset damage flag

            -- Show attack text and damage number immediately
            attackBlockText = "ATTACK"
            attackBlockTimer = 0.5

            -- Item triggers will be queued when animation actually starts

            -- Add floating damage number immediately (but don't apply damage yet)
            addFloatingDamage(player.damage, 760, 145, 400, 250, "player") -- Move to enemy health bar
        end
    end
end

-- Draw everything
function love.draw()
    -- Clear screen with dark background
    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Set white color for text and UI
    love.graphics.setColor(1, 1, 1)

    -- Draw title
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf("COMBAT GAME", 0, 50, love.graphics.getWidth(), "center")

    -- Draw enemy level
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("Enemy Level: " .. enemyLevel, 0, 80, love.graphics.getWidth(), "center")

    -- Draw player health bar (left side)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.print("PLAYER HEALTH:", 50, 120)
    -- Check for player health pop animation
    local playerHealthScale = 1.0
    for _, anim in ipairs(attributePopAnimations) do
        if anim.type == "player_health" then
            playerHealthScale = anim.scale
            break
        end
    end

    love.graphics.setColor(0.8, 0.2, 0.2) -- Red for health bar background
    love.graphics.rectangle("fill", 50, 140, 200 * playerHealthScale, 20 * playerHealthScale)
    love.graphics.setColor(0.2, 0.8, 0.2) -- Green for current health
    local playerHealthRatio = player.health / player.maxHealth
    love.graphics.rectangle("fill", 50, 140, 200 * playerHealthRatio * playerHealthScale, 20 * playerHealthScale)
    love.graphics.setColor(1, 1, 1) -- White for text
    love.graphics.setFont(love.graphics.newFont(16 * playerHealthScale))
    love.graphics.print(player.health .. "/" .. player.maxHealth, 260, 145)
    love.graphics.setFont(love.graphics.newFont(16)) -- Reset font

    -- Draw player damage with pop animation
    local playerDamageScale = 1.0
    for _, anim in ipairs(attributePopAnimations) do
        if anim.type == "player_damage" then
            playerDamageScale = anim.scale
            break
        end
    end
    love.graphics.setFont(love.graphics.newFont(16 * playerDamageScale))
    love.graphics.print("Damage: " .. player.damage, 50, 170)
    love.graphics.setFont(love.graphics.newFont(16)) -- Reset font

    -- Draw inventory
    love.graphics.print("INVENTORY:", 50, 500)
    local boxSize = 60
    local boxSpacing = 70
    local itemsPerRow = 3

    for i, item in ipairs(inventory) do
        local row = math.floor((i - 1) / itemsPerRow)
        local col = (i - 1) % itemsPerRow
        local boxX = 50 + col * boxSpacing
        local boxY = 520 + row * boxSpacing

        -- Get animation scale for this item
        local scale = 1.0
        if itemAnimations[i] then
            scale = itemAnimations[i].scale
        end

        -- Calculate scaled position and size
        local scaledSize = boxSize * scale
        local offsetX = (scaledSize - boxSize) / 2
        local offsetY = (scaledSize - boxSize) / 2

        -- Draw item box with animation scale
        love.graphics.setColor(0.3, 0.3, 0.3) -- Dark gray background
        love.graphics.rectangle("fill", boxX - offsetX, boxY - offsetY, scaledSize, scaledSize)

        -- Draw box border
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.rectangle("line", boxX - offsetX, boxY - offsetY, scaledSize, scaledSize)

        -- Draw item name (centered in box) with smaller font
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(12)) -- Smaller font for item names
        love.graphics.printf(item.name, boxX + 2, boxY + boxSize/2 - 6, boxSize - 4, "center")
        love.graphics.setFont(love.graphics.newFont(16)) -- Reset to default font
    end
    love.graphics.setColor(1, 1, 1) -- Reset to white


    -- Draw enemy health bar (right side)
    love.graphics.print("ENEMY HEALTH:", 550, 120)

    -- Check for enemy health pop animation (currently no effects target enemy health, but ready for future)
    local enemyHealthScale = 1.0
    for _, anim in ipairs(attributePopAnimations) do
        if anim.type == "enemy_health" then
            enemyHealthScale = anim.scale
            break
        end
    end

    love.graphics.setColor(0.8, 0.2, 0.2) -- Red for health bar background
    love.graphics.rectangle("fill", 550, 140, 200 * enemyHealthScale, 20 * enemyHealthScale)
    love.graphics.setColor(0.2, 0.8, 0.2) -- Green for current health
    local enemyHealthRatio = enemy.health / enemy.maxHealth
    love.graphics.rectangle("fill", 550, 140, 200 * enemyHealthRatio * enemyHealthScale, 20 * enemyHealthScale)
    love.graphics.setColor(1, 1, 1) -- White for text
    love.graphics.setFont(love.graphics.newFont(16 * enemyHealthScale))
    love.graphics.print(enemy.health .. "/" .. enemy.maxHealth, 760, 145)
    love.graphics.setFont(love.graphics.newFont(16)) -- Reset font

    -- Draw enemy damage with pop animation
    local enemyDamageScale = 1.0
    for _, anim in ipairs(attributePopAnimations) do
        if anim.type == "enemy_damage" then
            enemyDamageScale = anim.scale
            break
        end
    end
    love.graphics.setFont(love.graphics.newFont(16 * enemyDamageScale))
    love.graphics.print("Damage: " .. enemy.damage, 550, 170)
    love.graphics.setFont(love.graphics.newFont(16)) -- Reset font

    -- Draw characters with animations
    local playerX = 150 + playerAttackOffset
    local enemyX = 650 - enemyAttackOffset

    -- Draw player character
    love.graphics.setColor(0.2, 0.6, 1.0) -- Blue player
    if damageFlashTimer > 0.3 and damageFlashTimer < 0.6 then
        love.graphics.setColor(1.0, 0.2, 0.2) -- Red flash when taking damage
    end
    love.graphics.rectangle("fill", playerX, 250, 50, 70)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("YOU", playerX + 10, 275)

    -- Draw enemy character
    love.graphics.setColor(1.0, 0.2, 0.2) -- Red enemy
    if damageFlashTimer > 0 and damageFlashTimer <= 0.3 then
        love.graphics.setColor(1.0, 1.0, 0.2) -- Yellow flash when taking damage
    end
    love.graphics.rectangle("fill", enemyX, 250, 50, 70)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("ENEMY", enemyX - 10, 275)

    -- Draw attack/block text in center
    if attackBlockText ~= "" then
        love.graphics.setFont(love.graphics.newFont(32))
        if attackBlockText == "ATTACK" then
            love.graphics.setColor(1.0, 0.8, 0.0) -- Gold for attack
        else
            love.graphics.setColor(0.8, 0.2, 0.2) -- Red for block
        end
        love.graphics.printf(attackBlockText, 0, 200, love.graphics.getWidth(), "center")
        love.graphics.setFont(love.graphics.newFont(16)) -- Reset font
    end

    -- Draw floating damage numbers
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.setColor(1, 1, 0) -- Yellow damage numbers
    for _, damage in ipairs(floatingDamages) do
        love.graphics.setColor(1, 1, 0, damage.alpha) -- Yellow with alpha
        love.graphics.print("-" .. damage.amount, damage.currentX, damage.currentY)
    end
    love.graphics.setFont(love.graphics.newFont(16)) -- Reset font

    if gameState == "playing" then
        -- Draw attack button (disabled during animations)
        if animationState == "idle" then
            love.graphics.setColor(0.3, 0.6, 0.9) -- Blue button
        else
            love.graphics.setColor(0.5, 0.5, 0.5) -- Grey when disabled
        end
        love.graphics.rectangle("fill", attackButton.x, attackButton.y, attackButton.width, attackButton.height)

        if animationState == "idle" then
            love.graphics.setColor(1, 1, 1) -- White text
        else
            love.graphics.setColor(0.7, 0.7, 0.7) -- Grey text when disabled
        end
        love.graphics.printf(attackButton.text, attackButton.x, attackButton.y + 15, attackButton.width, "center")

        -- Draw turn indicator and instructions
        love.graphics.setColor(0.8, 0.8, 0.8)
        if animationState == "idle" then
            love.graphics.printf("Your turn - Click ATTACK to fight!", 0, 380, love.graphics.getWidth(), "center")
        elseif animationState == "playerAttack" then
            love.graphics.printf("You are attacking...", 0, 380, love.graphics.getWidth(), "center")
        elseif animationState == "enemyAttack" then
            love.graphics.printf("Enemy is attacking...", 0, 380, love.graphics.getWidth(), "center")
        end
    elseif gameState == "enemyDefeated" then
        -- Draw greyed out attack button
        love.graphics.setColor(0.5, 0.5, 0.5) -- Grey button
        love.graphics.rectangle("fill", attackButton.x, attackButton.y, attackButton.width, attackButton.height)
        love.graphics.setColor(0.7, 0.7, 0.7) -- Grey text
        love.graphics.printf(attackButton.text, attackButton.x, attackButton.y + 15, attackButton.width, "center")

        -- Draw next enemy button
        love.graphics.setColor(0.9, 0.6, 0.2) -- Orange button
        love.graphics.rectangle("fill", nextEnemyButton.x, nextEnemyButton.y, nextEnemyButton.width, nextEnemyButton.height)
        love.graphics.setColor(1, 1, 1) -- White text
        love.graphics.printf(nextEnemyButton.text, nextEnemyButton.x, nextEnemyButton.y + 15, nextEnemyButton.width, "center")

        -- Draw victory message
        love.graphics.setColor(0.2, 0.9, 0.2)
        love.graphics.print("ENEMY DEFEATED!", 50, 350)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Click NEXT ENEMY to continue", 50, 370)
    elseif gameState == "itemChoice" then
        -- Draw item choice screen
        love.graphics.setFont(love.graphics.newFont(24))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Choose an Item!", 0, 100, love.graphics.getWidth(), "center")

        -- Draw choice boxes
        for i, box in ipairs(choiceBoxes) do
            local item = itemChoices[i]

            -- Draw box background
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)

            -- Draw box border
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.rectangle("line", box.x, box.y, box.width, box.height)

            -- Draw item name
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(love.graphics.newFont(16))
            love.graphics.printf(item.name, box.x + 5, box.y + 5, box.width - 10, "center")

            -- Draw simplified description
            love.graphics.setFont(love.graphics.newFont(12))
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf(item.description, box.x + 5, box.y + 30, box.width - 10, "left")

        end

        -- Draw instruction
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf("Click on an item to choose it", 0, 350, love.graphics.getWidth(), "center")
    else
        -- Game Over screen
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.printf("GAME OVER", 0, 300, love.graphics.getWidth(), "center")

        love.graphics.setFont(love.graphics.newFont(18))
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf("Click anywhere to restart", 0, 350, love.graphics.getWidth(), "center")
    end

    -- Draw item description tooltip on top of everything (anchored to bottom left)
    if hoveredItem then
        -- Draw background box
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        local descWidth = 300
        local descHeight = 100
        local boxX = mouseX + 10
        local boxY = mouseY - descHeight - 10 -- Position above mouse cursor
        love.graphics.rectangle("fill", boxX, boxY, descWidth, descHeight)

        -- Draw border
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("line", boxX, boxY, descWidth, descHeight)

        -- Draw item name
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(hoveredItem.name, boxX + 5, boxY + 5)

        -- Draw simple description
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf(hoveredItem.description, boxX + 5, boxY + 25, descWidth - 10, "left")
    end
end
