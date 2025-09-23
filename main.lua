-- luacheck: globals love love.graphics love.physics love.window love.mouse
-- LOVE2D Physics draggable box example

local world
local box = {}
local floor = {}
local font

local gravityPixelsPerSecond2 = 900 -- positive Y is down in LOVE
local pullStrength = 600 -- proportional gain for attraction force
local maxForce = 20000 -- clamp to avoid instability
local linearDamping = 1
local currentPullForce = 0

function love.load()
	love.window.setTitle("Physics Drag Box")
	love.graphics.setBackgroundColor(0.08, 0.08, 0.1)
	font = love.graphics.newFont(16)

	world = love.physics.newWorld(0, gravityPixelsPerSecond2, true)

	local startX, startY = love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.3
	box.body = love.physics.newBody(world, startX, startY, "dynamic")
	box.shape = love.physics.newRectangleShape(80, 80)
	box.fixture = love.physics.newFixture(box.body, box.shape, 1)
	box.fixture:setFriction(0)
	box.fixture:setRestitution(0.1)
	box.body:setLinearDamping(linearDamping)
	box.body:setAngularDamping(8)
	box.color = {0.2, 0.7, 1.0}

	-- Floor (static)
	floor.body = love.physics.newBody(world, 0, 0, "static")
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local function rebuildFloor(width, height)
		if floor.fixture then floor.fixture:destroy() end
		floor.shape = love.physics.newRectangleShape(width, height)
		floor.fixture = love.physics.newFixture(floor.body, floor.shape, 1)
		floor.fixture:setFriction(0.9)
		floor.fixture:setRestitution(0.0)
		floor.height = height
		floor.width = width
	end
	-- keep a reference for resize
	floor.rebuild = rebuildFloor
	floor.color = {0.3, 0.3, 0.35}
	floor.rebuild(w - 40, 20)
	floor.body:setPosition(w * 0.5, h - 10)
end

local function applyAttractionForceToBox(dt)
	if not love.mouse.isDown(1) then
		currentPullForce = 0
		return
	end
	local mx, my = love.mouse.getPosition()
	local bx, by = box.body:getPosition()
	local dx, dy = mx - bx, my - by
	-- Distance-proportional force (simple spring-like behavior)
	local fx = dx * pullStrength
	local fy = dy * pullStrength
	-- Clamp force magnitude
	local mag = math.sqrt(fx * fx + fy * fy)
	if mag > maxForce then
		local scale = maxForce / (mag + 1e-6)
		fx, fy = fx * scale, fy * scale
	end
	currentPullForce = mag
	box.body:applyForce(fx, fy)
end

function love.update(dt)
	world:update(dt)
	applyAttractionForceToBox(dt)
end

local function drawBox()
	local r, g, b = box.color[1], box.color[2], box.color[3]
	love.graphics.setColor(r, g, b)
	local x, y = box.body:getPosition()
	local angle = box.body:getAngle()
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(angle)
	local w, h = 80, 80
	love.graphics.rectangle("fill", -w/2, -h/2, w, h, 6, 6)
	-- Outline
	love.graphics.setColor(1, 1, 1, 0.6)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", -w/2, -h/2, w, h, 6, 6)
	love.graphics.pop()
end

function love.draw()
	-- Attraction line when dragging
	if love.mouse.isDown(1) then
		local mx, my = love.mouse.getPosition()
		local bx, by = box.body:getPosition()
		love.graphics.setColor(1, 1, 1, 0.25)
		love.graphics.setLineWidth(2)
		love.graphics.line(bx, by, mx, my)
		love.graphics.setColor(1, 1, 1, 0.4)
		love.graphics.circle("fill", mx, my, 4)
	end

	-- Floor draw
	local fx, fy = floor.body:getPosition()
	love.graphics.setColor(floor.color)
	love.graphics.push()
	love.graphics.translate(fx, fy)
	love.graphics.rectangle("fill", -floor.width/2, -floor.height/2, floor.width, floor.height)
	love.graphics.pop()

	drawBox()

	-- UI text
	love.graphics.setFont(font)
	love.graphics.setColor(1, 1, 1, 0.85)
	local info = string.format("Hold Left Mouse to pull the box toward the cursor\nPress R to reset position\nForce: %.0f N (arbitrary units)", currentPullForce)
	love.graphics.print(info, 12, 12)
end

function love.keypressed(key)
	if key == "r" then
		local startX, startY = love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.3
		box.body:setPosition(startX, startY)
		box.body:setLinearVelocity(0, 0)
		box.body:setAngularVelocity(0)
		box.body:setAngle(0)
	end
end

function love.resize(w, h)
	-- Rebuild and reposition floor when window changes
	if floor and floor.rebuild then
		floor.rebuild(math.max(100, w - 40), 20)
		floor.body:setPosition(w * 0.5, h - 10)
	end
end