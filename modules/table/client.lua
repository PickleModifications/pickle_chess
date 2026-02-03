tableEntity = {} -- Global so chess module can access it
local pieceOriginalPositions = {} -- Store original positions for move validation
local validMovesDisplay = {} -- Store valid moves to display
local isAnimating = false

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

function GetBoardRowColFromCoords(coords)
    local closest = nil
    local closestDistance = 1000.0
    for row = 0, 7 do
        for col = 0, 7 do
            local squareCoords = GetBoardSquareCoords(row, col)
            local distance = #(coords - squareCoords)
            if distance < closestDistance then
                closestDistance = distance
                closest = {row, col}
            end
        end
    end
    if not closest then return end
    return closest[1], closest[2]
end

function GetChessPieceModel(piece, isWhite)
    local index = 1
    local offset = {
        coords = vector3(0.0, 0.0, 0.09),
        rotation = vector3(0.0, 0.0, 0.0),
    }
    if piece == "pawn" then 
        index = 6 
        offset.coords = vector3(0.0, 0.0, 0.0875)
        offset.rotation = vector3(0.0, 0.0, 0.0)
    end
    if piece == "rook" then 
        index = 1 
        offset.coords = vector3(0.0, 0.0, 0.09)
        offset.rotation = vector3(0.0, 0.0, 0.0)
    end
    if piece == "knight" then 
        index = 2 
        offset.coords = vector3(0.0, 0.0, 0.11)
        offset.rotation = vector3(0.0, 0.0, 0.0)
    end
    if piece == "bishop" then 
        index = 3
        offset.coords = vector3(0.0, 0.0, 0.11)
        offset.rotation = vector3(0.0, 0.0, 0.0)
    end
    if piece == "queen" then 
        index = 5 
        offset.coords = vector3(0.0, 0.0, 0.11)
        offset.rotation = vector3(0.0, 0.0, 0.0)
    end
    if piece == "king" then 
        index = 4 
        offset.coords = vector3(0.0, 0.0, 0.11)
        offset.rotation = vector3(0.0, 0.0, 0.0)
    end
    local model = "prop_chess_" .. (isWhite and "w" or "b") .. "_0" .. index
    -- return GetHashKey("prop_checkers_" .. (isWhite and "w" or "b") .. "_01"), model
    return GetHashKey(model), model, offset
end

function GetChessPieceFromHash(hash)
    local tbl = {"pawn", "rook", "knight", "bishop", "queen", "king"}
    for i=1, #tbl do
        for j=1, 2 do
            local modelHash, model, offset = GetChessPieceModel(tbl[i], j == 1)
            if modelHash == hash then
                return model, tbl[i], offset
            end
        end
    end
end

function GetChessPieceFromEntity(entity)
    if not tableEntity then return end
    local modelHash = GetEntityModel(entity)
    local model, piece, offset = GetChessPieceFromHash(modelHash)
    for i=1, #tableEntity.whitePieces do
        if tableEntity.whitePieces[i] == entity then
            return true, i, model, piece, offset
        end
    end
    for i=1, #tableEntity.blackPieces do
        if tableEntity.blackPieces[i] == entity then
            return false, i, model, piece, offset
        end
    end
end

function CreateScriptedCamera()
    if CurrentCamera then ExitScriptedCamera() end
    local initialCamSettings = {
        coords = GetGameplayCamCoord(),
        rotation = GetGameplayCamRot(),
        fov = GetGameplayCamFov(),
    }
    CurrentCamera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", 
        initialCamSettings.coords.x, initialCamSettings.coords.y, initialCamSettings.coords.z, 
        initialCamSettings.rotation.x, initialCamSettings.rotation.y, initialCamSettings.rotation.z, initialCamSettings.fov
    )
    SetCamActive(CurrentCamera, true)
    RenderScriptCams(true, false, 0, true, true)
end

function ExitScriptedCamera(durationValue)
    local duration = durationValue
    if duration == nil then duration = 2000 end
    ClearFocus()
	DestroyAllCams()
    RenderScriptCams(false, true, duration, true, false) 
end

function CreateTableEntity()
    local coords = vector3(-76.3546, -817.9402, 326.1745)
    local heading = 132.6008
    tableEntity.coords = coords
    tableEntity.heading = heading
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
    local camCoords = coords + (tableEntity.boardMatrix.forward * -0.35) + vector3(0.0, 0.0, 0.25)
    StartInteraction(camCoords, heading)
    
    -- Initialize chess game
    InitializeChessBoard()
    
    local order = {
        "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn",
        "rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook",
    }
    tableEntity.whitePieces = {}
    tableEntity.blackPieces = {}
    -- Black: rows 1 (pawns), 0 (back); facing toward white (heading)
    for i = 1, 16 do
        local hash, model, offset = GetChessPieceModel(order[i], false)
        local row = (i <= 8) and 1 or 0
        local col = (i - 1) % 8
        local offCoords = GetBoardSquareCoords(row, col)
        tableEntity.blackPieces[i] = CreateInteractiveEntity("chess_piece", offCoords + offset.coords, heading + offset.rotation.z, {
            model = model,
        })
        FreezeEntityPosition(tableEntity.blackPieces[i], true)
        SetEntityRotation(tableEntity.blackPieces[i], 0.0, 0.0, heading, 2, true)
    end
    -- White: rows 6 (pawns), 7 (back); facing toward black (heading + 180)
    for i = 1, 16 do
        local hash, model, offset = GetChessPieceModel(order[i], true)
        local row = (i <= 8) and 6 or 7
        local col = (i - 1) % 8
        local offCoords = GetBoardSquareCoords(row, col)
        tableEntity.whitePieces[i] = CreateInteractiveEntity("chess_piece", offCoords + offset.coords, heading + offset.rotation.z, {
            model = model,
        })
        FreezeEntityPosition(tableEntity.whitePieces[i], true)
        SetEntityRotation(tableEntity.whitePieces[i], 0.0, 0.0, heading, 2, true)
    end
    
    -- Sync board state after pieces are created
    Wait(100)
    SyncBoardWithPieces()
end

function DeleteTableEntity()
    if not tableEntity then return end
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
    pieceOriginalPositions = {}
    validMovesDisplay = {}
end

-- Animate piece movement smoothly
function AnimatePieceMove(entity, fromCoords, toCoords, offset, duration, callback)
    duration = duration or Config.Chess.MoveAnimationDuration
    local startTime = GetGameTimer()
    local startCoords = vector3(fromCoords.x, fromCoords.y, fromCoords.z)
    local endCoords = vector3(toCoords.x + offset.coords.x, toCoords.y + offset.coords.y, toCoords.z + offset.coords.z)
    
    CreateThread(function()
        while GetGameTimer() - startTime < duration do
            local progress = (GetGameTimer() - startTime) / duration
            progress = math.min(1.0, progress)
            -- Ease in-out
            local eased = progress < 0.5 and 2 * progress * progress or 1 - math.pow(-2 * progress + 2, 2) / 2
            
            local currentCoords = vector3(
                startCoords.x + (endCoords.x - startCoords.x) * eased,
                startCoords.y + (endCoords.y - startCoords.y) * eased,
                startCoords.z + (endCoords.z - startCoords.z) * eased
            )
            
            SetEntityCoords(entity, currentCoords.x, currentCoords.y, currentCoords.z, false, false, false, false)
            Wait(0)
        end
        -- Ensure final position
        SetEntityCoords(entity, endCoords.x, endCoords.y, endCoords.z, false, false, false, false)
        if callback then callback() end
    end)
end

-- Execute CPU move
function ExecuteCPUMove()
    if Config.Debug then
        print(string.format("[Chess] ExecuteCPUMove called - isCPUTurn=%s, currentTurn=%s, gameState=%s", 
            tostring(chessGame.isCPUTurn), chessGame.currentTurn or "nil", chessGame.gameState or "nil"))
    end
    
    if chessGame.isCPUTurn then 
        if Config.Debug then print("[Chess] ExecuteCPUMove: Already CPU turn, returning") end
        return 
    end
    if chessGame.currentTurn ~= "black" then 
        if Config.Debug then print(string.format("[Chess] ExecuteCPUMove: Not black's turn (currentTurn=%s), returning", chessGame.currentTurn or "nil")) end
        return 
    end
    if chessGame.gameState ~= "playing" then 
        if Config.Debug then print(string.format("[Chess] ExecuteCPUMove: Game not playing (gameState=%s), returning", chessGame.gameState or "nil")) end
        return 
    end
    
    chessGame.isCPUTurn = true
    
    CreateThread(function()
        Wait(Config.Chess.CPU_ThinkDelay or 1000)
        
        -- Sync board before getting CPU move (only if tableEntity exists)
        if tableEntity and tableEntity.whitePieces and tableEntity.blackPieces then
            SyncBoardWithPieces()
        else
            if Config.Debug then print("[Chess] ExecuteCPUMove: tableEntity not ready, cannot sync board") end
        end
        
        local cpuMove = GetCPUMove()
        
        if not cpuMove then
            if Config.Debug then print("[Chess] ExecuteCPUMove: No valid CPU move found") end
            chessGame.isCPUTurn = false
            return
        end
        
        if Config.Debug then
            print(string.format("[Chess] ExecuteCPUMove: CPU moving from (%d,%d) to (%d,%d)", 
                cpuMove.fromRow, cpuMove.fromCol, cpuMove.toRow, cpuMove.toCol))
        end
        
        local fromCoords = GetBoardSquareCoords(cpuMove.fromRow, cpuMove.fromCol)
        local toCoords = GetBoardSquareCoords(cpuMove.toRow, cpuMove.toCol)
        local piece = GetPieceAt(cpuMove.fromRow, cpuMove.fromCol)
        
        if piece and piece.entity and DoesEntityExist(piece.entity) then
            local _, _, _, _, offset = GetChessPieceFromEntity(piece.entity)
            
            -- Handle castling
            if cpuMove.moveData and cpuMove.moveData.castling then
                local rookRow = cpuMove.fromRow
                local rookFromCol = cpuMove.moveData.castling == "kingSide" and 7 or 0
                local rookToCol = cpuMove.moveData.castling == "kingSide" and 5 or 3
                local rook = GetPieceAt(rookRow, rookFromCol)
                
                if rook and rook.entity then
                    local rookFromCoords = GetBoardSquareCoords(rookRow, rookFromCol)
                    local rookToCoords = GetBoardSquareCoords(rookRow, rookToCol)
                    local _, _, _, _, rookOffset = GetChessPieceFromEntity(rook.entity)
                    AnimatePieceMove(rook.entity, rookFromCoords, rookToCoords, rookOffset, Config.Chess.MoveAnimationDuration)
                end
            end
            
            -- Handle captured piece
            local capturedPiece = GetPieceAt(cpuMove.toRow, cpuMove.toCol)
            if capturedPiece and capturedPiece.entity then
                CreateThread(function()
                    Wait(Config.Chess.MoveAnimationDuration / 2)
                    -- Fade out captured piece
                    for i = 255, 0, -10 do
                        SetEntityAlpha(capturedPiece.entity, i, false)
                        Wait(10)
                    end
                    SetEntityAlpha(capturedPiece.entity, 0, false)
                end)
            end
            
            -- Execute move in game state
            ExecuteMove(cpuMove.fromRow, cpuMove.fromCol, cpuMove.toRow, cpuMove.toCol, cpuMove.moveData)
            
            -- Check for pawn promotion after move
            local promotedPiece = GetPieceAt(cpuMove.toRow, cpuMove.toCol)
            local entityToAnimate = piece.entity
            
            if promotedPiece and promotedPiece.needsPromotion then
                local isWhite = promotedPiece.isWhite
                local hash, model, newOffset = GetChessPieceModel("queen", isWhite)
                local oldEntity = piece.entity
                DeleteEntity(oldEntity)
                local newCoords = GetBoardSquareCoords(cpuMove.toRow, cpuMove.toCol)
                local newEntity = CreateProp(hash, newCoords.x + newOffset.coords.x, newCoords.y + newOffset.coords.y, newCoords.z + newOffset.coords.z, false, false, false)
                FreezeEntityPosition(newEntity, true)
                SetEntityRotation(newEntity, 0.0, 0.0, tableEntity.heading + newOffset.rotation.z, 2, true)
                promotedPiece.entity = newEntity
                promotedPiece.needsPromotion = nil
                entityToAnimate = newEntity
                
                -- Update piece arrays
                if not isWhite then
                    for i = 1, #tableEntity.blackPieces do
                        if tableEntity.blackPieces[i] == oldEntity then
                            tableEntity.blackPieces[i] = newEntity
                            break
                        end
                    end
                end
            end
            
            -- Animate piece move
            AnimatePieceMove(entityToAnimate, fromCoords, toCoords, offset, Config.Chess.MoveAnimationDuration, function()
                SetEntityRotation(entityToAnimate, 0.0, 0.0, tableEntity.heading + offset.rotation.z, 2, true)
                
                -- ExecuteMove already updated board state correctly
                -- Just ensure entity reference is correct
                local movedPiece = GetPieceAt(cpuMove.toRow, cpuMove.toCol)
                if movedPiece then
                    movedPiece.entity = entityToAnimate
                end
                
                -- Sync board after CPU move to ensure all pieces are correctly placed
                if tableEntity and tableEntity.whitePieces and tableEntity.blackPieces then
                    local pieceAtDest = GetPieceAt(cpuMove.toRow, cpuMove.toCol)
                    SyncBoardWithPieces()
                    -- Ensure CPU piece is at correct destination
                    if pieceAtDest then
                        local syncedPiece = nil
                        for r = 0, 7 do
                            for c = 0, 7 do
                                if chessGame.board[r] and chessGame.board[r][c] and chessGame.board[r][c].entity == entityToAnimate then
                                    syncedPiece = chessGame.board[r][c]
                                    chessGame.board[r][c] = nil
                                    break
                                end
                            end
                            if syncedPiece then break end
                        end
                        if syncedPiece then
                            chessGame.board[cpuMove.toRow][cpuMove.toCol] = syncedPiece
                            if syncedPiece.piece == "king" then
                                if syncedPiece.isWhite then chessGame.whiteKingPos = {row = cpuMove.toRow, col = cpuMove.toCol}
                                else chessGame.blackKingPos = {row = cpuMove.toRow, col = cpuMove.toCol} end
                            end
                        end
                    end
                end
                
                -- Update game state (board should now have all pieces correctly placed)
                UpdateGameState()
                
                chessGame.isCPUTurn = false
                
                -- Check game state
                if chessGame.gameState == "checkmate" then
                    ShowNotification("Checkmate! You lost!")
                elseif chessGame.gameState == "stalemate" then
                    ShowNotification("Stalemate! Game is a draw.")
                elseif chessGame.gameState == "check" then
                    ShowNotification("Check!")
                end
            end)
        else
            chessGame.isCPUTurn = false
        end
    end)
end

-- Display game state information
CreateThread(function()
    while true do
        Wait(0)
        if CURRENT_INTERACTION and chessGame then
            local gameStateText = ""
            local turnText = ""
            
            if chessGame.isCPUTurn then
                turnText = "CPU is thinking..."
            elseif chessGame.currentTurn == "white" then
                turnText = "Your turn (White)"
            else
                turnText = "CPU's turn (Black)"
            end
            
            if chessGame.gameState == "checkmate" then
                gameStateText = chessGame.currentTurn == "white" and "Checkmate! You lost!" or "Checkmate! You won!"
            elseif chessGame.gameState == "stalemate" then
                gameStateText = "Stalemate! Game is a draw."
            elseif chessGame.gameState == "check" then
                gameStateText = "Check!"
            end
            
            -- Display turn and game state
            if turnText ~= "" then
                local camCoords = CURRENT_INTERACTION.coords
                DrawText3D(camCoords.x, camCoords.y, camCoords.z + 0.3, turnText)
            end
            
            if gameStateText ~= "" then
                local camCoords = CURRENT_INTERACTION.coords
                DrawText3D(camCoords.x, camCoords.y, camCoords.z + 0.35, gameStateText)
            end
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    RegisterInteractiveEntity("chess_piece", {
        init = function(coords, heading, data, params)
            local chessPiece = CreateProp(params.model, coords.x, coords.y, coords.z, false, false, false)
            SetEntityCoordsNoOffset(chessPiece, coords.x, coords.y, coords.z, false, false, false, false)
            SetEntityCollision(chessPiece, true, true)
            SetEntityHeading(chessPiece, heading)
            return chessPiece, {
                disableGravity = true,
            }
        end,
        entityThread = function(entity, data)
        end,
        selectedThread = function(entity, data)
            -- Check if it's player's turn and piece belongs to player
            if chessGame.isCPUTurn or chessGame.currentTurn ~= "white" then return end
            
            local isWhite, index, model, piece, offset = GetChessPieceFromEntity(entity)
            if not isWhite then return end -- Can't select black pieces
            
            local entityCoords = GetEntityCoords(entity)
            local row, col = GetBoardRowColFromCoords(entityCoords - vector3(0.0, 0.0, 0.075))
            if not row or not col then return end
            
            -- Store original position ONLY on first frame (don't overwrite every frame while dragging)
            if not pieceOriginalPositions[entity] then
                pieceOriginalPositions[entity] = {row = row, col = col, coords = GetBoardSquareCoords(row, col)}
                
                -- Ensure board is initialized and synced
                if not chessGame.board or not chessGame.board[0] then
                    InitializeChessBoard()
                end
                -- Always sync before getting valid moves to ensure board is up to date
                if tableEntity and tableEntity.whitePieces and tableEntity.blackPieces then
                    SyncBoardWithPieces()
                end
                
                -- Find and move this piece to (row,col) without full sync (preserve other pieces' positions)
                local found = false
                local pieceData = nil
                -- Find the piece on the board
                for r = 0, 7 do
                    if found then break end
                    for c = 0, 7 do
                        if chessGame.board[r] and chessGame.board[r][c] and chessGame.board[r][c].entity == entity then
                            pieceData = chessGame.board[r][c]
                            chessGame.board[r][c] = nil
                            found = true
                            break
                        end
                    end
                end
                -- If piece not found on board, create entry from entity info
                if not pieceData then
                    pieceData = {
                        piece = piece,  -- piece type from GetChessPieceFromEntity
                        isWhite = isWhite,
                        entity = entity,
                        hasMoved = false
                    }
                end
                -- Sync board first to ensure all pieces are in correct positions for capture detection
                SyncBoardWithPieces()
                
                -- Debug: Check board state after sync, before placing our piece
                if Config.Debug then
                    local opponentCount = 0
                    local friendlyCount = 0
                    for r = 0, 7 do
                        for c = 0, 7 do
                            if chessGame.board[r] and chessGame.board[r][c] then
                                if chessGame.board[r][c].isWhite ~= isWhite then
                                    opponentCount = opponentCount + 1
                                else
                                    friendlyCount = friendlyCount + 1
                                end
                            end
                        end
                    end
                    print(string.format("[Chess] After SyncBoardWithPieces: %d opponent pieces, %d friendly pieces on board", opponentCount, friendlyCount))
                    
                    -- Check diagonal squares specifically for pawns
                    if piece == "pawn" then
                        local direction = isWhite and -1 or 1
                        for dc = -1, 1, 2 do
                            local checkRow = row + direction
                            local checkCol = col + dc
                            if IsValidSquare(checkRow, checkCol) then
                                local diagonalPiece = chessGame.board[checkRow] and chessGame.board[checkRow][checkCol]
                                if diagonalPiece then
                                    -- Verify which array this entity belongs to
                                    local isWhiteEntity = false
                                    local foundInArray = "none"
                                    if tableEntity.whitePieces then
                                        for i = 1, #tableEntity.whitePieces do
                                            if tableEntity.whitePieces[i] == diagonalPiece.entity then
                                                isWhiteEntity = true
                                                foundInArray = "whitePieces[" .. i .. "]"
                                                break
                                            end
                                        end
                                    end
                                    if not isWhiteEntity and tableEntity.blackPieces then
                                        for i = 1, #tableEntity.blackPieces do
                                            if tableEntity.blackPieces[i] == diagonalPiece.entity then
                                                foundInArray = "blackPieces[" .. i .. "]"
                                                break
                                            end
                                        end
                                    end
                                    print(string.format("[Chess] Diagonal (%d,%d) after sync: %s (entity in %s, board says isWhite=%s)", 
                                        checkRow, checkCol, 
                                        diagonalPiece.isWhite and "white " .. diagonalPiece.piece or "black " .. diagonalPiece.piece,
                                        foundInArray,
                                        tostring(diagonalPiece.isWhite)))
                                else
                                    print(string.format("[Chess] Diagonal (%d,%d) after sync: empty", checkRow, checkCol))
                                end
                            end
                        end
                    end
                end
                
                -- Place piece at (row, col) for validation (in case sync didn't place it correctly)
                -- This ensures our piece is at the clicked square for move validation
                chessGame.board[row][col] = pieceData
                if pieceData.piece == "king" then
                    if pieceData.isWhite then chessGame.whiteKingPos = {row = row, col = col}
                    else chessGame.blackKingPos = {row = row, col = col} end
                end
                
                -- Get valid moves - piece is now guaranteed to be at (row, col) and board is synced
                validMovesDisplay[entity] = GetValidMoves(row, col)
                
                -- Debug output
                if Config.Debug then
                    local verifyPiece = GetPieceAt(row, col)
                    if verifyPiece then
                        print(string.format("[Chess] Piece %s at (%d,%d) - Found %d valid moves", pieceData.piece, row, col, #validMovesDisplay[entity]))
                    else
                        print(string.format("[Chess] ERROR: Piece %s not found at (%d,%d) after placement!", pieceData.piece, row, col))
                    end
                end
            end
            
            local orig = pieceOriginalPositions[entity]
            if not orig then return end
            row, col = orig.row, orig.col
            
            local square = 0.062  -- Match GetBoardSquareCoords so quads align with board
            local half = square * 0.5
            local zOffset = 0.042
            local f, r = tableEntity.boardMatrix.forward, tableEntity.boardMatrix.right
            
            -- Draw selected square (origin) in red while dragging
            local coords = GetBoardSquareCoords(row, col)
            if coords then
                local bottomRight = coords + f * half + r * half + vector3(0.0, 0.0, zOffset)
                local c1 = bottomRight
                local c2 = bottomRight - f * square
                local c3 = bottomRight - f * square - r * square
                local c4 = bottomRight - r * square
                DrawPoly(c1.x, c1.y, c1.z, c3.x, c3.y, c3.z, c2.x, c2.y, c2.z, 255, 0, 0, 200)
                DrawPoly(c1.x, c1.y, c1.z, c4.x, c4.y, c4.z, c3.x, c3.y, c3.z, 255, 0, 0, 200)
            end
            
            local currentCoords = GetEntityCoords(entity)
            local currentRow, currentCol = GetBoardRowColFromCoords(currentCoords - vector3(0.0, 0.0, 0.075))
            if currentRow and currentCol then
                local currentCoords = GetBoardSquareCoords(currentRow, currentCol)
                if currentCoords then
                    local currentBottomRight = currentCoords + f * half + r * half + vector3(0.0, 0.0, zOffset + 0.003)
                    local currentC1 = currentBottomRight
                    local currentC2 = currentBottomRight - f * square
                    local currentC3 = currentBottomRight - f * square - r * square
                    local currentC4 = currentBottomRight - r * square
                    DrawPoly(currentC1.x, currentC1.y, currentC1.z, currentC3.x, currentC3.y, currentC3.z, currentC2.x, currentC2.y, currentC2.z, 255, 255, 255, 200)
                    DrawPoly(currentC1.x, currentC1.y, currentC1.z, currentC4.x, currentC4.y, currentC4.z, currentC3.x, currentC3.y, currentC3.z, 255, 255, 255, 200)
                end
            end

            -- Draw valid move positions in green while dragging (each square as two triangles)
            if validMovesDisplay[entity] then
                local validZOffset = zOffset  -- Above board so quads are visible and don't z-fight
                for _, move in ipairs(validMovesDisplay[entity]) do
                    local moveCoords = GetBoardSquareCoords(move.toRow, move.toCol)
                    if moveCoords then
                        local moveBottomRight = moveCoords + f * half + r * half + vector3(0.0, 0.0, validZOffset)
                        local mc1 = moveBottomRight
                        local mc2 = moveBottomRight - f * square
                        local mc3 = moveBottomRight - f * square - r * square
                        local mc4 = moveBottomRight - r * square
                        -- Two triangles per square (front face up)
                        DrawPoly(mc1.x, mc1.y, mc1.z, mc3.x, mc3.y, mc3.z, mc2.x, mc2.y, mc2.z, 0, 255, 100, 180)
                        DrawPoly(mc1.x, mc1.y, mc1.z, mc4.x, mc4.y, mc4.z, mc3.x, mc3.y, mc3.z, 0, 255, 100, 180)
                    end
                end
            end
        end,
        unSelected = function(entity, data)
            -- Clear valid moves display
            validMovesDisplay[entity] = nil
            
            -- Check if it's player's turn
            if chessGame.isCPUTurn or chessGame.currentTurn ~= "white" then
                -- Restore to original position
                if pieceOriginalPositions[entity] then
                    local orig = pieceOriginalPositions[entity]
                    local origCoords = GetBoardSquareCoords(orig.row, orig.col)
                    if origCoords then
                        local _, _, _, _, offset = GetChessPieceFromEntity(entity)
                        SetEntityCoords(entity, origCoords.x + offset.coords.x, origCoords.y + offset.coords.y, origCoords.z + offset.coords.z, false, false, false, false)
                    end
                end
                pieceOriginalPositions[entity] = nil
                return
            end
            
            local isWhite, index, model, piece, offset = GetChessPieceFromEntity(entity)
            if not isWhite then
                -- Restore black piece to original position
                if pieceOriginalPositions[entity] then
                    local orig = pieceOriginalPositions[entity]
                    local origCoords = GetBoardSquareCoords(orig.row, orig.col)
                    if origCoords then
                        SetEntityCoords(entity, origCoords.x + offset.coords.x, origCoords.y + offset.coords.y, origCoords.z + offset.coords.z, false, false, false, false)
                    end
                end
                pieceOriginalPositions[entity] = nil
                return
            end
            
            local entityCoords = GetEntityCoords(entity)
            local toRow, toCol = GetBoardRowColFromCoords(entityCoords - vector3(0.0, 0.0, 0.075))
            if not toRow or not toCol then
                -- Restore to original position
                if pieceOriginalPositions[entity] then
                    local orig = pieceOriginalPositions[entity]
                    local origCoords = GetBoardSquareCoords(orig.row, orig.col)
                    if origCoords then
                        SetEntityCoords(entity, origCoords.x + offset.coords.x, origCoords.y + offset.coords.y, origCoords.z + offset.coords.z, false, false, false, false)
                    end
                end
                pieceOriginalPositions[entity] = nil
                return
            end
            
            -- Get original position
            local origPos = pieceOriginalPositions[entity]
            if not origPos then
                pieceOriginalPositions[entity] = nil
                return
            end
            
            local fromRow, fromCol = origPos.row, origPos.col
            
            -- CRITICAL: Temporarily move the dragged piece entity back to its original position
            -- before syncing, so sync doesn't place it at the drop position
            local origCoords = GetBoardSquareCoords(fromRow, fromCol)
            local tempEntityPos = nil
            if origCoords then
                tempEntityPos = GetEntityCoords(entity)
                -- Temporarily move entity back to original position for sync
                SetEntityCoords(entity, origCoords.x + offset.coords.x, origCoords.y + offset.coords.y, origCoords.z + offset.coords.z, false, false, false, false)
            end
            
            -- Sync board to ensure all pieces (including opponent pieces) are correctly placed
            -- This is critical for capture detection
            if tableEntity and tableEntity.whitePieces and tableEntity.blackPieces then
                SyncBoardWithPieces()
            end
            
            -- Restore entity to drop position (we'll validate based on board state)
            if tempEntityPos then
                SetEntityCoords(entity, tempEntityPos.x, tempEntityPos.y, tempEntityPos.z, false, false, false, false)
            end
            
            -- Ensure our piece is at fromRow/fromCol on the board (sync should have placed it there)
            local pieceOnBoard = GetPieceAt(fromRow, fromCol)
            if not pieceOnBoard or pieceOnBoard.entity ~= entity then
                -- Find piece anywhere on board and move it to fromRow/fromCol
                local pieceData = nil
                for r = 0, 7 do
                    for c = 0, 7 do
                        if chessGame.board[r] and chessGame.board[r][c] and chessGame.board[r][c].entity == entity then
                            pieceData = chessGame.board[r][c]
                            chessGame.board[r][c] = nil
                            break
                        end
                    end
                    if pieceData then break end
                end
                
                -- If piece not found, create from entity info
                if not pieceData then
                    pieceData = {
                        piece = piece,
                        isWhite = isWhite,
                        entity = entity,
                        hasMoved = false
                    }
                end
                
                -- Place at fromRow/fromCol for validation
                chessGame.board[fromRow][fromCol] = pieceData
                if pieceData.piece == "king" then
                    if pieceData.isWhite then chessGame.whiteKingPos = {row = fromRow, col = fromCol}
                    else chessGame.blackKingPos = {row = fromRow, col = fromCol} end
                end
            end
            
            -- Now validate move with synced board state (opponent pieces should be correctly placed)
            local isValid, moveData = IsValidMove(fromRow, fromCol, toRow, toCol)
            
            if not isValid then
                -- Invalid move - restore to original position
                local origCoords = GetBoardSquareCoords(fromRow, fromCol)
                if origCoords then
                    SetEntityCoords(entity, origCoords.x + offset.coords.x, origCoords.y + offset.coords.y, origCoords.z + offset.coords.z, false, false, false, false)
                    ShowNotification("Invalid move!")
                end
                pieceOriginalPositions[entity] = nil
                return
            end
            
            -- Valid move - execute it
            local fromCoords = GetBoardSquareCoords(fromRow, fromCol)
            local toCoords = GetBoardSquareCoords(toRow, toCol)
            
            -- Handle captured piece
            local capturedPiece = GetPieceAt(toRow, toCol)
            if capturedPiece and capturedPiece.entity then
                CreateThread(function()
                    Wait(Config.Chess.MoveAnimationDuration / 2)
                    -- Fade out captured piece
                    for i = 255, 0, -10 do
                        SetEntityAlpha(capturedPiece.entity, i, false)
                        Wait(10)
                    end
                    SetEntityAlpha(capturedPiece.entity, 0, false)
                end)
            end
            
            -- Handle castling
            if moveData and moveData.castling then
                local rookRow = fromRow
                local rookFromCol = moveData.castling == "kingSide" and 7 or 0
                local rookToCol = moveData.castling == "kingSide" and 5 or 3
                local rook = GetPieceAt(rookRow, rookFromCol)
                
                if rook and rook.entity then
                    local rookFromCoords = GetBoardSquareCoords(rookRow, rookFromCol)
                    local rookToCoords = GetBoardSquareCoords(rookRow, rookToCol)
                    local _, _, _, _, rookOffset = GetChessPieceFromEntity(rook.entity)
                    AnimatePieceMove(rook.entity, rookFromCoords, rookToCoords, rookOffset, Config.Chess.MoveAnimationDuration)
                end
            end
            
            -- Animate piece movement
            isAnimating = true
            AnimatePieceMove(entity, fromCoords, toCoords, offset, Config.Chess.MoveAnimationDuration, function()
                SetEntityRotation(entity, 0.0, 0.0, tableEntity.heading + offset.rotation.z, 2, true)
                
                -- Don't sync here - board should already be correct from last sync
                -- Just ensure the piece we're moving is at (fromRow, fromCol) for ExecuteMove
                -- (we may have moved it during piece selection for validation)
                local pieceOnBoard = GetPieceAt(fromRow, fromCol)
                if not pieceOnBoard or pieceOnBoard.entity ~= entity then
                    -- Find piece anywhere on board and move it to fromRow, fromCol
                    local pieceData = nil
                    for r = 0, 7 do
                        for c = 0, 7 do
                            if chessGame.board[r] and chessGame.board[r][c] and chessGame.board[r][c].entity == entity then
                                pieceData = chessGame.board[r][c]
                                chessGame.board[r][c] = nil
                                break
                            end
                        end
                        if pieceData then break end
                    end
                    
                    -- If piece not found on board, create from entity info
                    if not pieceData then
                        pieceData = {
                            piece = piece,
                            isWhite = isWhite,
                            entity = entity,
                            hasMoved = false
                        }
                    end
                    
                    -- Place at fromRow, fromCol
                    chessGame.board[fromRow][fromCol] = pieceData
                    if pieceData.piece == "king" then
                        if pieceData.isWhite then chessGame.whiteKingPos = {row = fromRow, col = fromCol}
                        else chessGame.blackKingPos = {row = fromRow, col = fromCol} end
                    end
                end
                
                -- Execute move in game state (piece is now at fromRow, fromCol on board)
                ExecuteMove(fromRow, fromCol, toRow, toCol, moveData)
                
                -- Handle pawn promotion
                local piece = GetPieceAt(toRow, toCol)
                if piece and piece.needsPromotion and piece.entity == entity then
                    local isWhite = piece.isWhite
                    local hash, model, newOffset = GetChessPieceModel("queen", isWhite)
                    local coords = GetEntityCoords(entity)
                    DeleteEntity(entity)
                    local newCoords = GetBoardSquareCoords(toRow, toCol)
                    local newEntity = CreateProp(hash, newCoords.x + newOffset.coords.x, newCoords.y + newOffset.coords.y, newCoords.z + newOffset.coords.z, false, false, false)
                    FreezeEntityPosition(newEntity, true)
                    SetEntityRotation(newEntity, 0.0, 0.0, tableEntity.heading + newOffset.rotation.z, 2, true)
                    piece.entity = newEntity
                    piece.needsPromotion = nil
                    
                    -- Update piece arrays
                    if isWhite then
                        for i = 1, #tableEntity.whitePieces do
                            if tableEntity.whitePieces[i] == entity then
                                tableEntity.whitePieces[i] = newEntity
                                break
                            end
                        end
                    else
                        for i = 1, #tableEntity.blackPieces do
                            if tableEntity.blackPieces[i] == entity then
                                tableEntity.blackPieces[i] = newEntity
                                break
                            end
                        end
                    end
                end
                
                -- ExecuteMove already updated board state correctly
                -- Just ensure entity reference is correct
                local movedPiece = GetPieceAt(toRow, toCol)
                if movedPiece then
                    movedPiece.entity = entity
                end
                
                -- Sync board after move to ensure all pieces are correctly placed
                -- This is especially important after the first move when board might not be fully synced
                if tableEntity and tableEntity.whitePieces and tableEntity.blackPieces then
                    -- Save where our piece should be
                    local pieceAtDest = GetPieceAt(toRow, toCol)
                    
                    -- Sync board (repopulates from entity positions)
                    SyncBoardWithPieces()
                    
                    -- Ensure our moved piece is at the correct destination
                    if pieceAtDest then
                        -- Find where sync placed our piece
                        local syncedPiece = nil
                        for r = 0, 7 do
                            for c = 0, 7 do
                                if chessGame.board[r] and chessGame.board[r][c] and chessGame.board[r][c].entity == entity then
                                    syncedPiece = chessGame.board[r][c]
                                    chessGame.board[r][c] = nil
                                    break
                                end
                            end
                            if syncedPiece then break end
                        end
                        -- Place at correct destination
                        if syncedPiece then
                            chessGame.board[toRow][toCol] = syncedPiece
                            if syncedPiece.piece == "king" then
                                if syncedPiece.isWhite then chessGame.whiteKingPos = {row = toRow, col = toCol}
                                else chessGame.blackKingPos = {row = toRow, col = toCol} end
                            end
                        end
                    end
                end
                
                pieceOriginalPositions[entity] = nil
                isAnimating = false
                
                -- Update game state (board should now have all pieces correctly placed)
                -- Only update if tableEntity exists
                if tableEntity and tableEntity.whitePieces and tableEntity.blackPieces then
                    UpdateGameState()
                    
                    -- Check game state
                    if chessGame.gameState == "checkmate" then
                        ShowNotification("Checkmate! You won!")
                    elseif chessGame.gameState == "stalemate" then
                        ShowNotification("Stalemate! Game is a draw.")
                    elseif chessGame.gameState == "check" then
                        ShowNotification("Check!")
                    else
                        -- CPU's turn
                        ExecuteCPUMove()
                    end
                else
                    -- If tableEntity not ready, just trigger CPU move anyway
                    if Config.Debug then print("[Chess] tableEntity not ready after move, but triggering CPU move anyway") end
                    ExecuteCPUMove()
                end
            end)
        end,
    })
    Wait(1000)
    CreateTableEntity()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    DeleteTableEntity()
end)