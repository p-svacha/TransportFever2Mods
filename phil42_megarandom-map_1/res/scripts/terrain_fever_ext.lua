local vec2 = require "vec2"

local tfExtensions = { }

function tfExtensions.makeGradient(angle, Sx, Sy, mapResolution)
	
	-- http://mathworld.wolfram.com/Point-LineDistance2-Dimensional.html
	local distanceToLine = function (p1, p2, a)
		local num = math.abs((p2.x - p1.x) * (p1.y - a.y) - (p1.x - a.x) * (p2.y - p1.y));
		local det = math.sqrt((p2.x - p1.x)^2 + (p2.y - p1.y)^2)
		local d = num / det;
		return d
	end
	
	local getNearestSquareCorner = function (dir)
		return {
			x = math.clamp(math.abs(math.round(0.5 + dir.x)), -1, 1),
			y = math.clamp(math.abs(math.round(0.5 + dir.y)), -1, 1)
		}
	end
	
	local dir = vec2.fromAngle(angle) -- directional vector describing the angle
	local p1 = getNearestSquareCorner(dir) -- gradient start line: point 1
	local p2 = vec2.add(p1, vec2.rotate90(dir)) -- gradient start line: point 2
	local po = getNearestSquareCorner(vec2.mul(-1, dir)) -- point in opposite direction of p1
	local dmax = distanceToLine(p1, p2, po)
	
	local data = { }
	for y = 0,Sy-1 do
		for x = 0,Sx-1 do
			local d = distanceToLine(p1, p2, vec2.new(x/(Sx-1), y/(Sy-1)))
			data[Sx * y + x + 1] = d / dmax
		end 
	end
	return {
		size = {Sx, Sy},
		data = data,
		delta = mapResolution
	}
end

function tfExtensions.makeRadialGradient(Sx, Sy, mapResolution)
	
	local center = vec2.new(Sx / 2, Sy / 2)
	local maxDistance = Sx / 2
	
	local data = { }
	for y = 0,Sy-1 do
		for x = 0,Sx-1 do
			local p = vec2.new(x, y)
			local d = vec2.distance(p, center)
			data[Sx * y + x + 1] = 1 - math.clamp(d / maxDistance, 0, 1);
		end 
	end
	
	return {
		size = {Sx, Sy},
		data = data,
		delta = mapResolution
	}
	
end

function tfExtensions.makePointCloud(Sx, Sy, radius, pointCount)
	local points = {}
	for pts = 1, pointCount do
		points[#points + 1] = {
			Sx / 2 + Sx * (math.random() * 2 - 1) / 2 * radius, 
			Sy / 2 + Sy * (math.random() * 2 - 1) / 2 * radius
		}
	end
	return points
end

function tfExtensions.Exlerp(layers, from, to, subdivisions)
	local step = 1 / subdivisions
	local count = subdivisions
	
	local a = {}
	local b = {}
	
	for i = 0, count, 1 do
		a[i] = i * step
		b[i] = a[i]^2
	end
	
	layers:Pwlerp(from, to, a, b)
end
 
function tfExtensions.Exlerp2(layers, from, to, subdivisions)
	local step = 1 / subdivisions
	local count = subdivisions
	
	local a = {}
	local b = {}
	
	for i = 0, count, 1 do
		a[i] = i * step
		b[i] = math.min(1, 256 * a[i]^3)
	end
	
	layers:Pwlerp(from, to, a, b)
end

return tfExtensions
