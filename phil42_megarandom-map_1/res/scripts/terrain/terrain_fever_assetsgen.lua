local data = {}

data.Make = function(layers, config, mkTemp, heightMap, waterDistanceMap, highMountainMask)

	-- ###########################################################################################################
	-- #### PARAMS
	-- ###########################################################################################################
	-- Tree types
	local conifer = 1
	local shrub = 2
	local hills = 3
	local broadleaf = 4
	local river = 5
	local plains = 6
	local anyTree = 255
	
	local treesMapping = {
		[hills] = "hills",
		[conifer] = "conifer",
		[shrub] = "shrub",
		[broadleaf] = "broadleaf",
		[river] = "river",
		[plains] = "plains",
		[anyTree] = "single",
	}
	
	local assetsMapping = {
		[1] = "granite",
	}		

	-- ###########################################################################################################
	-- #### CONFIG
	-- ###########################################################################################################
	local maxSlope = config.maxTreeSlope
	local maxHeight = config.maxTerrainHeight  * config.maxTreeHeight
	local treeAmount = config.trees
	local forestSize = config.forestSize
	local mountainLowerLimit = config.mountainLowerLimit
	local mountainUpperLimit = config.mountainUpperLimit
	local hillsLowerLimit = config.hillsLowerLimit
	local hillsUpperLimit = config.hillsUpperLimit
	local riverTreeLimit = 10

	if config.humidity == 0 then
		local forestMap = mkTemp:Get()
		local rocksMap = mkTemp:Get()
		layers:Constant(forestMap, 0)
		layers:Constant(rocksMap, -1)
		return forestMap, treesMapping, rocksMap, assetsMapping
	end
	
	-- ###########################################################################################################
	-- #### PREPARATION
	-- ###########################################################################################################
	local slopeMap = mkTemp:Get()
	layers:Grad(heightMap, slopeMap, 2)

	local heightCutoffMap = mkTemp:Get()
	layers:Pwconst(heightMap, heightCutoffMap, {maxHeight}, {1, 0})
	
	local trees = mkTemp:Get()
	layers:WhiteNoise(trees, 0.075 + 0.15 * treeAmount)
	
	local treeNoise = mkTemp:Get()
	layers:PerlinNoise(treeNoise, {frequency = 1 / 3})
	layers:Mul(trees, treeNoise, trees)
	mkTemp:Restore(treeNoise)

	
	-- ###########################################################################################################
	-- #### Conifiers near / on mountains
	-- ###########################################################################################################
	local coniferMask = mkTemp:Get()
	layers:Mul(highMountainMask, heightCutoffMap, coniferMask)
	
	local coniferForestShapeMask = mkTemp:Get()
	layers:GradientNoise(coniferForestShapeMask, {numOctaves = 5, frequency = 1 / 1000, lacunarity = 2, gain = 0.8, warp = 0.2})
	layers:Pwconst(coniferForestShapeMask, coniferForestShapeMask, {0.5 - forestSize * 1.4}, {0, 1})
	layers:Mul(coniferForestShapeMask, coniferMask, coniferMask)
	mkTemp:Restore(coniferForestShapeMask)
	
	local coniferShapeMap = mkTemp:Get()
	layers:GradientNoise(coniferShapeMap, {numOctaves = 8, frequency = 1 / (800 + 800 * forestSize), lacunarity = 3, gain = 0.8, warp = 0.5})
	layers:Pwconst(coniferShapeMap, coniferShapeMap, {1.5 - treeAmount}, {0, 1})
	layers:Mul(coniferShapeMap, coniferMask, coniferMask)
	mkTemp:Restore(coniferShapeMap)
	
	local coniferHeightMap = mkTemp:Get()
	layers:Pwconst(heightMap, coniferHeightMap, {mountainUpperLimit}, {1, 0})
	layers:Mul(coniferHeightMap, coniferMask, coniferMask)
	mkTemp:Restore(coniferHeightMap)
	
	local coniferSlopeMap = mkTemp:Get()
	layers:Pwconst(slopeMap, coniferSlopeMap, {0.3, maxSlope}, {0, 1, 0})
	layers:Mul(coniferSlopeMap, coniferMask, coniferMask)
	mkTemp:Restore(coniferSlopeMap)
	
	local coniferTrees = mkTemp:Get()
	layers:Pwconst(trees, coniferTrees, {0}, {0, conifer})
	layers:Mul(coniferMask, coniferTrees, coniferTrees)
	
	-- ###########################################################################################################
	-- #### Mixed forests
	-- ###########################################################################################################
	local mixedForestMask = mkTemp:Get()
	layers:Constant(mixedForestMask, 1)
	
	-- shape mask 1 
	local mixedForesShapeMask = mkTemp:Get()
	layers:GradientNoise(mixedForesShapeMask, {numOctaves = 4, frequency = 1 / 1200, lacunarity = 2, gain = 0.5, warp = 0})
	layers:Pwconst(mixedForesShapeMask, mixedForesShapeMask, {0.5 - forestSize * 1.4}, {0, 1})
	layers:Mul(mixedForesShapeMask, mixedForestMask, mixedForestMask)
	
	-- shape mask 2
	layers:PerlinNoise(mixedForesShapeMask, {frequency = 1 / 500})
	layers:Pwconst(mixedForesShapeMask, mixedForesShapeMask, {0.7 - forestSize * 0.5}, {0, 1})
	layers:Mul(mixedForesShapeMask, mixedForestMask, mixedForestMask)
	mkTemp:Restore(mixedForesShapeMask)
	
	local mixedForestShapeMap = mkTemp:Get()
	layers:GradientNoise(mixedForestShapeMap, {numOctaves = 6, frequency = 1 / (800 + 800 * forestSize), lacunarity = 4, gain = 0.8, warp = 0.05})
	layers:Pwconst(mixedForestShapeMap, mixedForestShapeMap, {1.5 - treeAmount * 0.2}, {0, 1})
	layers:Mul(mixedForestShapeMap, mixedForestMask, mixedForestMask)
	mkTemp:Restore(mixedForestShapeMap)
	
	local mixedForestHeightMap = mkTemp:Get()
	layers:Pwconst(heightMap, mixedForestHeightMap, {hillsLowerLimit + (hillsUpperLimit - hillsLowerLimit) / 3, hillsUpperLimit}, {0, 1, 0})
	layers:Mul(mixedForestHeightMap, mixedForestMask, mixedForestMask)
	mkTemp:Restore(mixedForestHeightMap)
	
	-- remove conifer mask from mixed forest mask (avoid overlaps)
	local temp = mkTemp:Get()
	layers:Map(coniferMask, temp, {0, 1}, {1, 0})
	layers:Mul(temp, mixedForestMask, mixedForestMask)
	mkTemp:Restore(temp)
	
	local mixedForestTrees = mkTemp:Get()
	layers:Pwconst(trees, mixedForestTrees, {0, 0.5}, {0, hills, conifer})
	layers:Mul(mixedForestMask, mixedForestTrees, mixedForestTrees)

	-- ###########################################################################################################
	-- #### Broadleafed forest
	-- ###########################################################################################################
	local broadleafedForestMask = mkTemp:Get()
	layers:Constant(broadleafedForestMask, 1)
	
	local broadleafNoise = mkTemp:Get()
	layers:PerlinNoise(broadleafNoise, {frequency = 1 / 80})
	layers:Map(broadleafNoise, broadleafNoise, {-1, 1}, {-0.3, 0.3}, true)
	
	-- shape mask 1 
	local broadleafedShapeMask = mkTemp:Get()
	layers:PerlinNoise(broadleafedShapeMask, {frequency = 1 / 500})
	layers:Add(broadleafNoise, broadleafedShapeMask, broadleafedShapeMask)
	layers:Pwconst(broadleafedShapeMask, broadleafedShapeMask, {0.5 - forestSize}, {0, 1})
	layers:Mul(broadleafedShapeMask, broadleafedForestMask, broadleafedForestMask)
	
	-- shape mask 2
	layers:PerlinNoise(broadleafedShapeMask, {frequency = 1 / 850})
	layers:Pwconst(broadleafedShapeMask, broadleafedShapeMask, {0.85 - forestSize * 0.3}, {0, 1})
	layers:Mul(broadleafedShapeMask, broadleafedForestMask, broadleafedForestMask)
	
	mkTemp:Restore(broadleafedShapeMask)
	mkTemp:Restore(broadleafNoise)
	
	local broadleafedForestHeightMap = mkTemp:Get()
	layers:Pwconst(heightMap, broadleafedForestHeightMap, {riverTreeLimit, hillsUpperLimit}, {0, 1, 0})
	layers:Mul(broadleafedForestHeightMap, broadleafedForestMask, broadleafedForestMask)
	mkTemp:Restore(broadleafedForestHeightMap)
	
	-- remove mixed forest mask from broadleafed forest mask (avoid overlaps)
	local temp = mkTemp:Get()
	layers:Map(mixedForestMask, temp, {0, 1}, {1, 0})
	layers:Mul(temp, broadleafedForestMask, broadleafedForestMask)
	mkTemp:Restore(temp)
	
	local broadleafedForestTrees = mkTemp:Get()
	layers:Pwconst(trees, broadleafedForestTrees, {0, 0.5}, {0, broadleaf, plains})
	layers:Mul(broadleafedForestMask, broadleafedForestTrees, broadleafedForestTrees)
	
	-- ###########################################################################################################
	-- #### Single trees
	-- ###########################################################################################################
	local singleTreesMask = mkTemp:Get()
	layers:Pwconst(heightMap, singleTreesMask, {mountainLowerLimit + (mountainUpperLimit - mountainLowerLimit) * 0.7}, {1, 0})
	
	local singleTreesShapeMap = mkTemp:Get()
	layers:GradientNoise(singleTreesShapeMap, {numOctaves = 4, frequency = 1 / (800 + 800 * forestSize), lacunarity = 2, gain = 0.5, warp = 0.7})
	layers:Pwconst(singleTreesShapeMap, singleTreesShapeMap, {1 - treeAmount * 0.5}, {0, 1})
	layers:Mul(singleTreesShapeMap, singleTreesMask, singleTreesMask)
	mkTemp:Restore(singleTreesShapeMap)
	
	local singleTrees = mkTemp:Get()
	layers:WhiteNoise(singleTrees, 0.001)
	layers:Pwconst(singleTrees, singleTrees, {0.5, 0.75}, {0, plains, broadleaf})
	layers:Mul(singleTreesMask, singleTrees, singleTrees)

	-- ###########################################################################################################
	-- #### Rivers trees
	-- ###########################################################################################################
	local riverTreesMask = mkTemp:Get()
	layers:Constant(riverTreesMask, 1)
	
	local riverTreesShapeMask = mkTemp:Get()
	layers:PerlinNoise(riverTreesShapeMask, {frequency = 1 / 8})
	layers:Pwconst(riverTreesShapeMask, riverTreesShapeMask, {0.5}, {0, 1})
	layers:Mul(riverTreesShapeMask, riverTreesMask, riverTreesMask)
	
	local tempHeightNoise = mkTemp:Get()
	layers:PerlinNoise(tempHeightNoise, {frequency = 1 / 60})
	layers:Map(tempHeightNoise, tempHeightNoise, {-1, 1}, {-10, 10}, true)

	local riverTreesHeightMap = mkTemp:Get()
	layers:Add(heightMap, tempHeightNoise, tempHeightNoise)
	layers:Pwconst(tempHeightNoise, riverTreesHeightMap, {riverTreeLimit}, {1, 0})
	layers:Mul(riverTreesHeightMap, riverTreesMask, riverTreesMask)

	local riverTrees = mkTemp:Get()
	layers:Pwconst(trees, riverTrees, {0.7, 0.85}, {0, shrub, river})
	layers:Mul(riverTreesMask, riverTrees, riverTrees)


	-- ###########################################################################################################
	-- #### Build final tree map
	-- ###########################################################################################################
	local forestMap = mkTemp:Get()
	layers:Add(coniferTrees, forestMap, forestMap)
	layers:Add(mixedForestTrees, forestMap, forestMap)
	layers:Add(broadleafedForestTrees, forestMap, forestMap)
	layers:Add(singleTrees, forestMap, forestMap)
	layers:Add(riverTrees, forestMap, forestMap)
	
	mkTemp:Restore(riverTreesHeightMap)
	mkTemp:Restore(tempHeightNoise)
	
	-- ###########################################################################################################
	-- #### Add rocks
	-- ###########################################################################################################
	-- add some rocks near water
	local riverRocksMap = mkTemp:Get()
	layers:WhiteNoise(riverRocksMap, 0.003)
	layers:Mul(riverTreesMask, riverRocksMap, riverRocksMap)
	
	-- add some rocks at mountainious flat areas
	local mountainRocksMap = mkTemp:Get()
	layers:Pwconst(trees, mountainRocksMap, {0.5, 0.7}, {0, 1, 0})
	
	local mountainRocksHeightMap = mkTemp:Get()
	layers:Pwconst(heightMap, mountainRocksHeightMap, {mountainLowerLimit + (mountainUpperLimit - mountainLowerLimit) * 0.4, mountainUpperLimit}, {0, 1, 0})
	layers:Mul(mountainRocksHeightMap, mountainRocksMap, mountainRocksMap)
	mkTemp:Restore(mountainRocksHeightMap)
	
	local mountainRocksSlopeMap = mkTemp:Get()
	layers:Pwconst(slopeMap, mountainRocksSlopeMap, {0.15}, {1, 0})
	layers:Mul(mountainRocksSlopeMap, mountainRocksMap, mountainRocksMap)
	mkTemp:Restore(mountainRocksSlopeMap)

	-- build final rocks map
	local rocksMap = mkTemp:Get()
	layers:Add(mountainRocksMap, riverRocksMap, rocksMap)
	mkTemp:Restore(mountainRocksHeightMap)
	mkTemp:Restore(mountainRocksMap)
	
	mkTemp:Restore(riverTreesMask)
	mkTemp:Restore(slopeMap)
	mkTemp:Restore(heightCutoffMap)
	
	return forestMap, treesMapping, rocksMap, assetsMapping
end

return data