local mapgenutil = require "terrain/mapgenutil"
local assetsgen = require "terrain/terrain_fever_assetsgen"
local layersutil = require "terrain/layersutil"
local maputil = require "maputil"
local tfExtensions = require "terrain_fever_ext"

function data() 

return {
	climate = "temperate.clima.lua",
	order = 0,
	name = _("Terrain Fever"),
	params = {
		{
			key = "distribution",
			name = _("Terrain distribution"),
			values = {"Semi-Random", "Linear", "Radial", "Radial (inverse)"},
			defaultIndex = 0,
			uiType = "COMBOBOX",
		},
		{
			key = "hm_ratio",
			name = _("Ratio: High Mountains"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 9,
			uiType = "SLIDER",
		},
		{
			key = "am_ratio",
			name = _("Ratio: Average Mountains"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 5,
			uiType = "SLIDER",
		},		{
			key = "rh_ratio",
			name = _("Ratio: Rolling Hills"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 9,
			uiType = "SLIDER",
		},		{
			key = "fl_ratio",
			name = _("Ratio: Plains"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 9,
			uiType = "SLIDER",
		},
		{
			key = "oc_ratio",
			name = _("Ratio: Ocean"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 0,
			uiType = "SLIDER",
		},		
		{
			key = "terrainHeight",
			name = _("Terrain Height"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 10,
			uiType = "SLIDER",
		},
		{
			key = "rivers",
			name = _("Rivers"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 4,
			uiType = "SLIDER",
		},
		{
			key = "lakeProbability",
			name = _("Lakes"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 4,
			uiType = "SLIDER",
		},
		{
			key = "lakeSize",
			name = _("Lake Size"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 8,
			uiType = "SLIDER",
		},
		{
			key = "trees",
			name = _("Trees"),
			values = { "", "", "", "", "" , "", "", "", "", "" , "", "", "", "", "" , "", "" , "", "", "", "" },
			defaultIndex = 10,
			uiType = "SLIDER",
		}
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

		local sameSeed = math.random(1, 100000000)
		math.randomseed(sameSeed) -- reset seed to match desert generator
		
		-- heightmapLayer does not get cleared automatically the map editor
		result.layers:Constant(result.heightmapLayer, 0)

		
		-- ###########################################################################################################
		-- #### PREPARE
		-- ###########################################################################################################
		local mkTemp = layersutil.TempMaker.new()
		
		local terrainDistribution = params.distribution
		local terrainBlendingFactor = 0.2 -- 0..1
		
		local ratioTotal = params.hm_ratio + params.am_ratio + params.rh_ratio + params.fl_ratio + params.oc_ratio
		local ratioHighMountains = params.hm_ratio / ratioTotal
		local ratioAverageMountains = params.am_ratio / ratioTotal
		local ratioRollingHills= params.rh_ratio / ratioTotal
		local ratioFlatLands= params.fl_ratio / ratioTotal
		local ratioOcean = params.oc_ratio / ratioTotal
		
		local noHighMountains = ratioHighMountains == 0
		local noAverageMountains = ratioAverageMountains == 0
		local noRollingHills = ratioRollingHills == 0
		local noFlatLands = ratioFlatLands == 0
		
		local hillyness = params.terrainHeight / 10 -- 0..2
		
		local amountRivers = params.rivers / 20
		local noRivers = amountRivers == 0
		
		local lakeSize = params.lakeSize / 20 -- 0..1
		local lakeProbability = params.lakeProbability / 20 -- 0..1
		local noLakes = lakeProbability == 0
	
		local humidity = params.trees / 20
		
		

		
		-- ###########################################################################################################
		-- #### HIGH MOUNTAINS
		-- ###########################################################################################################
		local hm_final = mkTemp:Get()
		local hm_minHeight = 75 * hillyness
		local hm_maxHeight = 550 * hillyness
		
		if not noHighMountains then
			local hm_density = 1 -- 1..2
			local hm_height = 0.75 -- 0..1
			local hm_detail = 12 -- 4..20
			local hm_detailStrength = 5
			local hm_highVariation = 0.75 -- 0..1
			
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
		end
		
		-- ###########################################################################################################
		-- #### AVERAGE MOUNTAINS
		-- ###########################################################################################################
		local am_final = mkTemp:Get()
		local am_minHeight = 40 * hillyness
		local am_maxHeight = 300 * hillyness
		
		if not noAverageMountains then
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

		end
		
		-- ###########################################################################################################
		-- #### ROLLING HILLS
		-- ###########################################################################################################
		local rh_final = mkTemp:Get()
		local rh_minHeight = 5 * hillyness
		local rh_maxHeight = 75 * hillyness
		if not noRollingHills then
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
		end
			
		-- ###########################################################################################################
		-- #### FLAT LAND
		-- ###########################################################################################################
		local fl_final = mkTemp:Get()
		local fl_minHeight = 5 * hillyness
		local fl_maxHeight = 50 * hillyness
		if not noFlatLands then
			
			local fl_detailsConfig = {
				numOctaves = 5,
				frequency = 1 / 400,
				lacunarity = 2,
				gain = 0.5,
				warp = 0.05
			}
			
			local fl_terrainShape = mkTemp:Get()
			result.layers:PerlinNoise(fl_terrainShape, {frequency = 1 / 1900})
			
			local fl_details = mkTemp:Get()
			result.layers:GradientNoise(fl_details, fl_detailsConfig)
			result.layers:Map(fl_details, fl_details, {-1, 1}, {-0.1, 0.1}, true)
			
			result.layers:Add(fl_terrainShape, fl_details, fl_final)
			result.layers:Map(fl_final, fl_final, {-1, 1}, {fl_minHeight, fl_maxHeight}, true)
			
			mkTemp:Restore(fl_terrainShape)
			mkTemp:Restore(fl_details)
		end
		
		
		-- ###########################################################################################################
		-- #### OCEAN
		-- ###########################################################################################################
		local oc_final = mkTemp:Get()
		local oc_height = -50
		result.layers:Constant(oc_final, oc_height)

			
		
		-- ###########################################################################################################
		-- #### TERRAIN DISTRIBUTION
		-- ###########################################################################################################
		local distributionMap = mkTemp:Get()

		-- semi random distribution
		if terrainDistribution == 0 then 
			result.layers:PerlinNoise(distributionMap, {frequency = 1 / 9000})
			result.layers:Map(distributionMap, distributionMap, {-1.5, 1.5}, {0, 1}, true)

		-- linear distribution
		elseif terrainDistribution == 1 then
			local angle = math.random() * 2 * math.pi
			local gradientMapSizeX = 16
			local gradientMapSizeY = 16
			local gradientMapData = tfExtensions.makeGradient(
				angle, 
				gradientMapSizeX, 
				gradientMapSizeY, 
				{
					params.mapSizeX / (gradientMapSizeX - 1), 
					params.mapSizeY / (gradientMapSizeY - 1) 
				}
			)
			result.layers:Data(distributionMap, gradientMapData, "BILINEAR")

		-- radial distribution
		elseif terrainDistribution == 2 or terrainDistribution == 3 then
			local gradientMapSizeX = 16
			local gradientMapSizeY = 16
			local gradientMapData = tfExtensions.makeRadialGradient(
				gradientMapSizeX, 
				gradientMapSizeY, 
				{
					params.mapSizeX / (gradientMapSizeX - 1), 
					params.mapSizeY / (gradientMapSizeY - 1) 
				}
			)
			result.layers:Data(distributionMap, gradientMapData, "BILINEAR")
			
			if terrainDistribution == 3 then
				result.layers:Map(distributionMap, distributionMap, {0, 1}, {1, 0}, true)
			end
			
		
		-- continental distribution (test)
		elseif terrainDistribution == "disabled" then
			local points = tfExtensions.makePointCloud(params.mapSizeX, params.mapSizeY, 0.6, 800)
			local cdPointMap = mkTemp:Get()
			result.layers:Points(cdPointMap, points, -1)
			
			local cdNoise = mkTemp:Get()
			result.layers:WhiteNoise(cdNoise, 0.41)
		
			result.layers:Percolation(cdNoise, cdPointMap, distributionMap, {
				seedThreshold = -0.5,
				noiseThreshold = 0.5,
				maxCluster = 40000,
			})
		end
		
		-- add some detail to the distribution map
		local detailFactor = 0.04 -- 0..1
		local distributionDetail = mkTemp:Get()
		result.layers:PerlinNoise(distributionDetail, {frequency = 1 / 600})
		result.layers:Map(distributionDetail, distributionDetail, {-1, 1}, {-detailFactor/2, detailFactor/2}, false)
		result.layers:Mad(distributionMap, distributionDetail, distributionMap)
		result.layers:Map(distributionMap, distributionMap, {0, 1}, {0.001, 1}, true) -- zero valuee scause issues with terrain blening 

		mkTemp:Restore(distributionDetail)
		
		-- ###########################################################################################################
		-- #### TERRAIN BLENDING
		-- ###########################################################################################################
		local getDistributionRange = function(ratio, previousDistribution)
			if previousDistribution == nil then 
				previousDistribution = {min = 0, max = 0}
			end
			
			return {
				min = previousDistribution.max,
				max = math.clamp(previousDistribution.max + ratio, 0, 1)
			}
		end
		
		local buildMask = function(map, min, max, blending)
			local mask = mkTemp:Get()
			
			local blendingMin = math.clamp(min - blending, 0, 1)
			local blendingMax = math.clamp(max + blending, 0, 1)
			result.layers:Pwlerp(map, mask, {-99999, blendingMin, min, max, blendingMax, 99999}, {0, 0, 1, 1, 0, 0})
			tfExtensions.Exlerp(result.layers, mask, mask, 50) -- convert linear to exponential blending
			
			return mask
		end
		
		local buildMaskedTerrain = function(distributionMap, terrainMap, target, distribution, blending)
			if distribution.min == distribution.max then return end
		
			local temp = mkTemp:Get()
			local mask = buildMask(distributionMap, distribution.min, distribution.max, blending)
			
			result.layers:Mul(mask, terrainMap, temp)
			result.layers:Add(temp, target, target)
			
			mkTemp:Restore(mask)
			mkTemp:Restore(temp)
		end

		
		local blendedTerrain = mkTemp:Get()
		
		local oceanDistribution = getDistributionRange(ratioOcean)
		buildMaskedTerrain(distributionMap, oc_final, blendedTerrain, oceanDistribution, terrainBlendingFactor)
		
		local flatLandsDistribution = getDistributionRange(ratioFlatLands, oceanDistribution)
		buildMaskedTerrain(distributionMap, fl_final, blendedTerrain, flatLandsDistribution, terrainBlendingFactor)
		
		local rollingHillsDistribution = getDistributionRange(ratioRollingHills, flatLandsDistribution)
		buildMaskedTerrain(distributionMap, rh_final, blendedTerrain, rollingHillsDistribution, terrainBlendingFactor)
		
		local averageMountainsDistribution = getDistributionRange(ratioAverageMountains, rollingHillsDistribution)
		buildMaskedTerrain(distributionMap, am_final, blendedTerrain, averageMountainsDistribution, terrainBlendingFactor)
		
		local highMountainsDistribution = getDistributionRange(ratioHighMountains, averageMountainsDistribution)
		buildMaskedTerrain(distributionMap, hm_final, blendedTerrain, highMountainsDistribution, terrainBlendingFactor)
		
		--print("Building OC: " .. oceanDistribution.min .. " - " .. oceanDistribution.max)
		--print("Building FL: " .. flatLandsDistribution.min .. " - " .. flatLandsDistribution.max)
		--print("Building RM: " .. rollingHillsDistribution.min .. " - " .. rollingHillsDistribution.max)
		--print("Building AM: " .. averageMountainsDistribution.min .. " - " .. averageMountainsDistribution.max)
		--print("Building HM: " .. highMountainsDistribution.min .. " - " .. highMountainsDistribution.max)
		
		mkTemp:Restore(oc_final)
		mkTemp:Restore(fl_final)
		mkTemp:Restore(rh_final)
		mkTemp:Restore(am_final)
		mkTemp:Restore(hm_final)

		-- ###########################################################################################################
		-- #### Water generation
		-- ###########################################################################################################
		local waterMap = mkTemp:Get()
		
		-- create rivers
		local maxRivers = 16;
		local riverConfig = {
			depthScale = 1.5,
			maxOrder = math.round(amountRivers * maxRivers),
			segmentLength = 3000,
			bounds = params.bounds,
			baseProbability = amountRivers * amountRivers * 4,
			minDist = amountRivers > 0.5 and 1 or 2,
		}
		
		local rivers = {}
		if not noRivers then
			local start = mapgenutil.FindGoodRiverStart(params.bounds)
			mapgenutil.MakeRivers(rivers, riverConfig, 120000, start.pos, start.angle)
			maputil.Convert(rivers)
			maputil.ValidateRiver(rivers)
		end
		
		result.layers:Constant(waterMap, 0.01)
		result.layers:River(waterMap, rivers)
		
		
		-- create lakes
		if not noLakes then
			local lakeMap = mkTemp:Get()
			result.layers:PerlinNoise(lakeMap, {frequency = 1 / 1500})
			result.layers:Pwconst(lakeMap, lakeMap, {1 - lakeSize}, {0, -1})
			
			local lakeProbabilityMask = mkTemp:Get()
			result.layers:PerlinNoise(lakeProbabilityMask, {frequency = 1 / 4000})
			result.layers:Pwconst(lakeProbabilityMask, lakeProbabilityMask, {2 * lakeProbability - 1}, {1, 0})
			result.layers:Mul(lakeMap, lakeProbabilityMask, lakeMap)
			
			local lakeTerrainMask = mkTemp:Get()
			result.layers:Pwlerp(blendedTerrain, lakeTerrainMask, {0, 100, 120}, {1, 1, 0})
			result.layers:Mul(lakeMap, lakeTerrainMask, lakeMap)
			
			local lakeRiverMask = mkTemp:Get()
			result.layers:Distance(waterMap, lakeRiverMask)
			result.layers:Pwlerp(lakeRiverMask, lakeRiverMask, {-1, 600, 700}, {0, 0, 1}, true)
			result.layers:Mul(lakeMap, lakeRiverMask, lakeMap)
			
			result.layers:Add(lakeMap, waterMap, waterMap)
			
			mkTemp:Restore(lakeMap)
			mkTemp:Restore(lakeProbabilityMask)
			mkTemp:Restore(lakeTerrainMask)
			mkTemp:Restore(lakeRiverMask)
		end
		
		-- blend water with terrain
		local staticWaterBlendDistance = 2000;
		local dynamicWaterBlendDistance = 3000;
		
		local distanceMap = mkTemp:Get()
		result.layers:Distance(waterMap, distanceMap)
		
        local waterFallOff = mkTemp:Get()
		result.layers:Map(distanceMap, waterFallOff, {-1, staticWaterBlendDistance}, {1, 0}, true)
  		tfExtensions.Exlerp(result.layers, waterFallOff, waterFallOff, 20) 
		
		local waterNoiseMask = mkTemp:Get()
        local waterBlendMap = mkTemp:Get()
		result.layers:Map(distanceMap, waterBlendMap, {-1, dynamicWaterBlendDistance}, {1, 0}, true)
		result.layers:PerlinNoise(waterNoiseMask, {frequency = 1 / 900})
		result.layers:Map(waterNoiseMask, waterNoiseMask, {-1, 1}, {0, 0.1}, true)
		result.layers:Mul(waterBlendMap, waterNoiseMask, waterBlendMap)
		result.layers:Add(waterFallOff, waterBlendMap, waterBlendMap)
		
		-- flatten terrain on water areas above sea level
		local terrainDepthMask = mkTemp:Get()
		result.layers:Pwconst(blendedTerrain, terrainDepthMask, {0}, {0, 1})
		result.layers:Mul(terrainDepthMask, waterBlendMap, terrainDepthMask)
 		result.layers:Map(terrainDepthMask, terrainDepthMask, {0, 1}, {1, 0}, true)
 		result.layers:Mul(terrainDepthMask, blendedTerrain, blendedTerrain)
		
		-- carve water areas into terrain 
		local waterCutoutMap = mkTemp:Get()
		result.layers:Pwconst(waterBlendMap, waterCutoutMap, {0.99}, {0, 1})
		result.layers:Distance(waterCutoutMap, waterCutoutMap)
		result.layers:Map(waterCutoutMap, waterCutoutMap, {0, 150}, {0, -10}, true)
		
		-- do not carve out water in the ocean
		local waterCutoutMask = mkTemp:Get()
		result.layers:Pwconst(blendedTerrain, waterCutoutMask, {-10}, {0, 1})
	 	result.layers:Mul(waterCutoutMask, waterCutoutMap, waterCutoutMap)
		
	 	result.layers:Add(waterCutoutMap, blendedTerrain, blendedTerrain)
		

	 	result.layers:Add(result.heightmapLayer, blendedTerrain, result.heightmapLayer)
	
		mkTemp:Restore(waterMap)
        mkTemp:Restore(waterFallOff)
        mkTemp:Restore(waterNoiseMask)
        mkTemp:Restore(waterBlendMap)
        mkTemp:Restore(terrainDepthMask)
        mkTemp:Restore(waterCutoutMap)
        mkTemp:Restore(waterCutoutMask)

		
		-- ###########################################################################################################
		-- #### Assets
		-- ###########################################################################################################
		local assetConfig =  {
			trees = humidity,
			noWater = amountRivers + lakeProbability == 0,
			maxTreeHeight = 0.65, -- realtive to max terrain height
			maxTreeSlope = 0.8, -- relative to max terrain height
			forestSize = 0.3 + humidity * 0.6,
			maxTerrainHeight = hm_maxHeight,
            mountainLowerLimit = hm_minHeight + 0.05 * hm_maxHeight,
            mountainUpperLimit = hm_maxHeight,
            hillsLowerLimit = am_minHeight,
            hillsUpperLimit = am_maxHeight,
            plainsLowerLimit = 0,
            plainsUpperLimit = rh_minHeight,
		}

		
		result.layers:PushColor("#007777")
		
		local highMountainMask = mkTemp:Get()
		if highMountainsDistribution.min ~= highMountainsDistribution.max then
			result.layers:Pwconst(distributionMap, highMountainMask, {highMountainsDistribution.min, highMountainsDistribution.max}, {0, 1, 0})
		end
		
		result.forestMap, result.treesMapping, result.assetsMap, result.assetsMapping = assetsgen.Make(
			result.layers, assetConfig, mkTemp, result.heightmapLayer, distanceMap, highMountainMask)
		result.layers:PopColor()		
		
		distanceMap = nil
		
		-- #################
		-- #### FINISH
        mkTemp:Restore(blendedTerrain)
        mkTemp:Restore(distributionMap)
        mkTemp:Restore(highMountainMask)
		mkTemp:Restore(result.forestMap)
		mkTemp:Restore(result.assetsMap)
		mkTemp:Finish()
		-- maputil.PrintGraph(result)
	
		return result
	end
}		
end
