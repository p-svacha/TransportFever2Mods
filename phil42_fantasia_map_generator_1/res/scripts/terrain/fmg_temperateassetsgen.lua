local data = {}

data.Make = function(layers, config, mkTemp, heightMap, ridgesMap, distanceMap)

	-- Tree types

	local shrub = 1
	local palm = 2
	local forest = 4
	local broadleaf = 5

	local conifer = 6
	local hills = 7
	local river = 8
	local plains = 9

	local cactus = 10
	local desert = 11
	local savanna = 12
	local canyon_shrub = 13
	local mesa_shrub = 14
	local ridge_shrub = 15

	local anyTree = 255
	
	local treesMapping = {
		[forest] = "forest",
		[palm] = "palm",
		[shrub] = "shrub",
		[broadleaf] = "broadleaf",

		[hills] = "hills",
		[conifer] = "conifer",
		[river] = "river",
		[plains] = "plains",

		[cactus] = "cactus",
		[savanna] = "savanna_shrub",
		[desert] = "desert_shrub",
		[canyon_shrub] = "canyon_shrub",
		[mesa_shrub] = "mesa_shrub",
		[ridge_shrub] = "ridge_shrub",

		[anyTree] = "all",
	}

	-- Rock types

	local cracked = 1
	local granite = 2
	local sandstone = 3
	local desertRock = 4
	local savanna_rock = 5
	
	local assetsMapping = {
		[cracked] = "cracked",
		[granite] = "granite",
		[sandstone] = "sandstone",
		[desertRock] = "desert_rock",
		[savanna_rock] = "savanna_rock",
	}	
	
	-- ###########################################################################################################
	-- #### HELPER METHODS
	-- ###########################################################################################################

	-- Returns a layered perlin map according to the given parameters
	local getLayeredPerlinNoise = function(numOctaves, startFrequency, lacunarity, persistence, minHeight, maxHeight)

		local perlinMap = mkTemp:Get()
		layers:Constant(perlinMap, 0)

		local currentFrequency = startFrequency
		local currentHeight = 1
		local maxPossibleHeight = 0

		for i = 1, numOctaves do
			local tempPerlin = mkTemp:Get()
			layers:PerlinNoise(tempPerlin, {frequency = currentFrequency})
			layers:Map(tempPerlin, tempPerlin, {-1.5, 1.5}, {0, currentHeight}, true)
			layers:Add(tempPerlin, perlinMap, perlinMap)
			mkTemp:Restore(tempPerlin)

			maxPossibleHeight = maxPossibleHeight + currentHeight
			currentFrequency = currentFrequency * lacunarity
			currentHeight = currentHeight * persistence		
		end

		layers:Map(perlinMap, perlinMap, {0, maxPossibleHeight}, {minHeight, maxHeight}, false)

		return perlinMap
	end

	-- Returns a mask that can be used to partially add a map to another map according to the mask
	-- coverageRatio: How much of the area of the targetMap will be covererd with the terrainMap (0-1)
	-- coverageMode: How the coverageRatio is calculated:
		-- 0: "Lakes": The mask will consist of multiple individual roundish shapes
		-- 1: "Snakes": The mask will consist of multiple connected strings snaking through the whole target map
	-- blendingRatio: How much the terrainMap will be blended into the targetMap (0-1)
	-- blobSize: The bigger this value, the bigger the individual clusters within the mask are (~ 1000 - 12000)
	-- irregularity: The higher, the more irregular will the shape of the mask be (1-8)
	local getRandomMask = function(coverageRatio, coverageMode, blendingRatio, blobSize, irregularity)

		local mask = mkTemp:Get()
		layers:Constant(mask, 0)
		local tempDist = mkTemp:Get()

		tempDist = getLayeredPerlinNoise(irregularity, 1 / blobSize, 2, 0.5, 0.001, 1)

		local min = 0
		local max = 1

		if coverageMode == 0 then
			min = 0
			max = coverageRatio
		elseif coverageMode == 1 then
			min = 0.5 - (coverageRatio / 2)
			max = 0.5 + (coverageRatio / 2)
		end

		local blendingMin = math.clamp(min - blendingRatio, 0, 1)
		local blendingMax = math.clamp(max + blendingRatio, 0, 1)

		layers:Pwlerp(tempDist, mask, {-99999, blendingMin, min, max, blendingMax, 99999}, {0, 0, 1, 1, 0, 0})
		--Exlerp(mask, mask, 50) -- convert linear to exponential blending

		mkTemp:Restore(tempDist)
		
		return mask
	end
	
	-- ###########################################################################################################
	-- #### PREPARE
	-- ###########################################################################################################

	local treeLineElevation = 550

	local ditheringMap = mkTemp:Get()
	local ditheringMap2 = mkTemp:Get()
	layers:Dithering(ditheringMap, "LOCAL")
	layers:Dithering(ditheringMap2, "LOCAL"):SetSeed(math.random())

	-- ###########################################################################################################
	-- #### TREES & FORESTS
	-- ###########################################################################################################

	local forestMap = mkTemp:Get()

	-- ##################### Single scattered trees
	local maxSingleTreeDensity = 0.003

	local map_single_trees = mkTemp:Get()
	map_single_trees = getLayeredPerlinNoise(1, 1 / 10000, 2, 0.5, 0, maxSingleTreeDensity)

	-- mask that high elevation has less trees
	local map_single_tree_elevation_mask = mkTemp:Get()
	layers:Map(heightMap, map_single_tree_elevation_mask, {40, treeLineElevation}, {1, 0}, true)
	layers:Mul(map_single_trees, map_single_tree_elevation_mask, map_single_trees)
	mkTemp:Restore(map_single_tree_elevation_mask)

	-- mask that some areas of the map have less trees
	local map_temp_mask = getRandomMask(0.4, 0, 0.2, 6000, 2)
	layers:Herp(map_temp_mask, map_temp_mask, {0, 1}) -- convert linear to smooth interpolation
	layers:Map(map_temp_mask, map_temp_mask, {0, 1}, {0.1, 1}, true) -- no areas with no trees at all
	layers:Mul(map_single_trees, map_temp_mask, map_single_trees) -- apply random mask
	mkTemp:Restore(map_temp_mask)

	-- add single trees to forest map
	layers:WhiteNoiseNonuniform(map_single_trees, map_single_trees)
	layers:Map(map_single_trees, map_single_trees, {0, 1}, {0, anyTree}, true)
	layers:Mask(map_single_trees, map_single_trees, forestMap)
	mkTemp:Restore(map_single_trees)

	-- ##################### Forests
	local numForestLayers = 6
	local paramForest = 4 -- 1..10
	local maxSlopeForForest = 0.6 -- how steep a slope has to be for forest to stop growing

	local minForestSize = 18 + (2 * paramForest)
	local maxForestSize = 28 + (2 * paramForest)

	for i = 1, numForestLayers do
		local forestAmount = math.random(minForestSize, maxForestSize) / 100
		local forestsSize = math.random(400, 1600)
		local treeType = anyTree
		local forestTreeDensity = math.random(20, 90) / 100
		local forestBlending = math.random(1, 30) / 1000


		-- make make initial forests
		local map_forests = mkTemp:Get()
		map_forests = getLayeredPerlinNoise(6, 1 / forestsSize, 2, 0.6, 0, 1)
		layers:Pwlerp(map_forests, map_forests, {0, 1 - forestAmount, 1 - forestAmount + forestBlending, 1, 1, 1}, {0, 0, forestTreeDensity, forestTreeDensity, forestTreeDensity, forestTreeDensity})

		-- mask steep cliffs
		local map_mask_cliffs = mkTemp:Get()
		layers:Grad(heightMap, map_mask_cliffs, 2) -- get gradients / slopes of heightmap (values go from 0 to ~5, cutoff at 1?)
		layers:Map(map_mask_cliffs, map_mask_cliffs, {maxSlopeForForest - 0.01, maxSlopeForForest}, {1, 0}, true)
		layers:Mul(map_forests, map_mask_cliffs, map_forests)
		mkTemp:Restore(map_mask_cliffs)

		-- reduce density on high elevations
		local map_mask_elevation = mkTemp:Get()
		layers:Map(heightMap, map_mask_elevation, {500, treeLineElevation}, {1, 0}, true)
		layers:Mul(map_forests, map_mask_elevation, map_forests)
		mkTemp:Restore(map_mask_elevation)

		-- add forests to forest map
		layers:WhiteNoiseNonuniform(map_forests, map_forests)
		layers:Map(map_forests, map_forests, {0, 1}, {0, treeType}, true)
		layers:Mask(map_forests, map_forests, forestMap)
		mkTemp:Restore(map_forests)
	end

	-- ###########################################################################################################
	-- #### ROCKS
	-- ###########################################################################################################
	local rocksMap = mkTemp:Get()

	-- ###########################################################################################################
	-- #### FINALIZE
	-- ###########################################################################################################

	mkTemp:Restore(ditheringMap)
	mkTemp:Restore(ditheringMap2)

	return forestMap, treesMapping, rocksMap, assetsMapping
end

return data