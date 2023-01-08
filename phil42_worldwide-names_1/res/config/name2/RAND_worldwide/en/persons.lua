local worldwide_names = require "WORLDWIDE_PERSON_NAMES_UTIL"

local firstNamesMale = worldwide_names.worldwide.english.firstNamesMale
local firstNamesFemale = worldwide_names.worldwide.english.firstNamesFemale
local lastNames = worldwide_names.worldwide.english.lastNames

function data()
return {
	makeName = function (male)
		if (male) then
			return firstNamesMale[math.random(#firstNamesMale)] .. " " .. lastNames[math.random(#lastNames)]
		else
			return firstNamesFemale[math.random(#firstNamesFemale)] .. " " .. lastNames[math.random(#lastNames)]
		end
	end
}
end
