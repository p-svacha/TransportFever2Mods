local layersutil = require "terrain/layersutil"

-- Credits for base code go to Pentasis (Not so Temperate Generator)

local climateModifier = {}

function climateModifier.modifyClimate(filename, climate)
  if climate ~= nil then
    if climate.updateFn ~= nil and climate.id == "temperate" then

      climate.updateFn = function (params)

        local result = {
          layers = layersutil.Layer.new(),
        }
        local heightmap = "heightmap"
        local mkTemp = layersutil.TempMaker.new()

        -- Greener grass
        local layer2_BaseRiverDistanceMin = 10
        local layer2_BaseRiverDistanceMax = 200 -- max: 256
        local layer2_NoiseStrength = 1.4
        local layer2_AmbientLevelsFrom = { 25, 150 } -- 0 to 255
        local layer2_AmbientLevelsTo = { 0.6, 1.0}
        -- Dark grass
        local layer4_AmbientLevelsFrom = { 100, 250 } -- 0 to 255
        local layer4_AmbientLevelsTo = { 0.9, 0 }
        -- Gravel beach
        local layerBeach_maxDistance = 80
        local layerBeach_gravelToStoneRatio = 0.4
        local layerBeach_gain = 0.9
        -- Cliffs
        local level2_CliffCutoff = { 0.7, 1.2 }

        -- #################
        -- #### PREPARE
        local distanceMap = mkTemp:Get()
        result.layers:Distance(heightmap, distanceMap, params.waterLevel)

        local ambientMap = mkTemp:Get()
        result.layers:AmbientOcclusion(heightmap, ambientMap, 14)

        -- #################
        -- #### Layer 2 - greenest grass
        local layer2Map = mkTemp:Get()
        result.layers:Map(distanceMap, layer2Map, { layer2_BaseRiverDistanceMin, layer2_BaseRiverDistanceMax }, { -1, 0}, true)

        local temp1Map = mkTemp:Get()
        result.layers:Map(ambientMap, temp1Map, layer2_AmbientLevelsFrom, layer2_AmbientLevelsTo, true)

        local noiseMap = mkTemp:Get()
        result.layers:PerlinNoise(noiseMap, {})
        result.layers:Map(noiseMap, noiseMap, {-1, 1}, {0, layer2_NoiseStrength}, true)

        local layer3Map = mkTemp:Get()
        result.layers:Mul(temp1Map, noiseMap, layer3Map)

        result.layers:Add(layer2Map, layer3Map, layer2Map)

        -- #################
        -- #### Layer 3 - Alpine grass
        do
          local temp2Map = mkTemp:Get()
          result.layers:Pwlerp(heightmap, temp2Map, { 300 , 400, 550, 620 } , { 0.5, 1, 0.5, 0 })
          result.layers:Mul(temp2Map, temp1Map, temp1Map)
          temp2Map = mkTemp:Restore(temp2Map)
        end

        result.layers:Mul(temp1Map, noiseMap, layer3Map)
        temp1Map = mkTemp:Restore(temp1Map)
        noiseMap = mkTemp:Restore(noiseMap)

        -- #################
        -- #### Layer 4 - Brown grass
        local layer4Map = mkTemp:Get()
        result.layers:Map(ambientMap, layer4Map, layer4_AmbientLevelsFrom, layer4_AmbientLevelsTo, false)

        do
          local temp1Map = mkTemp:Get()
          result.layers:Pwlerp(heightmap, temp1Map, { 500, 550, 600, 650, 700 }, { 0.5, 0.8, 1, 0.8, 0.5})
          result.layers:Mul(layer4Map, temp1Map, layer4Map)
          temp1Map = mkTemp:Restore(temp1Map)
        end

        -- Optional step
        result.layers:Pwlerp(layer4Map, layer4Map, {0, 0.1, 0.3, 1.0}, {0, 0, 1.0, 1.0})

        -- #################
        -- #### Layer 5 - Slopes
        local layer5Map, layer5bMap
        do
          local temp1Map = mkTemp:Get()
          result.layers:Map(distanceMap, temp1Map, { 150, 250 }, { 0.3, 1 }, true)

          result.layers:Mul(layer4Map, temp1Map, layer4Map)

          result.layers:Grad(heightmap, temp1Map, 3)

          layer5Map = mkTemp:Get()
          result.layers:Map(temp1Map, layer5Map, level2_CliffCutoff, { 0.0, 0.7 }, true)

          layer5bMap = mkTemp:Get()
          result.layers:Map(temp1Map, layer5bMap, level2_CliffCutoff, { 0.0, 0.8 }, true)
          temp1Map = mkTemp:Restore(temp1Map)
        end

        do
          local temp1Map = mkTemp:Get()
          result.layers:Laplace(heightmap, temp1Map)

          result.layers:Map(temp1Map, temp1Map, {0.2, 0.8 }, { 0.5, 0.7 }, true)

          result.layers:Mul(layer5bMap, temp1Map, layer5bMap)
          temp1Map = mkTemp:Restore(temp1Map)
        end

        -- #################
        -- #### Beach layer - gravel stone
        local layer6Map = mkTemp:Get()
        result.layers:Map(distanceMap, layer6Map, { 0, layerBeach_maxDistance }, { 2.3, 0}, true)
        distanceMap = mkTemp:Restore(distanceMap)

        do
          local noiseMap = mkTemp:Get()
          result.layers:RidgedNoise(noiseMap, { octaves = 3, lacunarity = 10.5, frequency = 1.0 / 1000.0, gain = layerBeach_gain})
          result.layers:Map(noiseMap, noiseMap, { 0.2, 0.8 }, { -2.3, 0}, true)
          result.layers:Add(layer6Map, noiseMap, layer6Map)
          mkTemp:Restore(noiseMap)
        end

        local layer7Map = mkTemp:Get()
        result.layers:Map(layer6Map, layer7Map, { 0.0, 1.0 }, { 0.0, layerBeach_gravelToStoneRatio}, true)

        -- #################
        -- #### Layer 8 - River bed
        local layer8Map = mkTemp:Get()
        result.layers:Map(heightmap, layer8Map, { -15.0, -1.0 }, { 1.0, 0.0}, true)

        -- #################
        -- #### Layer 9 - Snow
        local layer9Map = mkTemp:Get()
        result.layers:Map(heightmap, layer9Map, { 650 , 750 } , { 0.8, 1 }, true)
        ambientMap = mkTemp:Restore(ambientMap)

        do
          local temp1Map = mkTemp:Get()
          result.layers:Pwlerp(heightmap, temp1Map, { 600, 650, 750 }, { 0, 0.8, 1})
          result.layers:Mul(layer9Map, temp1Map, layer9Map)
          temp1Map = mkTemp:Restore(temp1Map)
        end
        -- #################
        -- #### Layer 10 - Brown under Snow
        local layer10Map = mkTemp:Get()
        result.layers:Map(heightmap, layer10Map, { 500 , 600 } , { 0.5, 1 }, true)

        do
          local temp1Map = mkTemp:Get()
          result.layers:Pwlerp(heightmap, temp1Map, { 400, 500, 600, 700 }, { 0, 0.5, 0.8, 1})
          result.layers:Mul(layer10Map, temp1Map, layer10Map)
          temp1Map = mkTemp:Restore(temp1Map)
        end

        -- #################
        -- #### Layer 11 - Mountain Grass
        local layer11Map = mkTemp:Get()
        result.layers:Map(heightmap, layer11Map, { 300 , 400, 500, 600 } , { 0.5, 1, 0.5, 0 }, true)

        do
          local temp1Map = mkTemp:Get()
          result.layers:Pwlerp(heightmap, temp1Map, { 250, 350, 450, 500, 550 }, { 0, 0.8, 1, 0.8, 0.3})
          result.layers:Mul(layer11Map, temp1Map, layer11Map)
          temp1Map = mkTemp:Restore(temp1Map)
        end

        result.mixingLayer = {
          backgroundMaterial = "grass_green.lua",
          layers = {
            -- Standard grass
            {
              map = layer2Map,
              dither = true,
              material = "grass_light_green.lua",
            },
            {
              map = layer4Map,
              dither = true,
              material = "scree.lua",
            },
            {
              map = layer11Map,
              dither = true,
              material = "grass_alpine.lua",
            },
            {
              map = layer3Map,
              dither = true,
              material = "grass_alpine.lua",
            },
            -- Snow scree materials
            {
              map = layer10Map,
              dither = true,
              material = "scree.lua",
            },
            -- Snow materials
            {
              map = layer9Map,
              dither = true,
              material = "snow_01.lua",
            },
            -- Slope rocks
            {
              map = layer5bMap,
              dither = true,
              material = "scree.lua",
            },
            {
              map = layer5Map,
              dither = true,
              material = "rock.lua",
            },
            -- Beach materials
            {
              map = layer6Map,
              dither = true,
              material = "gravel_01.lua",
            },
            {
              map = layer7Map,
              dither = true,
              material = "scree.lua",
            },
            -- River materials
            {
              map = layer8Map,
              dither = true,
              material = "scree.lua",
            },
          }
        }

        mkTemp:RestoreAll(result.mixingLayer)
        mkTemp:Finish()

        return result
      end
    end
  end

  return climate
end

return climateModifier
