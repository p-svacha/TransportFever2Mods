local mapgenutil = require "terrain/fmg_mapgenutil"
local temperateassetsgen = require "terrain/fmg_temperateassetsgen"
local layersutil = require "terrain/layersutil"
local desertlayers = require "terrain/desertlayers"
local maputil = require "maputil"
local vec2 = require "vec2"

function data() 

return {
	climate = "temperate.clima.lua",
	order = 0,
	name = _("Fantasia Map Generator"),
	params = {
		{
			key = "coastalLakesAmount",
			name = _("Lakes"),
			values = {"", "", "", "", ""},
			defaultIndex = 2,
			uiType = "SLIDER",
		},
		{
			key = "coastalLakesSize",
			name = _("Lake Size"),
			values = {"", "", "", "", "", "", "", "", ""},
			defaultIndex = 4,
			uiType = "SLIDER",
		},
		{
			key = "riversAmount",
			name = _("Rivers"),
			values = {"", "", "", "", ""},
			defaultIndex = 2,
			uiType = "SLIDER",
		},
		{
			key = "mountainRidgesAmount",
			name = _("Mountains"),
			values = {"", "", "", "", "", "", "", "", ""},
			defaultIndex = 4,
			uiType = "SLIDER",
		},
		{
			key = "mountainRidgesPeakHeight",
			name = _("Mountain Height"),
			values = {"", "", "", "", "", "", "", "", ""},
			defaultIndex = 4,
			uiType = "SLIDER",
		},
		{
			key = "canyons",
			name = _("Coastal Cliffs"),
			values = { "", "", "", "", "", "", "" },
			defaultIndex = 3,
			uiType = "SLIDER",
		},
		{
			key = "plateausAmount",
			name = _("Plateaus"),
			values = { "", "", "", "", "", "", "" },
			defaultIndex = 3,
			uiType = "SLIDER",
		},
		{
			key = "flatAreasAmount",
			name = _("Flattened Areas"),
			values = { "", "", "", "", "", "", "" },
			defaultIndex = 3,
			uiType = "SLIDER",
		},		
		{
			key = "forestAmount",
			name = _("Forests"),
			values = { "", "", "", "", "", "", "" },
			defaultIndex = 3,
			uiType = "SLIDER",
		},
	},
	updateFn = function(params)
		-- local temperateassetsgen = dofile("./res/scripts/terrain/temperateassetsgen.lua")
		-- local mapgenutil = dofile("./res/scripts/terrain/mapgenutil.lua")
		-- local layersutil = dofile("./res/scripts/terrain/layersutil.lua")
		local result = {
			parallelFactor = 32,
			heightmapLayer = "HM",
			layers = layersutil.Layer.new(),
		}	

		-- ###########################################################################################################
		-- #### PARAMS
		-- ###########################################################################################################

		local coastalLakesAmount = params.coastalLakesAmount
		local coastalLakesSize = params.coastalLakesSize
		local mountainRidgesAmount = params.mountainRidgesAmount
		local mountainRidgesPeakHeight = params.mountainRidgesPeakHeight
		local riversAmount = params.riversAmount
		local canyon = params.canyons / 6 + 0.2
		local plateausAmount = params.plateausAmount
		local flatAreasAmount = params.flatAreasAmount
		local forestAmount = params.forestAmount

		-- ###########################################################################################################
		-- #### INITIALIZE
		-- ###########################################################################################################

		local sameSeed = math.random(1, 100000000)
		math.randomseed(sameSeed) -- reset seed to match desert generator
		
		-- heightmapLayer does not get cleared automatically the map editor
		result.layers:Constant(result.heightmapLayer, 0)

		local mkTemp = layersutil.TempMaker.new()

		local baseHeight = 1
		local mapSize = params.mapSizeX * params.mapSizeY

		-- ###########################################################################################################
		-- #### FUNCTIONS
		-- ###########################################################################################################

		-- Helper function that converts linear blending to exponential
		local Exlerp = function(from, to, subdivisions)
			local step = 1 / subdivisions
			local count = subdivisions
			
			local a = {}
			local b = {}
			
			for i = 0, count, 1 do
				a[i] = i * step
				b[i] = a[i]^2
			end
			
			result.layers:Pwlerp(from, to, a, b)
		end

		-- Returns a single perlin map according to the given parameters
		local addPerlinNoise = function(targetMap, _frequency, minHeight, maxHeight)
			local tempMap = mkTemp:Get()
			local params = {
				frequency = _frequency,
			}
			result.layers:PerlinNoise(tempMap, params)
			result.layers:Map(tempMap, tempMap, {-1.5, 1.5}, {minHeight, maxHeight}, true)
			result.layers:Add(tempMap, targetMap, targetMap)
			mkTemp:Restore(tempMap)
		end

		-- Returns a Noise for mountain ranges (very straight and spaces in between)
		local addGradientNoise = function(targetMap, _numOctaves, _frequency, _lacunarity, _gain, _warp, minHeight, maxHeight)
			local tempMap = mkTemp:Get()
			local params = {
				octaves = _numOctaves,
				frequency = _frequency,
				lacunarity = _lacunarity,
				warp = _warp,
				gain = _gain
			}
			result.layers:GradientNoise(tempMap, params)
			result.layers:Map(tempMap, tempMap, {0, 1.8}, {minHeight, maxHeight}, true)
			result.layers:Add(tempMap, targetMap, targetMap)
			mkTemp:Restore(tempMap)
		end

		-- Returns a Noise for mountain ranges but more varied
		local addRidgedNoise = function(targetMap, _numOctaves, _frequency, _lacunarity, _gain, minHeight, maxHeight)
			local tempMap = mkTemp:Get()
			local params = {
				octaves = _numOctaves,
				frequency = _frequency,
				lacunarity = _lacunarity,
				gain = _gain
			}
			result.layers:RidgedNoise(tempMap, params)
			result.layers:Map(tempMap, tempMap, {0, 1}, {minHeight, maxHeight}, true)
			result.layers:Add(tempMap, targetMap, targetMap)
			mkTemp:Restore(tempMap)
		end

		-- Returns a layered perlin map according to the given parameters
		local addLayeredPerlinNoise = function(targetMap, numOctaves, startFrequency, lacunarity, persistence, minHeight, maxHeight)
		
			local perlinMap = mkTemp:Get()

			local currentFrequency = startFrequency
			local currentMinHeight = minHeight
			local currentMaxHeight = maxHeight

			for i = 1, numOctaves do
				addPerlinNoise(perlinMap, currentFrequency, currentMinHeight, currentMaxHeight)
				currentFrequency = currentFrequency * lacunarity
				currentMinHeight = currentMinHeight * persistence
				currentMaxHeight = currentMaxHeight * persistence
			end

			result.layers:Map(perlinMap, perlinMap, {minHeight * 2, maxHeight * 2}, {minHeight, maxHeight}, false)
			result.layers:Add(perlinMap, targetMap, targetMap)
			

			mkTemp:Restore(perlinMap)
		end

		-- Returns a layered perlin map according to the given parameters
		local getLayeredPerlinNoise = function(numOctaves, startFrequency, lacunarity, persistence, minHeight, maxHeight)

			local perlinMap = mkTemp:Get()
			result.layers:Constant(perlinMap, 0)

			local currentFrequency = startFrequency
			local currentHeight = 1
			local maxPossibleHeight = 0

			for i = 1, numOctaves do
				local tempPerlin = mkTemp:Get()
				result.layers:PerlinNoise(tempPerlin, {frequency = currentFrequency})
				result.layers:Map(tempPerlin, tempPerlin, {-1.5, 1.5}, {0, currentHeight}, true)
				result.layers:Add(tempPerlin, perlinMap, perlinMap)
				mkTemp:Restore(tempPerlin)

				maxPossibleHeight = maxPossibleHeight + currentHeight
				currentFrequency = currentFrequency * lacunarity
				currentHeight = currentHeight * persistence		
			end

			result.layers:Map(perlinMap, perlinMap, {0, maxPossibleHeight}, {minHeight, maxHeight}, false)

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
			result.layers:Constant(mask, 0)
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

			result.layers:Pwlerp(tempDist, mask, {-99999, blendingMin, min, max, blendingMax, 99999}, {0, 0, 1, 1, 0, 0})
			--Exlerp(mask, mask, 50) -- convert linear to exponential blending

			mkTemp:Restore(tempDist)
			
			return mask
		end

		-- ###########################################################################################################
		-- #### STEP 1 - Land / Water Distribution
		-- ###########################################################################################################

		-- ##################### Flat Base
		result.layers:Constant(result.heightmapLayer, baseHeight)

		-- ##################### Create Water mask
		local map_water_mask = mkTemp:Get() -- All terrain changes applied to water should use this mask!

		-- ##################### Lakes
		local numLakes = (mapSize * coastalLakesAmount / 9000000)
		numLakes = math.round(numLakes, 1)
		debugPrint("Creating " .. numLakes .. " Coastal Lakes")

		for pts = 1, numLakes do
			local map_lakes_mask = mkTemp:Get()
			result.layers:Constant(map_lakes_mask, 1)

			
			local lakeCoverage = 0.3 + (coastalLakesSize * 0.04) + ((mapSize / 9000000) * 0.015)
			local lakeIslandAmount = 0.35

			local lakeOriginPoints = {}
			
			local px = math.random(0, params.mapSizeX)
			local py = math.random(0, params.mapSizeY)
			lakeOriginPoints[#lakeOriginPoints + 1] = { px, py }			

			local noiseMap = mkTemp:Get()
			result.layers:WhiteNoise(noiseMap, 0.419 - (lakeCoverage * 0.02)) -- 0.399 - 0.419 are valid values
			result.layers:Points(map_lakes_mask, lakeOriginPoints, 	-1)
			result.layers:Percolation(noiseMap, map_lakes_mask, map_lakes_mask, {
				seedThreshold = -0.5,
				noiseThreshold = 0.5,
				maxCluster = 20000 - (lakeIslandAmount * 19000),
			})

			mkTemp:Restore(noiseMap)

			-- add to water mask
			result.layers:Add(map_lakes_mask, map_water_mask, map_water_mask)
			mkTemp:Restore(map_lakes_mask)
			end

		-- ##################### River Preparation	
		local numRivers = 0.15 + (mapSize * riversAmount / 12000000)
		numRivers = math.round(numRivers, 1)
		debugPrint("Creating " .. numRivers .. " Rivers")

		  local riverStartPoints = {{}}
		  local riverStartAngles = {}
		  for i = 1, numRivers do
			  local px = math.random(0, params.mapSizeX)
			  local py = math.random(0, params.mapSizeY)
			  riverStartPoints[#riverStartPoints + 1] = {{ px, py }}
			  riverStartAngles[#riverStartAngles + 1] = math.random(0, 360)
		  end

		-- ##################### Rivers
		local map_rivers_mask = mkTemp:Get()
		result.layers:Constant(map_rivers_mask, 1)

		local rivers = {}
		local start = mapgenutil.FindGoodRiverStart(params.bounds)

		local additionalSegmentsFromMapSize = (mapSize / 9000000) * 2.5
		additionalSegmentsFromMapSize = math.clamp(0, 10)
		additionalSegmentsFromMapSize = math.round(additionalSegmentsFromMapSize, 1)
		local minNumSegments = 15
		local maxNumSegments = 35 + additionalSegmentsFromMapSize

		local additionalWidthFromMapSize = (mapSize / 9000000) * 200
		additionalSegmentsFromMapSize = math.clamp(0, 1000)
		additionalSegmentsFromMapSize = math.round(additionalSegmentsFromMapSize, 1)
		local minStartWidth = 120
		local maxStartWidth = 200 + additionalWidthFromMapSize

		for i = 1, numRivers do

			local riverConfig = {
				depthScale = 2.2,
				maxOrder = 10,
				numSegments = math.random(minNumSegments, maxNumSegments),
				segmentLength = math.random(500, 700),
				bounds = params.bounds,
				baseProbability = 0.5,
				minDist = 0,
				startWidth = math.random(minStartWidth, maxStartWidth),
				endWidth = math.random(20, 45),
				curvature = math.random(200, 800) / 1000,
				is_winding = math.random() < 0.5 and true or false
			  }

			-- convert start point on noise map to start point for river (they use different dimensions for some reason)
			local px = (riverStartPoints[i + 1][1][1] * 4) - (params.bounds.max.x)
			local py = (riverStartPoints[i + 1][1][2] * 4) - (params.bounds.max.y)
			local startPos = vec2.new(px, py)
			mapgenutil.MakeRivers(rivers, riverConfig, 120000, startPos, riverStartAngles[i])
		end

		maputil.Convert(rivers)
		maputil.ValidateRiver(rivers)
		result.layers:River(map_rivers_mask, rivers)
		result.layers:Map(map_rivers_mask, map_rivers_mask, {1, 0}, {0, 1}, false)

		-- add to water mask
		result.layers:Add(map_rivers_mask, map_water_mask, map_water_mask)
		mkTemp:Restore(map_rivers_mask)

		-- ##################### River End Lakes
		local minLakeSize = (150 + ((mapSize / 9000000) * 450)) * (1 + ((coastalLakesSize - 2) * 0.1))
		local maxLakeSize = (300 + ((mapSize / 9000000) * 800)) * (1 + ((coastalLakesSize - 2) * 0.1))

		for i = 1, numRivers do
			local lake_size = math.random(minLakeSize, maxLakeSize)

			local map_river_lakes_mask = mkTemp:Get()
			result.layers:Constant(map_river_lakes_mask, 1)

			-- take real river start point as lake source
			result.layers:Points(map_river_lakes_mask,  riverStartPoints[i + 1], 0)
			
			result.layers:Distance(map_river_lakes_mask, map_river_lakes_mask)

			-- add detail so it's not completely round

			local map_river_lake_detail = mkTemp:Get() -- small for interesting shoreline
			addLayeredPerlinNoise(map_river_lake_detail, 5, 1 / 2000, 2, 0.7, -lake_size / 2, lake_size / 2)
			result.layers:Add(map_river_lake_detail, map_river_lakes_mask, map_river_lakes_mask)
			mkTemp:Restore(map_river_lake_detail)

			local map_river_lake_detail2 = mkTemp:Get() -- big so the shape isn't so roundish
			addLayeredPerlinNoise(map_river_lake_detail2, 1, 1 / 10000, 2, 0.5, -lake_size, lake_size)
			result.layers:Add(map_river_lake_detail2, map_river_lakes_mask, map_river_lakes_mask)
			mkTemp:Restore(map_river_lake_detail2)

			-- map it to make it a valid mask
			result.layers:Map(map_river_lakes_mask, map_river_lakes_mask, {0, lake_size}, {0,1}, true)

			result.layers:Map(map_river_lakes_mask, map_river_lakes_mask, {0,1}, {1,0}, true) -- invert

			-- make sure there are only 0 and 1 values with Compare
			local map_comparator = mkTemp:Get()
			result.layers:Constant(map_comparator, 0)
			result.layers:Compare(map_river_lakes_mask, map_comparator, map_river_lakes_mask, "GREATER")
			mkTemp:Restore(map_comparator)

			 -- add to water mask
			result.layers:Add(map_river_lakes_mask, map_water_mask, map_water_mask)
			mkTemp:Restore(map_river_lakes_mask)
		end

		-- make sure there are only 0 and 1 values in the water mask (needs to be at the end!)
		local map_comparator = mkTemp:Get()
		result.layers:Constant(map_comparator, 0)
		result.layers:Compare(map_water_mask, map_comparator, map_water_mask, "GREATER")
		mkTemp:Restore(map_comparator)

		-- ##################### Create Land mask
		local landMaskGradientWidth = 600 -- over how big of a width the terrain can start being raised around water
		local maxCoastalPlaneWidth = 600

		local map_land_mask = mkTemp:Get() -- All terrain changes applied to land should use this mask!
		result.layers:Map(map_water_mask, map_land_mask, {1, 0}, {0, 1}, true)
		result.layers:Distance(map_land_mask, map_land_mask)

		-- add some detail that creates coastal planes in some areas of the map
		local map_land_mask_detail_big = getLayeredPerlinNoise(5, 1 / 800, 2, 0.5, -maxCoastalPlaneWidth, maxCoastalPlaneWidth / 4) -- broad detail that creates coastal planes in some areas of the map
		result.layers:Add(map_land_mask_detail_big, map_land_mask, map_land_mask)
		mkTemp:Restore(map_land_mask_detail_big)

		-- convert into valid mask
		result.layers:Map(map_land_mask, map_land_mask, {0, landMaskGradientWidth}, {0, 1}, true)
		result.layers:Herp(map_land_mask, map_land_mask, {0, 1}) -- convert linear interpolation to smooth

		-- JUST TO TEST the land mask
		--result.layers:Map(map_land_mask, map_land_mask, {0, 1}, {0, 100}, true)
		--result.layers:Add(map_land_mask, result.heightmapLayer, result.heightmapLayer) 
		--result.layers:Map(map_land_mask, map_land_mask, {0, 1}, {0, 1}, true)


		-- ##################### Water
		local map_water = mkTemp:Get()

		result.layers:Distance(map_water_mask, map_water)
		result.layers:Map(map_water, map_water, {0, 1}, {0, -0.1}, false)

		result.layers:Add(map_water, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap
		mkTemp:Restore(map_water)

		-- ##################### Land Distance Map (helper)
		local map_land_distance = mkTemp:Get() -- map where values are equal to how they close the point is to water
		result.layers:Distance(result.heightmapLayer, map_land_distance)

		-- ###########################################################################################################
		-- #### STEP 2 - Land Features - consisting of following layers:
		-- #### Canyons
		-- #### Very Rare Extra High Mountains Peaks
		-- #### Rare Average Mountains
		-- #### Rolling Hills
		-- #### Mesa / Tafelberg
		-- #### Soft Dunes
		-- #### Soft Rolling Hills Offset
		-- #### Dunes
		-- #### Classic Mountain Ridges
		-- #### Ripples
		-- #### High Elevation Areas
		-- ###########################################################################################################

		-- ##################### Canyons / Coastal Cliffs
		local canyonMap = mkTemp:Get()

		local canyonWidth = 0.9 -- how much space there is in between the cliffs
		local canyonHeight = 0.22 -- how high the cliffs are
		local canyonDistance = 9500
		
		local canyonMapSizeX = math.max(math.ceil(params.mapSizeX / 1000 * 2), 2)
		local canyonMapSizeY = math.max(math.ceil(params.mapSizeY / 1000 * 2), 2)
		local canyonMapScale = { 1 / (params.mapSizeX / 1000 * 2 / 6), 1 / (params.mapSizeY / 1000 * 2 / 6) }
		local canyonDataMap = maputil.MakePerlin(
			canyonMapSizeX, canyonMapSizeY, canyonMapScale,
			{ params.mapSizeX / (canyonMapSizeX - 1), params.mapSizeY / (canyonMapSizeY - 1) }
		)

		local canyonProbLow =  math.map(canyon, 0, 1, 0.7, -0.3) -- , 0.7, -0.3)
		local canyonProbHigh =  math.map(canyon, 0, 1, 1.2, 0.2) -- , 1.1, 0.1)

		local canyonConfig = {
			canyonWidthScaling = canyonWidth, 
			canyonDistanceOffset = -15,
			canyonHeightScaling = canyonHeight,
			canyonProbLow = canyonProbLow,
			canyonProbHigh = canyonProbHigh,
			canyonness = canyon
		}
		

		local distanceMap = mkTemp:Get()
		result.layers:Distance(result.heightmapLayer, distanceMap)
		
		result.layers:Data(canyonMap, canyonDataMap, "BICUBIC")
		
		result.layers:Map(canyonMap, canyonMap, {canyonProbLow, canyonProbHigh}, {0, 1}, true)
		
		result.layers:Herp(canyonMap, canyonMap, {0, 1})-- convert linear interpolation to smooth
		
		local cutoff = mkTemp:Get()
		result.layers:Map(distanceMap, cutoff, {0, canyonDistance}, {1, 0}, true)
		
		local t1 = mkTemp:Get()
		result.layers:Gauss(cutoff, t1, 3)
		
		result.layers:Herp(t1, cutoff, {0, 1})-- convert linear interpolation to smooth
		t1 = mkTemp:Restore(t1)
		
		result.layers:Mul(cutoff, canyonMap, canyonMap)
		result.layers:Map(canyonMap, cutoff, {1, 0})
		
		desertlayers.MakeCanyonLayer(result.layers, mkTemp, canyonConfig, canyonMap, distanceMap, result.heightmapLayer) -- add to final heightmap

		mkTemp:Restore(distanceMap)
		mkTemp:Restore(canyonMap)
		mkTemp:Restore(cutoff)

		-- ##################### Very Rare Extra High Mountains Peaks (credits to Terrain Fever mod by Haviland)
		local hm_final = mkTemp:Get()
		local hm_minHeight = 75
		local hm_maxHeight = 550
		

		local hm_density = 1 -- 1..2
		local hm_height = 0.75 -- 0..1
		local hm_detail = 12 -- 4..20
		local hm_detailStrength = 5
		local hm_highVariation = 1 -- 0..1
		
		-- create basic mountains
		local hm_ridgesConfig = {
			bounds = params.bounds, 
			probabilityLow = 0.3,
			probabilityHigh = 0.5, 
			minHeight = hm_minHeight * hm_height, 
			maxHeight = hm_maxHeight * hm_height,
			density = hm_density
		}

		local hm_valleys = {}
		local hm_ridges = mapgenutil.MakeRidges(hm_ridgesConfig)
		
		local hm_ridge = mkTemp:Get()
		result.layers:Ridge(hm_ridge, {
			valleys = hm_valleys.points,
			ridges = hm_ridges,
			noiseStrength = hm_detail 
		})

		
		-- create details
		local hm_detailMap = mkTemp:Get()
		
		-- create details in high mountain regions
		local hm_heightDetailConfig = {
			numOctaves = 8,
			frequency = 1 / 150,
			lacunarity = 2,
			gain = 0.5,
		}
		local hm_heightDetail = mkTemp:Get()
		local hm_heightDetailMask = mkTemp:Get()
		
		result.layers:RidgedNoise(hm_heightDetail, hm_heightDetailConfig)
		result.layers:Map(hm_ridge, hm_heightDetailMask, {hm_ridgesConfig.minHeight, hm_ridgesConfig.maxHeight}, {0, hm_detailStrength}, true)
		result.layers:Mul(hm_heightDetail, hm_heightDetailMask, hm_heightDetail)
		result.layers:Add(hm_heightDetail, hm_detailMap, hm_detailMap)
		
		-- create details in lower regions
		local hm_lowDetail = mkTemp:Get()
		local hm_lowDetailMask = mkTemp:Get()
		local tempNoise1 = mkTemp:Get()
		local tempNoise2 = mkTemp:Get()
		
		result.layers:Constant(hm_lowDetail, hm_ridgesConfig.minHeight)
		
		-- fine details
		result.layers:RidgedNoise(tempNoise1, { octaves = 5, frequency = 1 / 900, lacunarity = 2.2, gain = 0.8 } )
		result.layers:Map(tempNoise1, tempNoise1, {-1, 1}, {-7, 7}, true)
		result.layers:Add(tempNoise1, hm_lowDetail, hm_lowDetail)
		
		-- coarse details
		result.layers:PerlinNoise(tempNoise2, { frequency = 1 / 1500 })
		result.layers:Map(tempNoise2, tempNoise2, {-1, 1}, {-20, 20}, true)
		result.layers:Add(tempNoise2, hm_lowDetail, hm_lowDetail)
		
		-- blend details
		result.layers:Map(hm_ridge, hm_lowDetailMask, {hm_ridgesConfig.minHeight, hm_ridgesConfig.maxHeight}, {1, 0}, true)
		result.layers:Mul(hm_lowDetail, hm_lowDetailMask, hm_lowDetail)
		result.layers:Add(hm_lowDetail, hm_detailMap, hm_detailMap)
	
		
		-- build basic mountain map
		result.layers:Add(hm_detailMap, hm_ridge, hm_final)
		
		-- add mountain high variations
		local hm_highVariationNoise = mkTemp:Get()
		result.layers:PerlinNoise(hm_highVariationNoise, {frequency = 1 / 3000})
		result.layers:Map(hm_highVariationNoise, hm_highVariationNoise, {-1, 1}, {hm_highVariation, 1}, true)
		result.layers:Mul(hm_highVariationNoise, hm_final, hm_final)
		
		mkTemp:Restore(hm_ridge)
		mkTemp:Restore(hm_lowDetail)
		mkTemp:Restore(hm_lowDetailMask)
		mkTemp:Restore(tempNoise1)
		mkTemp:Restore(tempNoise2)
		mkTemp:Restore(hm_detailMap)			
		mkTemp:Restore(hm_heightDetail)
		mkTemp:Restore(hm_heightDetailMask)
		mkTemp:Restore(hm_highVariationNoise)

		local map_temp_mask = getRandomMask(0.3, 0, 0.1, math.random(4000, 8000), 3)
		result.layers:Herp(map_temp_mask, map_temp_mask, {0, 1}) -- convert linear to smooth interpolation
		result.layers:Mul(hm_final, map_temp_mask, hm_final) -- apply random mask
		mkTemp:Restore(map_temp_mask)

		result.layers:Mul(hm_final, map_land_mask, hm_final) -- apply land mask
		result.layers:Add(hm_final, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap
		mkTemp:Restore(hm_final)

		-- ##################### Rare Average Mountains (credits to Terrain Fever mod by Haviland)
		local am_final = mkTemp:Get()
		local am_minHeight = 40
		local am_maxHeight = 300
		
		local am_detailStrength = 4

		-- create smooth mountains
		local am_smoothMountainsConfig = {
			numOctaves = 9,
			frequency = 1 / 2000,
			lacunarity = 2.5,
			gain = 0.5,
			warp = 0.1
		}
		
		local am_smoothMountains = mkTemp:Get()
		result.layers:GradientNoise(am_smoothMountains, am_smoothMountainsConfig)
		result.layers:Map(am_smoothMountains, am_smoothMountains, {-1, 1.5}, {am_minHeight * 0.7, am_maxHeight * 0.7}, true)
		
		-- create sharp mountains
		local am_ridgesConfig = {
			bounds = params.bounds, 
			probabilityLow = 0.6,
			probabilityHigh = 0.3, 
			minHeight = am_minHeight * 0.3, 
			maxHeight = am_maxHeight * 0.3,
			density = 1
		}

		local am_valleys = {}
		local am_ridges = mapgenutil.MakeRidges(am_ridgesConfig)
		local am_ridge = mkTemp:Get()
		result.layers:Ridge(am_ridge, {
			valleys = am_valleys.points,
			ridges = am_ridges,
			noiseStrength = 10 
		})
		
		-- mix smooth and sharp mountains
		result.layers:Add(am_smoothMountains, am_ridge, am_final)
		
		-- add details
		local am_detailNoise = mkTemp:Get()
		result.layers:PerlinNoise(am_detailNoise, {frequency = 1 / 150})
		result.layers:Map(am_detailNoise, am_detailNoise, {-1, 1}, {0, am_detailStrength}, true)
		result.layers:Add(am_detailNoise, am_final, am_final)
		

		-- blend with basic noise to reduce the total number of mountains
		local am_mult1 = mkTemp:Get()
		result.layers:PerlinNoise(am_mult1, {frequency = 1 / 1500})
		
		local am_mult2Config = {
			numOctaves = 3,
			frequency = 1 / 3500,
			lacunarity = 2,
			gain = 0.8,
			warp = 0.1
		}
		
		local am_mult2 = mkTemp:Get()
		result.layers:GradientNoise(am_mult2, am_mult2Config)
		result.layers:Map(am_mult2, am_mult2, {-2, 2}, {-1, 1}, true)
		
		local am_multFinal = mkTemp:Get()		
		result.layers:Add(am_mult1, am_mult2, am_multFinal)
		result.layers:Map(am_multFinal, am_multFinal, {-1.7, 2}, {0.0, 1}, true)
		result.layers:Mul(am_final, am_multFinal, am_final)
		
		mkTemp:Restore(am_smoothMountains)
		mkTemp:Restore(am_ridge)
		mkTemp:Restore(am_detailNoise)
		mkTemp:Restore(am_mult1)
		mkTemp:Restore(am_mult2)
		mkTemp:Restore(am_multFinal)		
		
		local map_temp_mask = getRandomMask(0.32, 0, 0.2, math.random(4000, 8000), 3)
		result.layers:Herp(map_temp_mask, map_temp_mask, {0, 1}) -- convert linear to smooth interpolation
		result.layers:Mul(am_final, map_temp_mask, am_final) -- apply random mask
		mkTemp:Restore(map_temp_mask)

		result.layers:Mul(am_final, map_land_mask, am_final) -- apply land mask
		result.layers:Add(am_final, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap
		mkTemp:Restore(am_final)

		-- ##################### Rolling Hills that cover some part of the map (credits to Terrain Fever mod by Haviland)
		local rh_final = mkTemp:Get()
		local rh_minHeight = 5
		local rh_maxHeight = 75

		local rh_detailStrength = 3
		
		-- create basic hills
		local rh_hills1 = mkTemp:Get()
		result.layers:PerlinNoise(rh_hills1, {frequency = 1 / 3000})
	
		local rh_hills2 = mkTemp:Get()
		result.layers:PerlinNoise(rh_hills2, {frequency = 1 / 8000})
	
		result.layers:Mul(rh_hills1, rh_hills2, rh_final)
		result.layers:Map(rh_final, rh_final, {-1, 1}, {rh_minHeight, rh_maxHeight}, true)
		
		-- add some detail
		local rh_detailNoise = mkTemp:Get()
		result.layers:PerlinNoise(rh_detailNoise, {frequency = 1 / 400})
		result.layers:Map(rh_detailNoise, rh_detailNoise, {-1, 1}, {-rh_detailStrength/2, rh_detailStrength/2}, true)
		result.layers:Add(rh_detailNoise, rh_final, rh_final)
		
		mkTemp:Restore(rh_hills1)
		mkTemp:Restore(rh_hills2)
		mkTemp:Restore(rh_detailNoise)			

		local map_temp_mask = getRandomMask(0.35, 0, 0.2, math.random(4000, 8000), 3)
		result.layers:Herp(map_temp_mask, map_temp_mask, {0, 1}) -- convert linear to smooth interpolation
		result.layers:Mul(rh_final, map_temp_mask, rh_final) -- apply random mask
		mkTemp:Restore(map_temp_mask)

		result.layers:Mul(rh_final, map_land_mask, rh_final) -- apply land mask
		result.layers:Add(rh_final, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap
		mkTemp:Restore(rh_final)


		-- ##################### Mesa / Tafelberg

		local maxMesaHeight = 180 -- how high the mesas are
		local mesaCoverageArea = 0.36 -- how much of the map the mesas cover
		local mesaSize = math.random(4000, 8000) -- how big the individual mesas are

		local map_mesa = getLayeredPerlinNoise(1, 1 / 2000, 2, 0.5, 0, maxMesaHeight)

		local map_mesa_mask = getRandomMask(mesaCoverageArea, 0, 0.02, mesaSize, 4)
		Exlerp(map_mesa_mask, map_mesa_mask, 50) -- convert linear to exponential interpolation
		result.layers:Mul(map_mesa, map_mesa_mask, map_mesa)
		mkTemp:Restore(map_mesa_mask)

		result.layers:Mul(map_mesa, map_land_mask, map_mesa) -- apply land mask
		result.layers:Add(map_mesa, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap

		mkTemp:Restore(map_mesa)

		-- ##################### Soft dunes covering the whole land
		local softDunesStrength = 15

		local map_soft_dunes = mkTemp:Get()
		result.layers:GradientNoise(map_soft_dunes, {
			octaves = 3, frequency = 1 / 300,
			lacunarity = 0.3, gain = 0.4, warp = 2.6
		})
		result.layers:Map(map_soft_dunes, map_soft_dunes, {0, 1}, {0, softDunesStrength}, true)

		local map_temp_mask = getRandomMask(0.25, 0, 0.35, math.random(4000, 8000), 4)
		result.layers:Mul(map_soft_dunes, map_temp_mask, map_soft_dunes)
		mkTemp:Restore(map_temp_mask)

		result.layers:Mul(map_soft_dunes, map_land_mask, map_soft_dunes) -- apply land mask
		result.layers:Add(map_soft_dunes, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap
		mkTemp:Restore(map_soft_dunes)

		-- ##################### Soft Rolling hills offset covering the whole land
		local map_soft_rolling_hills = getLayeredPerlinNoise(3, 1 / 1000, 2, 0.5, -40, 60)
		result.layers:Mul(map_soft_rolling_hills, map_land_mask, map_soft_rolling_hills) -- apply land mask
		result.layers:Add(map_soft_rolling_hills, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap
		mkTemp:Restore(map_soft_rolling_hills)

		-- ##################### Dunes covering parts of the land

		local dunesStrength = 40 -- how big the dunes are
		local dunesCoverageArea = 0.25 -- how much of the map the dunes cover
		local dunesBlending = 0.35 -- how soft the dunes blend into the areas without them
		local dunesAreasSize = math.random(4000, 12000) -- how big the individual areas containing dunes are 

		local map_scattered_dunes = mkTemp:Get()
		local cutoff = mkTemp:Get()
		result.layers:RidgedNoise(map_scattered_dunes, { frequency = 1 / 3000, octaves = 6, lacunarity = 1.4, gain = 5.4})
		result.layers:Map(map_land_distance, cutoff, {200, 400}, {0, dunesStrength}, true) -- {0, 0.54}
		result.layers:Mul(map_scattered_dunes, cutoff, map_scattered_dunes)
		mkTemp:Restore(cutoff)

		local map_temp_mask = getRandomMask(dunesCoverageArea, 0, dunesBlending, dunesAreasSize, 4)
		result.layers:Mul(map_scattered_dunes, map_temp_mask, map_scattered_dunes)
		mkTemp:Restore(map_temp_mask)

		result.layers:Add(map_scattered_dunes, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap
		mkTemp:Restore(map_scattered_dunes)
		

		-- ##################### Classic Mountain Ridges scattered across the map
		local map_scattered_ridges = mkTemp:Get()

		local ridgesConfig = {
			bounds = params.bounds,
			probabilityLow = 0.02 + (mountainRidgesAmount * 0.06),
			probabilityHigh = 0.02 + (mountainRidgesAmount * 0.06),
			minHeight = 0 + 80 * (mountainRidgesPeakHeight / 10), 
			maxHeight = 75 + 400 * (mountainRidgesPeakHeight / 10),
			angle = math.random(0, 360)
		}

		local ridges = mapgenutil.MakeRidges(ridgesConfig)

		result.layers:Ridge(map_scattered_ridges, {
		  valleys = {},
		  ridges = ridges,
		  noiseStrength = 20 -- default = 10
		})

		result.layers:Mul(map_scattered_ridges, map_land_mask, map_scattered_ridges)
		result.layers:Add(map_scattered_ridges, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap
		mkTemp:Restore(map_scattered_ridges)


		-- ##################### Soft Ripples covering parts of the land
		local map_soft_ridges = mkTemp:Get()

		local noiseStrength = 60 -- how big the ripples are
		local ripplesCoverageArea = 0.25 -- how much of the map the ripples cover
		local ripplesBlending = 0.35 -- how soft the ripples blend into the areas without them
		local ripplesAreasSize = 7000 -- how big the individual areas containing ripples are

		result.layers:RidgedNoise(map_soft_ridges, { octaves = 5, frequency = 1 / 600, lacunarity = 2.2, gain = 0.8 } )
		result.layers:Map(map_soft_ridges, map_soft_ridges, {0, 4}, {0, noiseStrength * 1.2}, false)

		local map_temp_mask = getRandomMask(ripplesCoverageArea, 0, ripplesBlending, ripplesAreasSize, 4)
		result.layers:Mul(map_soft_ridges, map_temp_mask, map_soft_ridges)
		mkTemp:Restore(map_temp_mask)

		result.layers:Mul(map_soft_ridges, map_land_mask, map_soft_ridges)
		result.layers:Add(map_soft_ridges, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap

		mkTemp:Restore(map_soft_ridges)

		-- ##################### High Elevation Areas
		local highElevationCoverage = 0.23 + (plateausAmount * 0.04)
		if plateausAmount == 0 then highElevationCoverage = 0 end
		debugPrint("Plateau Coverage = " .. highElevationCoverage)

		local map_high_areas = getLayeredPerlinNoise(2, 1 / 12000, 2, 0.5, 200, 300)

		local map_temp_mask = getRandomMask(highElevationCoverage, 0, 0.1, 12000, 2)
		result.layers:Herp(map_temp_mask, map_temp_mask, {0, 1}) -- convert linear to smooth interpolation
		result.layers:Mul(map_high_areas, map_temp_mask, map_high_areas) -- apply random mask
		mkTemp:Restore(map_temp_mask)

		result.layers:Mul(map_high_areas, map_land_mask, map_high_areas) -- apply land mask
		result.layers:Add(map_high_areas, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap
		mkTemp:Restore(map_high_areas)

		mkTemp:Restore(map_high_areas)

		-- ###########################################################################################################
		-- #### Step 3 - Heightmap Post Processing (operations that overwrite parts of the heightmap)
		-- ###########################################################################################################

		-- ##################### Flatten some areas
		local numFlatLayers = (flatAreasAmount * 2)
		local highFlatAreaChance = 0.33
		debugPrint("Creating " .. numFlatLayers .. " flat area layers")

		for i = 1, numFlatLayers do

			local flattenHeight = math.random(20, 150) -- low flat area

			if math.random() < highFlatAreaChance then
				flattenHeight = math.random(150, 500) -- high flat area
			end

			--debugPrint("Creating flat areas at elevation " .. (flattenHeight))

			local flattenRange = math.random(10,20) -- all elevations of flattenHeight +- flattenRange will be flattened to flattenHeight
			local flattenBlendingRange = math.random(60,70) -- all elevations of flattenHeight +- (flattenRange + flattenBlendingRange) will be blended into the flatten spot
			local flattenNoiseStrength = math.random(5,20) -- the flat areas are not 100% flat, they have some noise 20-50
			local flattenedAreasSize = math.random(3000, 6000) -- how big the individual areas that get flattened are
			local map_elevation_mask = mkTemp:Get()

			local map_flat_map = mkTemp:Get()
			map_flat_map = getLayeredPerlinNoise(2, 1 / 1000, 2, 0.5, flattenHeight - flattenNoiseStrength, flattenHeight + flattenNoiseStrength)

			-- create a mask for this elevation (that covers the whole map)
			result.layers:Pwlerp(result.heightmapLayer, map_elevation_mask, {-99999, flattenHeight - flattenRange - flattenBlendingRange, flattenHeight - flattenRange, flattenHeight + flattenRange, flattenHeight + flattenRange + flattenBlendingRange, 99999}, {0, 0, 1, 1, 0, 0})

			-- create a mask so only small parts of the map with this elevation will be flattened
			local map_area_mask = mkTemp:Get()
			map_area_mask = getRandomMask(0.34, 0, 0.1, flattenedAreasSize, 2)
			result.layers:Herp(map_area_mask, map_area_mask, {0, 1}) -- convert linear to smooth interpolation
			result.layers:Mul(map_elevation_mask, map_area_mask, map_elevation_mask) -- apply area mask
			mkTemp:Restore(map_area_mask)

			result.layers:Herp(map_elevation_mask, map_elevation_mask, {0, 1}) -- convert linear to smooth interpolation

			-- cut out the parts of the heightmap that will be replaced by the flat spots
			local invertedHeightMap = mkTemp:Get()	
			result.layers:Map(result.heightmapLayer, invertedHeightMap, {0,1}, {0,-1}, false)
			result.layers:Mul(invertedHeightMap, map_elevation_mask, invertedHeightMap)
			result.layers:Mul(invertedHeightMap, map_land_mask, invertedHeightMap)
			result.layers:Add(result.heightmapLayer, invertedHeightMap, result.heightmapLayer) -- create holes into the real heightmap at height 0
			mkTemp:Restore(invertedHeightMap)

			-- fill the cutout with the flat spots
			result.layers:Mul(map_flat_map, map_elevation_mask, map_flat_map)
			result.layers:Mul(map_flat_map, map_land_mask, map_flat_map)
			result.layers:Add(map_flat_map, result.heightmapLayer, result.heightmapLayer)

			--result.layers:Copy(map_flat_map, result.heightmapLayer) -- just to test
			
			mkTemp:Restore(map_elevation_mask)
			mkTemp:Restore(map_flat_map)
		end

		-- ##################### Stalagmites
		local numStalagmites = (mapSize / 6000000)
		numStalagmites = math.round(numStalagmites, 1)

		local minStalagmiteSize = 10
		local maxStalagmiteSize = 20

		local minStalagmiteHeight = 100
		local maxStalagmiteHeight = 200

		debugPrint("Creating " .. numStalagmites .. " stalagmites")

		for i = 1, numStalagmites do
			local singleStalagmiteHeight = math.random(minStalagmiteHeight, maxStalagmiteHeight)
			local stalagmiteSize = math.random(minStalagmiteSize, maxStalagmiteSize)
			local stalagmiteBlend = 70

			local map_single_stalagmite = mkTemp:Get()
			map_single_stalagmite = getLayeredPerlinNoise(6, 1 / 100, 2, 0.5, singleStalagmiteHeight - 50, singleStalagmiteHeight + 50)

			local stalagmitePoints = {}
			local px = math.random(0, params.mapSizeX)
			local py = math.random(0, params.mapSizeY)
			stalagmitePoints[#stalagmitePoints + 1] = { px, py }

			local map_temp_mask = mkTemp:Get()
			result.layers:Constant(map_temp_mask, 1)
			result.layers:Points(map_temp_mask,  stalagmitePoints, 0)		
			result.layers:Distance(map_temp_mask, map_temp_mask)

			-- small detail
			local map_temp_detail = mkTemp:Get()
			addLayeredPerlinNoise(map_temp_detail, 5, 1 / 50, 2, 0.5, -50, 0)
			result.layers:Add(map_temp_detail, map_temp_mask, map_temp_mask)
			mkTemp:Restore(map_temp_detail)
			
			-- map it to make it a valid mask
			result.layers:Pwlerp(map_temp_mask, map_temp_mask, {-99999, -101, -100, stalagmiteSize, stalagmiteSize + stalagmiteBlend, 99999}, {0, 0, 1, 1, 0, 0})

			 -- apply mask
			result.layers:Mul(map_single_stalagmite, map_temp_mask, map_single_stalagmite)
			mkTemp:Restore(map_temp_mask)

			--result.layers:Copy(map_single_stalagmite, result.heightmapLayer) -- test
			result.layers:Add(map_single_stalagmite, result.heightmapLayer, result.heightmapLayer) -- add to final heightmap

			mkTemp:Restore(map_single_stalagmite)
		end

		-- ###########################################################################################################
		-- #### Step 4 - Assets
		-- ###########################################################################################################

		local t1 = mkTemp:Get()

		local assetsConfig =  {
			forestAmount = forestAmount,
			mapSizeX = params.mapSizeX,
			mapSizeY = params.mapSizeY,
			mapSize = mapSize
		}
		
		result.forestMap, result.treesMapping, result.assetsMap, result.assetsMapping = temperateassetsgen.Make(
			result.layers, assetsConfig, mkTemp, result.heightmapLayer, t1, map_land_distance
		)

		mkTemp:Restore(t1)

		-- ###########################################################################################################
		-- #### FINALIZE
		-- ###########################################################################################################

		mkTemp:Restore(map_land_distance)
		mkTemp:Restore(map_land_mask)
		mkTemp:Restore(map_water_mask)

		mkTemp:Restore(result.forestMap)
		mkTemp:Restore(result.assetsMap)

		mkTemp:Finish()
	
		return result
	end
}		
end
