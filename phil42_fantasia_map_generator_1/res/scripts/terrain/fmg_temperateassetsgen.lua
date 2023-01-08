local data = {}

data.Make = function(layers, config, mkTemp, heightMap, ridgesMap, distanceMap)

	-- #################
	-- #### PARAMS
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

	-- #################
	-- #### CONFIG
	local noWater = config.water == 0
	
	-- LEVEL 1: Plain trees seed density
	-- Patch sizes and densities
	local seedDensity = 0.00008 - 0.0001 * config.humidity * config.humidity + 0.0001 -- increase to increase number of forest
	local permeability = 0.51 + math.sqrt(config.humidity) * 0.12 - 0.19 -- overall size of forest
	local permeabilityVariance = 1.3 -- variability in size of forest
	-- Densities and composition
	local plainTreeVals = {0.2}
	local plainTreeTypes = { plains, 0}

	-- LEVEL 2: River trees
	-- Distances
	local treeBaseDistanceFromRiver = 20 -- min offset of noise [m] (negative, starts from dist)
	local treeDistanceFromRiver = 50 -- max offset of noise [m]
	local treeMinDistanceFromRiver = 10 -- [m]
	-- Densities and composition
	local riverTreeVals = {0.2}
	local riverTreeTypes = { river, 0}

	-- LEVEL 3: Hill trees
	-- Densities and composition
	local hillTreeVals = { 0.82 }
	local hillTreeTypes = { 0, hills}
	-- Heights
	local hillsHighLimit = 130 -- absolute [m]

	-- LEVEL 4: Ridge trees (conifers)
	-- Densities
	local maxSlope = 0.8 -- also for hills
	local coniferDitheringCutoff = 0.6
	-- Heights
	local coniferLimit = 120 -- absolute [m] (where conifers have full density)
	local coniferTransitionLow = 30 -- transition size [m] (offset for conifers start)
	local coniferTransitionHigh = 80 -- transition size [m] (offset for conifer end)
	
	
	-- #################
	-- #### NO WATER GENERATION
	if config.humidity == -1 then
		local forestMap = mkTemp:Get()
		local rocksMap = mkTemp:Get()
		layers:Constant(forestMap, 0)
		layers:Constant(rocksMap, -1)
		return forestMap, treesMapping, rocksMap, assetsMapping
	end
	
	-- #################
	-- #### LEVEl 0 - scattered trees
	local tempMap = mkTemp:Get()
	layers:Map(ridgesMap, tempMap, {40, 100}, {0.002, 0}, true)
	layers:WhiteNoiseNonuniform(tempMap, tempMap)
	
	-- #################
	-- #### PREPARE DITHERING 
	local ditheringMap = mkTemp:Get()
	local ditheringMap2 = mkTemp:Get()
	layers:Dithering(ditheringMap, "LOCAL")
	layers:Dithering(ditheringMap2, "LOCAL"):SetSeed(math.random())
	
	-- #################
	-- #### LEVEL 1 - plains
	-- Background noise (permeability)
	-- Impermeable rivers
	local probabilityMap = mkTemp:Get()
	if noWater then
		layers:Constant(probabilityMap, permeability * 0.5)
	else
		layers:Pwlerp(distanceMap, probabilityMap,
			{-5, 0, 0.1, treeDistanceFromRiver, 300.1},
			{0, 0, 0.7 * permeability, permeability, permeability}
		)
	end
	
	-- Variance in size
	local yMap = mkTemp:Get()
	layers:PerlinNoise(yMap, {})
	
	layers:Map(yMap, yMap, {0, 2.5}, {1.0, permeabilityVariance}, true)
	layers:Mul(probabilityMap, yMap, probabilityMap)
	
	-- Generate permeability
	layers:WhiteNoiseNonuniform(probabilityMap, probabilityMap)
	
	-- Seeds
	if noWater then
		layers:Constant(yMap, 2*seedDensity)
	else
		layers:Pwlerp(distanceMap, yMap, 
			{-5, 0, 0.1, 200.1, 300.1},
			{0, 0, 2*seedDensity, seedDensity, seedDensity}
		)
	end

	local forestMap = mkTemp:Get()
	layers:WhiteNoiseNonuniform(yMap, forestMap)
	yMap = mkTemp:Restore(yMap)
	
	-- Invert seeds  for input in percolation
	layers:Map(forestMap, forestMap, {0, 1}, {0, -1})
	-- Percolate
	layers:Percolation(probabilityMap, forestMap, forestMap, {
		noiseThreshold = 0.5,
		seedThreshold = -0.5,
		maxCluster = 333
	})
	-- Embiggen
	layers:Distance(forestMap, forestMap)
	layers:Map(ridgesMap, probabilityMap, {20, 40}, {1, 100}, true)
	layers:Add(probabilityMap, forestMap, forestMap)
	layers:Pwconst(forestMap, forestMap, {10},  {1, 0})
	
	-- Content for mask
	layers:Pwconst(ditheringMap, probabilityMap, plainTreeVals, plainTreeTypes)
	
	-- Reduce density
	layers:Mask(forestMap, probabilityMap, forestMap)
	
	-- #################
	-- #### LEVEL 0 AND 1 MIX
	layers:Map(tempMap, tempMap, {0, 1}, {0, anyTree}, true)
	layers:Mask(tempMap, tempMap, forestMap)

	-- SLOPE CUTOFF
	layers:Grad(heightMap, tempMap, 2)
	local slopeCutoffMap = mkTemp:Get()
	layers:Pwconst(tempMap, slopeCutoffMap, {maxSlope}, {1, 0})

	-- #################
	-- #### LEVEL 3 : Hill Trees
	-- Cutoff from above and below
	layers:Pwlerp(ridgesMap, tempMap,
		{config.hillsLowLimit - 10, config.hillsLowLimit, config.hillsLowLimit + config.hillsLowTransition, config.hillsLowLimit + config.hillsLowTransition + 60},
		{0, 0, 1, 1}
	)
	layers:Pwconst(heightMap, probabilityMap, {hillsHighLimit}, {1, 0})
	layers:Mul(probabilityMap, tempMap, tempMap)
	
	-- Slope cutoff
	layers:Mul(slopeCutoffMap, tempMap, probabilityMap)
	
	-- Content for mask
	layers:Compare(probabilityMap, ditheringMap2, probabilityMap)
	
	layers:Pwconst(ditheringMap, tempMap, hillTreeVals, hillTreeTypes)
	layers:Mul(tempMap, probabilityMap, probabilityMap)
	
	layers:Mask(probabilityMap, probabilityMap, forestMap)
	
	-- #################
	-- #### LEVEL 4 : Mountain Trees
	-- HEIGHT CUTOFF
	layers:Pwlerp(heightMap, tempMap,
		{0, coniferLimit - coniferTransitionLow, coniferLimit, config.treeLimit, config.treeLimit + coniferTransitionHigh, config.treeLimit + coniferTransitionHigh + 20},
		{0, 0, coniferDitheringCutoff, coniferDitheringCutoff, 0, 0}
	)
	layers:Compare(tempMap, ditheringMap2, tempMap)
	ditheringMap2 = mkTemp:Restore(ditheringMap2)
	
	-- EDGE DETECTIION
	local rocksMap = mkTemp:Get()
	layers:Laplace(ridgesMap, rocksMap)
	
	do
		local temp2Map = mkTemp:Get()
		layers:Pwlerp(ridgesMap, temp2Map, {0, 4, 10, 20}, {0, 0, 1, 1})
		
		layers:Mul(rocksMap, temp2Map, rocksMap)
		temp2Map = mkTemp:Restore(temp2Map)
	end
	
	layers:Pwconst(rocksMap, rocksMap,
		{-config.ridgeFactor, config.valleyFactor},
		{ conifer, 0, conifer}
	)
	-- BLEND SLOPE, HEIGHT AND RIDGE
	layers:Mul(rocksMap, tempMap, rocksMap)
	tempMap = mkTemp:Restore(tempMap)
	
	layers:Mad(rocksMap, slopeCutoffMap, forestMap)
	
	if not noWater then 
		-- LEVEL 2 : river trees
		local yMap = mkTemp:Get()
		layers:GradientNoise(yMap, { octaves = 4, warp = 0.5, lacunarity = 1.4, gain = 2.2})
		
		layers:Map(yMap, yMap, {0, 10}, {0, treeDistanceFromRiver}, true)
		local xMap = mkTemp:Get()
		layers:Pwconst(distanceMap, xMap, {0, treeMinDistanceFromRiver}, {0, 0, 1})
		
		layers:Add(distanceMap, yMap, yMap)
		
		layers:Pwconst(yMap, yMap, {0, treeDistanceFromRiver}, {0, 1, 0})
		layers:Pwconst(ditheringMap, probabilityMap, riverTreeVals, riverTreeTypes)
		
		layers:Mul(xMap, yMap, yMap)
		layers:Mask(yMap, probabilityMap, forestMap, 0, "GREATER")
		mkTemp:Restore(yMap)
		mkTemp:Restore(xMap)
	end
	ditheringMap = mkTemp:Restore(ditheringMap)
	probabilityMap = mkTemp:Restore(probabilityMap)

	-- #################
	-- ####  ROCKS
	layers:WhiteNoise(rocksMap, 0.005)
	
	-- Stones on beach
	local layerBeach_maxDistance = 20
	local layerBeach_gain = 1.2
	
	local tempRocksMap = mkTemp:Get()
	layers:Map(distanceMap, tempRocksMap, { 0, layerBeach_maxDistance }, { 3.3, 0}, true)
	
	local noise2Map = mkTemp:Get()
	layers:RidgedNoise(noise2Map, { octaves = 3, lacunarity = 10.5, frequency = 1.0 / 1000.0, gain = layerBeach_gain})
	
	layers:Map(noise2Map, noise2Map, { 0.2, 0.8 }, { -1, 1}, true)
	
	layers:Add(tempRocksMap, noise2Map, tempRocksMap)
	layers:Map(distanceMap, noise2Map, { 0, layerBeach_maxDistance * 2 }, { 2.0, 0}, true)
	layers:Mul(noise2Map, tempRocksMap, tempRocksMap)
	noise2Map = mkTemp:Restore(noise2Map)
	
	layers:Mul(tempRocksMap, distanceMap, tempRocksMap)
	distanceMap = mkTemp:Restore(distanceMap)
	
	do
		local noise3Map = mkTemp:Get()
		layers:WhiteNoise(noise3Map, 0.25)
		
		layers:Mul(noise3Map, tempRocksMap, tempRocksMap)
		noise3Map = mkTemp:Restore(noise3Map)
	end
	
	layers:Add(tempRocksMap, rocksMap, rocksMap)
	tempRocksMap = mkTemp:Restore(tempRocksMap)
	
	layers:Mul(slopeCutoffMap, rocksMap, rocksMap)
	local slopeCutoffMap = mkTemp:Restore(slopeCutoffMap)
	
	layers:Pwconst(rocksMap, rocksMap, {0.5}, {0, 1})
	
	return forestMap, treesMapping, rocksMap, assetsMapping
end

return data