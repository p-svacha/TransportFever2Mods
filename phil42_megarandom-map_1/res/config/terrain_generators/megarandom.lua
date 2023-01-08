local mapgenutil = require "terrain/mapgenutil"
local assetsgen = require "terrain/terrain_fever_assetsgen"
local layersutil = require "terrain/layersutil"
local maputil = require "maputil"
local tfExtensions = require "terrain_fever_ext"

function data() 

return {
	climate = "temperate.clima.lua",
	order = 0,
	name = _("MegaRandom"),
	params = {
		{
			key = "distDetail",
			name = _("Distribution Detail"),
			values = {"", "", "", "", "", "", "", "", "", ""},
			defaultIndex = 0,
			uiType = "SLIDER", --COMBOBOX
		},
		{
			key = "terrainBlendingFactor",
			name = _("Terrain Blending Factor"),
			values = {"", "", "", "", "", "", "", "", "", ""},
			defaultIndex = 0,
			uiType = "SLIDER", --COMBOBOX
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

		local sameSeed = math.random(1, 100000000)
		math.randomseed(sameSeed) -- reset seed to match desert generator
		
		-- heightmapLayer does not get cleared automatically the map editor
		result.layers:Constant(result.heightmapLayer, 0)

		local mkTemp = layersutil.TempMaker.new()

		local distDetail = params.distDetail * 0.03
		local terrainBlendingFactor = params.terrainBlendingFactor * 0.1
		local baseHeight = 10

		-- ###########################################################################################################
		-- #### FUNCTIONS
		-- ###########################################################################################################

		local addSinglePerlinHeightMap = function(targetMap, frequency1, height)
			local tempPerlin = mkTemp:Get()
			result.layers:PerlinNoise(tempPerlin, {frequency = frequency1})
			result.layers:Map(tempPerlin, tempPerlin, {-1, 1}, {0, height}, true)
			result.layers:Add(tempPerlin, targetMap, targetMap)
			mkTemp:Restore(tempPerlin)
		end

		local getPerlinHeightMap = function(numOctaves, startFrequency, maxHeight, lacunarity, persistence)
		
			local perlinMap = mkTemp:Get()

			local currentFrequency = startFrequency
			local currentHeight = maxHeight

			if numOctaves >= 1 then
				addSinglePerlinHeightMap(perlinMap, currentFrequency, currentHeight)
				currentFrequency = currentFrequency * lacunarity
				currentHeight = currentHeight * persistence
			end
			if numOctaves >= 2 then
				addSinglePerlinHeightMap(perlinMap, currentFrequency, currentHeight)
				currentFrequency = currentFrequency * lacunarity
				currentHeight = currentHeight * persistence
			end
			if numOctaves >= 3 then
				addSinglePerlinHeightMap(perlinMap, currentFrequency, currentHeight)
				currentFrequency = currentFrequency * lacunarity
				currentHeight = currentHeight * persistence
			end
			if numOctaves >= 4 then
				addSinglePerlinHeightMap(perlinMap, currentFrequency, currentHeight)
				currentFrequency = currentFrequency * lacunarity
				currentHeight = currentHeight * persistence
			end
			if numOctaves >= 5 then
				addSinglePerlinHeightMap(perlinMap, currentFrequency, currentHeight)
				currentFrequency = currentFrequency * lacunarity
				currentHeight = currentHeight * persistence
			end
			if numOctaves >= 6 then
				addSinglePerlinHeightMap(perlinMap, currentFrequency, currentHeight)
				currentFrequency = currentFrequency * lacunarity
				currentHeight = currentHeight * persistence
			end
			if numOctaves >= 7 then
				addSinglePerlinHeightMap(perlinMap, currentFrequency, currentHeight)
				currentFrequency = currentFrequency * lacunarity
				currentHeight = currentHeight * persistence
			end
			if numOctaves >= 8 then
				addSinglePerlinHeightMap(perlinMap, currentFrequency, currentHeight)
				currentFrequency = currentFrequency * lacunarity
				currentHeight = currentHeight * persistence
			end

			return perlinMap
		end

		local getRandomMask = function(coverageRatio, coverageMode, blendingRatio)

			local mask = mkTemp:Get()
			local tempDist = mkTemp:Get()

			local freq = math.random(4000, 12000)
			result.layers:PerlinNoise(tempDist, {frequency = 1 / freq})
			result.layers:Map(tempDist, tempDist, {-1.5, 1.5}, {0, 1}, true)

			-- add some detail to the distribution map
			local detailFactor = distDetail
			local distributionDetail = mkTemp:Get()
			local detailFreq = math.random(400, 1400)
			result.layers:PerlinNoise(distributionDetail, {frequency = 1 / detailFreq})
			result.layers:Map(distributionDetail, distributionDetail, {-1, 1}, {-detailFactor/2, detailFactor/2}, false)
			result.layers:Mad(tempDist, distributionDetail, tempDist) -- Mad = Add I think

			result.layers:Map(tempDist, tempDist, {0, 1}, {0.001, 1}, true) -- zero valuee scause issues with terrain blening 
			mkTemp:Restore(distributionDetail)

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
			tfExtensions.Exlerp(result.layers, mask, mask, 50) -- convert linear to exponential blending

			mkTemp:Restore(tempDist)
			
			return mask

		end


		
		-- Adds a terrainMap to the targetMap according on a random area according to the coverageRatio.
		-- terrainMap: The heightmap you want to add
		-- targetMap: The target map that you add the terrainMap to
		-- coverageRatio: How much of the area of the targetMap will be covererd with the terrainMap (0-1)
		-- blendingRatio: How much the terrainMap will be blended into the targetMap (0-1)
		-- coverageMode: How the coverageRatio is calculated:
			-- 0: "Lakes": The mask will consist of multiple individual roundish shapes
			-- 1: "Snakes": The mask will consist of multiple connected strings snaking through the whole target map
		-- buildMode: how the terrainMap will be integrated to the targetMap:
			-- 0: "Add": The terrainMap will be added on top the targetMap in the coverage area
			-- 1: "Overwrite": The terrainMap will overwrite the targetMap in the coverage area
		local buildMaskedTerrain = function(terrainMap, targetMap, coverageRatio, blendingRatio, coverageMode, buildMode)
		
			local temp = mkTemp:Get()
			local mask = getRandomMask(coverageRatio, coverageMode, blendingRatio)
			
			if buildMode == 0 then
				-- add terrainMao
				result.layers:Mul(mask, terrainMap, temp)
				result.layers:Add(temp, targetMap, targetMap)

			elseif buildMode == 1 then

				-- reset terrain within mask
				local invertMap = mkTemp:Get()
				local baseHeightMap = mkTemp:Get()
				local invertedTargetMap = mkTemp:Get()	

				result.layers:Constant(invertMap, -1)
				result.layers:Mul(mask, invertMap, invertMap)

				result.layers:Constant(baseHeightMap, baseHeight)
				result.layers:Mul(mask, baseHeightMap, baseHeightMap)

				result.layers:Mul(targetMap, invertMap, invertedTargetMap)
				result.layers:Add(invertedTargetMap, baseHeightMap, invertedTargetMap)
				
				result.layers:Add(targetMap, invertedTargetMap, targetMap)

				mkTemp:Restore(invertMap)
				mkTemp:Restore(baseHeightMap)
				mkTemp:Restore(invertedTargetMap)

				-- add terrainMap
				result.layers:Mul(mask, terrainMap, temp)
				result.layers:Add(temp, targetMap, targetMap)

			end
			
			mkTemp:Restore(mask)
			mkTemp:Restore(temp)
		end



		-- ###########################################################################################################
		-- #### PREPARE
		-- ###########################################################################################################
		
		local baseheightMap_frequency = 4000 --(params.baseheight_frequency * 2000) + 500 -- 1..2000
		local baseHeightMap_MaxHeight = 800;

		-- ###########################################################################################################
		-- #### TERRAIN 1 - Flat Base
		-- ###########################################################################################################

		local baseMap = mkTemp:Get()
		result.layers:Constant(baseMap, baseHeight)

		-- ###########################################################################################################
		-- #### TERRAIN 2 - Added Rough Terrain
		-- ###########################################################################################################

		local t2_coverage = 0.35
		local t2_coverageMode = 0
		local t2_buildMode = 0
		local t2_map = mkTemp:Get()
		local t2_perlin = getPerlinHeightMap(8, 1 / 1000, 160, 2, 0.5)
		result.layers:Add(t2_perlin, t2_map, t2_map)
		mkTemp:Restore(t2_perlin)

		-- ###########################################################################################################
		-- #### TERRAIN 3 - Forced Lakes
		-- ###########################################################################################################
	
		local t3_coverage = 0.3
		local t3_coverageMode = 0
		local t3_buildMode = 1
		local t3_map = mkTemp:Get()
		local t3_height = -50
		result.layers:Constant(t3_map, t3_height)

		-- ###########################################################################################################
		-- #### TERRAIN 4 - Forced High Plateau
		-- ###########################################################################################################
	
		local t4_coverage = 0.2
		local t4_blending = 0.05
		local t4_coverageMode = 0
		local t4_buildMode = 1
		local t4_map = mkTemp:Get()
		local t4_height = 400
		result.layers:Constant(t4_map, t4_height)

		-- ###########################################################################################################
		-- #### TERRAIN DISTRIBUTION & BLENDING
		-- ###########################################################################################################

		local buildRandomMaskedTerrain = function(targetMap)

			local appliedLayerId = math.random(2, 4)
			print("appliedLayerId: " .. appliedLayerId)

			if appliedLayerId == 2 then
				buildMaskedTerrain(t2_map, targetMap, t2_coverage, terrainBlendingFactor, t2_coverageMode, t2_buildMode)
			elseif appliedLayerId == 3 then
				buildMaskedTerrain(t3_map, targetMap, t3_coverage, terrainBlendingFactor, t3_coverageMode, t3_buildMode)
			elseif appliedLayerId == 4 then
				buildMaskedTerrain(t4_map, targetMap, t4_coverage, t4_blending, t4_coverageMode, t4_buildMode)
			end

		end

		local distributionMap = mkTemp:Get() -- keep this else it breaks for whatever reason

		local finalTerrain = mkTemp:Get()

		result.layers:Add(finalTerrain, baseMap, finalTerrain)

		local numLayers = math.random(1, 1)
		for i = 0, numLayers - 1, 1 do
			buildRandomMaskedTerrain(finalTerrain)
		end
		--buildMaskedTerrain(t2_map, finalTerrain, t2_coverage, terrainBlendingFactor, 1, 0)
		

		--buildMaskedTerrain(t3_map, finalTerrain, t3_coverage, terrainBlendingFactor, 0, 0)
		

		--buildMaskedTerrain(t4_map, finalTerrain, t4_coverage, t4_blending, 1, 1)
		

		mkTemp:Restore(t2_map)
		mkTemp:Restore(t3_map)
		mkTemp:Restore(t4_map)

		-- ###########################################################################################################
		-- #### FINISH
		-- ###########################################################################################################

		result.layers:Add(result.heightmapLayer, finalTerrain, result.heightmapLayer)
		
        mkTemp:Restore(finalTerrain)
        -- mkTemp:Restore(distributionMap)
        -- mkTemp:Restore(highMountainMask)
		-- mkTemp:Restore(result.forestMap)
		-- mkTemp:Restore(result.assetsMap)
		mkTemp:Finish()
		-- maputil.PrintGraph(result)
	
		return result
	end
}		
end
