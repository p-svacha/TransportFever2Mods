local vec2 = require("vec2")

local state = {
	initialized = 0
}

-- returns the coordinates of a random on a position on the map that is valid for construction (not under water, not on cliff, not too close to town/industry)
local function getRandomValidPosition()

	local terrain = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.TERRAIN)
	local mapSizeX = terrain.size.x
	local mapSizeY = terrain.size.y

	local realMapSizeX = mapSizeX * 250
	local realMapSizeY = mapSizeY * 250
	local edgeOffset = 50
	
	local realMinX = -(realMapSizeX / 2) + edgeOffset
	local realMaxX = (realMapSizeX / 2) - edgeOffset
	local realMinY = -(realMapSizeY / 2) + edgeOffset
	local realMaxY = (realMapSizeY / 2) - edgeOffset

	local isValid = false

	while(not isValid)
	do
		isValid = true

		local px = math.random(realMinX, realMaxX)
		local py = math.random(realMinY, realMaxY)
		local posVec = api.type.Vec2f.new(px,py)
		local height = api.engine.terrain.getHeightAt(posVec)
	
		-- check if position is under water
		if(height < 1) then
			isValid = false
		end
	
		-- check if position is on steep cliff
		local heightCheckOffset = 10
		local heightDiffLimit = 3
	
		local heightCheckDiff1 = api.engine.terrain.getHeightAt(api.type.Vec2f.new(px + heightCheckOffset, py + heightCheckOffset)) - height
		if(heightCheckDiff1 > heightDiffLimit or heightCheckDiff1 < -heightDiffLimit) then 
			isValid = false
		end
	
		local heightCheckDiff2 = api.engine.terrain.getHeightAt(api.type.Vec2f.new(px + heightCheckOffset, py - heightCheckOffset)) - height
		if(heightCheckDiff2 > heightDiffLimit or heightCheckDiff2 < -heightDiffLimit) then 
			isValid = false
		end
	
		local heightCheckDiff3 = api.engine.terrain.getHeightAt(api.type.Vec2f.new(px - heightCheckOffset, py - heightCheckOffset)) - height
		if(heightCheckDiff3 > heightDiffLimit or heightCheckDiff3 < -heightDiffLimit) then 
			isValid = false
		end
	
		local heightCheckDiff4 = api.engine.terrain.getHeightAt(api.type.Vec2f.new(px - heightCheckOffset, py + heightCheckOffset)) - height
		if(heightCheckDiff4 > heightDiffLimit or heightCheckDiff4 < -heightDiffLimit) then 
			isValid = false
		end

		-- check if not too close to a town
		local minDistanceToTown = 600

		local towns = game.interface.getTowns()
		for i=1,#towns do
			local townId = towns[i]
			local town = game.interface.getEntity(townId)
			local townPos = api.type.Vec2f.new(town.position[1], town.position[2])

			local distance = vec2.distance(posVec, townPos)
			if(distance < minDistanceToTown) then
				isValid = false
			end
		end

		-- check if not too close to an industry
		local minDistanceToIndustry = 200

		local constIdList = (game.interface.getEntities({ radius = 1e100 }, { type = "CONSTRUCTION" }))
		if (constIdList) then
			for index=1,#constIdList do
				local id = constIdList[index]
				if(id) then
					local constr = game.interface.getEntity(id)
					if (constr and constr.params and constr.simBuildings and constr.fileName and (string.sub(constr.fileName,1,9)=="industry/")) then
						-- this is an industry
						local industryPos = api.type.Vec2f.new(constr.position[1], constr.position[2])
						local distance = vec2.distance(posVec, industryPos)
						if(distance < minDistanceToIndustry) then
							isValid = false
						end
					end
				end
			end
		end

		-- return if position is valid, else try again
		if isValid then
			return posVec
		end
	end
end

local function createTown(caps, pos, name)
	local town = api.type.TownInfo.new()
	town.name = name
	town.position = api.type.Vec2f.new(pos[1],pos[2])
	town.initialLandUseCapacities = caps
	api.cmd.sendCommand(api.cmd.make.createTowns({town}))
end

-- Tries to create a town at a random position. Returns if it was successful.
local function tryCreateRandomTown()
	local caps = { math.random(5,60), 0, 0 }
	--local caps = {10, 10, 10}
	local townPosition = getRandomValidPosition()

	debugPrint("Creating Town at " .. townPosition.x .. "/" .. townPosition.y)
	local pos = {townPosition.x, townPosition.y}
	local townname = "" -- autoname
	createTown(caps, pos, townname)
	return true
end

local function createTowns()
	local terrain = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.TERRAIN)
	local area = terrain.size.x * terrain.size.y
	local targetNumTowns = area / 256
	if targetNumTowns < 1 then
		targetNumTowns = 1
	end

	local numCreatedTowns = 0
	
	while(numCreatedTowns < targetNumTowns)
	do
		if tryCreateRandomTown() then
			numCreatedTowns = numCreatedTowns + 1
		end
	end
end

-- moves random buildings (unused)
local function replaceStructures()
	local entities = game.interface.getEntities({radius = 999999},{type = "CONSTRUCTION", includeData = false})
	for _, constrId in pairs (entities) do
		local constr = api.engine.getComponent(constrId, api.type.ComponentType.CONSTRUCTION)
		if constr.fileName then

			--debugPrint("Found construnction " .. constr.fileName .. ": listing transf:")
			--for i = 1, 16 do
			--	debugPrint(i ..": " .. constr.transf[i])
			--end

			if math.random(0,99) <= 10 then
				local newConstr = api.type.SimpleProposal.ConstructionEntity.new()
				newConstr.fileName = constr.fileName
				newConstr.params = game.interface.getEntity(constrId).params
				for i = 1, 16 do
					newConstr.transf[i] = constr.transf[i]
				end

				-- get new position
				local pos = getRandomValidPosition()
				local height = api.engine.terrain.getHeightAt(pos) 

				debugPrint("replacing " .. constr.fileName .. " at " .. newConstr.transf[13] .." / " .. newConstr.transf[14] .. " to new position " .. pos.x .. " / " .. pos.y)

				newConstr.transf[13] = pos.x
				newConstr.transf[14] = pos.y
				newConstr.transf[15] = height


				newConstr.name = "monument"
				--newConstr.playerEntity = api.engine.util.getPlayer()
				--newConstr.headquarters = false

				local proposal = api.type.SimpleProposal.new()
				proposal.old2new = {[constrId] = 0}
				proposal.constructionsToRemove = {constrId}
				proposal.constructionsToAdd[1] = newConstr
				api.cmd.sendCommand(api.cmd.make.buildProposal(proposal, nil, true))
			end
		end
	end
end

local function placeFeatures()
	math.randomseed(os.time()) -- init randomness
	createTowns()
	--replaceStructures()
	--createStructures()
end

function update()
	--local time = game.interface.getGameTime()
	if state.initialized == 0 then
		debugPrint("################## INITIALIZING HAMLETS #################")			
		placeFeatures()
		state.initialized = 1
	end
end

local function save()
	return state
end

local function load(loadedState)
	state = loadedState or state
end

function data()
	return {
		-- Engine Callbacks
		load = load, -- is the callback that is called once on savegame load to retrieve the state data that was stored with the savegame.
		save = save, -- is a callback that can be triggered to save data to the shared state from where it can be persisted on savegame save.
		update = update, -- is a callback that is regularily called to do update processing in the engine simulation.
		handleEvent = function (src, id, name, param) end, -- is a callback that is called whenever an engine event happens.

		-- UI Callbacks
		guiInit = function() end, -- is a callback that is called once on startup.
		guiUpdate = function () end, -- is a callback that is regularily called to refresh the gui.
		guiHandleEvent = function (id, name, param) end, -- is a callback that is called whenever a gui event happens
	}
  end