-- luacheck: globals love love.graphics love.physics love.window love.mouse
-- Spell Collector - Main Game File

-- Import modules
local Render = require("render")
local Spellbook = require("spellbook")

local world
local player = {}
local walls = {}
local staticBoxes = {} -- Array to store static boxes
local font
local wizardImage
local wizardCastingImage
local wizardGreenImage
local wizardGreenCastingImage
local backgroundImage
local grimoireFont, spellTitleFont, spellDescFont

local gravityPixelsPerSecond2 = 900 -- positive Y is down in LOVE
local moveForce = 1000 -- force applied by A/D keys
local levitateForce = 5000 -- upward force applied by W key
local linearDamping = 0.5
local playerWidth = 150
local playerHeight = 150
local isOnGround = false
local groundCheckDistance = 100 -- pixels below box to check for ground
local raycastResult = nil

local raycastCallback = function(fixture, x, y, xn, yn, fraction)
	local body = fixture:getBody()
	local bodyType = body:getType()
	
	-- Check if the fixture belongs to a static body (ground or static box)
	if bodyType == "static" then
		-- Store the closest fraction found (0 = closest to ray start)
		if raycastResult == nil or fraction < raycastResult then
			raycastResult = fraction
		end
	end
	
	-- Continue raycast to find the closest hit
	return -1
end

local startX, startY = 0, 0 -- will be set in love.load()
local maxHorizontalSpeed = 400 -- maximum horizontal speed in pixels per second


-- Function to create a static immovable box
-- x, y are top-left coordinates (not center)
local function createStaticBox(x, y, width, height)
	local staticBox = {}
		-- Convert top-left coordinates to center coordinates for physics body
	local centerX = x + width / 2
	local centerY = y + height / 2
	staticBox.body = love.physics.newBody(world, centerX, centerY, "static")
	staticBox.shape = love.physics.newRectangleShape(width, height)
	staticBox.fixture = love.physics.newFixture(staticBox.body, staticBox.shape, 0)
	staticBox.fixture:setFriction(0)
	staticBox.fixture:setRestitution(0)
	staticBox.width = width
	staticBox.height = height
	staticBox.color = {0.6, 0.4, 0.2} -- Brown color for boxes
	
	table.insert(staticBoxes, staticBox)
	return staticBox
end

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
	
	-- Initialize modules
	Spellbook.init()
	
	-- Set up render module with global references
	Render.setGlobals({
		player = player,
		staticBoxes = staticBoxes,
		wizardImage = wizardImage,
		wizardCastingImage = wizardCastingImage,
		wizardGreenImage = wizardGreenImage,
		wizardGreenCastingImage = wizardGreenCastingImage,
		backgroundImage = backgroundImage,
		font = font,
		grimoireFont = grimoireFont,
		spellTitleFont = spellTitleFont,
		spellDescFont = spellDescFont,
		isOnGround = isOnGround,
		grimoireOpen = function() return Spellbook.isGrimoireOpen() end,
		currentPage = function() return Spellbook.getCurrentPage() end,
		spells = function() return Spellbook.getSpells() end,
		activeSpellEffects = function() return Spellbook.getActiveSpellEffects() end,
		magicSchool = function() return Spellbook.getMagicSchool() end,
		bookmarks = function() return Spellbook.getBookmarks() end
	})

	world = love.physics.newWorld(0, gravityPixelsPerSecond2, true)

	-- Set global start position
	startX, startY = love.graphics.getWidth() * 0.1, love.graphics.getHeight() * 0.9
	player.body = love.physics.newBody(world, startX, startY, "dynamic")
	player.shape = love.physics.newRectangleShape(playerWidth, playerHeight)
	player.fixture = love.physics.newFixture(player.body, player.shape, 1)
	player.fixture:setFriction(1.0)
	player.fixture:setRestitution(0.6)
	player.body:setLinearDamping(linearDamping)
	player.body:setAngularDamping(0)
	player.body:setBullet(true)
	player.color = {0.2, 0.7, 1.0}

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
		walls[idx].fixture:setRestitution(0)
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
	
	-- Create some example static boxes (using top-left coordinates)
	createStaticBox(w * 0.3 - 40, h * 0.95 - 30, 80, 60) -- Box on the left side
	createStaticBox(w * 0.4 - 60, h * 0.90 - 40, 120, 80) -- Box on the right side
end

local function checkGroundContact()
	local px, py = player.body:getPosition()
	
	-- Cast a ray downward from the center of the player
	local rayStartX = px
	local rayStartY = py
	local rayEndX = px
	local rayEndY = py + groundCheckDistance
	
	-- Reset raycast result before performing raycast
	raycastResult = nil
	
	-- Perform the raycast
	world:rayCast(rayStartX, rayStartY, rayEndX, rayEndY, raycastCallback)
	
	-- If we hit something within the ground check distance, we're on ground
	isOnGround = raycastResult ~= nil and raycastResult <= 1.0
	
	-- Fallback: check if close to bottom wall
	if not isOnGround then
		isOnGround = (py + groundCheckDistance) >= love.graphics.getHeight()
	end
end

local function applyMovementForces()
	local vx, vy = player.body:getLinearVelocity()
	local currentSpeed = math.abs(vx)
	
	-- Horizontal movement with A/D keys (with speed limiting)
	if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
		-- Only apply force if we're not already at max speed in this direction
		if vx > -maxHorizontalSpeed then
			-- Reduce force as we approach max speed
			local speedRatio = math.max(0, (maxHorizontalSpeed + vx) / maxHorizontalSpeed)
			player.body:applyForce(-moveForce * speedRatio, 0)
		end
	end
	if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
		-- Only apply force if we're not already at max speed in this direction
		if vx < maxHorizontalSpeed then
			-- Reduce force as we approach max speed
			local speedRatio = math.max(0, (maxHorizontalSpeed - vx) / maxHorizontalSpeed)
			player.body:applyForce(moveForce * speedRatio, 0)
		end
	end
	
	-- Levitate with W key (only near ground)
	if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
		if isOnGround then
			player.body:applyForce(0, -levitateForce)
		end
	end
end

function love.update(dt)
	world:update(dt)
	checkGroundContact()
	applyMovementForces()
end

function love.draw()
	Render.draw()
end

function love.keypressed(key)
	if key == "r" then
		player.body:setPosition(startX, startY)
		player.body:setLinearVelocity(0, 0)
		player.body:setAngularVelocity(0)
		player.body:setAngle(0)
	elseif key == "g" then
		Spellbook.toggleGrimoire()
	end
end

-- Check if mouse is over a spell in the grimoire
local function isMouseOverSpell(spellIndex)
	if not Spellbook.isGrimoireOpen() then return false end
	
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	local pageW = screenW * 0.8
	local pageH = screenH * 0.8
	local pageX = (screenW - pageW) / 2
	local pageY = (screenH - pageH) / 2
	
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

function love.mousepressed(x, y, button)
	if button == 1 and Spellbook.isGrimoireOpen() then -- Left mouse button and grimoire is open
		-- Check if clicking on any spell
		for i = 1, 4 do
			if isMouseOverSpell(i) then
				local spells = Spellbook.getSpells()
				local spell = spells[i]
				if Spellbook.canCastSpell(spell.name) then
					Spellbook.castSpell(spell.name)
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