local vec2 = require("vec2")
local vec3 = require("vec3")

local guiState = {}

function createButton(text, tooltipText, iconPath) 

	local buttonLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")

	local textView = api.gui.comp.TextView.new(_(text))	
	local imageView = api.gui.comp.ImageView.new(iconPath)
	imageView:setMaximumSize(api.gui.util.Size.new(24, 24))

	buttonLayout:addItem(imageView)
	buttonLayout:addItem(textView)

	local buttonComp = api.gui.comp.Component.new(" ")
	buttonComp:setLayout(buttonLayout)
	local button = api.gui.comp.Button.new(buttonComp,false)

	if tooltipText then
		button:setTooltip(_(tooltipText))
	end

	return button
end

-- ######################################## CAMERA FUNCTIONS ##############################

local function setCameraPosition(center, dist, angle, pitch)
	local cameraController = api.gui.util.getGameUI():getMainRendererComponent():getCameraController() -- get camera controller
	cameraController:follow(-1, false) -- unfollow currently followed object
	cameraController:setCameraData(center, dist, angle, pitch) -- set new position
	debugPrint("camera position set to " .. center.x .. "/" .. center.y .. ", distance: " .. dist .. ", angle: " .. angle .. ", pitch: " .. pitch)
end

local function getRandomPoisition()

	math.randomseed(os.time()) -- init randomness

	local terrain = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.TERRAIN)
	local mapSizeX = terrain.size.x
	local mapSizeY = terrain.size.y

	local realMapSizeX = mapSizeX * 250
	local realMapSizeY = mapSizeY * 250
	local edgeOffset = 50
	
	local realMinX = -(realMapSizeX / 2) + edgeOffset
	local realMaxX = (realMapSizeX / 2) - edgeOffset
	local realMinY = -(realMapSizeY / 2) + edgeOffset
	local realMaxY = (realMapSizeY / 2) - edgeOffset

	local px = math.random(realMinX, realMaxX)
	local py = math.random(realMinY, realMaxY)
	local posVec = api.type.Vec2f.new(px,py)

	return posVec
end

-- moves the camera to a fully random position
local function setRandomPosition()
	local center = getRandomPoisition()
	local dist = math.random(20, 300)
	local angle = math.random(0, 314) / 100
	local pitch = math.random(-50, 100) / 100
	setCameraPosition(center, dist, angle, pitch)
end

local function randomizeAnglesForFollowCam()
	local center = api.type.Vec2f.new(0,0)
	local dist = 20
	local angle = math.random(0, 314) / 100
	local pitch = math.random(-50, 50) / 100
	setCameraPosition(center, dist, angle, pitch)
end

local function setRandomEdgeView(type)

 	-- init randomness
	math.randomseed(os.time())

	-- get camera controller
	local cameraController = api.gui.util.getGameUI():getMainRendererComponent():getCameraController()

	-- get a random street
	local edgeIdList = (game.interface.getEntities({ radius = 1e100 }, { type = "BASE_EDGE" })) -- get all edges

	if next(edgeIdList) == nil then
		debugPrint("abort setRandomEdgeView() because no edges found")
		return 
	end

	local randomEdgeId = edgeIdList[math.random(#edgeIdList)]
	local edgeEntity = game.interface.getEntity(randomEdgeId)
	local baseEdgeComponent = api.engine.getComponent(randomEdgeId, api.type.ComponentType.BASE_EDGE)
	local edgeComponent = api.engine.getComponent(randomEdgeId, type)
	local counter = 0
	while(edgeComponent == nil or baseEdgeComponent.type == 2) --check if edge is of prefered type and not a tunnel
	do
		randomEdgeId = edgeIdList[math.random( #edgeIdList)]
		edgeEntity = game.interface.getEntity(randomEdgeId)
		baseEdgeComponent = api.engine.getComponent(randomEdgeId, api.type.ComponentType.BASE_EDGE)
		edgeComponent = api.engine.getComponent(randomEdgeId, type)
		counter = counter + 1
		if counter >= 1000 then
			debugPrint("abort setRandomEdgeView() because no candidate found that matches type")
			return
		end
	end

	debugPrint("chose street with id " .. randomEdgeId .. " and it has nodes with id " .. edgeEntity.node0 .. " & " .. edgeEntity.node1)

	local startNode = game.interface.getEntity(edgeEntity.node0)
	local endNode = game.interface.getEntity(edgeEntity.node1)
	local tangent = baseEdgeComponent.tangent0
	local angleOffset = -3.1416
	local centerOffset = 5
	if(math.random() < 0.5) then
		startNode = game.interface.getEntity(edgeEntity.node1)
		endNode = game.interface.getEntity(edgeEntity.node0)
		tangent = baseEdgeComponent.tangent1
		angleOffset = 0
		centerOffset = -5
	end

	-- move camera
	local centerOffset3 = vec3.mul(centerOffset, vec3.normalize(vec3.new(tangent.x, tangent.y, tangent.z))) -- offset forward to counteract minimum distance of camera
	local center = api.type.Vec2f.new(startNode.position[1] + centerOffset3.x, startNode.position[2] + centerOffset3.y)
	local dist = 15
	local angle = vec3.xyAngle(vec3.new(tangent.x, tangent.y, tangent.z)) + angleOffset
	local pitch = -0.35
	setCameraPosition(center, dist, angle, pitch)

	if baseEdgeComponent.type == 1 then -- special case for bridges
		cameraController:follow(randomEdgeId, false)
	end
end

local function followRandomVehicle()
	-- init randomness
	math.randomseed(os.time())

	-- get camera controller
	local cameraController = api.gui.util.getGameUI():getMainRendererComponent():getCameraController()

	-- get a random entity of specified type
	local vehicleIdList = (game.interface.getEntities({ radius = 1e100 }, { type = "VEHICLE" })) -- get all vehicles

	if next(vehicleIdList) == nil then
		debugPrint("abort followRandomVehicle() because no vehicles found")
		return 
	end

	local randomVehicleId = vehicleIdList[math.random(#vehicleIdList)]
	randomizeAnglesForFollowCam()
	cameraController:follow(randomVehicleId, false)

	debugPrint("Following vehicle with id " .. randomVehicleId)
end


local function followRandomVehicleOfType(type)
	-- init randomness
	math.randomseed(os.time())

	-- get camera controller
	local cameraController = api.gui.util.getGameUI():getMainRendererComponent():getCameraController()

	-- get a random entity of specified type
	local vehicleIdList = (game.interface.getEntities({ radius = 1e100 }, { type = "VEHICLE" })) -- get all vehicles

	if next(vehicleIdList) == nil then
		debugPrint("abort followRandomVehicleOfType() because no vehicles found")
		return 
	end

	local randomVehicleId = vehicleIdList[math.random(#vehicleIdList)]
	local typeComponent = api.engine.getComponent(randomVehicleId, type)
	local counter = 0
	while(typeComponent == nil) --check if vehicle is of prefered type
	do
		randomVehicleId = vehicleIdList[math.random(#vehicleIdList)]
		typeComponent = api.engine.getComponent(randomVehicleId, type)
		counter = counter + 1
		if counter >= 1500 then
			debugPrint("abort followRandomVehicleOfType() because no vehicles match specified type")
			return
		end
	end

	randomizeAnglesForFollowCam()
	cameraController:follow(randomVehicleId, false)

	debugPrint("Following vehicle with id " .. randomVehicleId)
end

local function followRandomPerson()
	-- init randomness
	math.randomseed(os.time())

	-- get camera controller
	local cameraController = api.gui.util.getGameUI():getMainRendererComponent():getCameraController()

	-- get a random entity id of specified type
	local personIdList = (game.interface.getEntities({ radius = 1e100 }, { type = "SIM_PERSON" }))

	if next(personIdList) == nil then
		debugPrint("abort followRandomPerson() because no person found")
		return 
	end

	local randomPersonId = personIdList[math.random(#personIdList)]
	randomizeAnglesForFollowCam()
	cameraController:follow(randomPersonId, false)

	debugPrint("Following person with id " .. randomPersonId)
end

local function followRandomAnimal()
	-- init randomness
	math.randomseed(os.time())

	-- get camera controller
	local cameraController = api.gui.util.getGameUI():getMainRendererComponent():getCameraController()

	-- get a random entity id of specified type
	local animalIdList = (game.interface.getEntities({ radius = 1e100 }, { type = "ANIMAL" }))

	if next(animalIdList) == nil then
		debugPrint("abort followRandomAnimal() because no animal found")
		return 
	end

	local randomAnimalId = animalIdList[math.random(#animalIdList)]
	randomizeAnglesForFollowCam()
	cameraController:follow(randomAnimalId, false)

	debugPrint("Following animal with id " .. randomAnimalId)
end

local function focusRandomBuilding(type, minDist, maxDist)
		-- init randomness
		math.randomseed(os.time())

		-- get camera controller
		local cameraController = api.gui.util.getGameUI():getMainRendererComponent():getCameraController()
	
		-- get a random entity of specified type
		local buildingIdList = (game.interface.getEntities({ radius = 1e100 }, { type = "CONSTRUCTION" }))
	
		if next(buildingIdList) == nil then
			debugPrint("abort focusRandomBuilding() because no building found")
			return 
		end
	
		local randomBuildingId = buildingIdList[math.random(#buildingIdList)]
		local buildingEntity = game.interface.getEntity(randomBuildingId)
		local isCorrectType = false
		local counter = 0
		while(not isCorrectType)
		do
			randomBuildingId = buildingIdList[math.random(#buildingIdList)]
			buildingEntity = game.interface.getEntity(randomBuildingId)
			if (buildingEntity and buildingEntity.fileName and (string.sub(buildingEntity.fileName, 1, string.len(type)) == type)) then
				isCorrectType = true
			end
			counter = counter + 1
			if counter >= 2000 then
				debugPrint("abort focusRandomBuilding() because no candidate found that matches type")
				return
			end
		end
		
		--local constructionComponent = api.engine.getComponent(randomBuildingId, api.type.ComponentType.CONSTRUCTION)

		local center = api.type.Vec2f.new(buildingEntity.position[1], buildingEntity.position[2])
		local dist = math.random(minDist, maxDist)
		local angle = math.random(0, 314) / 100
		local pitch = math.random(-50, 75) / 100
		setCameraPosition(center, dist, angle, pitch)
	
		debugPrint("Focussing building with id " .. randomBuildingId)
end

local function fullRandom()
	math.randomseed(os.time()) -- init randomness

	local rng = math.random(1, 5)

	if(rng == 1) then setRandomPosition() end-- any random position
		
	if(rng == 2) then -- street view
		local rng2 = math.random(1,3)
		if(rng2 == 1) then setRandomEdgeView(api.type.ComponentType.BASE_EDGE) end
		if(rng2 == 2) then setRandomEdgeView(api.type.ComponentType.BASE_EDGE_STREET) end
		if(rng2 == 3) then setRandomEdgeView(api.type.ComponentType.BASE_EDGE_TRACK) end
	end

	if(rng == 3) then -- vehicle
		local rng2 = math.random(1,5)
		if(rng2 == 1) then followRandomVehicle() end
		if(rng2 == 2) then followRandomVehicleOfType(api.type.ComponentType.TRAIN) end
		if(rng2 == 3) then followRandomVehicleOfType(api.type.ComponentType.ROAD_VEHICLE) end
		if(rng2 == 4) then followRandomVehicleOfType(api.type.ComponentType.SHIP) end
		if(rng2 == 5) then followRandomVehicleOfType(api.type.ComponentType.AIRCRAFT) end
	end

	if (rng == 4) then -- organism
		local rng2 = math.random(1,2)
		if(rng2 == 1) then followRandomPerson() end
		if(rng2 == 2) then followRandomAnimal() end
	end

	if(rng == 5) then -- structure
		local rng2 = math.random(1,3)
		if(rng2 == 1) then focusRandomBuilding("building/", 20, 80) end
		if(rng2 == 2) then focusRandomBuilding("industry/", 30, 200) end
		if(rng2 == 3) then focusRandomBuilding("station/", 30, 150) end
	end
end


-- ######################################## GUI BASE ##############################

local function buildWindow(geoguessrCamerasButton)

	local mainLayout = api.gui.layout.BoxLayout.new("VERTICAL");

	-- ROW: TITLE
	local rowTitle = api.gui.layout.BoxLayout.new("HORIZONTAL");
	rowTitle:addItem(api.gui.comp.TextView.new(_("Click on any button below to move the camera to a random object of that type.")))


	-- ROW: MISC / ANY
	local rowMisc = api.gui.layout.BoxLayout.new("HORIZONTAL");
	rowMisc:addItem(api.gui.comp.TextView.new(_("Misc:            ")))

	-- >> Random Position
	local randomPosButton = createButton("Any Position", "Moves the camera to a completely random position anywhere on the map.", "ui/icons/game-menu/highlines@2x.tga")
	rowMisc:addItem(randomPosButton)
	randomPosButton:onClick(function()
		setRandomPosition()
	end) 

	-- >> Full Random
	local fullRandomButton = createButton("Anything", "Randomly chooses one of all the other available options.", "ui/icons/construction-menu/filter_misc@2x.tga")
	rowMisc:addItem(fullRandomButton)
	fullRandomButton:onClick(function()
		fullRandom()
	end) 


	-- ROW: EDGES
	local rowEdges = api.gui.layout.BoxLayout.new("HORIZONTAL");
	rowEdges:addItem(api.gui.comp.TextView.new(_("Street View:")))

	-- >> Random Edge (street / track)
	local randomEdgeButton = createButton("Any Path", "Moves the camera to show a random street or rail track section from Street View position. Tunnels are excluded.", "ui/icons/construction-menu/category_street_construction@2x.tga")
	rowEdges:addItem(randomEdgeButton)
	randomEdgeButton:onClick(function() 
		setRandomEdgeView(api.type.ComponentType.BASE_EDGE)
	end)

	-- >> Random Street
	local randomStreetButton = createButton("Street", "Moves the camera to show a random street from Street View position. Tunnels are excluded.", "ui/icons/construction-menu/category_street@2x.tga")
	rowEdges:addItem(randomStreetButton)
	randomStreetButton:onClick(function() 
		setRandomEdgeView(api.type.ComponentType.BASE_EDGE_STREET)
	end)

	-- >> Random Rail Track
	local randomTrackButton = createButton("Rail Track", "Moves the camera to show a random rail track section from Street View position. Tunnels are excluded.", "ui/icons/construction-menu/category_tracks@2x.tga")
	rowEdges:addItem(randomTrackButton)
	randomTrackButton:onClick(function() 
		setRandomEdgeView(api.type.ComponentType.BASE_EDGE_TRACK)
	end)


	-- ROW: VEHICLES
	local rowVehicles = api.gui.layout.BoxLayout.new("HORIZONTAL")
	rowVehicles:addItem(api.gui.comp.TextView.new(_("Vehicles:      ")))

	-- >> Random Vehicle
	local randomVehicleButton = createButton("Any", "Moves the camera to follow any random transport vehicle (no private vehicles).", "ui/icons/game-menu/stats_vehicles@2x.tga")
	rowVehicles:addItem(randomVehicleButton)
	randomVehicleButton:onClick(function() 
		followRandomVehicle()
	end)

	-- >> Random Train
	local randomTrainButton = createButton("Train", "Moves the camera to follow a random train.", "ui/icons/game-menu/hud_filter_trains@2x.tga")
	rowVehicles:addItem(randomTrainButton)
	randomTrainButton:onClick(function() 
		followRandomVehicleOfType(api.type.ComponentType.TRAIN)
	end)

	-- >> Random Road Vehicle
	local randomRoadVehicleButton = createButton("Road Vehicle", "Moves the camera to follow a random road vehicle (truck / bus / tram).", "ui/icons/game-menu/hud_filter_road_vehicles@2x.tga")
	rowVehicles:addItem(randomRoadVehicleButton)
	randomRoadVehicleButton:onClick(function() 
		followRandomVehicleOfType(api.type.ComponentType.ROAD_VEHICLE)
	end)

	-- >> Random Ship
	local randomShipButton = createButton("Ship", "Moves the camera to follow a random ship.", "ui/icons/game-menu/hud_filter_ships@2x.tga")
	rowVehicles:addItem(randomShipButton)
	randomShipButton:onClick(function() 
		followRandomVehicleOfType(api.type.ComponentType.SHIP)
	end)

	-- >> Random Plane
	local randomPlaneButton = createButton("Plane", "Moves the camera to follow a random plane.", "ui/icons/game-menu/hud_filter_planes@2x.tga")
	rowVehicles:addItem(randomPlaneButton)
	randomPlaneButton:onClick(function() 
		followRandomVehicleOfType(api.type.ComponentType.AIRCRAFT)
	end)

	-- ROW: STRUCTURES
	local rowStructures = api.gui.layout.BoxLayout.new("HORIZONTAL")
	rowStructures:addItem(api.gui.comp.TextView.new(_("Structures:  ")))

	-- >> Random Town Building
	local randomTownBuildingButton = createButton("Town Building", "Moves the camera a random town building.", "ui/icons/game-menu/hud_filter_towns@2x.tga")
	rowStructures:addItem(randomTownBuildingButton)
	randomTownBuildingButton:onClick(function() 
		focusRandomBuilding("building/", 20, 80)
	end)

	-- >> Random Industry
	local randomIndustryButton = createButton("Industry", "Moves the camera a random industry.", "ui/icons/game-menu/hud_filter_industries@2x.tga")
	rowStructures:addItem(randomIndustryButton)
	randomIndustryButton:onClick(function() 
		focusRandomBuilding("industry/", 30, 200)
	end)

	-- >> Random Station
	local randomStationButton = createButton("Station", "Moves the camera a random station of any kind.", "ui/icons/game-menu/hud_filter_stops@2x.tga")
	rowStructures:addItem(randomStationButton)
	randomStationButton:onClick(function() 
		focusRandomBuilding("station/", 30, 150)
	end)
	

	-- ROW: ORGANISMS
	local rowOrganisms = api.gui.layout.BoxLayout.new("HORIZONTAL")
	rowOrganisms:addItem(api.gui.comp.TextView.new(_("Creatures:   ")))

	-- >> Random Person
	local randomPersonButton = createButton("Person", "Moves the camera to follow any random person that is currently travelling by foot or private transport.", "ui/icons/game-menu/passengers@2x.tga")
	rowOrganisms:addItem(randomPersonButton)
	randomPersonButton:onClick(function() 
		followRandomPerson()
	end)

	-- >> Random Animal
	local randomAnimalButton = createButton("Animal", "Moves the camera to follow a random animal.", "ui/icons/construction-menu/category_assets@2x.tga")
	rowOrganisms:addItem(randomAnimalButton)
	randomAnimalButton:onClick(function() 
		followRandomAnimal()
	end)



	-- complete layout
	mainLayout:addItem(rowTitle)
	mainLayout:addItem(rowEdges)
	mainLayout:addItem(rowVehicles)
	mainLayout:addItem(rowOrganisms)
	mainLayout:addItem(rowStructures)
	mainLayout:addItem(rowMisc)
	
    local window = api.gui.comp.Window.new(_('Geoguessr Cameras'), mainLayout)
	window:addHideOnCloseHandler()
	window:onClose(function() 
			guiState.isActive = false
			geoguessrCamerasButton:setSelected(false, false)
	 	end)
	window:setResizable(false)
	return {
		window = window,
	}
end

local function guiInit()

	local icon = api.gui.comp.ImageView.new("ui/geoguessr_cameras.tga")
    local mainButtonsLayout = api.gui.util.getById("mainButtonsLayout"):getItem(2)
    icon:setMaximumSize(api.gui.util.Size.new(60,60))
    icon:setMinimumSize(api.gui.util.Size.new(50,50))
    local geoguessrCameraButton = api.gui.comp.ToggleButton.new(icon)
	geoguessrCameraButton:setTooltip(_("Geoguessr Cameras"))
    geoguessrCameraButton:setName("ConstructionMenuIndicator")
    mainButtonsLayout:addItem(geoguessrCameraButton)
	  
	 
    local window = buildWindow(geoguessrCameraButton)
	window.window:setVisible(false,false)
	
	--api.gui.util.getGameUI():getMainRendererComponent():insertMouseListener(mouseListener)
	geoguessrCameraButton:onToggle(function (b)
		guiState.isActive = b
		if b then 
			window.window:setVisible(true,false)
		else
			window.window:close()
		end
    end)

    guiState.geoguessrCamerasWindow = window 	 

	debugPrint("guiInit done")
end

function data()
	return {
		-- Engine Callbacks
		load = function(loadedstate) end, -- is the callback that is called once on savegame load to retrieve the state data that was stored with the savegame.
		save = function() end, -- is a callback that can be triggered to save data to the shared state from where it can be persisted on savegame save.
		update = function() end, -- is a callback that is regularily called to do update processing in the engine simulation.
		handleEvent = function (src, id, name, param) end, -- is a callback that is called whenever an engine event happens.

		-- UI Callbacks
		guiInit = guiInit, -- is a callback that is called once on startup.
		guiUpdate = function () end, -- is a callback that is regularily called to refresh the gui.
		guiHandleEvent = function (id, name, param) end, -- is a callback that is called whenever a gui event happens
	}
  end