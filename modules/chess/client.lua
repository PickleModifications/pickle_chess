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
    halfmoveClock = 0,
    fullmoveNumber = 1,
    positionHistory = {},
    drawReason = nil,
    awaitingPromotion = false,
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
    chessGame.enPassantTarget = nil
    chessGame.castlingRights = {
        white = {kingSide = true, queenSide = true},
        black = {kingSide = true, queenSide = true}
    }
    chessGame.halfmoveClock = 0
    chessGame.fullmoveNumber = 1
    chessGame.positionHistory = {}
    chessGame.drawReason = nil
    chessGame.awaitingPromotion = false
    chessGame.isCPUTurn = false

    UpdatePositionHistory()
end

-- Sync board state with actual piece positions
function SyncBoardWithPieces(ignoreEntity)
    if not tableEntity or not tableEntity.whitePieces or not tableEntity.blackPieces then 
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
            end
        end
        ::continue_black::
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

local function GetPositionKey()
    local rows = {}
    for row = 0, 7 do
        local empty = 0
        local rowStr = ""
        for col = 0, 7 do
            local piece = GetPieceAt(row, col)
            if piece then
                if empty > 0 then
                    rowStr = rowStr .. tostring(empty)
                    empty = 0
                end
                local letter = "p"
                if piece.piece == "rook" then letter = "r"
                elseif piece.piece == "knight" then letter = "n"
                elseif piece.piece == "bishop" then letter = "b"
                elseif piece.piece == "queen" then letter = "q"
                elseif piece.piece == "king" then letter = "k"
                end
                if piece.isWhite then
                    letter = string.upper(letter)
                end
                rowStr = rowStr .. letter
            else
                empty = empty + 1
            end
        end
        if empty > 0 then
            rowStr = rowStr .. tostring(empty)
        end
        table.insert(rows, rowStr)
    end
    local boardKey = table.concat(rows, "/")
    local sideKey = chessGame.currentTurn == "white" and "w" or "b"
    local castlingKey = ""
    if chessGame.castlingRights.white.kingSide then castlingKey = castlingKey .. "K" end
    if chessGame.castlingRights.white.queenSide then castlingKey = castlingKey .. "Q" end
    if chessGame.castlingRights.black.kingSide then castlingKey = castlingKey .. "k" end
    if chessGame.castlingRights.black.queenSide then castlingKey = castlingKey .. "q" end
    if castlingKey == "" then castlingKey = "-" end
    local epKey = "-"
    if chessGame.enPassantTarget then
        epKey = tostring(chessGame.enPassantTarget.row) .. "," .. tostring(chessGame.enPassantTarget.col)
    end
    return boardKey .. " " .. sideKey .. " " .. castlingKey .. " " .. epKey
end

function UpdatePositionHistory()
    local key = GetPositionKey()
    chessGame.positionHistory[key] = (chessGame.positionHistory[key] or 0) + 1
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
                    end
                    
                    -- En passant capture
                    if chessGame.enPassantTarget and
                       chessGame.enPassantTarget.row == captureRow and
                       chessGame.enPassantTarget.col == captureCol then
                        local capturedRow = isWhite and (captureRow + 1) or (captureRow - 1)
                        local capturedPawn = GetPieceAt(capturedRow, captureCol)
                        if capturedPawn and capturedPawn.piece == "pawn" and capturedPawn.isWhite ~= isWhite then
                            table.insert(moves, {toRow = captureRow, toCol = captureCol, enPassant = true})
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
                    else
                        -- Friendly piece blocks this direction
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
        
        -- Castling (only if not attackOnly)
        if not attackOnly then
            local castling = chessGame.castlingRights[isWhite and "white" or "black"]
            local kingPiece = GetPieceAt(row, col)
            
            if kingPiece and not kingPiece.hasMoved and castling then
                -- King side castling (O-O)
                if castling.kingSide then
                    local rook = GetPieceAt(row, 7)
                    if rook and rook.piece == "rook" and rook.isWhite == isWhite and not rook.hasMoved then
                        if not GetPieceAt(row, 5) and not GetPieceAt(row, 6) then
                            if not IsSquareAttacked(row, 4, not isWhite, true, true) and
                               not IsSquareAttacked(row, 5, not isWhite, true, true) and
                               not IsSquareAttacked(row, 6, not isWhite, true, true) then
                                table.insert(moves, {toRow = row, toCol = 6, castling = "kingSide"})
                            end
                        end
                    end
                end
                
                -- Queen side castling (O-O-O)
                if castling.queenSide then
                    local rook = GetPieceAt(row, 0)
                    if rook and rook.piece == "rook" and rook.isWhite == isWhite and not rook.hasMoved then
                        if not GetPieceAt(row, 1) and not GetPieceAt(row, 2) and not GetPieceAt(row, 3) then
                            if not IsSquareAttacked(row, 4, not isWhite, true, true) and
                               not IsSquareAttacked(row, 3, not isWhite, true, true) and
                               not IsSquareAttacked(row, 2, not isWhite, true, true) then
                                table.insert(moves, {toRow = row, toCol = 2, castling = "queenSide"})
                            end
                        end
                    end
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
            -- Skip this move
        elseif not WouldMoveCauseCheck(row, col, move.toRow, move.toCol, move) then
            -- Move is valid - doesn't leave king in check
            table.insert(validMoves, move)
        end
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

function WouldMoveCauseCheck(fromRow, fromCol, toRow, toCol, moveData)
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then return true end  -- No piece to move, invalid
    
    local undo = ApplyMove(fromRow, fromCol, toRow, toCol, moveData, true)
    if not undo then return true end
    
    local wouldBeInCheck = IsInCheck(piece.isWhite, true)
    UndoMove(undo)
    
    return wouldBeInCheck
end

-- Check if a move is valid according to chess rules
-- Returns: true, moveData if valid, false otherwise
function IsValidMove(fromRow, fromCol, toRow, toCol)
    -- Check if source square has a piece
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then 
        return false 
    end
    
    -- Check if it's the correct turn
    if (piece.isWhite and chessGame.currentTurn ~= "white") or (not piece.isWhite and chessGame.currentTurn ~= "black") then
        return false
    end
    
    -- Check if destination square is valid
    if not IsValidSquare(toRow, toCol) then
        return false
    end
    
    -- Check if moving to a friendly piece (not allowed)
    local targetPiece = GetPieceAt(toRow, toCol)
    if targetPiece and targetPiece.isWhite == piece.isWhite then
        return false
    end
    
    -- Get all valid moves for this piece
    local validMoves = GetValidMoves(fromRow, fromCol)
    
    -- Check if the requested move is in the valid moves list
    for _, move in ipairs(validMoves) do
        if move.toRow == toRow and move.toCol == toCol then
            return true, move
        end
    end
    
    -- Move not found in valid moves
    return false
end

local function CopyCastlingRights()
    return {
        white = {
            kingSide = chessGame.castlingRights.white.kingSide,
            queenSide = chessGame.castlingRights.white.queenSide
        },
        black = {
            kingSide = chessGame.castlingRights.black.kingSide,
            queenSide = chessGame.castlingRights.black.queenSide
        }
    }
end

function ApplyMove(fromRow, fromCol, toRow, toCol, moveData, simulate)
    moveData = moveData or {}
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then return nil end
    
    local undo = {
        fromRow = fromRow,
        fromCol = fromCol,
        toRow = toRow,
        toCol = toCol,
        capturedPiece = GetPieceAt(toRow, toCol),
        enPassantCaptured = nil,
        prevEnPassantTarget = chessGame.enPassantTarget,
        prevCastlingRights = CopyCastlingRights(),
        prevHalfmoveClock = chessGame.halfmoveClock,
        prevFullmoveNumber = chessGame.fullmoveNumber,
        prevLastMove = chessGame.lastMove,
        prevWhiteKingPos = {row = chessGame.whiteKingPos.row, col = chessGame.whiteKingPos.col},
        prevBlackKingPos = {row = chessGame.blackKingPos.row, col = chessGame.blackKingPos.col},
        prevTurn = chessGame.currentTurn,
        prevPieceType = piece.piece,
        prevPieceHasMoved = piece.hasMoved,
        rookUndo = nil,
    }
    
    -- En passant capture
    if moveData.enPassant then
        local capturedRow = piece.isWhite and (toRow + 1) or (toRow - 1)
        undo.enPassantCaptured = GetPieceAt(capturedRow, toCol)
        chessGame.board[capturedRow][toCol] = nil
    end
    
    -- Castling rook move
    if moveData.castling then
        local rookFromCol = moveData.castling == "kingSide" and 7 or 0
        local rookToCol = moveData.castling == "kingSide" and 5 or 3
        local rook = GetPieceAt(fromRow, rookFromCol)
        if rook then
            undo.rookUndo = {
                rook = rook,
                fromCol = rookFromCol,
                toCol = rookToCol,
                prevHasMoved = rook.hasMoved
            }
            chessGame.board[fromRow][rookFromCol] = nil
            chessGame.board[fromRow][rookToCol] = rook
            rook.hasMoved = true
        end
    end
    
    local wasPawnMove = piece.piece == "pawn"
    
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
    
    -- Handle promotion (for simulation)
    if moveData.promotion then
        piece.piece = moveData.promotion
        piece.needsPromotion = nil
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
        local homeRow = piece.isWhite and 7 or 0
        if fromRow == homeRow then
            if fromCol == 0 then
                chessGame.castlingRights[piece.isWhite and "white" or "black"].queenSide = false
            elseif fromCol == 7 then
                chessGame.castlingRights[piece.isWhite and "white" or "black"].kingSide = false
            end
        end
    end
    if undo.capturedPiece and undo.capturedPiece.piece == "rook" then
        local homeRow = undo.capturedPiece.isWhite and 7 or 0
        if toRow == homeRow then
            if toCol == 0 then
                chessGame.castlingRights[undo.capturedPiece.isWhite and "white" or "black"].queenSide = false
            elseif toCol == 7 then
                chessGame.castlingRights[undo.capturedPiece.isWhite and "white" or "black"].kingSide = false
            end
        end
    end
    
    -- Update halfmove clock
    if wasPawnMove or undo.capturedPiece or undo.enPassantCaptured then
        chessGame.halfmoveClock = 0
    else
        chessGame.halfmoveClock = chessGame.halfmoveClock + 1
    end
    
    -- Update fullmove number
    if chessGame.currentTurn == "black" then
        chessGame.fullmoveNumber = chessGame.fullmoveNumber + 1
    end
    
    -- Update turn
    chessGame.currentTurn = chessGame.currentTurn == "white" and "black" or "white"
    
    -- Store last move
    chessGame.lastMove = {fromRow = fromRow, fromCol = fromCol, toRow = toRow, toCol = toCol, piece = piece.piece, isWhite = piece.isWhite, moveData = moveData}
    
    return undo
end

function UndoMove(undo)
    if not undo then return end
    
    local piece = GetPieceAt(undo.toRow, undo.toCol)
    if piece then
        piece.piece = undo.prevPieceType
        piece.hasMoved = undo.prevPieceHasMoved
    end
    
    chessGame.board[undo.fromRow][undo.fromCol] = piece
    chessGame.board[undo.toRow][undo.toCol] = undo.capturedPiece
    
    if undo.enPassantCaptured then
        local capturedRow = piece.isWhite and (undo.toRow + 1) or (undo.toRow - 1)
        chessGame.board[capturedRow][undo.toCol] = undo.enPassantCaptured
    end
    
    if undo.rookUndo then
        chessGame.board[undo.fromRow][undo.rookUndo.toCol] = nil
        chessGame.board[undo.fromRow][undo.rookUndo.fromCol] = undo.rookUndo.rook
        undo.rookUndo.rook.hasMoved = undo.rookUndo.prevHasMoved
    end
    
    chessGame.enPassantTarget = undo.prevEnPassantTarget
    chessGame.castlingRights = undo.prevCastlingRights
    chessGame.halfmoveClock = undo.prevHalfmoveClock
    chessGame.fullmoveNumber = undo.prevFullmoveNumber
    chessGame.lastMove = undo.prevLastMove
    chessGame.whiteKingPos = undo.prevWhiteKingPos
    chessGame.blackKingPos = undo.prevBlackKingPos
    chessGame.currentTurn = undo.prevTurn
end

-- Execute a move on the board (real move)
function ExecuteMove(fromRow, fromCol, toRow, toCol, moveData)
    moveData = moveData or {}
    local piece = GetPieceAt(fromRow, fromCol)
    if not piece then return false end
    
    local undo = ApplyMove(fromRow, fromCol, toRow, toCol, moveData, false)
    if not undo then return false end
    
    -- Handle pawn promotion (set flag for table module to handle entity update)
    local pendingPromotion = false
    if piece.piece == "pawn" and (toRow == 0 or toRow == 7) and not moveData.promotion then
        piece.needsPromotion = true
        chessGame.awaitingPromotion = true
        pendingPromotion = true
    end
    
    if not pendingPromotion then
        UpdatePositionHistory()
    end
    
    return true
end

-- Update game state (check, checkmate, stalemate)
function UpdateGameState()
    if not tableEntity or not tableEntity.whitePieces or not tableEntity.blackPieces then 
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
        SyncBoardWithPieces()
    end
    
    local currentPlayerIsWhite = chessGame.currentTurn == "white"
    local inCheck = IsInCheck(currentPlayerIsWhite)
    local allMoves = GetAllValidMoves(currentPlayerIsWhite)
    local hasValidMoves = #allMoves > 0
    local drawReason = nil
    
    if not hasValidMoves then
        if inCheck then
            chessGame.gameState = "checkmate"
            chessGame.drawReason = nil
        else
            chessGame.gameState = "stalemate"
            chessGame.drawReason = "stalemate"
        end
    elseif inCheck then
        chessGame.gameState = "check"
        chessGame.drawReason = nil
    else
        chessGame.gameState = "playing"
        chessGame.drawReason = nil
    end
    
    if chessGame.gameState ~= "checkmate" then
        if chessGame.halfmoveClock >= 100 then
            drawReason = "50-move"
        elseif IsThreefoldRepetition() then
            drawReason = "threefold"
        elseif IsInsufficientMaterial() then
            drawReason = "insufficient"
        end
        if drawReason then
            chessGame.gameState = "draw"
            chessGame.drawReason = drawReason
        end
    end
end

function IsThreefoldRepetition()
    local key = GetPositionKey()
    return (chessGame.positionHistory[key] or 0) >= 3
end

function IsInsufficientMaterial()
    local totalMinor = 0
    local bishops = {}
    for row = 0, 7 do
        for col = 0, 7 do
            local piece = GetPieceAt(row, col)
            if piece then
                if piece.piece == "pawn" or piece.piece == "rook" or piece.piece == "queen" then
                    return false
                end
                if piece.piece == "bishop" or piece.piece == "knight" then
                    totalMinor = totalMinor + 1
                    if piece.piece == "bishop" then
                        table.insert(bishops, (row + col) % 2)
                    end
                end
            end
        end
    end
    if totalMinor == 0 then
        return true -- K vs K
    end
    if totalMinor == 1 then
        return true -- K+N vs K or K+B vs K
    end
    if #bishops > 0 and totalMinor == #bishops then
        -- Only bishops remain; draw if all bishops on same color
        local color = bishops[1]
        for i = 2, #bishops do
            if bishops[i] ~= color then
                return false
            end
        end
        return true
    end
    return false
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
                    local moveData = {}
                    for k, v in pairs(move) do
                        moveData[k] = v
                    end
                    if piece.piece == "pawn" and (move.toRow == 0 or move.toRow == 7) then
                        moveData.promotion = "queen"
                    end
                    table.insert(allMoves, {fromRow = row, fromCol = col, toRow = move.toRow, toCol = move.toCol, moveData = moveData})
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
        for i, move in ipairs(allMoves) do
            -- Yield every 10 moves to prevent freezing (only in CPU thread)
            if i % 10 == 0 then Wait(0) end
            
            local undo = ApplyMove(move.fromRow, move.fromCol, move.toRow, move.toCol, move.moveData, true)
            local eval = Minimax(depth - 1, false, alpha, beta)
            UndoMove(undo)
            
            maxEval = math.max(maxEval, eval)
            alpha = math.max(alpha, eval)
            if beta <= alpha then break end
        end
        return maxEval
    else
        local minEval = 99999
        for i, move in ipairs(allMoves) do
            -- Yield every 10 moves to prevent freezing (only in CPU thread)
            if i % 10 == 0 then Wait(0) end
            
            local undo = ApplyMove(move.fromRow, move.fromCol, move.toRow, move.toCol, move.moveData, true)
            local eval = Minimax(depth - 1, true, alpha, beta)
            UndoMove(undo)
            
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
    
    for i, move in ipairs(allMoves) do
        -- Yield every 5 moves to prevent freezing (only in CPU thread)
        if i % 5 == 0 then Wait(0) end
        
        local undo = ApplyMove(move.fromRow, move.fromCol, move.toRow, move.toCol, move.moveData, true)
        local eval = Minimax(depth - 1, true, -99999, 99999)
        UndoMove(undo)
        
        if eval < bestEval then
            bestEval = eval
            bestMove = move
        end
    end
    
    return bestMove
end

function GetCPUMove()
    -- Check if CPU is in check - if so, we MUST get out of check
    local cpuInCheck = IsInCheck(false, false) -- CPU is black (false)
    
    local difficulty = Config.Chess and Config.Chess.CPU_Difficulty or "medium"
    local depth = 1
    if difficulty == "easy" then depth = 1
    elseif difficulty == "medium" then depth = 2
    elseif difficulty == "hard" then depth = 3
    end
    
    local move = nil
    if cpuInCheck then
        -- When in check, prioritize moves that get out of check
        -- Get all valid moves (these should already filter out moves that leave king in check)
        local allMoves = GetAllValidMoves(false) -- CPU is black
        
        if #allMoves == 0 then
            return nil
        end
        
        -- Filter to only moves that get out of check
        local movesOutOfCheck = {}
        for i, m in ipairs(allMoves) do
            -- Yield every 20 moves to prevent freezing (only in CPU thread)
            if i % 20 == 0 then Wait(0) end
            
            local undo = ApplyMove(m.fromRow, m.fromCol, m.toRow, m.toCol, m.moveData, true)
            local stillInCheck = IsInCheckPseudo(false, true)
            UndoMove(undo)
            
            if not stillInCheck then
                table.insert(movesOutOfCheck, m)
            end
        end
        
        if #movesOutOfCheck > 0 then
            -- Use best move from moves that get out of check
            local bestMove = nil
            local bestEval = 99999
            for i, m in ipairs(movesOutOfCheck) do
                -- Yield every 5 moves to prevent freezing (only in CPU thread)
                if i % 5 == 0 then Wait(0) end
                
                local undo = ApplyMove(m.fromRow, m.fromCol, m.toRow, m.toCol, m.moveData, true)
                local eval = Minimax(depth - 1, true, -99999, 99999)
                UndoMove(undo)
                
                if eval < bestEval then
                    bestEval = eval
                    bestMove = m
                end
            end
            move = bestMove
        else
            -- No moves get out of check - checkmate
            return nil
        end
    else
        -- Not in check, use normal move selection
        move = GetBestCPUMove(depth)
        if not move then
            move = GetRandomCPUMove()
        end
    end
    
    if move then
        -- Validate move: ensure it's not moving to a friendly piece
        local piece = GetPieceAt(move.fromRow, move.fromCol)
        local targetPiece = GetPieceAt(move.toRow, move.toCol)
        
        if piece and targetPiece and targetPiece.isWhite == piece.isWhite then
            -- Try to get a different move
            local allMoves = GetAllValidMoves(false) -- CPU is black
            local validMoves = {}
            for i, m in ipairs(allMoves) do
                -- Yield every 20 moves to prevent freezing (only in CPU thread)
                if i % 20 == 0 then Wait(0) end
                
                local target = GetPieceAt(m.toRow, m.toCol)
                if not target or target.isWhite ~= false then -- Only moves to empty squares or opponent pieces
                    table.insert(validMoves, m)
                end
            end
            if #validMoves > 0 then
                move = validMoves[math.random(#validMoves)]
            else
                return nil
            end
        end
        
        local moveData = move.moveData or {}
        
        return {
            fromRow = move.fromRow,
            fromCol = move.fromCol,
            toRow = move.toRow,
            toCol = move.toCol,
            moveData = moveData
        }
    end
    
    return nil
end
