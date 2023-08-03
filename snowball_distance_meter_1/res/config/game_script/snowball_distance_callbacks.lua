local gui = require "gui"
local vec3 = require "snowball/common/vec3_1"

local state = {
    label = nil,
    value = nil,
    mostRecent = nil,   
}

local function createComponents()
    
    state.labels = {}
    state.values = {}
    
    local line = api.gui.comp.Component.new("VerticalLine")
    state.label = api.gui.comp.TextView.new(_("D:"))
    state.value = api.gui.comp.TextView.new(_("0.0"))
    
    local gameInfoLayout = api.gui.util.getById("gameInfo"):getLayout()
    gameInfoLayout:addItem(line) 
    gameInfoLayout:addItem(state.label) 
    gameInfoLayout:addItem(state.value)
    
end

local function getClosestNodeToMousePosition()   
    
    local target = game.gui.getTerrainPos()
    local nodes = game.interface.getEntities({pos = target, radius = 100}, {type="BASE_NODE", includeData=true})
         
    local closestPosition = nil
    local closestDistance = nil

    for id, node in pairs(nodes) do        
        local distance = vec3.distance(target, node.position)

        if not closestDistance or distance < closestDistance then
            closestDistance = distance
            closestPosition = node.position
        end
        
    end

    return closestPosition
end

function data()
    return {
       
        guiHandleEvent = function(id, name, params)
            
            if name == "builder.proposalCreate" then                
                state.potential = game.gui.getTerrainPos()
            elseif name == "builder.apply" then 
                
                --Construction
                if #params.result > 0 then
                    state.mostRecent = game.interface.getEntity(params.result[1]).position
                --Straße oder Gleis
                elseif #params.proposal.proposal.addedNodes > 0 then 
                    state.mostRecent = getClosestNodeToMousePosition()
                --Haltestelle oder Wegpunkt
                else
                    state.mostRecent = game.gui.getTerrainPos()                   
                end                
            end                   
            
        end,
        guiUpdate = function()
            
            if not state.value then
                createComponents()
            end
            
            local pos = game.gui.getTerrainPos()
            
            if state.mostRecent and pos then
                
                local a = pos[1] - state.mostRecent[1]
                local b = pos[2] - state.mostRecent[2]
                local c = pos[3] - state.mostRecent[3]
                local d = math.sqrt(a * a + b * b + c * c)
                
                state.value:setText(string.format("%5.1f m", d))
            
            else
                state.value:setText("")
            end
        
        end
    }
end
