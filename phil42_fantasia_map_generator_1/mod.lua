local climate = require "fmg/fmg_climateModifier"

function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
		if type(k) ~= 'number' then k = '"'..k..'"' end
		s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

function data()
return {
	info = {
		minorVersion = 4,
		severityAdd = "NONE",
		severityRemove = "NONE",
		name = "Fantasia Map Generator",
		visible = true,
		description = "This mods adds a new map generator with its own new climate. The Fantasia Map Generator is built up from the ground with the goal to generate unique, interesting, varied and challenging maps allowing (and requiring) usage of street, rail, water and air vehicles. The generator attempts to combine a lot of different features into one map, so you no longer have to choose between alpine rivers, dry mesas and tropical islands, because this generator has it all (mostly). Different parts of the map will look and play different and have their own identity and recognizability. A lot is also configurable so you can tune the map generation to your own preferences.",
		tags = { "Map", "Terrain", "Generator", "Generation", "Temperate", "European", "Hills", "Mountains", "Random", "Rivers", "Lakes", "Misc", "Script Mod", "Peaks", "Variety", "Fantasy", "Challenge", "Canyon", "Mesa", "Climate", "Desert", "Cliffs" },
		authors = {
			{
				name = "Phil42",
				role = 'CREATOR',
			},
		}
	},
	options = {
		climate = { { "fantasia", _("Fantasia") } }
	},
	runFn = function (settings)
		if settings.climate == "fantasia" then
			game.config.climate = "temperate.clima.lua"
			addModifier("loadClimate", climate.modifyClimate)
		end
	end
}
end
