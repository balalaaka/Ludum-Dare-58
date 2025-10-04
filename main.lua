-- luacheck: globals love love.graphics love.physics love.window love.mouse
-- LOVE2D Physics draggable box example

local world
local box = {}
local walls = {}
local font
local wizardImage
local wizardCastingImage
local wizardGreenImage
local wizardGreenCastingImage
local backgroundImage
local grimoireFont, spellTitleFont, spellDescFont

-- Grimoire system
local grimoireOpen = false
local currentPage = 1
local activeSpellEffects = {} -- Currently active spell effects

-- Spell effect system
local spellEffects = {
	["Become Green"] = {
		normalImage = "wizardGreenImage",
		castingImage = "wizardGreenCastingImage",
		description = "You feel your skin tingling with magical energy as you turn a vibrant shade of green."
	}
	-- Future spells can be added here easily
}

local spells = {
	[1] = {
		name = "Become Green",
		description = "Transform yourself into a vibrant green color, granting camouflage in forest environments.",
		image = "green.png"
	},
	[2] = { name = "???", description = "Hidden beneath the forest temple", image = "???" },
	[3] = { name = "???", description = "Follow us on Twitter to unlock this spell", image = "???" },
	[4] = { name = "???", description = "Available now for owners of 'Spell Collector: Season 1 Pass'", image = "???" }
}
local magicSchool = "Transmutation"
local bookmarks = {"Transmutation", "Evocation", "Abjuration", "Sleep", "Disenchantment"}

local gravityPixelsPerSecond2 = 900 -- positive Y is down in LOVE
local moveForce = 1000 -- force applied by A/D keys
local levitateForce = 5000 -- upward force applied by W key
local linearDamping = 0.5
local isOnGround = false
local groundCheckDistance = 10 -- pixels below box to check for ground
local startX, startY = 0, 0 -- will be set in love.load()
local maxHorizontalSpeed = 400 -- maximum horizontal speed in pixels per second

function love.load()
	love.window.setTitle("Spell Collector")
	font = love.graphics.newFont(16)
	backgroundImage = love.graphics.newImage("gfx/background.jpg")
	wizardImage = love.graphics.newImage("gfx/wizard.png")
	wizardCastingImage = love.graphics.newImage("gfx/wizard_casting.png")
	wizardGreenImage = love.graphics.newImage("gfx/wizard_green.png")
	wizardGreenCastingImage = love.graphics.newImage("gfx/wizard_green_casting.png")
	
	-- Load additional fonts for grimoire
	grimoireFont = love.graphics.newFont(20)
	spellTitleFont = love.graphics.newFont(18)
	spellDescFont = love.graphics.newFont(14)

	world = love.physics.newWorld(0, gravityPixelsPerSecond2, true)

	-- Set global start position
	startX, startY = love.graphics.getWidth() * 0.1, love.graphics.getHeight() * 0.9
	box.body = love.physics.newBody(world, startX, startY, "dynamic")
	box.shape = love.physics.newRectangleShape(40, 80)
	box.fixture = love.physics.newFixture(box.body, box.shape, 1)
	box.fixture:setFriction(1.0)
	box.fixture:setRestitution(1.0)
	box.body:setLinearDamping(linearDamping)
	box.body:setAngularDamping(0)
	box.body:setBullet(true)
	box.color = {0.2, 0.7, 1.0}

	-- Screen walls
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local function createOrUpdateEdge(idx, x1, y1, x2, y2)
		if not walls[idx] then
			walls[idx] = { body = love.physics.newBody(world, 0, 0, "static") }
		else
			if walls[idx].fixture then walls[idx].fixture:destroy() end
		end
		walls[idx].shape = love.physics.newEdgeShape(x1, y1, x2, y2)
		walls[idx].fixture = love.physics.newFixture(walls[idx].body, walls[idx].shape, 0)
		walls[idx].fixture:setFriction(0)
		walls[idx].fixture:setRestitution(1.0)
	end

	local function rebuildWalls(width, height)
		-- Edges exactly at the screen bounds
		createOrUpdateEdge(1, 0, 0, width, 0)          -- top
		createOrUpdateEdge(2, 0, height, width, height) -- bottom
		createOrUpdateEdge(3, 0, 0, 0, height)          -- left
		createOrUpdateEdge(4, width, 0, width, height)  -- right
	end
	walls.rebuild = rebuildWalls
	walls.rebuild(w, h)
end

local function checkGroundContact()
	local bx, by = box.body:getPosition()
	-- Simple ground check - if box is close to bottom wall
	isOnGround = (by + 80 + groundCheckDistance) >= love.graphics.getHeight()
end

local function applyMovementForces()
	local vx, vy = box.body:getLinearVelocity()
	local currentSpeed = math.abs(vx)
	
	-- Horizontal movement with A/D keys (with speed limiting)
	if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
		-- Only apply force if we're not already at max speed in this direction
		if vx > -maxHorizontalSpeed then
			-- Reduce force as we approach max speed
			local speedRatio = math.max(0, (maxHorizontalSpeed + vx) / maxHorizontalSpeed)
			box.body:applyForce(-moveForce * speedRatio, 0)
		end
	end
	if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
		-- Only apply force if we're not already at max speed in this direction
		if vx < maxHorizontalSpeed then
			-- Reduce force as we approach max speed
			local speedRatio = math.max(0, (maxHorizontalSpeed - vx) / maxHorizontalSpeed)
			box.body:applyForce(moveForce * speedRatio, 0)
		end
	end
	
	-- Levitate with W key (only near ground)
	if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
		if isOnGround then
			box.body:applyForce(0, -levitateForce)
		end
	end
end

function love.update(dt)
	world:update(dt)
	checkGroundContact()
	applyMovementForces()
end

local function castSpell(spellName)
	if spellEffects[spellName] then
		activeSpellEffects[spellName] = true
		print("Cast: " .. spellName .. " - " .. spellEffects[spellName].description)
	end
end

local function getCurrentWizardImage(isCasting)
	-- Check for active spell effects in order of priority
	if activeSpellEffects["Become Green"] then
		return isCasting and wizardGreenCastingImage or wizardGreenImage
	end
	
	-- Default wizard images
	return isCasting and wizardCastingImage or wizardImage
end

local function drawWizard()
	local x, y = box.body:getPosition()
	local angle = box.body:getAngle()
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(angle)
	
	-- Determine which image to use based on movement/levitation and active spells
	local isMoving = love.keyboard.isDown("a") or love.keyboard.isDown("d") or 
	                 love.keyboard.isDown("left") or love.keyboard.isDown("right")
	local isLevitating = love.keyboard.isDown("w") or love.keyboard.isDown("up")
	local isCasting = isMoving or isLevitating
	local currentImage = getCurrentWizardImage(isCasting)
	
	-- Get the image dimensions
	local imgW, imgH = currentImage:getDimensions()
	-- Get the physics shape dimensions
	local shape = box.shape
	local x1, y1, x2, y2, x3, y3, x4, y4 = shape:getPoints()
	
	local physicsW = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
	local physicsH = math.sqrt((x3 - x2)^2 + (y3 - y2)^2)
	
	-- Draw the appropriate wizard image centered on the physics body
	love.graphics.setColor(1, 1, 1) -- white tint (no color modification)
	love.graphics.draw(currentImage, 0, 0, 0, physicsW/imgW, physicsH/imgH, imgW/2, imgH/2)
	
	love.graphics.pop()
end

local function isMouseOverSpell(spellIndex, pageX, pageY, pageW, pageH)
	local mx, my = love.mouse.getPosition()
	
	-- Calculate spell position
	local spellW = pageW * 0.45
	local spellH = pageH * 0.35
	local spellSpacing = pageW * 0.05
	local topSpellY = pageY + 80
	
	local col = ((spellIndex - 1) % 2) + 1
	local row = math.floor((spellIndex - 1) / 2) + 1
	local spellX = pageX + spellSpacing + (col - 1) * (spellW + spellSpacing)
	local spellY = topSpellY + (row - 1) * (spellH + 20)
	
	return mx >= spellX and mx <= spellX + spellW and my >= spellY and my <= spellY + spellH
end

local function drawBackground()
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	local imgW, imgH = backgroundImage:getDimensions()
	
	-- Scale the background to cover the entire screen
	local scaleX = screenW / imgW
	local scaleY = screenH / imgH
	
	love.graphics.setColor(1, 1, 1) -- No color tinting
	love.graphics.draw(backgroundImage, 0, 0, 0, scaleX, scaleY)
end

local function drawGrimoire()
	if not grimoireOpen then return end
	
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	local pageW = screenW * 0.8
	local pageH = screenH * 0.8
	local pageX = (screenW - pageW) / 2
	local pageY = (screenH - pageH) / 2
	
	-- Draw page background (parchment-like)
	love.graphics.setColor(0.95, 0.9, 0.8)
	love.graphics.rectangle("fill", pageX, pageY, pageW, pageH, 8, 8)
	
	-- Draw page border
	love.graphics.setColor(0.7, 0.6, 0.4)
	love.graphics.setLineWidth(3)
	love.graphics.rectangle("line", pageX, pageY, pageW, pageH, 8, 8)
	
	-- Draw magic school title at top
	love.graphics.setFont(grimoireFont)
	love.graphics.setColor(0.2, 0.1, 0.0)
	local titleW = grimoireFont:getWidth(magicSchool)
	love.graphics.print(magicSchool, pageX + (pageW - titleW) / 2, pageY + 20)
	
	-- Draw spells in 2x2 grid
	local spellW = pageW * 0.45
	local spellH = pageH * 0.35
	local spellSpacing = pageW * 0.05
	local topSpellY = pageY + 80
	
	for i = 1, 4 do
		local col = ((i - 1) % 2) + 1
		local row = math.floor((i - 1) / 2) + 1
		local spellX = pageX + spellSpacing + (col - 1) * (spellW + spellSpacing)
		local spellY = topSpellY + (row - 1) * (spellH + 20)
		
		local spell = spells[i]
		
		-- Draw spell box with different colors for active/available/unknown spells
		local isActive = activeSpellEffects[spell.name]
		local isAvailable = spell.name ~= "???"
		
		if isActive then
			love.graphics.setColor(0.8, 0.9, 0.8) -- Light green for active spells
		elseif isAvailable then
			love.graphics.setColor(0.9, 0.85, 0.75) -- Normal parchment color
		else
			love.graphics.setColor(0.7, 0.7, 0.7) -- Gray for unknown spells
		end
		love.graphics.rectangle("fill", spellX, spellY, spellW, spellH, 4, 4)
		
		love.graphics.setColor(0.6, 0.5, 0.3)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", spellX, spellY, spellW, spellH, 4, 4)
		
		-- Draw spell name
		love.graphics.setFont(spellTitleFont)
		love.graphics.setColor(0.2, 0.1, 0.0)
		love.graphics.print(spell.name, spellX + 10, spellY + 10)
		
		-- Draw image placeholder
		local imgW, imgH = 60, 60
		local imgX = spellX + 10
		local imgY = spellY + 35
		love.graphics.setColor(0.8, 0.8, 0.8)
		love.graphics.rectangle("fill", imgX, imgY, imgW, imgH)
		love.graphics.setColor(0.5, 0.5, 0.5)
		love.graphics.rectangle("line", imgX, imgY, imgW, imgH)
		
		-- Draw image placeholder text
		love.graphics.setFont(font)
		love.graphics.setColor(0.3, 0.3, 0.3)
		local placeholderW = font:getWidth(spell.image)
		local placeholderH = font:getHeight()
		love.graphics.print(spell.image, imgX + (imgW - placeholderW) / 2, imgY + (imgH - placeholderH) / 2)
		
		-- Draw description
		love.graphics.setFont(spellDescFont)
		love.graphics.setColor(0.3, 0.2, 0.1)
		local descW = spellW - imgW - 30
		local descX = imgX + imgW + 10
		local descY = imgY + 5
		
		-- Word wrap description
		local words = {}
		for word in spell.description:gmatch("%S+") do
			table.insert(words, word)
		end
		
		local line = ""
		local y = descY
		for _, word in ipairs(words) do
			local testLine = line == "" and word or line .. " " .. word
			if spellDescFont:getWidth(testLine) <= descW then
				line = testLine
			else
				if line ~= "" then
					love.graphics.print(line, descX, y)
					y = y + spellDescFont:getHeight() + 2
				end
				line = word
			end
		end
		if line ~= "" then
			love.graphics.print(line, descX, y)
		end
	end
	
	-- Draw bookmarks at bottom
	local bookmarkH = 30
	local bookmarkY = pageY + pageH - bookmarkH - 10
	local bookmarkW = (pageW - 20) / #bookmarks
	
	for i, bookmark in ipairs(bookmarks) do
		local bookmarkX = pageX + 10 + (i - 1) * bookmarkW
		local bookmarkColor = i == currentPage and {0.9, 0.8, 0.6} or {0.8, 0.7, 0.5}
		
		love.graphics.setColor(bookmarkColor)
		love.graphics.rectangle("fill", bookmarkX, bookmarkY, bookmarkW - 2, bookmarkH, 2, 2)
		love.graphics.setColor(0.6, 0.5, 0.3)
		love.graphics.rectangle("line", bookmarkX, bookmarkY, bookmarkW - 2, bookmarkH, 2, 2)
		
		love.graphics.setFont(font)
		love.graphics.setColor(0.2, 0.1, 0.0)
		local textW = font:getWidth(bookmark)
		love.graphics.print(bookmark, bookmarkX + (bookmarkW - textW) / 2, bookmarkY + 8)
	end
end

function love.draw()
	-- Draw background first
	drawBackground()
	
	-- Draw wizard
	drawWizard()
	
	-- Draw grimoire if open
	drawGrimoire()

	-- UI text (only show when grimoire is closed)
	if not grimoireOpen then
		love.graphics.setFont(font)
		love.graphics.setColor(1, 1, 1, 0.85)
		local info = string.format("WASD to move and levitate\nA/D - Move left/right\nW - Levitate (when near ground)\nPress R to reset position\nPress G to open grimoire")
		love.graphics.print(info, 12, 12)
	else
		-- Show grimoire instructions
		love.graphics.setFont(font)
		love.graphics.setColor(1, 1, 1, 0.85)
		love.graphics.print("Press G to close grimoire\nClick spells in grimoire to cast them", 12, 12)
	end
end

function love.keypressed(key)
	if key == "r" then
		box.body:setPosition(startX, startY)
		box.body:setLinearVelocity(0, 0)
		box.body:setAngularVelocity(0)
		box.body:setAngle(0)
	elseif key == "g" then
		grimoireOpen = not grimoireOpen
	end
end

function love.mousepressed(x, y, button)
	if button == 1 and grimoireOpen then -- Left mouse button
		local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
		local pageW = screenW * 0.8
		local pageH = screenH * 0.8
		local pageX = (screenW - pageW) / 2
		local pageY = (screenH - pageH) / 2
		
		-- Check if clicking on any spell
		for i = 1, 4 do
			if isMouseOverSpell(i, pageX, pageY, pageW, pageH) then
				local spell = spells[i]
				if spell.name ~= "???" and spellEffects[spell.name] then
					castSpell(spell.name)
				end
				break
			end
		end
	end
end

function love.resize(w, h)
	if walls and walls.rebuild then
		walls.rebuild(w, h)
	end
end