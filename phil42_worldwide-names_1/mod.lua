function data()
return {
	info = {
	    minorVersion = 0,
	    severityAdd = "NONE",
	    severityRemove = "NONE",
	    name = _("Worldwide Names"),
	    description = _("Want to play in a world where borders and nation states are a thing of the past? This mods adds a wide and random selection of city names, people names and street names from ALL regions of the world and puts them in this one mod. There is no detailed selection criteria to the names included, I just took huge datasets of country-specific names, and selected the names randomly. Since the country filter was applied first in the random selection, no country or region should be over- or underrepresented. Includes 10'000 each for town names, street names, male first names, female first names and last names."),
        tags = {"World", "Misc", "City Names", "Script Mod", "People Names", "Street Names", "Worldwide", "Random", "Names", "City", "Town", "Street", "People", "Generated", "Representation"},
        authors = {
			{
				name = "Phil42",
				role = "Creator",
			},
		},
	},
	categories = {
		{ key = "nameList", name = _("Town names") },
	},
	options = {
		nameList = {
            {"RAND_worldwide", _("Worldwide")},
        },
    }
}
end
	