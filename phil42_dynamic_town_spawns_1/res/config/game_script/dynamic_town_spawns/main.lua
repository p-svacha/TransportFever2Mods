local state = {
	rngInitialized = 0,
	tick = 0
}

local function createTown(caps, pos, name)
	local town = api.type.TownInfo.new()
	town.name = name
	town.position = api.type.Vec2f.new(pos[1],pos[2])
	town.initialLandUseCapacities = caps
	api.cmd.sendCommand(api.cmd.make.createTowns({town}))
end

local lastRng = -1
function update()
	local gameWorld = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	
	math.randomseed(gameWorld.gameTime)

	state.tick = state.tick + 1

	local rng = math.random(0, 600)

	if rng ~= lastRng then	
		debugPrint("Update " .. state.tick .. " RNG = " .. rng .. " (lastRng was " .. lastRng .. ")")
	end

	if rng <= 2 and rng ~= lastRng then
		
		local caps = { 50, 50, 50 }

		local terrain = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.TERRAIN)
		local mapSizeX = terrain.size.x
		local mapSizeY = terrain.size.y
		
		debugPrint("mapsize is " .. mapSizeX .. "/" .. mapSizeY)

		local px = math.random(0, mapSizeX)
		local py = math.random(0, mapSizeY)

		debugPrint("Creating Town at " .. px .. "/" .. py)

		local pos = {px, py}

		local townname = ""

		createTown(caps, pos, townname)
	end

	lastRng = rng
end

function data()
	return {
		-- Engine Callbacks
		load = function(loadedstate) end, -- is the callback that is called once on savegame load to retrieve the state data that was stored with the savegame.
		save = function() end, -- is a callback that can be triggered to save data to the shared state from where it can be persisted on savegame save.
		update = update, -- is a callback that is regularily called to do update processing in the engine simulation.
		handleEvent = function (src, id, name, param) end, -- is a callback that is called whenever an engine event happens.

		-- UI Callbacks
		guiInit = function() end, -- is a callback that is called once on startup.
		guiUpdate = function() end, -- is a callback that is regularily called to refresh the gui.
		guiHandleEvent = function (id, name, param) end, -- is a callback that is called whenever a gui event happens
	}
  end