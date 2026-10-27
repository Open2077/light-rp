LightRpBoardGames = {
    chess = { item = "chess_board", label = "Chess Board", size = 8 },
    checkers = { item = "checkers_board", label = "Checkers Board", size = 10 },
    connect4 = { item = "connect4_board", label = "Connect Four Board", size = 7 },
}
for _, spec in pairs(LightRpBoardGames) do
    LightRpItems[spec.item] = { label = spec.label, description = "Use to place the board. E: play; use the target menu to pick up your board.", weight = 1.5, stack = 1, icon = "grid-3x3", category = "misc" }
end
