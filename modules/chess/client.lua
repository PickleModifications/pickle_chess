-- Chess game logic module (global so table/interaction modules can access)
chessGame = {
    board = {}, -- 8x8 array: board[row][col] = {piece, isWhite, entity, hasMoved}
    currentTurn = "white",
    gameState = "playing", -- "playing", "checkmate", "stalemate", "check"
    whiteKingPos = {row = 7, col = 4},
    blackKingPos = {row = 0, col = 4},
    lastMove = nil, -- {fromRow, fromCol, toRow, toCol, piece, isWhite}
    isCPUTurn = false,
}

-- Initialize empty board
function InitializeChessBoard()
    if not chessGame.board then
        chessGame.board = {}
    end
    for row = 0, 7 do
        if not chessGame.board[row] then
            chessGame.board[row] = {}
        end
        for col = 0, 7 do
            chessGame.board[row][col] = nil
        end
    end
    
    chessGame.currentTurn = "white"
    chessGame.gameState = "playing"
    chessGame.whiteKingPos = {row = 7, col = 4}
    chessGame.blackKingPos = {row = 0, col = 4}
    chessGame.isCPUTurn = false
end

-- Sync board state with actual piece positions
function SyncBoardWithPieces(ignoreEntity)
    if not tableEntity or not tableEntity.whitePieces or not tableEntity.blackPieces then 
        if Config.Debug then print("[Chess] SyncBoardWithPieces: tableEntity or pieces arrays missing!") end
        return 
    end
    
    -- Ensure board structure exists
    if not chessGame.board then
        chessGame.board = {}
    end
    for row = 0, 7 do
        if not chessGame.board[row] then
            chessGame.board[row] = {}
        end
    end
    
    -- Clear board
    for row = 0, 7 do
        for col = 0, 7 do
            chessGame.board[row][col] = nil
        end
    end
    
    local order = {
        "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn",
        "rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook",
    }
    
    -- Sync black pieces
    local blackCount = 0
    for i = 1, 16 do
        local piece = order[i]
        local isWhite = false
        local expectedRow = (i <= 8) and 1 or 0
        local expectedCol = (i - 1) % 8
        if tableEntity.blackPieces[i] and DoesEntityExist(tableEntity.blackPieces[i]) then
            if ignoreEntity and tableEntity.blackPieces[i] == ignoreEntity then
                goto continue_black
            end
            if GetEntityAlpha(tableEntity.blackPieces[i]) <= 0 or not IsEntityVisible(tableEntity.blackPieces[i]) then
                goto continue_black
            end
            if GetChessPieceFromEntity then
                local entityIsWhite, _, _, entityPiece = GetChessPieceFromEntity(tableEntity.blackPieces[i])
                if entityPiece then
                    piece = entityPiece
                end
                if entityIsWhite ~= nil then
                    isWhite = entityIsWhite
                end
            end
            local entityCoords = GetEntityCoords(tableEntity.blackPieces[i])
            local actualRow, actualCol = GetBoardRowColFromCoords(entityCoords - vector3(0.0, 0.0, 0.075))
            if actualRow and actualCol then
                chessGame.board[actualRow][actualCol] = {
                    piece = piece,
                    isWhite = isWhite,
                    entity = tableEntity.blackPieces[i],
                    hasMoved = (actualRow ~= expectedRow or actualCol ~= expectedCol)
                }
                if piece == "king" then
                    if isWhite then
                        chessGame.whiteKingPos = {row = actualRow, col = actualCol}
                    else
                        chessGame.blackKingPos = {row = actualRow, col = actualCol}
                    end
                end
                blackCount = blackCount + 1
                if Config.Debug and (piece == "bishop" or piece == "pawn") then
                    print(string.format("[Chess] SyncBoardWithPieces: Black %s synced to (%d,%d)", piece, actualRow, actualCol))
                end
            else
                -- Fallback: use expected position
                chessGame.board[expectedRow][expectedCol] = {
                    piece = piece,
                    isWhite = isWhite,
                    entity = tableEntity.blackPieces[i],
                    hasMoved = false
                }
                if piece == "king" then
                    if isWhite then
                        chessGame.whiteKingPos = {row = expectedRow, col = expectedCol}
                    else
                        chessGame.blackKingPos = {row = expectedRow, col = expectedCol}
                    end
                end
                blackCount = blackCount + 1
                if Config.Debug and (piece == "bishop" or piece == "pawn") then
                    print(string.format("[Chess] SyncBoardWithPieces: Black %s synced to fallback (%d,%d)", piece, expectedRow, expectedCol))
                end
            end
        end
        ::continue_black::
    end
    if Config.Debug then
        print(string.format("[Chess] SyncBoardWithPieces: Synced %d black pieces", blackCount))
    end
    
    -- Sync white pieces
    local whiteCount = 0
    for i = 1, 16 do
        local piece = order[i]
        local isWhite = true
        local expectedRow = (i <= 8) and 6 or 7
        local expectedCol = (i - 1) % 8
        if tableEntity.whitePieces[i] and DoesEntityExist(tableEntity.whitePieces[i]) then
            if ignoreEntity and tableEntity.whitePieces[i] == ignoreEntity then
                goto continue_white
            end
            if GetEntityAlpha(tableEntity.whitePieces[i]) <= 0 or not IsEntityVisible(tableEntity.whitePieces[i]) then
                goto continue_white
            end
            if GetChessPieceFromEntity then
                local entityIsWhite, _, _, entityPiece = GetChessPieceFromEntity(tableEntity.whitePieces[i])
                if entityPiece then
                    piece = entityPiece
                end
                if entityIsWhite ~= nil then
                    isWhite = entityIsWhite
                end
            end
            local entityCoords = GetEntityCoords(tableEntity.whitePieces[i])
            local actualRow, actualCol = GetBoardRowColFromCoords(entityCoords - vector3(0.0, 0.0, 0.075))
            if actualRow and actualCol then
                chessGame.board[actualRow][actualCol] = {
                    piece = piece,
                    isWhite = isWhite,
                    entity = tableEntity.whitePieces[i],
                    hasMoved = (actualRow ~= expectedRow or actualCol ~= expectedCol)
                }
                if piece == "king" then
                    if isWhite then
                        chessGame.whiteKingPos = {row = actualRow, col = actualCol}
                    else
                        chessGame.blackKingPos = {row = actualRow, col = actualCol}
                    end
                end
                whiteCount = whiteCount + 1
            else
                -- Fallback: use expected position
                chessGame.board[expectedRow][expectedCol] = {
                    piece = piece,
                    isWhite = isWhite,
                    entity = tableEntity.whitePieces[i],
                    hasMoved = false
                }
                if piece == "king" then
                    if isWhite then
                        chessGame.whiteKingPos = {row = expectedRow, col = expectedCol}
                    else
                        chessGame.blackKingPos = {row = expectedRow, col = expectedCol}
                    end
                end
                whiteCount = whiteCount + 1
            end
        end
        ::continue_white::
    end
    if Config.Debug then
        print(string.format("[Chess] SyncBoardWithPieces: Synced %d white pieces, %d black pieces (total: %d)", 
            whiteCount, blackCount, whiteCount + blackCount))
    end
end

-- Check if coordinates are within board bounds
function IsValidSquare(row, col)
    return row >= 0 and row <= 7 and col >= 0 and col <= 7
end

-- Get piece at square
function GetPieceAt(row, col)
    if not IsValidSquare(row, col) then return nil end
    return chessGame.board[row] and chessGame.board[row][col]
end

-- Check if square is attacked by opponent
function IsSquareAttackedPseudo(row, col, byWhite, skipSync)
    -- Ensure board is synced before checking attacks unless told to skip
    if not skipSync and tableEntity and tableEntity.whitePieces and tableEntity.blackPieces then
        SyncBoardWithPieces()
    end
    
    for r = 0, 7 do
        for c = 0, 7 do
            local piece = GetPieceAt(r, c)
            if piece and piece.isWhite == byWhite then
                local moves = GenerateMovesForPiece(r, c, piece.piece, piece.isWhite, true)
                for _, move in ipairs(moves) do
                    if move.toRow == row and move.toCol == col then
                        if Config.Debug then
                            print(string.format("[Chess] Square (%d,%d) is attacked by %s %s at (%d,%d)", 
                                row, col, piece.isWhite and "white" or "black", piece.piece, r, c))
                        end
                        return true
                    end
                end
            end
        end
    end
    return false
end

function IsSquareAttacked(row, col, byWhite, skipSync, legalOnly)
    if not legalOnly then
        return IsSquareAttackedPseudo(row, col, byWhite, skipSync)
    end
    
    if not skipSync and tableEntity and tableEntity.whitePieces and tableEntity.blackPieces then
        SyncBoardWithPieces()
    end
    
    for r = 0, 7 do
        for c = 0, 7 do
            local piece = GetPieceAt(r, c)
            if piece and piece.isWhite == byWhite then
                local moves = GenerateMovesForPiece(r, c, piece.piece, piece.isWhite, true)
                for _, move in ipairs(moves) do
                    if move.toRow == row and move.toCol == col then
                        if not WouldMoveCauseCheckPseudo(r, c, move.toRow, move.toCol) then
                            if Config.Debug then
                                print(string.format("[Chess] Square (%d,%d) is attacked by legal %s %s at (%d,%d)", 
                                    row, col, piece.isWhite and "white" or "black", piece.piece, r, c))
                            end
                            return true
                        end
                    end
                end
            end
        end
    end
    
    return false
end

-- Check if king is in check
function IsInCheck(isWhite, skipSync)
    local kingPos = isWhite and chessGame.whiteKingPos or chessGame.blackKingPos
    return IsSquareAttacked(kingPos.row, kingPos.col, not isWhite, skipSync, true)
end

function IsInCheckPseudo(isWhite, skipSync)
    local kingPos = isWhite and chessGame.whiteKingPos or chessGame.blackKingPos
    return IsSquareAttackedPseudo(kingPos.row, kingPos.col, not isWhite, skipSync)
end

-- Generate moves for a piece according to chess rules
-- This function generates ALL possible moves for a piece, excluding moves that would:
-- - Move to a square with a friendly piece
-- Parameters:
--   row, col: Current position of the piece
--   piece: Piece type ("pawn", "rook", "knight", "bishop", "queen", "king")
--   isWhite: true if white piece, false if black
--   attackOnly: if true, only generate capture moves (for check detection)
function GenerateMovesForPiece(row, col, piece, isWhite, attackOnly)
    attackOnly = attackOnly or false
    local moves = {}
    
    if piece == "pawn" then
        -- Pawns move forward, capture diagonally forward
        local direction = isWhite and -1 or 1  -- White moves up (decreasing row), black moves down (increasing row)
        local startRow = isWhite and 6 or 1     -- Starting row for pawns
        
        -- Forward moves (only if not attackOnly)
        if not attackOnly then
            -- Single square forward
            local forwardRow = row + direction
            if IsValidSquare(forwardRow, col) then
                local forwardPiece = GetPieceAt(forwardRow, col)
                if not forwardPiece then
                    table.insert(moves, {toRow = forwardRow, toCol = col})
                    
                    -- Double move from starting position
                    if row == startRow then
                        local doubleForwardRow = row + 2 * direction
                        if IsValidSquare(doubleForwardRow, col) then
                            local doubleForwardPiece = GetPieceAt(doubleForwardRow, col)
                            if not doubleForwardPiece then
                                table.insert(moves, {toRow = doubleForwardRow, toCol = col})
                            end
                        end
                    end
                end
            end
        end
        
        -- Diagonal attacks/captures
        for colOffset = -1, 1, 2 do  -- Left and right diagonals
            local captureRow = row + direction
            local captureCol = col + colOffset
            
            if IsValidSquare(captureRow, captureCol) then
                if attackOnly then
                    -- Pawns attack diagonally regardless of occupancy
                    table.insert(moves, {toRow = captureRow, toCol = captureCol})
                else
                    local target = GetPieceAt(captureRow, captureCol)
                    -- Can capture opponent piece
                    if target and target.isWhite ~= isWhite then
                        table.insert(moves, {toRow = captureRow, toCol = captureCol})
                        if Config.Debug then
                            print(string.format("[Chess] Pawn at (%d,%d) can capture %s at (%d,%d)", 
                                row, col, target.piece, captureRow, captureCol))
                        end
                    end
                end
            end
        end
        
    elseif piece == "rook" then
        -- Rooks move horizontally and vertically (NOT diagonally)
        local directions = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}  -- up, down, left, right
        
        for _, dir in ipairs(directions) do
            for distance = 1, 7 do
                local newRow = row + dir[1] * distance
                local newCol = col + dir[2] * distance
                
                if not IsValidSquare(newRow, newCol) then break end
                
                local target = GetPieceAt(newRow, newCol)
                if target then
                    -- Can capture opponent piece, but stop here (can't move through pieces)
                    if target.isWhite ~= isWhite then
                        table.insert(moves, {toRow = newRow, toCol = newCol})
                    end
                    break  -- Stop in this direction (blocked by piece)
                else
                    -- Empty square - can move here
                    table.insert(moves, {toRow = newRow, toCol = newCol})
                end
            end
        end
        
    elseif piece == "knight" then
        -- Knights move in L-shape (can jump over pieces)
        local offsets = {
            {-2, -1}, {-2, 1},  -- Up-left, Up-right
            {-1, -2}, {-1, 2},  -- Left-up, Right-up
            {1, -2}, {1, 2},    -- Left-down, Right-down
            {2, -1}, {2, 1}      -- Down-left, Down-right
        }
        
        for _, offset in ipairs(offsets) do
            local newRow = row + offset[1]
            local newCol = col + offset[2]
            
            if IsValidSquare(newRow, newCol) then
                local target = GetPieceAt(newRow, newCol)
                -- Can move to empty square or capture opponent piece (NOT friendly piece)
                if not target or target.isWhite ~= isWhite then
                    table.insert(moves, {toRow = newRow, toCol = newCol})
                end
            end
        end
        
    elseif piece == "bishop" then
        -- Bishops move diagonally ONLY
        local directions = {{-1, -1}, {-1, 1}, {1, -1}, {1, 1}}  -- Four diagonal directions
        
        for _, dir in ipairs(directions) do
            for distance = 1, 7 do
                local newRow = row + dir[1] * distance
                local newCol = col + dir[2] * distance
                
                if not IsValidSquare(newRow, newCol) then break end
                
                local target = GetPieceAt(newRow, newCol)
                if target then
                    -- Can capture opponent piece, but stop here (can't move through pieces)
                    if target.isWhite ~= isWhite then
                        -- Valid capture move
                        table.insert(moves, {toRow = newRow, toCol = newCol})
                        if Config.Debug then
                            print(string.format("[Chess] Bishop at (%d,%d) can capture %s at (%d,%d)", 
                                row, col, target.piece, newRow, newCol))
                        end
                    else
                        -- Friendly piece blocks this direction
                        if Config.Debug then
                            print(string.format("[Chess] Bishop at (%d,%d) blocked by friendly %s at (%d,%d)", 
                                row, col, target.piece, newRow, newCol))
                        end
                    end
                    break  -- Stop in this direction (blocked by piece)
                else
                    -- Empty square - can move here (always valid, even if attackOnly)
                    table.insert(moves, {toRow = newRow, toCol = newCol})
                end
            end
        end
        
    elseif piece == "queen" then
        -- Queens move in all 8 directions (horizontal, vertical, diagonal)
        local directions = {
            {-1, -1}, {-1, 0}, {-1, 1},  -- Up-left, Up, Up-right
            {0, -1}, {0, 1},             -- Left, Right
            {1, -1}, {1, 0}, {1, 1}      -- Down-left, Down, Down-right
        }
        
        for _, dir in ipairs(directions) do
            for distance = 1, 7 do
                local newRow = row + dir[1] * distance
                local newCol = col + dir[2] * distance
                
                if not IsValidSquare(newRow, newCol) then break end
                
                local target = GetPieceAt(newRow, newCol)
                if target then
                    -- Can capture opponent piece, but stop here (can't move through pieces)
                    if target.isWhite ~= isWhite then
                        table.insert(moves, {toRow = newRow, toCol = newCol})
                    end
                    break  -- Stop in this direction (blocked by piece)
                else
                    -- Empty square - can move here
                    table.insert(moves, {toRow = newRow, toCol = newCol})
                end
            end
        end
        
    elseif piece == "king" then
        -- Kings move one square in any direction
        local directions = {
            {-1, -1}, {-1, 0}, {-1, 1},  -- Up-left, Up, Up-right
            {0, -1}, {0, 1},             -- Left, Right
            {1, -1}, {1, 0}, {1, 1}      -- Down-left, Down, Down-right
        }
        
        for _, dir in ipairs(directions) do
            local newRow = row + dir[1]
            local newCol = col + dir[2]
            
            if IsValidSquare(newRow, newCol) then
                local target = GetPieceAt(newRow, newCol)
                -- Can move to empty square or capture opponent piece (NOT friendly piece)
                if not target or target.isWhite ~= isWhite then
                    table.insert(moves, {toRow = newRow, toCol = newCol})
                end
            end
        end
    end
    
    return moves
end

-- Get all valid moves for a piece (checking if move leaves king in check)
-- This filters out moves that would leave the king in check
function GetValidMoves(row, col)
    local piece = GetPieceAt(row, col)
    if not piece then 
        if Config.Debug then 
            print(string.format("[Chess] GetValidMoves: No piece at (%d,%d)", row, col)) 
        end
        return {} 
    end
    
    -- Generate all possible moves for this piece
    local allMoves = GenerateMovesForPiece(row, col, piece.piece, piece.isWhite, false)
    local validMoves = {}
    
    -- Filter out moves that would leave the king in check
    for _, move in ipairs(allMoves) do
        -- Double-check: ensure we're not moving to a friendly piece (shouldn't happen, but safety check)
        local targetPiece = GetPieceAt(move.toRow, move.toCol)
        if targetPiece and targetPiece.isWhite == piece.isWhite then
            if Config.Debug then
                print(string.format("[Chess] GetValidMoves: WARNING - Move (%d,%d)->(%d,%d) would capture friendly piece %s! This should not happen.", 
                    row, col, move.toRow, move.toCol, targetPiece.piece))
            end
            -- Skip this move
        elseif not WouldMoveCauseCheck(row, col, move.toRow, move.toCol) then
            -- Move is valid - doesn't leave king in check
            table.insert(validMoves, move)
        end
    end
    
    if Config.Debug and #allMoves > 0 then
        local captureCount = 0
        for _, mv in ipairs(validMoves) do
            local target = GetPieceAt(mv.toRow, mv.toCol)
            if target and target.isWhite ~= piece.isWhite then
                captureCount = captureCount + 1
            end
        end
        print(string.format("[Chess] GetValidMoves: %s at (%d,%d) - Generated: %d, Valid: %d, Captures: %d", 
            piece.piece, row, col, #allMoves, #validMoves, captureCount))
    end
    
    return validMoves
end

-- Check if a move would leave the king in check (simulate move and test)
-- Returns: true if move would cause check (invalid), false if move is safe
function WouldMoveCauseCheckPseudo(fromRow, fromCol, toRow, toCol)
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then return true end  -- No piece to move, invalid
    
    -- Save current board state
    local capturedPiece = GetPieceAt(toRow, toCol)
    local originalPiece = chessGame.board[fromRow][fromCol]
    
    -- Simulate the move
    chessGame.board[toRow][toCol] = originalPiece
    chessGame.board[fromRow][fromCol] = nil
    
    -- Update king position if moving the king
    local originalKingPos = nil
    if piece.piece == "king" then
        if piece.isWhite then
            originalKingPos = {row = chessGame.whiteKingPos.row, col = chessGame.whiteKingPos.col}
            chessGame.whiteKingPos = {row = toRow, col = toCol}
        else
            originalKingPos = {row = chessGame.blackKingPos.row, col = chessGame.blackKingPos.col}
            chessGame.blackKingPos = {row = toRow, col = toCol}
        end
    end
    
    -- Check if the king is in check after this move
    local wouldBeInCheck = IsInCheckPseudo(piece.isWhite, true)
    
    -- Restore board state
    chessGame.board[fromRow][fromCol] = originalPiece
    chessGame.board[toRow][toCol] = capturedPiece
    
    -- Restore king position
    if piece.piece == "king" and originalKingPos then
        if piece.isWhite then
            chessGame.whiteKingPos = originalKingPos
        else
            chessGame.blackKingPos = originalKingPos
        end
    end
    
    return wouldBeInCheck
end

function WouldMoveCauseCheck(fromRow, fromCol, toRow, toCol)
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then return true end  -- No piece to move, invalid
    
    -- Save current board state
    local capturedPiece = GetPieceAt(toRow, toCol)
    local originalPiece = chessGame.board[fromRow][fromCol]
    
    -- Simulate the move
    chessGame.board[toRow][toCol] = originalPiece
    chessGame.board[fromRow][fromCol] = nil
    
    -- Update king position if moving the king
    local originalKingPos = nil
    if piece.piece == "king" then
        if piece.isWhite then
            originalKingPos = {row = chessGame.whiteKingPos.row, col = chessGame.whiteKingPos.col}
            chessGame.whiteKingPos = {row = toRow, col = toCol}
        else
            originalKingPos = {row = chessGame.blackKingPos.row, col = chessGame.blackKingPos.col}
            chessGame.blackKingPos = {row = toRow, col = toCol}
        end
    end
    
    -- Check if the king is in check after this move (legal attacks only)
    local wouldBeInCheck = IsInCheck(piece.isWhite, true)
    
    -- Restore board state
    chessGame.board[fromRow][fromCol] = originalPiece
    chessGame.board[toRow][toCol] = capturedPiece
    
    -- Restore king position
    if piece.piece == "king" and originalKingPos then
        if piece.isWhite then
            chessGame.whiteKingPos = originalKingPos
        else
            chessGame.blackKingPos = originalKingPos
        end
    end
    
    return wouldBeInCheck
end

-- Check if a move is valid according to chess rules
-- Returns: true, moveData if valid, false otherwise
function IsValidMove(fromRow, fromCol, toRow, toCol)
    -- Check if source square has a piece
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then 
        if Config.Debug then 
            print(string.format("[Chess] IsValidMove: No piece at (%d,%d)", fromRow, fromCol)) 
        end
        return false 
    end
    
    -- Check if it's the correct turn
    if (piece.isWhite and chessGame.currentTurn ~= "white") or (not piece.isWhite and chessGame.currentTurn ~= "black") then
        if Config.Debug then 
            print(string.format("[Chess] IsValidMove: Wrong turn - piece isWhite=%s, currentTurn=%s", 
                tostring(piece.isWhite), chessGame.currentTurn or "nil")) 
        end
        return false
    end
    
    -- Check if destination square is valid
    if not IsValidSquare(toRow, toCol) then
        if Config.Debug then
            print(string.format("[Chess] IsValidMove: Invalid destination square (%d,%d)", toRow, toCol))
        end
        return false
    end
    
    -- Check if moving to a friendly piece (not allowed)
    local targetPiece = GetPieceAt(toRow, toCol)
    if targetPiece and targetPiece.isWhite == piece.isWhite then
        if Config.Debug then
            print(string.format("[Chess] IsValidMove: Cannot move to square with friendly piece (%d,%d)->(%d,%d)", 
                fromRow, fromCol, toRow, toCol))
        end
        return false
    end
    
    -- Get all valid moves for this piece
    local validMoves = GetValidMoves(fromRow, fromCol)
    
    -- Check if the requested move is in the valid moves list
    for _, move in ipairs(validMoves) do
        if move.toRow == toRow and move.toCol == toCol then
            if Config.Debug then
                print(string.format("[Chess] IsValidMove: ✓ Move (%d,%d)->(%d,%d) is valid", 
                    fromRow, fromCol, toRow, toCol))
            end
            return true, move
        end
    end
    
    -- Move not found in valid moves
    if Config.Debug then
        print(string.format("[Chess] IsValidMove: ✗ Move (%d,%d)->(%d,%d) is not valid (not in valid moves list, %d valid moves available)", 
            fromRow, fromCol, toRow, toCol, #validMoves))
    end
    
    return false
end

-- Execute a move on the board
function ExecuteMove(fromRow, fromCol, toRow, toCol, moveData)
    moveData = moveData or {}
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then return false end
    
    local capturedPiece = GetPieceAt(toRow, toCol)
    
    -- Move piece
    chessGame.board[toRow][toCol] = piece
    chessGame.board[fromRow][fromCol] = nil
    piece.hasMoved = true
    
    -- Update king position
    if piece.piece == "king" then
        if piece.isWhite then
            chessGame.whiteKingPos = {row = toRow, col = toCol}
        else
            chessGame.blackKingPos = {row = toRow, col = toCol}
        end
    end
    
    -- Handle pawn promotion (set flag for table module to handle entity update)
    if piece.piece == "pawn" and (toRow == 0 or toRow == 7) then
        piece.needsPromotion = true
    end
    
    -- Update turn
    chessGame.currentTurn = chessGame.currentTurn == "white" and "black" or "white"
    
    -- Store last move
    chessGame.lastMove = {fromRow = fromRow, fromCol = fromCol, toRow = toRow, toCol = toCol, piece = piece.piece, isWhite = piece.isWhite}
    
    return true
end

-- Update game state (check, checkmate, stalemate)
function UpdateGameState()
    if not tableEntity or not tableEntity.whitePieces or not tableEntity.blackPieces then 
        if Config.Debug then print("[Chess] UpdateGameState: tableEntity not ready, skipping...") end
        return 
    end
    
    -- Sync board if it seems out of sync (fewer than 10 pieces)
    local pieceCount = 0
    for row = 0, 7 do
        for col = 0, 7 do
            if chessGame.board[row] and chessGame.board[row][col] then
                pieceCount = pieceCount + 1
            end
        end
    end
    if pieceCount < 10 then
        if Config.Debug then print(string.format("[Chess] UpdateGameState: Board seems out of sync (%d pieces), syncing...", pieceCount)) end
        SyncBoardWithPieces()
    end
    
    local currentPlayerIsWhite = chessGame.currentTurn == "white"
    local inCheck = IsInCheck(currentPlayerIsWhite)
    local allMoves = GetAllValidMoves(currentPlayerIsWhite)
    local hasValidMoves = #allMoves > 0
    
    if Config.Debug then
        local pieceCount = 0
        for row = 0, 7 do
            for col = 0, 7 do
                if chessGame.board[row] and chessGame.board[row][col] then
                    pieceCount = pieceCount + 1
                end
            end
        end
        print(string.format("[Chess] UpdateGameState: Turn=%s, Pieces=%d, HasMoves=%s, InCheck=%s", 
            chessGame.currentTurn, pieceCount, tostring(hasValidMoves), tostring(inCheck)))
    end
    
    if not hasValidMoves then
        if inCheck then
            chessGame.gameState = "checkmate"
            if Config.Debug then print("[Chess] Game Over: Checkmate!") end
        else
            chessGame.gameState = "stalemate"
            if Config.Debug then print("[Chess] Game Over: Stalemate!") end
        end
    elseif inCheck then
        chessGame.gameState = "check"
        if Config.Debug then print("[Chess] King in check!") end
    else
        chessGame.gameState = "playing"
    end
end

-- Get all valid moves for a color
function GetAllValidMoves(isWhite)
    local allMoves = {}
    for row = 0, 7 do
        for col = 0, 7 do
            local piece = GetPieceAt(row, col)
            if piece and piece.isWhite == isWhite then
                local moves = GetValidMoves(row, col)
                for _, move in ipairs(moves) do
                    table.insert(allMoves, {fromRow = row, fromCol = col, toRow = move.toRow, toCol = move.toCol})
                end
            end
        end
    end
    return allMoves
end

-- CPU AI functions
function GetRandomCPUMove()
    local allMoves = GetAllValidMoves(false) -- CPU is black
    if #allMoves == 0 then return nil end
    return allMoves[math.random(#allMoves)]
end

function EvaluateBoard()
    local score = 0
    for row = 0, 7 do
        for col = 0, 7 do
            local piece = GetPieceAt(row, col)
            if piece then
                local value = GetPieceValue(piece.piece)
                local positionValue = GetPositionValue(piece.piece, row, col, piece.isWhite)
                if piece.isWhite then
                    score = score + value + positionValue
                else
                    score = score - value - positionValue
                end
            end
        end
    end
    return score
end

function Minimax(depth, isMaximizing, alpha, beta)
    if depth == 0 then
        return EvaluateBoard()
    end
    
    local isWhite = isMaximizing
    local allMoves = GetAllValidMoves(isWhite)
    
    if #allMoves == 0 then
        if IsInCheck(isWhite, true) then
            return isMaximizing and -99999 or 99999 -- Checkmate
        else
            return 0 -- Stalemate
        end
    end
    
    if isMaximizing then
        local maxEval = -99999
        for _, move in ipairs(allMoves) do
            local piece = GetPieceAt(move.fromRow, move.fromCol)
            local capturedPiece = GetPieceAt(move.toRow, move.toCol)
            
            -- Simulate move
            ExecuteMove(move.fromRow, move.fromCol, move.toRow, move.toCol)
            local eval = Minimax(depth - 1, false, alpha, beta)
            
            -- Undo move
            chessGame.currentTurn = "white"
            chessGame.board[move.fromRow][move.fromCol] = piece
            chessGame.board[move.toRow][move.toCol] = capturedPiece
            if piece.piece == "king" then
                if piece.isWhite then
                    chessGame.whiteKingPos = {row = move.fromRow, col = move.fromCol}
                else
                    chessGame.blackKingPos = {row = move.fromRow, col = move.fromCol}
                end
            end
            
            maxEval = math.max(maxEval, eval)
            alpha = math.max(alpha, eval)
            if beta <= alpha then break end
        end
        return maxEval
    else
        local minEval = 99999
        for _, move in ipairs(allMoves) do
            local piece = GetPieceAt(move.fromRow, move.fromCol)
            local capturedPiece = GetPieceAt(move.toRow, move.toCol)
            
            -- Simulate move
            ExecuteMove(move.fromRow, move.fromCol, move.toRow, move.toCol)
            local eval = Minimax(depth - 1, true, alpha, beta)
            
            -- Undo move
            chessGame.currentTurn = "black"
            chessGame.board[move.fromRow][move.fromCol] = piece
            chessGame.board[move.toRow][move.toCol] = capturedPiece
            if piece.piece == "king" then
                if piece.isWhite then
                    chessGame.whiteKingPos = {row = move.fromRow, col = move.fromCol}
                else
                    chessGame.blackKingPos = {row = move.fromRow, col = move.fromCol}
                end
            end
            
            minEval = math.min(minEval, eval)
            beta = math.min(beta, eval)
            if beta <= alpha then break end
        end
        return minEval
    end
end

function GetBestCPUMove(depth)
    depth = depth or 2
    local allMoves = GetAllValidMoves(false) -- CPU is black
    if #allMoves == 0 then return nil end
    
    local bestMove = nil
    local bestEval = 99999
    
    for _, move in ipairs(allMoves) do
        local piece = GetPieceAt(move.fromRow, move.fromCol)
        local capturedPiece = GetPieceAt(move.toRow, move.toCol)
        
        -- Simulate move
        ExecuteMove(move.fromRow, move.fromCol, move.toRow, move.toCol)
        local eval = Minimax(depth - 1, true, -99999, 99999)
        
        -- Undo move
        chessGame.currentTurn = "black"
        chessGame.board[move.fromRow][move.fromCol] = piece
        chessGame.board[move.toRow][move.toCol] = capturedPiece
        if piece.piece == "king" then
            if piece.isWhite then
                chessGame.whiteKingPos = {row = move.fromRow, col = move.fromCol}
            else
                chessGame.blackKingPos = {row = move.fromRow, col = move.fromCol}
            end
        end
        
        if eval < bestEval then
            bestEval = eval
            bestMove = move
        end
    end
    
    return bestMove
end

function GetCPUMove()
    if Config.Debug then print("[Chess] GetCPUMove: Starting CPU move calculation...") end
    
    local difficulty = Config.Chess and Config.Chess.CPU_Difficulty or "medium"
    local depth = 1
    if difficulty == "easy" then depth = 1
    elseif difficulty == "medium" then depth = 2
    elseif difficulty == "hard" then depth = 3
    end
    
    local move = GetBestCPUMove(depth)
    if not move then
        move = GetRandomCPUMove()
    end
    
    if move then
        -- Validate move: ensure it's not moving to a friendly piece
        local piece = GetPieceAt(move.fromRow, move.fromCol)
        local targetPiece = GetPieceAt(move.toRow, move.toCol)
        
        if piece and targetPiece and targetPiece.isWhite == piece.isWhite then
            if Config.Debug then
                print(string.format("[Chess] GetCPUMove: ERROR - Move would place piece on friendly piece! (%d,%d)->(%d,%d), target=%s", 
                    move.fromRow, move.fromCol, move.toRow, move.toCol, targetPiece.piece))
            end
            -- Try to get a different move
            local allMoves = GetAllValidMoves(false) -- CPU is black
            local validMoves = {}
            for _, m in ipairs(allMoves) do
                local target = GetPieceAt(m.toRow, m.toCol)
                if not target or target.isWhite ~= false then -- Only moves to empty squares or opponent pieces
                    table.insert(validMoves, m)
                end
            end
            if #validMoves > 0 then
                move = validMoves[math.random(#validMoves)]
                if Config.Debug then
                    print(string.format("[Chess] GetCPUMove: Using alternative move (%d,%d)->(%d,%d)", 
                        move.fromRow, move.fromCol, move.toRow, move.toCol))
                end
            else
                if Config.Debug then print("[Chess] GetCPUMove: No alternative moves available!") end
                return nil
            end
        end
        
        local moveData = {}
        local validMoves = GetValidMoves(move.fromRow, move.fromCol)
        for _, vm in ipairs(validMoves) do
            if vm.toRow == move.toRow and vm.toCol == move.toCol then
                moveData = vm
                break
            end
        end
        
        if Config.Debug then
            print(string.format("[Chess] GetCPUMove: CPU chose move from (%d,%d) to (%d,%d)", 
                move.fromRow, move.fromCol, move.toRow, move.toCol))
        end
        
        return {
            fromRow = move.fromRow,
            fromCol = move.fromCol,
            toRow = move.toRow,
            toCol = move.toCol,
            moveData = moveData
        }
    end
    
    if Config.Debug then print("[Chess] GetCPUMove: No valid CPU move found!") end
    return nil
end
