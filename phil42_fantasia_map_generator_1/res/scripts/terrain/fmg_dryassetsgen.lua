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
		[shrub] = "shrub",
		[broadleaf] = "broadleaf",
		[conifer] = "conifer",

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
	-- #### TREES & FORESTS
	-- ###########################################################################################################

	local treeLineElevation = 550
	local forestMap = mkTemp:Get()
	layers:Constant(forestMap, 0)

	-- ##################### Single scattered trees
	local maxSingleTreeDensity = 0.004

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

	-- ##################### Rare High Density Forests
	local numForestLayers = (config.forestAmount * 2) + 1
	local maxSlopeForForest = 0.6 -- how steep a slope has to be for forest to stop growing

	debugPrint("Creating " .. numForestLayers .. " forest layers")

	local minForestSize = 24 + (2 * config.forestAmount)
	local maxForestSize = 31 + (2 * config.forestAmount)

	for i = 1, numForestLayers do
		local forestAmount = math.random(minForestSize, maxForestSize) / 108
		local forestsSize = math.random(400, 2000)
		local treeType = anyTree
		local forestTreeDensity = math.random(30, 55) / 100
		local forestBlending = math.random(1, 30) / 1000

		local treeTypeRng = math.random(0, 3)
		if treeTypeRng <= 1 then
			treeType = broadleaf
			forestTreeDensity = forestTreeDensity * 0.65
		elseif treeTypeRng <= 2 then
			treeType = cactus
		elseif treeTypeRng <= 3 then
			treeType = anyTree
		end


		-- make initial forests
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
		layers:Map(heightMap, map_mask_elevation, {250, treeLineElevation}, {1, 0}, true)
		layers:Mul(map_forests, map_mask_elevation, map_forests)
		mkTemp:Restore(map_mask_elevation)

		-- add forests to forest map
		layers:WhiteNoiseNonuniform(map_forests, map_forests)
		layers:Map(map_forests, map_forests, {0, 1}, {0, treeType}, true)
		layers:Mask(map_forests, map_forests, forestMap)
		mkTemp:Restore(map_forests)
	end

	-- ##################### Lower density, higher coverage forest
	local lowDensityForestMaxDensity = 0.1
	local lowDensityForestCoverage = 0.37 + (0.02 * config.forestAmount)
	local lowDensityForestBlending = 0.18

	local map_low_density_forest = mkTemp:Get()
	map_low_density_forest = getLayeredPerlinNoise(8, 1 / 1000, 2, 0.5, 0, 1)
	layers:Map(map_low_density_forest, map_low_density_forest, {1 - lowDensityForestCoverage, (1 - lowDensityForestCoverage) + lowDensityForestBlending}, {0, lowDensityForestMaxDensity}, true)

	-- mask steep cliffs
	local map_mask_cliffs = mkTemp:Get()
	layers:Grad(heightMap, map_mask_cliffs, 2) -- get gradients / slopes of heightmap (values go from 0 to ~5, cutoff at 1?)
	layers:Map(map_mask_cliffs, map_mask_cliffs, {maxSlopeForForest - 0.01, maxSlopeForForest}, {1, 0}, true)
	layers:Mul(map_low_density_forest, map_mask_cliffs, map_low_density_forest)
	mkTemp:Restore(map_mask_cliffs)

	-- reduce density on high elevations
	local map_mask_elevation = mkTemp:Get()
	layers:Map(heightMap, map_mask_elevation, {250, treeLineElevation}, {1, 0}, true)
	layers:Mul(map_low_density_forest, map_mask_elevation, map_low_density_forest)
	mkTemp:Restore(map_mask_elevation)

	-- add to forest map
	layers:WhiteNoiseNonuniform(map_low_density_forest, map_low_density_forest)
	layers:Map(map_low_density_forest, map_low_density_forest, {0, 1}, {0, anyTree}, true)
	layers:Mask(map_low_density_forest, map_low_density_forest, forestMap)
	mkTemp:Restore(map_low_density_forest)


	-- ##################### Coastal Forests
	local maxCoastDensity = 0.7
	local coastalForestAmount = 0.47 + (config.forestAmount * 0.02)
	local coastalForestBlending = 0.05

	local map_coastal_forest = mkTemp:Get()
	map_coastal_forest = getLayeredPerlinNoise(6, 1 / 700, 2, 0.6, 0, 1)
	layers:Pwlerp(map_coastal_forest, map_coastal_forest, {0, 1 - coastalForestAmount, 1 - coastalForestAmount + coastalForestBlending, 1, 1, 1}, {0, 0, maxCoastDensity, maxCoastDensity, maxCoastDensity, maxCoastDensity})

	-- mask coasts
	local map_distance_mask = mkTemp:Get()
	layers:Map(distanceMap, map_distance_mask, {0, 10}, {0, 1}, true)
	layers:Map(distanceMap, map_distance_mask, {40, 200}, {1, 0}, true)
	layers:Mul(map_coastal_forest, map_distance_mask, map_coastal_forest)
	mkTemp:Restore(map_distance_mask)

	-- mask steep cliffs
	local map_mask_cliffs = mkTemp:Get()
	layers:Grad(heightMap, map_mask_cliffs, 2) -- get gradients / slopes of heightmap (values go from 0 to ~5, cutoff at 1?)
	layers:Map(map_mask_cliffs, map_mask_cliffs, {maxSlopeForForest - 0.01, maxSlopeForForest}, {1, 0}, true)
	layers:Mul(map_coastal_forest, map_mask_cliffs, map_coastal_forest)
	mkTemp:Restore(map_mask_cliffs)

	-- mask that some areas of the map have less
	local map_temp_mask = getRandomMask(0.47, 0, 0.1, 3000, 6)
	layers:Mul(map_coastal_forest, map_temp_mask, map_coastal_forest) -- apply random mask
	mkTemp:Restore(map_temp_mask)

	-- add to forest map
	layers:WhiteNoiseNonuniform(map_coastal_forest, map_coastal_forest)
	layers:Map(map_coastal_forest, map_coastal_forest, {0, 1}, {0, forest}, true)
	layers:Mask(map_coastal_forest, map_coastal_forest, forestMap)
	mkTemp:Restore(map_coastal_forest)

	-- ##################### Low density, high area shrubs
	local shrubsMaxDensity = 0.02
	local shrubsCoverage = 0.4 + (0.05 * config.forestAmount)
	local shrubsBlending = 0.4

	local map_shrubs = mkTemp:Get()
	map_shrubs = getLayeredPerlinNoise(8, 1 / 1000, 2, 0.5, 0, 1)
	layers:Map(map_shrubs, map_shrubs, {1 - shrubsCoverage, (1 - shrubsCoverage) + shrubsBlending}, {0, shrubsMaxDensity}, true)

	-- mask steep cliffs
	local map_mask_cliffs = mkTemp:Get()
	layers:Grad(heightMap, map_mask_cliffs, 2) -- get gradients / slopes of heightmap (values go from 0 to ~5, cutoff at 1?)
	layers:Map(map_mask_cliffs, map_mask_cliffs, {maxSlopeForForest - 0.01, maxSlopeForForest}, {1, 0}, true)
	layers:Mul(map_shrubs, map_mask_cliffs, map_shrubs)
	mkTemp:Restore(map_mask_cliffs)

	-- reduce density on high elevations
	local map_mask_elevation = mkTemp:Get()
	layers:Map(heightMap, map_mask_elevation, {250, treeLineElevation}, {1, 0}, true)
	layers:Mul(map_shrubs, map_mask_elevation, map_shrubs)
	mkTemp:Restore(map_mask_elevation)

	-- add to forest map
	layers:WhiteNoiseNonuniform(map_shrubs, map_shrubs)
	layers:Map(map_shrubs, map_shrubs, {0, 1}, {0, shrub}, true)
	layers:Mask(map_shrubs, map_shrubs, forestMap)
	mkTemp:Restore(map_shrubs)

	-- ###########################################################################################################
	-- #### ROCKS
	-- ###########################################################################################################

	local maxSlopeForRocks = 0.6

	local rocksMap = mkTemp:Get()
	layers:Constant(rocksMap, 0)

	-- ##################### Rare white rocks
	local maxRockDensity = 0.0015

	local map_single_rocks = mkTemp:Get()
	map_single_rocks = getLayeredPerlinNoise(1, 1 / 10000, 2, 0.5, 0, maxRockDensity)

	-- mask that high elevations have more rocks
	local map_elevation_mask = mkTemp:Get()
	layers:Map(heightMap, map_elevation_mask, {200, 800}, {1, 3}, true)
	layers:Mul(map_single_rocks, map_elevation_mask, map_single_rocks)
	mkTemp:Restore(map_elevation_mask)

	-- mask that some areas of the map have less rocks
	local map_temp_mask = getRandomMask(0.5, 0, 0.3, 6000, 2)
	layers:Mul(map_single_rocks, map_temp_mask, map_single_rocks) -- apply random mask
	mkTemp:Restore(map_temp_mask)

	-- mask steep cliffs
	local map_mask_cliffs = mkTemp:Get()
	layers:Grad(heightMap, map_mask_cliffs, 2) -- get gradients / slopes of heightmap (values go from 0 to ~5, cutoff at 1?)
	layers:Map(map_mask_cliffs, map_mask_cliffs, {maxSlopeForRocks - 0.01, maxSlopeForRocks}, {1, 0}, true)
	layers:Mul(map_single_rocks, map_mask_cliffs, map_single_rocks)
	mkTemp:Restore(map_mask_cliffs)

	-- add single rocks to rock map
	layers:WhiteNoiseNonuniform(map_single_rocks, map_single_rocks)
	layers:Map(map_single_rocks, map_single_rocks, {0, 1}, {0, granite}, true)
	layers:Mask(map_single_rocks, map_single_rocks, rocksMap)
	mkTemp:Restore(map_single_rocks)

	-- ##################### Common desert rocks
	local maxDesertRockDensity = 0.01

	local map_desert_rocks = mkTemp:Get()
	map_desert_rocks = getLayeredPerlinNoise(1, 1 / 10000, 2, 0.5, 0, maxDesertRockDensity)

	-- mask that high elevations have more rocks
	local map_elevation_mask = mkTemp:Get()
	layers:Map(heightMap, map_elevation_mask, {200, 800}, {1, 3}, true)
	layers:Mul(map_desert_rocks, map_elevation_mask, map_desert_rocks)
	mkTemp:Restore(map_elevation_mask)

	-- mask that some areas of the map have less rocks
	local map_temp_mask = getRandomMask(0.6, 0, 0.3, 6000, 2)
	layers:Mul(map_desert_rocks, map_temp_mask, map_desert_rocks) -- apply random mask
	mkTemp:Restore(map_temp_mask)

	-- mask steep cliffs
	local map_mask_cliffs = mkTemp:Get()
	layers:Grad(heightMap, map_mask_cliffs, 2) -- get gradients / slopes of heightmap (values go from 0 to ~5, cutoff at 1?)
	layers:Map(map_mask_cliffs, map_mask_cliffs, {maxSlopeForRocks - 0.01, maxSlopeForRocks}, {1, 0}, true)
	layers:Mul(map_desert_rocks, map_mask_cliffs, map_desert_rocks)
	mkTemp:Restore(map_mask_cliffs)

	-- add single rocks to rock map
	layers:WhiteNoiseNonuniform(map_desert_rocks, map_desert_rocks)
	layers:Map(map_desert_rocks, map_desert_rocks, {0, 1}, {0, sandstone}, true)
	layers:Mask(map_desert_rocks, map_desert_rocks, rocksMap)
	mkTemp:Restore(map_desert_rocks)

	-- ##################### Stone circles

	local numStoneCircles = (config.mapSize / 5000000)
	numStoneCircles = math.round(numStoneCircles, 1)

	local minStoneCircleSize = 40
	local maxStoneCircleSize = 120

	local minStoneCircleWidth = 3
	local maxStoneCircleWidth = 7

	local minStoneCircleDensity = 0.04
	local maxStoneCircleDensity = 0.4

	debugPrint("Creating " .. numStoneCircles .. " stone circles")

	for i = 1, numStoneCircles do
		local stoneCircleSize = math.random(minStoneCircleSize, maxStoneCircleSize)
		local stoneCircleWidth = math.random(minStoneCircleWidth, maxStoneCircleWidth)
		local stoneCircleDensity = math.random(minStoneCircleDensity * 100, maxStoneCircleDensity * 100) / 100

		local map_stone_circle = mkTemp:Get()
		layers:Constant(map_stone_circle, stoneCircleDensity)

		local stoneCircleCenterPoint = {}
		local px = math.random(0, config.mapSizeX)
		local py = math.random(0, config.mapSizeY)
		stoneCircleCenterPoint[#stoneCircleCenterPoint + 1] = { px, py }

		--debugPrint("Creating stone circle at " .. px .. "/" .. py)

		local map_temp_mask = mkTemp:Get()
		layers:Constant(map_temp_mask, 1)
		layers:Points(map_temp_mask,  stoneCircleCenterPoint, 0)		
		layers:Distance(map_temp_mask, map_temp_mask)

		-- map it to make it a valid mask
		layers:Pwlerp(map_temp_mask, map_temp_mask, {-99999, stoneCircleSize - 1, stoneCircleSize, stoneCircleSize + stoneCircleWidth, stoneCircleSize + stoneCircleWidth + 1, 99999}, {0, 0, 1, 1, 0, 0})
		layers:Mul(map_stone_circle, map_temp_mask, map_stone_circle) -- apply mask
		mkTemp:Restore(map_temp_mask)

		-- mask steep cliffs
		local map_mask_cliffs = mkTemp:Get()
		layers:Grad(heightMap, map_mask_cliffs, 2) -- get gradients / slopes of heightmap (values go from 0 to ~5, cutoff at 1?)
		layers:Map(map_mask_cliffs, map_mask_cliffs, {maxSlopeForRocks - 0.01, maxSlopeForRocks}, {1, 0}, true)
		layers:Mul(map_stone_circle, map_mask_cliffs, map_stone_circle)
		mkTemp:Restore(map_mask_cliffs)

		-- add to rock map
		layers:WhiteNoiseNonuniform(map_stone_circle, map_stone_circle)
		layers:Map(map_stone_circle, map_stone_circle, {0, 1}, {0, granite}, true)
		layers:Mask(map_stone_circle, map_stone_circle, rocksMap)
		mkTemp:Restore(map_stone_circle)
	end


	-- ###########################################################################################################
	-- #### FINALIZE
	-- ###########################################################################################################

	return forestMap, treesMapping, rocksMap, assetsMapping
end

return data