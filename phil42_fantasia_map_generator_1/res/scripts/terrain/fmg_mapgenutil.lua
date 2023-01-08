require "math"
local vec2 = require "vec2"

local data = {}
local datan = {}

function data.FindGoodRiverStart(bounds)
		local start = {}

		local Q = math.random(4)
		if Q == 1 then
			start.pos = vec2.new(bounds.min.x - 100, math.random(bounds.min.y, bounds.max.y))
		elseif Q == 2 then
			start.pos  = vec2.new(math.random(bounds.min.x, bounds.max.x), bounds.min.y - 100)
		elseif Q == 3 then
			start.pos  = vec2.new(bounds.max.x + 100, math.random(bounds.min.y, bounds.max.y))
		else
			start.pos  = vec2.new(math.random(bounds.min.x, bounds.max.x), bounds.max.y + 100)
		end
		local center = vec2.mul(0.5, vec2.new(bounds.max.x + bounds.min.x, bounds.max.y + bounds.min.y))
		local dist = vec2.sub(center, start.pos )
		start.angle = math.atan2(dist.y, dist.x)
		
		return start
end

function data.MakeRivers(valleys, config, startLength, startPosition, startDirection, order, feededId, feederDir, effluentIndex, i)
	
	if config.curvature == nil then config.curvature = 0.2 end
	if config.map == nil then config.map = {} end
	if config.map.riverId == nil then
		config.map.riverId = 4
	end
	if order == nil then order = 0 end

	local length = startLength
	local position = startPosition
	local direction = startDirection
	local oldDirection = startDirection
    if feederDir then
        oldDirection = feederDir
    end
    
	local oldPosition = startPosition
	local totalDirection = 0
 
	-- BEGIN DETECT INTERSECTIONS
	local blockSize = 1400
	local distanceCheck = config.startWidth + 100 -- how close rivers are allowed to be close to each other
	local function GetIndex(position) 
		return 500000 * math.floor((position.y + 500000) / blockSize) + math.floor(position.x / blockSize)
	end
	-- BEGIN DETECT INTERSECTIONS

	local valley = {
		effluent = {effluentIndex, i},
		points = {}, 
		widths = {},
		depths = {},
		tangents = {}, 
		widthTangents = {},
		depthTangents = {},
		features = {},
		feeders = {}, -- cached
	}
	local directions = {}
 
	local widthStep = (config.endWidth - config.startWidth) / config.numSegments
	local stepWidth = config.startWidth
	for i = 1, config.numSegments do
		-- set width for all segments
		local actualStepWidth = stepWidth
		--if i < 4 and order == 0 then actualStepWidth = stepWidth * (5 - i) end -- make start wider
		valley.points[#valley.points + 1] = position
		valley.widths[#valley.widths + 1] = vec2.new(
			actualStepWidth,
			actualStepWidth
		)
		stepWidth = stepWidth + widthStep
		valley.depths[#valley.depths + 1] = config.depthScale * (3 + math.random() * 1) * 1.5
		
		valley.widthTangents[#valley.widthTangents + 1] = vec2.new(0,0)
		valley.depthTangents[#valley.depthTangents + 1] = 0
		valley.features[#valley.features + 1] = {}
		directions[#directions + 1] = 0.5 * (direction + oldDirection)
		
		local step = config.segmentLength ~= nil and config.segmentLength or 0.667 * (50.0 + 5 * math.sqrt(length))
		local dirVec = vec2.fromAngle(direction)
		position = vec2.add(position, vec2.mul(step, dirVec))
		length = length - step
		valley.tangents[#valley.tangents + 1] = vec2.mul(vec2.length(vec2.sub(position, oldPosition)), vec2.fromAngle(0.5 * (direction + oldDirection) + math.randf(-math.rad(-20), math.rad(20))))
		
		-- BEGIN DETECT INTERSECTIONS
		if oldPosition ~= nil then
			local nsegments = math.ceil(vec2.distance(position, oldPosition) / distanceCheck) * 4
			for j = 1, nsegments do
				local factor = j / nsegments
				local newPos = vec2.add(oldPosition, vec2.mul(factor, vec2.sub(position, oldPosition)))
				local index = GetIndex(newPos)
				if config.map[index] == nil then config.map[index] = {} end
				config.map[index][#config.map[index]+1] = {
					riverId = config.map.riverId,
					position = newPos
				}
			end
		end
		-- BEGIN DETECT INTERSECTIONS

		if length < 0 then return 0 end
		if position.x > config.bounds.max.x + 5000
			or position.y > config.bounds.max.y + 5000
			or position.x < config.bounds.min.x - 5000
			or position.y < config.bounds.min.y - 5000 then
			break
		end	
		
		-- BEGIN DETECT INTERSECTIONS
		local dmap = { }
		if oldPosition ~= nil then
			local nsegments = math.ceil(vec2.distance(position, oldPosition) / distanceCheck) * 4
			for j = 1, nsegments do
				local factor = j / nsegments
				local newPos = vec2.add(oldPosition, vec2.mul(factor, vec2.sub(position, oldPosition)))
				dmap[#dmap + 1] = GetIndex(newPos)
				dmap[#dmap + 1] = GetIndex(vec2.add(newPos, vec2.new(-distanceCheck, 0)))
				dmap[#dmap + 1] = GetIndex(vec2.add(newPos, vec2.new( distanceCheck, 0)))
				dmap[#dmap + 1] = GetIndex(vec2.add(newPos, vec2.new( 0,-distanceCheck)))
				dmap[#dmap + 1] = GetIndex(vec2.add(newPos, vec2.new( 0, distanceCheck)))
				dmap[#dmap + 1] = GetIndex(vec2.add(newPos, vec2.new(math.sqrt(2) * distanceCheck,  math.sqrt(2) * distanceCheck)))
				dmap[#dmap + 1] = GetIndex(vec2.add(newPos, vec2.new(math.sqrt(2) * distanceCheck,  math.sqrt(2) * -distanceCheck)))
				dmap[#dmap + 1] = GetIndex(vec2.add(newPos, vec2.new(math.sqrt(2) * -distanceCheck, math.sqrt(2) * distanceCheck)))
				dmap[#dmap + 1] = GetIndex(vec2.add(newPos, vec2.new(math.sqrt(2) * -distanceCheck, math.sqrt(2) * -distanceCheck)))
				for k, index in pairs(dmap) do
					if config.map[index] ~= nil then
						for k2, mapVal in pairs(config.map[index]) do
							if mapVal.riverId ~= config.map.riverId 
								and not (i == 1 and mapVal.riverId == feededId)
								and not (newPos.x < config.bounds.min.x)
								and not (newPos.x > config.bounds.max.x)
								and not (newPos.y < config.bounds.min.y)
								and not (newPos.y > config.bounds.max.y)
								and vec2.distance(mapVal.position, newPos) < distanceCheck then
								return 0
							end
						end
					end
				end
			end
		end
		
		-- Calculate direction of next segment
		oldPosition = position
		oldDirection = direction

		local newDirection = math.clamp(step / 300, 0.667, 1.5) * math.randf(-config.curvature, config.curvature)
		if math.abs(totalDirection + newDirection) > math.rad(135) then newDirection = 0 end
		if config.is_winding then
			if totalDirection > math.rad(20) then
				newDirection = math.rad(-math.random(20,120))
			elseif
			totalDirection < math.rad(-20) then
				newDirection = math.rad(math.random(20,120))
			end
		end

		totalDirection = totalDirection + newDirection
		direction = direction + newDirection
	end

	valleys[#valleys+1] = valley
	

	-- Check if new river arm should start from this segment
	local riverProbability = {0.6, 0.4, 0.1, 0.05, 0.05, 0, 0} -- Probabilities are based on order
	local childCount = {12, 4, 4, 4, 4} -- Max splits are based on order
	local baseVolume = {3, 2, 1, 1, 1}
	
	local totVolume = baseVolume[order + 1]
	
	local effluentIndex = #valleys
	local feededId = config.map.riverId
	if order < config.maxOrder + 1 then
		local count = 0
		local lastFeeder = -1
		for i = 2, #valley.points - 1 do
			if math.random() < riverProbability[order + 1] * config.baseProbability
				and count <= childCount[order + 1] and i - lastFeeder > config.minDist then
					local side = math.random() < 0.5 and 1 or -1
					local newDirection = directions[i] + side * math.pi * math.randf(0.1, 0.3)
					local newLength = math.randf(2 / 3, 1) * length
					local feeder = #valleys + 1
					local maxStartWidth = valley.widths[i]["x"] * 1.1
					local minStartWidth = maxStartWidth / 3
					local newNumSegments = config.numSegments - i + math.random(-10, 5)
					newNumSegments = math.clamp(newNumSegments, 5, 999999)
					local newConfig = {
						depthScale = config.depthScale,
						maxOrder = config.maxOrder,
						numSegments = config.numSegments - i + math.random(-10, 5),
						segmentLength = math.random(500, 700),
						bounds = config.bounds,
						baseProbability = config.baseProbability,
						minDist = config.minDist,
						startWidth = math.random(minStartWidth, maxStartWidth),
						endWidth = math.random(20, 40),
						curvature = math.random(200, 800) / 1000,
						is_winding = math.random() < 0.5 and true or false,
						map = config.map
					}
					newConfig.map.riverId = config.map.riverId + 1
					local riverVolume = data.MakeRivers(valleys, newConfig, 
						newLength, valley.points[i], newDirection, order + 1, feededId, directions[i], effluentIndex, i
					)


					valley.widths[i][side == 1 and "x" or "y"] = valley.widths[i][side == 1 and "x" or "y"] + 10

					count = count + 1
					lastFeeder = i
			end
		end
	end

end

function data.AddCurvesToSegment(valley, index, strength1, strength2, getWidthMutiplierFn)
	local tangentParam = 700
	local varianceParam = 100.0
	local distVarianceParam = 10.0
	local lengthVarianceParam = 0.1
	local curveBaseOffset = 200

	local startPoint = valley.points[index]
	local endPoint = valley.points[index + 1]
	local startWidth = valley.widths[index]
	local endWidth = valley.widths[index + 1]
	local startDepth = valley.depths[index]
	local endDepth = valley.depths[index + 1]
	
	local subdivLength = 600
	local segmentVec = vec2.sub(endPoint, startPoint)
	local segmentLength = vec2.length(segmentVec)
	local subdiv = math.ceil(segmentLength / subdivLength)
	local subdivLength = segmentLength / subdiv
	local subdivVec = vec2.div(segmentVec, subdiv)
	local dirVec = vec2.div(segmentVec, segmentLength)
	
	local sign = 1
	
	for i = 1, subdiv - 1 do
		local t = i / subdiv
		local offsetParam =  math.lerp(strength1, strength2, t)
		local lengthVariance = 0.01 --math.random(-lengthVarianceParam, lengthVarianceParam)
		
		local nextPoint = vec2.add(
			startPoint, 
			vec2.mul(i + lengthVariance, subdivVec)
		)
		local curveOffsetMultiplier = math.lerp(strength1, strength2, t)
		local perpOffset = curveBaseOffset * curveOffsetMultiplier + math.random(-distVarianceParam, distVarianceParam)
		
		sign = sign * -1

		local newPos = vec2.add(
			nextPoint, 
			vec2.mul(
				sign * perpOffset,
				vec2.new(-dirVec.y, dirVec.x)
			)
		)
		local newTangent = vec2.mul(tangentParam + math.random(-varianceParam, varianceParam), dirVec)
		local widthMultiplier = getWidthMutiplierFn(nextPoint)
		
		table.insert(valley.points, index + i, newPos)
		table.insert(valley.tangents, index + i, newTangent)
		table.insert(valley.widths, index + i, vec2.new(math.lerp(startWidth.x, endWidth.x, t) * widthMultiplier, math.lerp(startWidth.y, endWidth.y, t) * widthMultiplier))
		table.insert(valley.depths, index + i, math.lerp(startDepth, endDepth, t))
		table.insert(valley.widthTangents, index + i, vec2.new(0,0))
		table.insert(valley.depthTangents, index + i, 0)
		table.insert(valley.features, index + i, { curve = true })
	end
	
	return subdiv - 1
end

function data.MakeCurvesOld(rivers, curveConfig)
	for k, river in pairs(rivers) do
		local index = 1
		while index < #river.points do
			local pos1 = river.points[index]
			local pos2 = river.points[index+1]
			
			local strength1 = curveConfig.getStrength(pos1)
			local strength2 = curveConfig.getStrength(pos2)
			
			local newNodes = 0
			if river.features[index].lake == nil then
				newNodes = data.AddCurvesToSegment(river, index, strength1, strength2, curveConfig.getWidthMultiplier)
			end
			index = index + newNodes + 1
		end
		for index = 2,#river.points - 1 do
			if river.features[index - 1].curve ~= nil
				and river.features[index].curve == nil
				and river.features[index + 1].curve ~= nil then
				river.features[index].curve = true
				river.widths[index] = vec2.mul(curveConfig.getWidthMultiplier(river.points[index]), river.widths[index])
				river.tangents[index] = vec2.mul(0.1, vec2.sub(river.points[index+1], river.widths[index-1]))
			end
		end
	end
end

function data.MakeLakesOld(rivers, lakeConfig)
	for k, river in pairs(rivers) do
		local index = 1
		while index < #river.points - 1 do
			local newNodes = 0
			
			local prob = 1
			for i = 0,5 do
				prob = math.min(prob, lakeConfig.getLakePropability(vec2.lerp(river.points[index], river.points[index+1], i/5)))
			end
			if river.features[index].curve == nil then 
				local isLake = prob > math.random() and index ~= 1
			
				local dist = vec2.sub(river.points[index+1], river.points[index])
				local segmentLength = vec2.length(dist)
			
				local startPoint = river.points[index]
				local endPoint = river.points[index+1]
				local startTangent = river.tangents[index]
				local endTangent = river.tangents[index+1]
				local startDepth= river.depths[index]
				local endDepth = river.depths[index+1]
				local startDepthT = river.depthTangents[index]
				local endDepthT = river.depthTangents[index+1]
				local startWidth = river.widths[index]
				local endWidth = river.widths[index+1]
				local startWidthT = river.widthTangents[index]
				local endWidthT = river.widthTangents[index+1]
				
				local numSegments = 3
				if isLake then river.features[index].lake = true end
				river.tangents[index] = vec2.div(river.tangents[index], numSegments)
				for i = 1, numSegments - 1 do
					local fact = i / numSegments 
					table.insert(river.points, index + i, vec2.herp(startPoint, endPoint, startTangent, endTangent, fact))
					table.insert(river.tangents, index + i, vec2.div(vec2.herpPrime(startPoint, endPoint, startTangent, endTangent, fact), numSegments))
					
					table.insert(river.widths, index + i, vec2.lerp(startWidth, endWidth, fact))
					table.insert(river.depths, index + i, math.lerp(startDepth, endDepth, fact))
					table.insert(river.widthTangents, index + i, vec2.lerp(startWidthT, endWidthT, fact))
					table.insert(river.depthTangents, index + i, math.lerp(startDepthT, endDepthT, fact))
					
					table.insert(river.features, index + i, { lake = isLake })
					newNodes = newNodes + 1
				end
				river.tangents[index + newNodes] = vec2.div(river.tangents[index + newNodes], numSegments)
				if isLake then river.features[index + newNodes].lake = true end
			end
			index = index + newNodes + 1
		end
		
		index = 1
		while index < #river.points - 1 do
		
			local lakeIndices = 0
			while river.features[index + lakeIndices].lake == true do
				lakeIndices = lakeIndices + 1
			end
			
			local offs = math.randf(0.1, 0.3)
			local startWidth = river.widths[index]
			local endWidth = river.widths[index + lakeIndices]
			local startDepth = river.depths[index]
			local endDepth = river.depths[index + lakeIndices]
			
			if lakeIndices > 0 then
				for i = index + 1, index + lakeIndices - 1 do
					local fact = (i - index - 1) / (lakeIndices - 2)
					local profile = (0.5-math.abs(math.mapClamp(fact, offs, 1 - offs, 0, 1) - 0.5)) * 2
					
					profile = profile * math.randf(0.8, 1.2)
					profile = math.herp(0, 1, 0, 0, profile)
					
					local newWidth = vec2.mul(lakeConfig.lakeSize, vec2.new(profile, profile))
					newWidth.x = math.max(newWidth.x, math.lerp(startWidth.x, endWidth.x, fact))
					newWidth.y = math.max(newWidth.y, math.lerp(startWidth.y, endWidth.y, fact))

					river.widths[i] = newWidth
					river.depths[i] = math.max(profile * 0.1 * lakeConfig.lakeSize, math.lerp(startDepth, endDepth, fact))
					river.widthTangents[i] = vec2.new(0,0)
					river.depthTangents[i] = 0
				end
				
				
				for i = index + 1, index + lakeIndices - 1 do
					river.widthTangents[i] = vec2.mul(0.2, vec2.add(vec2.sub(river.widths[i+1], river.widths[i]),vec2.sub(river.widths[i], river.widths[i-1])))
				end
			end
			
			index = index + lakeIndices + 1
		end
		
		-- local effId = river.effluent[1]
		-- local effIdx = river.effluent[2]
		-- if effId ~= nil and rivers[effId] ~= nil then
			-- if (rivers[effId].widths[effIdx].x > 180 or rivers[effId].widths[effIdx].y > 180) then
				-- river.widths[1].x = river.widths[1].x + 160
				-- river.widths[1].y = river.widths[1].y + 160
			-- end
		-- end
	end
end

function data.MakeRidge(startPos, startDir, startHeight, peakHeight, maxHeight, maxAngle, step)
	local ridge = {
		points = {},
		heights = {},
		directions = {},
	}

	local oldDir = startDir
	local maxAngle = math.rad(maxAngle)
	local stop = false
	local goDown = false
	local count = 0
	while true do
		ridge.points[#ridge.points + 1] = { startPos.x, startPos.y }
		ridge.heights[#ridge.heights + 1] = startHeight
		ridge.directions[#ridge.directions + 1] = 0.5 * (oldDir + startDir)
		if stop then break end

		startPos = vec2.add(startPos, vec2.mul(step, vec2.fromAngle(startDir)))

		oldDir = startDir;
		startDir = startDir + math.random(-maxAngle, maxAngle);

		if goDown 
			then startHeight = startHeight + math.random(-266, 200)
			else startHeight = startHeight + math.random(-200, 266) 
		end

		if startHeight >= peakHeight then goDown = true end
		if goDown and startHeight <= 0 then stop = true end
		startHeight = math.clamp(startHeight, 0, maxHeight)

		count = count + 1
	end

	return ridge
end

function data.MakeRidges(config)
	local ridges = {}

	local dimx = 2048
	local dimy = 2048

	local nx = math.ceil((config.bounds.max.x - config.bounds.min.x) / (2*dimx) )
	local ny = math.ceil((config.bounds.max.y - config.bounds.min.y) / (2*dimy) )

	for i = -ny, ny do
		for j = -nx, nx do
			
		
			local randomNumber = math.random()
			local numr = config.density ~= nil and config.density or 
				(randomNumber > config.probabilityLow and 0 or (randomNumber > config.probabilityHigh and 1 or 2))

			local skip = false
			
			local pos = vec2.new(dimx * j, dimy * i)
			if config.strengthMap then
				local X = math.floor((j + nx) / (2 * nx + 1) * config.strengthMap.size[1])
				local Y = math.floor((i + ny) / (2 * ny + 1) * config.strengthMap.size[2])
				if config.strengthMap.data[Y * config.strengthMap.size[1] + X + 1] > 0.3 then
					skip = true
				end
			end
			if not skip then
				for I = 1, numr do

					local rndx = math.randf(0.25 * dimx, 0.75 * dimx)
					local rndy = math.randf(0.25 * dimy, 0.75 * dimy)
					local startPos = vec2.add(pos, vec2.new(rndx, rndy))
					local startDir = math.random() * math.pi * 2
					local peakHeight = math.randf(config.minHeight, config.maxHeight - 5)
					local maxAngle = math.random(2, 20) -- max angle of ridges is random
					local stepLength = math.random(400, 700) -- step length of ridges is random (default = 500)
					ridges[#ridges + 1] = data.MakeRidge(startPos, startDir, 0, peakHeight, config.maxHeight, maxAngle, stepLength)
				end
			end
		end
	end

	return ridges
end

function data.MakeValley(valleys, startPos, startDir, length, step, order)
	if order == nil then order = 0 end
	local maxOrder = 2
	local pChild = { 0.3, 0.1 }
	local countChild = { 8, 8 }
	local lenChild = { 6000, 4000 }

	local maxAngle = math.rad(order == 0 and 15 or 10)
	local count = 0
	local lastChild = -10
	repeat
		valleys.points[#valleys.points + 1] = { startPos.x, startPos.y }

		if order < maxOrder 
				and count - lastChild > 4 
				and length >= lenChild[order+1]
				and math.random() <= pChild[order + 1]
				and count >= countChild[order+1] then

			local sign = math.random() < 0.5 and 1 or -1
			local newDir = startDir + sign * math.map(math.random(), 0, 1, 0.333, 0.667) * math.pi
			local newLength = math.map(math.random(), 0, 1, 0.667, 0.75) * length

			data.MakeValley(valleys, startPos, newDir, newLength, 300, order+1)
			lastChild = count;
		end

		startPos = vec2.add(startPos, vec2.mul(step, vec2.fromAngle(startDir)))
		startDir = startDir + math.random(-maxAngle, maxAngle)
		length = length - step
		count = count + 1
	until length < 0
end

function data.MakeManyValleys()
	local valleys = { 
		points = { }
	}

	local initialValleys = 4
	local valDir = math.random() * math.pi * 2
	local frac = 2 / initialValleys;

	for i = 1, initialValleys do
		data.MakeValley(valleys, vec2.new(0, 0), valDir + i * frac * math.pi, 25000, 500)
	end

	return valleys
end

return data