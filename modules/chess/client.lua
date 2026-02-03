-- Chess game logic module (global so table/interaction modules can access)
chessGame = {
    board = {}, -- 8x8 array: board[row][col] = {piece, isWhite, entity, hasMoved}
    currentTurn = "white",
    gameState = "playing", -- "playing", "checkmate", "stalemate", "check"
    whiteKingPos = {row = 7, col = 4},
    blackKingPos = {row = 0, col = 4},
    enPassantTarget = nil, -- {row, col} if available
    castlingRights = {
        white = {kingSide = true, queenSide = true},
        black = {kingSide = true, queenSide = true}
    },
    lastMove = nil, -- {fromRow, fromCol, toRow, toCol, piece, isWhite}
    isCPUTurn = false,
}

-- Initialize empty board
function InitializeChessBoard()
    -- Only initialize board structure if it doesn't exist or is corrupted
    if not chessGame.board then
        chessGame.board = {}
    end
    for row = 0, 7 do
        if not chessGame.board[row] then
            chessGame.board[row] = {}
        end
        for col = 0, 7 do
            -- Don't clear existing pieces - just ensure structure exists
            if chessGame.board[row][col] == nil then
                chessGame.board[row][col] = nil  -- Already nil, but ensures structure
            end
        end
    end
    -- Only reset game state if not already set
    if not chessGame.currentTurn then
        chessGame.currentTurn = "white"
    end
    if not chessGame.gameState then
        chessGame.gameState = "playing"
    end
    if not chessGame.whiteKingPos then
        chessGame.whiteKingPos = {row = 7, col = 4}
    end
    if not chessGame.blackKingPos then
        chessGame.blackKingPos = {row = 0, col = 4}
    end
    if chessGame.enPassantTarget == nil and chessGame.lastMove == nil then
        chessGame.enPassantTarget = nil
    end
    if not chessGame.castlingRights then
        chessGame.castlingRights = {
            white = {kingSide = true, queenSide = true},
            black = {kingSide = true, queenSide = true}
        }
    end
    if chessGame.isCPUTurn == nil then
        chessGame.isCPUTurn = false
    end
end

-- Sync board state with actual piece positions
function SyncBoardWithPieces()
    if not tableEntity or not tableEntity.whitePieces or not tableEntity.blackPieces then 
        if Config.Debug then print("[Chess] SyncBoardWithPieces: tableEntity or pieces arrays missing!") end
        return 
    end
    
    -- Ensure board structure exists without clearing existing pieces
    if not chessGame.board then
        chessGame.board = {}
    end
    for row = 0, 7 do
        if not chessGame.board[row] then
            chessGame.board[row] = {}
        end
    end
    -- Clear board squares (but keep structure) before repopulating
    for row = 0, 7 do
        for col = 0, 7 do
            chessGame.board[row][col] = nil
        end
    end
    
    local order = {
        "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn",
        "rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook",
    }
    
    local blackPlaced = 0
    local blackMissing = 0
    
    -- Sync black pieces
    for i = 1, 16 do
        local piece = order[i]
        local expectedRow = (i <= 8) and 1 or 0
        local expectedCol = (i - 1) % 8
        if tableEntity.blackPieces[i] and DoesEntityExist(tableEntity.blackPieces[i]) then
            local entityCoords = GetEntityCoords(tableEntity.blackPieces[i])
            local actualRow, actualCol = GetBoardRowColFromCoords(entityCoords - vector3(0.0, 0.0, 0.075))
            if actualRow and actualCol then
                -- Check if there's already a piece at this position
                local existingPiece = chessGame.board[actualRow] and chessGame.board[actualRow][actualCol]
                if existingPiece and Config.Debug then
                    print(string.format("[Chess] SyncBoardWithPieces: Overwriting piece at (%d,%d): %s (was %s)", 
                        actualRow, actualCol, 
                        existingPiece.isWhite and "white " .. existingPiece.piece or "black " .. existingPiece.piece,
                        "black " .. piece))
                end
                chessGame.board[actualRow][actualCol] = {
                    piece = piece,
                    isWhite = false,  -- CRITICAL: Black pieces are always isWhite = false
                    entity = tableEntity.blackPieces[i],
                    hasMoved = (actualRow ~= expectedRow or actualCol ~= expectedCol)
                }
                if piece == "king" then
                    chessGame.blackKingPos = {row = actualRow, col = actualCol}
                end
                blackPlaced = blackPlaced + 1
            else
                -- Fallback: use expected position if GetBoardRowColFromCoords fails
                blackMissing = blackMissing + 1
                if Config.Debug then
                    print(string.format("[Chess] SyncBoardWithPieces: Black %s[%d] at (%f,%f,%f) - GetBoardRowColFromCoords failed, using expected pos (%d,%d)", 
                        piece, i, entityCoords.x, entityCoords.y, entityCoords.z, expectedRow, expectedCol))
                end
                -- Place at expected position as fallback
                chessGame.board[expectedRow][expectedCol] = {
                    piece = piece,
                    isWhite = false,
                    entity = tableEntity.blackPieces[i],
                    hasMoved = false
                }
                if piece == "king" then
                    chessGame.blackKingPos = {row = expectedRow, col = expectedCol}
                end
                blackPlaced = blackPlaced + 1
            end
        else
            blackMissing = blackMissing + 1
            if Config.Debug then
                print(string.format("[Chess] SyncBoardWithPieces: Black %s[%d] entity missing or doesn't exist", piece, i))
            end
        end
    end
    
    if Config.Debug then
        print(string.format("[Chess] SyncBoardWithPieces: Black pieces - Placed: %d, Missing: %d", blackPlaced, blackMissing))
    end
    
    local whitePlaced = 0
    local whiteMissing = 0
    
    -- Sync white pieces
    for i = 1, 16 do
        local piece = order[i]
        local expectedRow = (i <= 8) and 6 or 7
        local expectedCol = (i - 1) % 8
        if tableEntity.whitePieces[i] and DoesEntityExist(tableEntity.whitePieces[i]) then
            local entityCoords = GetEntityCoords(tableEntity.whitePieces[i])
            local actualRow, actualCol = GetBoardRowColFromCoords(entityCoords - vector3(0.0, 0.0, 0.075))
            if actualRow and actualCol then
                -- Check if there's already a piece at this position
                local existingPiece = chessGame.board[actualRow] and chessGame.board[actualRow][actualCol]
                if existingPiece and Config.Debug then
                    print(string.format("[Chess] SyncBoardWithPieces: Overwriting piece at (%d,%d): %s (was %s)", 
                        actualRow, actualCol, 
                        existingPiece.isWhite and "white " .. existingPiece.piece or "black " .. existingPiece.piece,
                        "white " .. piece))
                end
                chessGame.board[actualRow][actualCol] = {
                    piece = piece,
                    isWhite = true,  -- CRITICAL: White pieces are always isWhite = true
                    entity = tableEntity.whitePieces[i],
                    hasMoved = (actualRow ~= expectedRow or actualCol ~= expectedCol)
                }
                if piece == "king" then
                    chessGame.whiteKingPos = {row = actualRow, col = actualCol}
                end
                whitePlaced = whitePlaced + 1
            else
                -- Fallback: use expected position if GetBoardRowColFromCoords fails
                whiteMissing = whiteMissing + 1
                if Config.Debug then
                    print(string.format("[Chess] SyncBoardWithPieces: White %s[%d] at (%f,%f,%f) - GetBoardRowColFromCoords failed, using expected pos (%d,%d)", 
                        piece, i, entityCoords.x, entityCoords.y, entityCoords.z, expectedRow, expectedCol))
                end
                -- Place at expected position as fallback
                chessGame.board[expectedRow][expectedCol] = {
                    piece = piece,
                    isWhite = true,
                    entity = tableEntity.whitePieces[i],
                    hasMoved = false
                }
                if piece == "king" then
                    chessGame.whiteKingPos = {row = expectedRow, col = expectedCol}
                end
                whitePlaced = whitePlaced + 1
            end
        else
            whiteMissing = whiteMissing + 1
            if Config.Debug then
                print(string.format("[Chess] SyncBoardWithPieces: White %s[%d] entity missing or doesn't exist", piece, i))
            end
        end
    end
    
    if Config.Debug then
        print(string.format("[Chess] SyncBoardWithPieces: White pieces - Placed: %d, Missing: %d", whitePlaced, whiteMissing))
    end
end

-- Check if coordinates are within board bounds
function IsValidSquare(row, col)
    return row >= 0 and row <= 7 and col >= 0 and col <= 7
end

-- Get piece at square
function GetPieceAt(row, col)
    if not IsValidSquare(row, col) then return nil end
    return chessGame.board[row][col]
end

-- Check if square is attacked by opponent
function IsSquareAttacked(row, col, byWhite)
    for r = 0, 7 do
        for c = 0, 7 do
            local piece = GetPieceAt(r, c)
            if piece and piece.isWhite == byWhite then
                local moves = GenerateMovesForPiece(r, c, piece.piece, piece.isWhite, true)
                for _, move in ipairs(moves) do
                    if move.toRow == row and move.toCol == col then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Check if king is in check
function IsInCheck(isWhite)
    local kingPos = isWhite and chessGame.whiteKingPos or chessGame.blackKingPos
    return IsSquareAttacked(kingPos.row, kingPos.col, not isWhite)
end

-- Generate moves for a piece (without checking if move leaves king in check)
-- This function generates ALL possible moves for a piece according to chess rules:
-- - Pawns: Forward moves (1 or 2 squares from start), diagonal captures ONLY
-- - Rooks: Horizontal/vertical moves and captures (NOT diagonal)
-- - Knights: L-shaped moves and captures (jumps over pieces)
-- - Bishops: Diagonal moves and captures ONLY
-- - Queens: All directions (horizontal, vertical, diagonal) moves and captures
-- - Kings: One square in any direction, moves and captures
function GenerateMovesForPiece(row, col, piece, isWhite, attackOnly)
    attackOnly = attackOnly or false
    local moves = {}
    
    if piece == "pawn" then
        local direction = isWhite and -1 or 1
        local startRow = isWhite and 6 or 1
        
        -- Forward move (only if not attackOnly)
        if not attackOnly then
            if IsValidSquare(row + direction, col) and not GetPieceAt(row + direction, col) then
                table.insert(moves, {toRow = row + direction, toCol = col})
                
                -- Double move from starting position
                if row == startRow and IsValidSquare(row + 2 * direction, col) and not GetPieceAt(row + 2 * direction, col) then
                    table.insert(moves, {toRow = row + 2 * direction, toCol = col})
                end
            end
        end
        
        -- Capture diagonally forward ONLY (pawns can ONLY capture diagonally)
        for dc = -1, 1, 2 do
            local newCol = col + dc
            local newRow = row + direction
            if IsValidSquare(newRow, newCol) then
                local target = GetPieceAt(newRow, newCol)
                -- Debug output for every diagonal check
                if Config.Debug then
                    print(string.format("[Chess] Pawn at (%d,%d) checking diagonal (%d,%d): target=%s, isWhite=%s, pieceIsWhite=%s", 
                        row, col, newRow, newCol, 
                        target and target.piece or "nil",
                        target and tostring(target.isWhite) or "nil",
                        tostring(isWhite)))
                end
                -- Pawns can ONLY capture diagonally - must have opponent piece
                if target then
                    if target.isWhite ~= isWhite then
                        table.insert(moves, {toRow = newRow, toCol = newCol})
                        if Config.Debug then
                            print(string.format("[Chess] ✓ Pawn capture ADDED: (%d,%d)->(%d,%d) capturing %s", 
                                row, col, newRow, newCol, target.piece))
                        end
                    else
                        if Config.Debug then
                            print(string.format("[Chess] ✗ Pawn diagonal (%d,%d) has friendly piece %s (same color), no capture", 
                                newRow, newCol, target.piece))
                        end
                    end
                else
                    if Config.Debug then
                        print(string.format("[Chess] ✗ Pawn diagonal square (%d,%d) is empty (no capture available)", newRow, newCol))
                    end
                end
                -- En passant (only if not attackOnly)
                if not attackOnly and chessGame.enPassantTarget and chessGame.enPassantTarget.row == newRow and chessGame.enPassantTarget.col == newCol then
                    table.insert(moves, {toRow = newRow, toCol = newCol, enPassant = true})
                end
            end
        end
        
    elseif piece == "rook" then
        -- Rook moves horizontally and vertically ONLY (NOT diagonally)
        local directions = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}  -- up, down, left, right
        for _, dir in ipairs(directions) do
            for i = 1, 7 do
                local newRow = row + dir[1] * i
                local newCol = col + dir[2] * i
                if not IsValidSquare(newRow, newCol) then break end
                local target = GetPieceAt(newRow, newCol)
                if target then
                    -- If there's a piece, we can capture if it's an opponent piece
                    if target.isWhite ~= isWhite then
                        table.insert(moves, {toRow = newRow, toCol = newCol})
                        if Config.Debug then
                            print(string.format("[Chess] Rook capture found: (%d,%d)->(%d,%d) capturing %s", 
                                row, col, newRow, newCol, target.piece))
                        end
                    end
                    -- Stop searching in this direction (can't move through pieces)
                    break
                end
                -- Empty square - can move here
                table.insert(moves, {toRow = newRow, toCol = newCol})
            end
        end
        
    elseif piece == "knight" then
        -- Knight moves in L-shape (2 squares in one direction, 1 square perpendicular)
        local offsets = {{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2}, {1, -2}, {1, 2}, {2, -1}, {2, 1}}
        for _, offset in ipairs(offsets) do
            local newRow = row + offset[1]
            local newCol = col + offset[2]
            if IsValidSquare(newRow, newCol) then
                local target = GetPieceAt(newRow, newCol)
                -- Can move to empty square or capture opponent piece
                if not target or target.isWhite ~= isWhite then
                    table.insert(moves, {toRow = newRow, toCol = newCol})
                end
            end
        end
        
    elseif piece == "bishop" then
        -- Bishop moves diagonally ONLY
        local directions = {{-1, -1}, {-1, 1}, {1, -1}, {1, 1}}  -- four diagonal directions
        for _, dir in ipairs(directions) do
            for i = 1, 7 do
                local newRow = row + dir[1] * i
                local newCol = col + dir[2] * i
                if not IsValidSquare(newRow, newCol) then break end
                local target = GetPieceAt(newRow, newCol)
                if target then
                    -- If there's a piece, we can capture if it's an opponent piece
                    if target.isWhite ~= isWhite then
                        table.insert(moves, {toRow = newRow, toCol = newCol})
                    end
                    -- Stop searching in this direction (can't move through pieces)
                    break
                end
                -- Empty square - can move here
                table.insert(moves, {toRow = newRow, toCol = newCol})
            end
        end
        
    elseif piece == "queen" then
        -- Queen moves in all 8 directions (horizontal, vertical, and diagonal)
        local directions = {{-1, -1}, {-1, 0}, {-1, 1}, {0, -1}, {0, 1}, {1, -1}, {1, 0}, {1, 1}}
        for _, dir in ipairs(directions) do
            for i = 1, 7 do
                local newRow = row + dir[1] * i
                local newCol = col + dir[2] * i
                if not IsValidSquare(newRow, newCol) then break end
                local target = GetPieceAt(newRow, newCol)
                if target then
                    -- If there's a piece, we can capture if it's an opponent piece
                    if target.isWhite ~= isWhite then
                        table.insert(moves, {toRow = newRow, toCol = newCol})
                    end
                    -- Stop searching in this direction (can't move through pieces)
                    break
                end
                -- Empty square - can move here
                table.insert(moves, {toRow = newRow, toCol = newCol})
            end
        end
        
    elseif piece == "king" then
        -- King moves one square in any direction
        local directions = {{-1, -1}, {-1, 0}, {-1, 1}, {0, -1}, {0, 1}, {1, -1}, {1, 0}, {1, 1}}
        for _, dir in ipairs(directions) do
            local newRow = row + dir[1]
            local newCol = col + dir[2]
            if IsValidSquare(newRow, newCol) then
                local target = GetPieceAt(newRow, newCol)
                -- Can move to empty square or capture opponent piece
                if not target or target.isWhite ~= isWhite then
                    table.insert(moves, {toRow = newRow, toCol = newCol})
                end
            end
        end
        
        -- Castling (only if not attackOnly)
        if not attackOnly then
            local castling = chessGame.castlingRights[isWhite and "white" or "black"]
            local kingPiece = GetPieceAt(row, col)
            
            -- King side castling
            if castling.kingSide and not kingPiece.hasMoved then
                local rook = GetPieceAt(row, 7)
                if rook and rook.piece == "rook" and rook.isWhite == isWhite and not rook.hasMoved then
                    if not GetPieceAt(row, 5) and not GetPieceAt(row, 6) then
                        if not IsSquareAttacked(row, 4, not isWhite) and not IsSquareAttacked(row, 5, not isWhite) and not IsSquareAttacked(row, 6, not isWhite) then
                            table.insert(moves, {toRow = row, toCol = 6, castling = "kingSide"})
                        end
                    end
                end
            end
            
            -- Queen side castling
            if castling.queenSide and not kingPiece.hasMoved then
                local rook = GetPieceAt(row, 0)
                if rook and rook.piece == "rook" and rook.isWhite == isWhite and not rook.hasMoved then
                    if not GetPieceAt(row, 1) and not GetPieceAt(row, 2) and not GetPieceAt(row, 3) then
                        if not IsSquareAttacked(row, 4, not isWhite) and not IsSquareAttacked(row, 3, not isWhite) and not IsSquareAttacked(row, 2, not isWhite) then
                            table.insert(moves, {toRow = row, toCol = 2, castling = "queenSide"})
                        end
                    end
                end
            end
        end
    end
    
    return moves
end

-- Get all valid moves for a piece (checking if move leaves king in check)
function GetValidMoves(row, col)
    local piece = GetPieceAt(row, col)
    if not piece then 
        if Config.Debug then print(string.format("[Chess] GetValidMoves: No piece at (%d,%d)", row, col)) end
        return {} 
    end
    
    -- Debug: Check board state around this piece
    if Config.Debug and piece.piece == "pawn" then
        local direction = piece.isWhite and -1 or 1
        for dc = -1, 1, 2 do
            local checkRow = row + direction
            local checkCol = col + dc
            if IsValidSquare(checkRow, checkCol) then
                local target = GetPieceAt(checkRow, checkCol)
                print(string.format("[Chess] Pawn at (%d,%d) checking diagonal (%d,%d): %s", 
                    row, col, checkRow, checkCol, target and (target.isWhite and "white " .. target.piece or "black " .. target.piece) or "empty"))
            end
        end
    end
    
    local moves = GenerateMovesForPiece(row, col, piece.piece, piece.isWhite, false)
    local validMoves = {}
    local captureMoves = 0
    local blockedMoves = 0
    
    for _, move in ipairs(moves) do
        local targetPiece = GetPieceAt(move.toRow, move.toCol)
        local isCapture = targetPiece ~= nil and targetPiece.isWhite ~= piece.isWhite
        
        if WouldMoveCauseCheck(row, col, move.toRow, move.toCol) == false then
            table.insert(validMoves, move)
            if isCapture then captureMoves = captureMoves + 1 end
        else
            blockedMoves = blockedMoves + 1
            if Config.Debug and isCapture then
                print(string.format("[Chess] Capture move (%d,%d)->(%d,%d) blocked (would cause check)", 
                    row, col, move.toRow, move.toCol))
            end
        end
    end
    
    if Config.Debug and #moves > 0 then
        print(string.format("[Chess] GetValidMoves: %s at (%d,%d) - Generated: %d, Valid: %d, Captures: %d, Blocked: %d", 
            piece.piece, row, col, #moves, #validMoves, captureMoves, blockedMoves))
        -- List all valid capture moves
        if captureMoves > 0 then
            for _, mv in ipairs(validMoves) do
                local target = GetPieceAt(mv.toRow, mv.toCol)
                if target and target.isWhite ~= piece.isWhite then
                    print(string.format("[Chess]   Valid capture: (%d,%d)->(%d,%d) capturing %s", 
                        row, col, mv.toRow, mv.toCol, target.piece))
                end
            end
        end
    end
    
    return validMoves
end

-- Check if a move would cause check (simulate move)
function WouldMoveCauseCheck(fromRow, fromCol, toRow, toCol)
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then return true end
    
    -- Simulate move
    local capturedPiece = GetPieceAt(toRow, toCol)
    local originalPiece = chessGame.board[fromRow][fromCol]
    
    chessGame.board[toRow][toCol] = originalPiece
    chessGame.board[fromRow][fromCol] = nil
    
    -- Update king position if moving king
    if piece.piece == "king" then
        if piece.isWhite then
            chessGame.whiteKingPos = {row = toRow, col = toCol}
        else
            chessGame.blackKingPos = {row = toRow, col = toCol}
        end
    end
    
    local inCheck = IsInCheck(piece.isWhite)
    
    -- Restore board
    chessGame.board[fromRow][fromCol] = originalPiece
    chessGame.board[toRow][toCol] = capturedPiece
    
    -- Restore king position
    if piece.piece == "king" then
        if piece.isWhite then
            chessGame.whiteKingPos = {row = fromRow, col = fromCol}
        else
            chessGame.blackKingPos = {row = fromRow, col = fromCol}
        end
    end
    
    return inCheck
end

-- Check if move is valid
function IsValidMove(fromRow, fromCol, toRow, toCol)
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then 
        if Config.Debug then print(string.format("[Chess] IsValidMove: No piece at (%d,%d)", fromRow, fromCol)) end
        return false 
    end
    
    if Config.Debug then
        print(string.format("[Chess] IsValidMove: Checking move (%d,%d)->(%d,%d) for %s", 
            fromRow, fromCol, toRow, toCol, piece.piece))
    end
    
    -- Check if it's the correct turn
    if (piece.isWhite and chessGame.currentTurn ~= "white") or (not piece.isWhite and chessGame.currentTurn ~= "black") then
        if Config.Debug then 
            print(string.format("[Chess] IsValidMove: Wrong turn - piece isWhite=%s, currentTurn=%s", 
                tostring(piece.isWhite), chessGame.currentTurn or "nil")) 
        end
        return false
    end
    
    local targetPiece = GetPieceAt(toRow, toCol)
    local isCapture = targetPiece ~= nil and targetPiece.isWhite ~= piece.isWhite
    
    if Config.Debug then
        print(string.format("[Chess] IsValidMove: Target square (%d,%d) has: %s (isCapture=%s)", 
            toRow, toCol, targetPiece and (targetPiece.isWhite and "white " .. targetPiece.piece or "black " .. targetPiece.piece) or "empty", tostring(isCapture)))
    end
    
    local validMoves = GetValidMoves(fromRow, fromCol)
    local found = false
    for _, move in ipairs(validMoves) do
        if move.toRow == toRow and move.toCol == toCol then
            found = true
            if Config.Debug then
                print(string.format("[Chess] IsValidMove: ✓ Move found in valid moves list!"))
            end
            break
        end
    end
    
    if Config.Debug and not found then
        print(string.format("[Chess] IsValidMove: Move (%d,%d)->(%d,%d) not in valid moves list (isCapture=%s, targetPiece=%s)", 
            fromRow, fromCol, toRow, toCol, tostring(isCapture), targetPiece and targetPiece.piece or "none"))
        print(string.format("[Chess] IsValidMove: Valid moves count: %d", #validMoves))
        if #validMoves > 0 and #validMoves <= 10 then
            for i, mv in ipairs(validMoves) do
                print(string.format("[Chess]   Valid move %d: (%d,%d)", i, mv.toRow, mv.toCol))
            end
        end
    end
    
    if found then
        for _, move in ipairs(validMoves) do
            if move.toRow == toRow and move.toCol == toCol then
                return true, move
            end
        end
    end
    
    return false
end

-- Execute a move on the board
function ExecuteMove(fromRow, fromCol, toRow, toCol, moveData)
    moveData = moveData or {}
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then return false end
    
    local capturedPiece = GetPieceAt(toRow, toCol)
    
    -- Handle en passant
    if moveData.enPassant then
        local epRow = isWhite and toRow + 1 or toRow - 1
        if chessGame.board[epRow] and chessGame.board[epRow][toCol] then
            chessGame.board[epRow][toCol] = nil
        end
    end
    
    -- Handle castling
    if moveData.castling then
        if moveData.castling == "kingSide" then
            local rook = GetPieceAt(fromRow, 7)
            if rook then
                chessGame.board[fromRow][7] = nil
                chessGame.board[fromRow][5] = rook
                rook.hasMoved = true
            end
        elseif moveData.castling == "queenSide" then
            local rook = GetPieceAt(fromRow, 0)
            if rook then
                chessGame.board[fromRow][0] = nil
                chessGame.board[fromRow][3] = rook
                rook.hasMoved = true
            end
        end
    end
    
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
    
    -- Update en passant target
    chessGame.enPassantTarget = nil
    if piece.piece == "pawn" and math.abs(toRow - fromRow) == 2 then
        chessGame.enPassantTarget = {row = (fromRow + toRow) / 2, col = fromCol}
    end
    
    -- Update castling rights
    if piece.piece == "king" then
        chessGame.castlingRights[piece.isWhite and "white" or "black"].kingSide = false
        chessGame.castlingRights[piece.isWhite and "white" or "black"].queenSide = false
    elseif piece.piece == "rook" then
        if fromCol == 0 then
            chessGame.castlingRights[piece.isWhite and "white" or "black"].queenSide = false
        elseif fromCol == 7 then
            chessGame.castlingRights[piece.isWhite and "white" or "black"].kingSide = false
        end
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
        if IsInCheck(isWhite) then
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
        local piece = GetPieceAt(move.fromRow, move.fromCol)
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
