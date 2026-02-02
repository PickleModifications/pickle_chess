INT_ENTITIES = {}
CURRENT_ENTITY = nil
CURRENT_INTERACTION = nil
local InteractiveEntityTypes = {}

-- Board drag: piece stays at this height (in meters relative to interaction coords) while dragging
local DRAG_Z_OFFSET = 0.075
-- Board/table half-extent in meters; pieces are clamped so they can't be dragged off
local DRAG_BOARD_HALF_EXTENT = 0.22
-- Screen region: inset from each edge (0-1); region is [inset, 1-inset]. Larger = smaller drag area.
local DRAG_SCREEN_INSET_X = 0.38
local DRAG_SCREEN_INSET_Y = 0.38
-- Grace zone (0-1) outside inset before we clamp; avoids sticky feel when cursor exceeds and returns
local DRAG_SCREEN_GRACE = 0.05

function lerp(a, b, t)
    return a + (b - a) * t
end

function clamp(value, minVal, maxVal)
    return math.max(minVal, math.min(maxVal, value))
end

-- Draw 3D text at a world position
function DrawText3D(x, y, z, text)
    local success, screenX, screenY = World3dToScreen2d(x, y, z)
    if success then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextOutline()
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(screenX - (text:len() * 0.0015), screenY)
    end
end

function InteractiveEntityThread(entity, data)
    local currentEntity = INT_ENTITIES[entity]
    if not currentEntity then return end
    local entType = InteractiveEntityTypes[currentEntity.type]
    if not entType then return end
    if entType.entityThread then
        entType.entityThread(entity, data)
    end
end

function SelectedInteractiveEntityThread(entity, data)
    local currentEntity = INT_ENTITIES[entity]
    if not currentEntity then return end
    local entType = InteractiveEntityTypes[currentEntity.type]
    if not entType then return end
    if entType.selectedThread then
        entType.selectedThread(entity, data)
    end
end

function UnselectedInteractiveEntity(entity, data)
    local currentEntity = INT_ENTITIES[entity]
    if not currentEntity then return end
    local entType = InteractiveEntityTypes[currentEntity.type]
    if not entType then return end
    if entType.unSelected then
        entType.unSelected(entity, data)
    end
end

function InteractiveEntityClicked(entity, data)
    local currentEntity = INT_ENTITIES[entity]
    if not currentEntity then return end
    local entType = InteractiveEntityTypes[currentEntity.type]
    if not entType then return end
    if entType.clicked then
        entType.clicked(entity, data)
    end
end

function RegisterInteractiveEntity(entType, data)
    InteractiveEntityTypes[entType] = data
end

function UpdateInteractiveEntityDisplay(entity, data)
    if not INT_ENTITIES[entity] then return end
    if data then
        for k,v in pairs(data) do
            INT_ENTITIES[entity].display[k] = v
        end
    else
        INT_ENTITIES[entity].display = nil
    end
end

function DeleteInteractiveEntity(entity)
    if not INT_ENTITIES[entity] then return end
    local entType = InteractiveEntityTypes[INT_ENTITIES[entity].type]
    if not entType then return end
    if entType.delete then
        entType.delete(entity)
    end
    if CURRENT_ENTITY == entity then
        CURRENT_ENTITY = nil
    end
    DeleteEntity(entity)
    INT_ENTITIES[entity] = nil
end

function CreateInteractiveEntity(entType, coords, heading, params)
    -- local entity = CreateEntity(entType, coords, heading, data)
    -- INT_ENTITIES[entity] = data
    if not InteractiveEntityTypes[entType] then return print("ERROR: No interactive entity type found for: ", entType) end
    local entityData = {
        type = entType,
        zOffset = 0.01,
        display = params.display,
    }
    local entity = nil
    local newData = {}
    if InteractiveEntityTypes[entType].init then
        entity, newData = InteractiveEntityTypes[entType].init(coords, heading, entityData, params)
    end
    if not entity then return print("ERROR: No entity created for: ", entType) end
    for k,v in pairs(newData or {}) do
        entityData[k] = v
    end
    INT_ENTITIES[entity] = entityData
    print("Created interactive entity: ", entType, json.encode(entityData, {indent = true}))
    return entity
end

function StartInteraction(coords, heading)
    if CURRENT_INTERACTION then return ShowNotification("ERROR: Interaction already started") end
    local temp = CreateTennisBall(coords.x, coords.y, coords.z)
    SetEntityRotation(temp, 0.0, 0.0, heading, 2, true)
    local forwardVector, rightVector, upVector, position = GetEntityMatrix(temp)
    DeleteEntity(temp)
    CreateScriptedCamera()
    local camCoords = coords
    local camRotation = vector3(-55.0, 0.0, heading)
    SetCamParams(CurrentCamera, camCoords.x, camCoords.y, camCoords.z,
        camRotation.x, camRotation.y, camRotation.z, 90.0, 
        0, 0, 0, 2
    )
    CURRENT_INTERACTION = {
        coords = coords,
        heading = heading,
        forwardVector = forwardVector,
        rightVector = rightVector,
        upVector = upVector,
    }
    -- Send controls to NUI
    SendNUIMessage({
        type = "updateControls",
        controls = {
            {key = "ESC", label = "controls_exit"}
        }
    })
    -- Cursor grace: pull cursor to closest point on grace boundary when it exceeds zone (runs every 500ms so it doesn't get stuck)
    CreateThread(function()
        while CURRENT_INTERACTION do
            if CURRENT_ENTITY then
                local screenX, screenY = GetNuiCursorPosition()
                local resX, resY = GetActualScreenResolution()
                screenX = screenX / resX
                screenY = screenY / resY
                local edgeMinX, edgeMaxX = DRAG_SCREEN_INSET_X, 1.0 - DRAG_SCREEN_INSET_X
                local edgeMinY, edgeMaxY = DRAG_SCREEN_INSET_Y, 1.0 - DRAG_SCREEN_INSET_Y
                local graceMinX = edgeMinX - DRAG_SCREEN_GRACE
                local graceMaxX = edgeMaxX + DRAG_SCREEN_GRACE
                local graceMinY = edgeMinY - DRAG_SCREEN_GRACE
                local graceMaxY = edgeMaxY + DRAG_SCREEN_GRACE
                local needsMove = false
                local newX, newY = screenX, screenY
                -- Clamp to closest point on grace boundary (only change the axis that exceeded)
                if screenX < graceMinX then
                    newX = graceMinX
                    needsMove = true
                elseif screenX > graceMaxX then
                    newX = graceMaxX
                    needsMove = true
                end
                if screenY < graceMinY then
                    newY = graceMinY
                    needsMove = true
                elseif screenY > graceMaxY then
                    newY = graceMaxY
                    needsMove = true
                end
                if needsMove then
                    print(newX, newY)
                    SetCursorLocation(newX, newY)
                end
            end
            Wait(500)
        end
    end)
    CreateThread(function()
        local pitch = 0.0
        local lastX, lastY = -1, -1
        while CURRENT_INTERACTION do
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 51, true)
            -- Handle ESC to exit interaction (control 200 = ESC)
            -- Use IsControlJustPressed instead of IsDisabledControlJustPressed so ESC isn't blocked
            if IsControlJustPressed(0, 200) then
                StopInteraction()
                break
            end
            local screenX, screenY = GetNuiCursorPosition()
            local x, y = GetActualScreenResolution()
            screenX = screenX / x
            screenY = screenY / y
            for k,v in pairs(INT_ENTITIES) do
                InteractiveEntityThread(k, {
                    coords = coords,
                    heading = heading,
                    minimum = minimum,
                    maximum = maximum,
                })
            end
            if not CURRENT_ENTITY then
                local hit, dragCoords, entityHit = GetCursorRaycast(camCoords, camRotation)
                -- DrawMarker(1, dragCoords.x, dragCoords.y, dragCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.1, 0.1, 255, 0, 0, 255, false, false, 2)
                if IsDisabledControlJustPressed(0, 24)  then
                    if hit and DoesEntityExist(entityHit) and INT_ENTITIES[entityHit] then
                        if not INT_ENTITIES[entityHit].disableInteraction then
                            CURRENT_ENTITY = entityHit
                            pitch = GetEntityRotation(CURRENT_ENTITY).x
                            -- Store fixed drag height so piece doesn't bob while dragging
                            INT_ENTITIES[entityHit].dragZ = GetEntityCoords(entityHit).z
                        end
                        InteractiveEntityClicked(entityHit)
                    end
                end
                SetMouseCursorThisFrame()
            else
                local currentEntity = INT_ENTITIES[CURRENT_ENTITY]
                local minimum, maximum = GetModelDimensions(GetEntityModel(CURRENT_ENTITY))
                -- Map cursor from screen region to board plane (region = [inset, 1-inset] per axis)
                local minX, maxX = DRAG_SCREEN_INSET_X, 1.0 - DRAG_SCREEN_INSET_X
                local minY, maxY = DRAG_SCREEN_INSET_Y, 1.0 - DRAG_SCREEN_INSET_Y
                local normX = clamp((screenX - minX) / (maxX - minX), 0.0, 1.0)
                local normY = clamp((screenY - minY) / (maxY - minY), 0.0, 1.0)
                local boardX = clamp(lerp(-DRAG_BOARD_HALF_EXTENT, DRAG_BOARD_HALF_EXTENT, normX), -DRAG_BOARD_HALF_EXTENT, DRAG_BOARD_HALF_EXTENT)
                local boardY = clamp(lerp(-DRAG_BOARD_HALF_EXTENT, DRAG_BOARD_HALF_EXTENT, normY), -DRAG_BOARD_HALF_EXTENT, DRAG_BOARD_HALF_EXTENT)
                local dragCoords = coords + (rightVector * boardX) - ((forwardVector * boardY) + (forwardVector * -0.35))
                SelectedInteractiveEntityThread(CURRENT_ENTITY, {
                    coords = coords,
                    heading = heading,
                    minimum = minimum,
                    maximum = maximum,
                    dragCoords = dragCoords,
                    pitch = pitch,
                })
                if IsDisabledControlPressed(0, 25) then
                    local normal = GetDisabledControlNormal(0, 1) * 60.0
                    pitch = pitch + normal
                    pitch = (pitch % 360 + 360) % 360
                    SetEntityRotation(CURRENT_ENTITY, 0.0, pitch, heading, 2, true)
                    if lastX == -1 then
                        lastX = screenX
                        lastY = screenY
                    end
                else
                    if lastX ~= -1 then
                        screenX = lastX
                        screenY = lastY
                        SetCursorLocation(lastX, lastY)
                        lastX = -1
                        lastY = -1
                    else
                        -- Use fixed Z (height when piece was picked up) so it doesn't bob while dragging
                        local dragZ = currentEntity.dragZ or (coords.z)
                        SetEntityCoords(CURRENT_ENTITY, dragCoords.x, dragCoords.y, dragZ + DRAG_Z_OFFSET)
                        if not IsDisabledControlPressed(0, 24) then
                            currentEntity.zOffset = dragZ - coords.z
                            UnselectedInteractiveEntity(CURRENT_ENTITY)
                            CURRENT_ENTITY = nil
                        end
                    end
                end
            end
            for k,v in pairs(INT_ENTITIES) do
                local entityCoords = GetEntityCoords(k)
                if v.display then
                    local onScreen, entityScreenX, entityScreenY = GetScreenCoordFromWorldCoord(entityCoords.x, entityCoords.y, entityCoords.z)
                    local rotation = GetEntityRotation(k, 2)
                    -- coords + (forwardVector * -0.5)

                    local hit, cursorCoords, entityHit = GetCursorRaycast(camCoords, camRotation)
                    local distance = #(cursorCoords - entityCoords)
                    local scale = lerp(1.0, 0.0, distance / 0.5)
                    if scale < 0.00 then
                        scale = 0.00
                    end
                    if scale > 1 then
                        scale = 1
                    end
                    SendNUIMessage({
                        type = "updateInteractiveEntityDisplay",
                        data = {
                            entity = k,
                            coords = entityCoords,
                            pitch = rotation.y,
                            display = v.display,
                            onScreen = onScreen,
                            screenX = entityScreenX,
                            screenY = entityScreenY,
                            scale = not v.display.hiddenHover and 1.0 or scale,
                        }
                    })
                end
            end
            Wait(0)
        end
    end)
    return CURRENT_INTERACTION
end

function StopInteraction()
    if not CURRENT_INTERACTION then return end
    
    -- Trigger event for other modules to cleanup (like station control)
    TriggerEvent("pickle_chess:stopInteraction")
    
    -- Hide controls in NUI
    SendNUIMessage({
        type = "updateControls",
        controls = nil
    })
    
    -- Clear all interactive entity displays
    for k,v in pairs(INT_ENTITIES) do
        SendNUIMessage({
            type = "updateInteractiveEntityDisplay",
            data = {
                entity = k,
                onScreen = false,
                display = nil,
            }
        })
        DeleteEntity(k)
    end
    INT_ENTITIES = {}
    CURRENT_INTERACTION = nil
    ExitScriptedCamera(2000)
end

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        for k,v in pairs(INT_ENTITIES) do
            DeleteEntity(k)
        end
        INT_ENTITIES = {}
    end
end)