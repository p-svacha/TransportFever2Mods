function data()
return {
	info = {
	    minorVersion = 0,
	    severityAdd = "NONE",
	    severityRemove = "NONE",
	    name = _("Interesting Towns"),
	    description = _("Towns will look and develop in more interesting and organic shapes, rather than just square blocks. Towns will also be generated in rougher terrain."),
        tags = {"World", "Misc", "Towns", "Script Mod", "Town", "Town Generation", "Square", "Blocks", "Shape", "Looks", "Town Generation", "Perpendicular", "Organic", "Terrain", "Rough", "Spawn", "Challenging"},
        authors = {
			{
				name = "Phil42",
				role = "Creator",
			},
		},
	},

	  -- main function before resource loading (optional)
	  runFn = function (settings, modParams)
		game.config.townMajorStreetAngleRange = 30
		game.config.townInitialMajorStreetAngleRange = 30
		game.config.locations.town.allowInRoughTerrain = true
	  	end, 
}
end
	