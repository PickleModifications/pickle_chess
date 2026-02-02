local tableEntity = {}

function GetBoardSquareCoords(row, col)
    if not tableEntity.boardMatrix then return nil end
    local square = 0.062
    local offset = 0.216
    local offCoords = tableEntity.boardMatrix.position
        + tableEntity.boardMatrix.forward * ((-offset) + row * square)
        + tableEntity.boardMatrix.right * ((col * square) - offset)
        + vector3(0.0, 0.0, 0.039)
    return offCoords
end

function GetChessPieceModel(piece, isWhite)
    local index = 1
    if piece == "pawn" then index = 6 end
    if piece == "rook" then index = 2 end
    if piece == "knight" then index = 3 end
    if piece == "bishop" then index = 4 end
    if piece == "queen" then index = 5 end
    if piece == "king" then index = 1 end
    local model = "prop_chess_" .. (isWhite and "w" or "b") .. "_0" .. index
    -- return GetHashKey("prop_checkers_" .. (isWhite and "w" or "b") .. "_01"), model
    return GetHashKey(model), model
end

function CreateTableEntity()
    local coords = vector3(-76.3546, -817.9402, 326.1745)
    local heading = 132.6008
    tableEntity.root = CreateProp(`prop_chess_table_01`, coords.x, coords.y, coords.z - 1.035, false, false, false)
    FreezeEntityPosition(tableEntity.root, true)
    SetEntityHeading(tableEntity.root, heading)
    local forwardVector, rightVector, upVector, position = GetEntityMatrix(tableEntity.root)
    tableEntity.rootMatrix = {
        forward = forwardVector,
        right = rightVector,
        up = upVector,
        position = position,
    }
    tableEntity.chairs = {}
    for i=1, 2 do
        local offCoords = tableEntity.rootMatrix.position + (tableEntity.rootMatrix.forward * (i == 1 and 1.0 or -1.0)) - vector3(0.0, 0.0, 0.75)
        tableEntity.chairs[i] = CreateProp(`prop_chess_chair`, offCoords.x, offCoords.y, offCoords.z, false, false, false)
        FreezeEntityPosition(tableEntity.chairs[i], true)
        SetEntityHeading(tableEntity.chairs[i], heading + (i==1 and 0.0 or 180.0), 2, true)
    end
    tableEntity.board = CreateProp(`prop_chess_m_01`, tableEntity.rootMatrix.position.x, tableEntity.rootMatrix.position.y, tableEntity.rootMatrix.position.z + 0.024, false, false, false)
    FreezeEntityPosition(tableEntity.board, true)
    SetEntityHeading(tableEntity.board, heading)
    tableEntity.boardMatrix = {
        forward = forwardVector,
        right = rightVector,
        up = upVector,
        position = position,
    }
    local order = {
        "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn",
        "rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook",
    }
    tableEntity.whitePieces = {}
    tableEntity.blackPieces = {}
    -- Black: rows 1 (pawns), 0 (back); facing toward white (heading)
    for i = 1, 16 do
        local hash, model = GetChessPieceModel(order[i], false)
        local row = (i <= 8) and 1 or 0
        local col = (i - 1) % 8
        local offCoords = GetBoardSquareCoords(row, col)
        tableEntity.blackPieces[i] = CreateProp(hash, offCoords.x, offCoords.y, offCoords.z, false, false, false)
        FreezeEntityPosition(tableEntity.blackPieces[i], true)
        SetEntityRotation(tableEntity.blackPieces[i], 0.0, 0.0, heading, 2, true)
    end
    -- White: rows 6 (pawns), 7 (back); facing toward black (heading + 180)
    for i = 1, 16 do
        local hash, model = GetChessPieceModel(order[i], true)
        local row = (i <= 8) and 6 or 7
        local col = (i - 1) % 8
        local offCoords = GetBoardSquareCoords(row, col)
        tableEntity.whitePieces[i] = CreateProp(hash, offCoords.x, offCoords.y, offCoords.z, false, false, false)
        FreezeEntityPosition(tableEntity.whitePieces[i], true)
        SetEntityRotation(tableEntity.whitePieces[i], 0.0, 0.0, heading, 2, true)
    end
    -- Single test piece that cycles through all 64 squares
    local hash = GetChessPieceModel("king", false)
    local firstSquare = GetBoardSquareCoords(0, 0)
    tableEntity.testPiece = CreateProp(hash, firstSquare.x, firstSquare.y, firstSquare.z, false, false, false)
    FreezeEntityPosition(tableEntity.testPiece, true)
    SetEntityHeading(tableEntity.testPiece, heading)
    tableEntity.testPieceLoop = true
end

function DeleteTableEntity()
    if not tableEntity then return end
    tableEntity.testPieceLoop = false
    if tableEntity.testPiece then
        DeleteScriptObject(tableEntity.testPiece)
        tableEntity.testPiece = nil
    end
    for i=1, #tableEntity.chairs do
        DeleteScriptObject(tableEntity.chairs[i])
    end
    for i=1, #tableEntity.whitePieces do
        DeleteScriptObject(tableEntity.whitePieces[i])
    end
    for i=1, #tableEntity.blackPieces do
        DeleteScriptObject(tableEntity.blackPieces[i])
    end
    DeleteScriptObject(tableEntity.board)
    DeleteScriptObject(tableEntity.root)
end

CreateThread(function()
    local currentRow = 0
    local currentCol = 0
    Wait(1000)
    CreateTableEntity()
    -- Move test piece through all 64 squares in a loop
    -- CreateThread(function()
    --     local delayMs = 100
    --     while tableEntity.testPieceLoop and tableEntity.testPiece do
    --         for row = 0, 7 do
    --             for col = 0, 7 do
    --                 currentRow = row
    --                 currentCol = col
    --                 -- local row = 7
    --                 -- local col = 7
    --                 if not tableEntity.testPieceLoop or not tableEntity.testPiece then return end
    --                 local coords = GetBoardSquareCoords(row, col)
    --                 if coords then
    --                     local zCoords = coords.z + 0.09
    --                     SetEntityCoords(tableEntity.testPiece, coords.x, coords.y, zCoords, false, false, false, false)
    --                 end
    --                 Wait(delayMs)
    --             end
    --         end
    --     end
    -- end)
    CreateThread(function()
        while true do
            local coords = GetBoardSquareCoords(currentRow, currentCol)
            if coords then
                local square = 0.064
                local half = square * 0.5
                local zOffset = 0.042
                local f, r = tableEntity.boardMatrix.forward, tableEntity.boardMatrix.right
                -- coords is cell center; root quad at bottom-right corner of the cell
                local bottomRight = coords + f * half + r * half + vector3(0.0, 0.0, zOffset)
                local c1 = bottomRight
                local c2 = bottomRight - f * square
                local c3 = bottomRight - f * square - r * square
                local c4 = bottomRight - r * square
                -- DrawPoly draws a triangle (3 vertices). Winding reversed so front face is on top (visible from above).
                DrawPoly(c1.x, c1.y, c1.z, c3.x, c3.y, c3.z, c2.x, c2.y, c2.z, 255, 0, 0, 200)
                DrawPoly(c1.x, c1.y, c1.z, c4.x, c4.y, c4.z, c3.x, c3.y, c3.z, 255, 0, 0, 200)
            end
            Wait(0)
        end
    end)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    DeleteTableEntity()
end)