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

local gameState = "playing" -- "playing", "gameOver", or "enemyDefeated"
local enemyLevel = 1

-- Animation system
local animationState = "idle" -- "idle", "playerAttack", "enemyAttack"
local animationTimer = 0
local animationDuration = 0.8 -- How long each animation takes
local playerAttackOffset = 0
local enemyAttackOffset = 0
local damageFlashTimer = 0
local playerDamageApplied = false -- Flag to ensure damage is only applied once
local enemyDamageApplied = false -- Flag to ensure damage is only applied once

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

-- Initialize the game
function love.load()
    love.window.setTitle("Combat Game")
    love.graphics.setFont(love.graphics.newFont(16))
end

-- Update game logic
function love.update(dt)
    -- Update animation timer
    if animationState ~= "idle" then
        animationTimer = animationTimer + dt

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
                animationState = "enemyAttack"
                animationTimer = 0
                enemyDamageApplied = false -- Reset enemy damage flag
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
        damage.timer = damage.timer + dt

        -- Check if pause period is over and start moving
        if damage.timer >= damage.pauseDuration and not damage.isMoving then
            damage.isMoving = true
        end

        local progress = damage.timer / damage.duration
        if progress < 1 then
            -- Only move if the pause period is over
            if damage.isMoving then
                -- Move towards target
                damage.currentX = damage.currentX + (damage.targetX - damage.currentX) * dt * 3
                damage.currentY = damage.currentY + (damage.targetY - damage.currentY) * dt * 3

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
                            gameState = "enemyDefeated"
                            animationState = "idle"
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
        attackBlockTimer = attackBlockTimer - dt
        if attackBlockTimer <= 0 then
            attackBlockText = ""
        end
    end
end

-- Handle mouse clicks
function love.mousepressed(x, y, button_pressed)
    if gameState == "gameOver" then
        -- Restart game
        player.health = player.maxHealth
        enemyLevel = 1
        -- Reset enemy to first level stats
        enemy.maxHealth = 80
        enemy.health = enemy.maxHealth
        enemy.damage = 15
        gameState = "playing"
    elseif gameState == "enemyDefeated" and button_pressed == 1 then
        -- Check if click is on next enemy button
        if x >= nextEnemyButton.x and x <= nextEnemyButton.x + nextEnemyButton.width and
           y >= nextEnemyButton.y and y <= nextEnemyButton.y + nextEnemyButton.height then
            -- Heal player to full HP
            player.health = player.maxHealth
            -- Create new enemy
            createNewEnemy()
            gameState = "playing"
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
            playerDamageApplied = false -- Reset damage flag
            enemyDamageApplied = false -- Reset damage flag

            -- Show attack text and damage number immediately
            attackBlockText = "ATTACK"
            attackBlockTimer = 0.5

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
    love.graphics.setColor(0.8, 0.2, 0.2) -- Red for health bar background
    love.graphics.rectangle("fill", 50, 140, 200, 20)
    love.graphics.setColor(0.2, 0.8, 0.2) -- Green for current health
    local playerHealthRatio = player.health / player.maxHealth
    love.graphics.rectangle("fill", 50, 140, 200 * playerHealthRatio, 20)
    love.graphics.setColor(1, 1, 1) -- White for text
    love.graphics.print(player.health .. "/" .. player.maxHealth, 260, 145)

    -- Draw player damage
    love.graphics.print("Damage: " .. player.damage, 50, 170)

    -- Draw enemy health bar (right side)
    love.graphics.print("ENEMY HEALTH:", 550, 120)
    love.graphics.setColor(0.8, 0.2, 0.2) -- Red for health bar background
    love.graphics.rectangle("fill", 550, 140, 200, 20)
    love.graphics.setColor(0.2, 0.8, 0.2) -- Green for current health
    local enemyHealthRatio = enemy.health / enemy.maxHealth
    love.graphics.rectangle("fill", 550, 140, 200 * enemyHealthRatio, 20)
    love.graphics.setColor(1, 1, 1) -- White for text
    love.graphics.print(enemy.health .. "/" .. enemy.maxHealth, 760, 145)

    -- Draw enemy damage
    love.graphics.print("Damage: " .. enemy.damage, 550, 170)

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
    else
        -- Game Over screen
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.printf("GAME OVER", 0, 300, love.graphics.getWidth(), "center")

        love.graphics.setFont(love.graphics.newFont(18))
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf("Click anywhere to restart", 0, 350, love.graphics.getWidth(), "center")
    end
end
