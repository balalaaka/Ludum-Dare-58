-- luacheck: globals love love.graphics love.physics love.window love.mouse
-- Spell Collector - Main Game File

-- Import modules
local Render = require("render")
local Spellbook = require("spellbook")

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
	
	-- Initialize modules
	Spellbook.init()
	
	-- Set up render module with global references
	Render.setGlobals({
		box = box,
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

function love.draw()
	Render.draw()
end

function love.keypressed(key)
	if key == "r" then
		box.body:setPosition(startX, startY)
		box.body:setLinearVelocity(0, 0)
		box.body:setAngularVelocity(0)
		box.body:setAngle(0)
	elseif key == "g" then
		Spellbook.toggleGrimoire()
	end
end

function love.mousepressed(x, y, button)
	if Spellbook.handleMouseClick(x, y, button) then
		-- Check if clicking on any spell
		for i = 1, 4 do
			if Render.isMouseOverSpell(i) then
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