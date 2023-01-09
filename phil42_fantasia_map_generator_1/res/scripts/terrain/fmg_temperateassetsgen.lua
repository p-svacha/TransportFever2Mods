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
	
	
	-- #### Scattered Trees
	local rocksMap = mkTemp:Get()
	local forestMap = mkTemp:Get()
	layers:PerlinNoise(forestMap, {frequency = 10000})

	return forestMap, treesMapping, rocksMap, assetsMapping
end

return data