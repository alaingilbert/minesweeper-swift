import Foundation

class AutoPlayer {
    private weak var gameBoard: GameBoard?
    private weak var gameView: GameView?
    private var isPlaying = false
    private let delay = 0.01
    private let moveCursorDuration = 0.25
    
    init(gameBoard: GameBoard, gameView: GameView) {
        self.gameBoard = gameBoard
        self.gameView = gameView
    }
    
    func toggle() {
        isPlaying.toggle()
        if isPlaying {
            gameView?.showCursor()
            self.startRound()
        } else {
            gameView?.hideCursor()
        }
    }
    
    private func startRound() {
        guard let gameBoard = gameBoard else { return }
        guard isPlaying else { return }
        flagMinesRecursively(gameBoard.knownMines(), nil)
    }
    
    private func flagMinesRecursively(_ tiles: [Tile], _ prevTile: Tile?) {
        guard isPlaying else { return }
        guard !tiles.isEmpty else {
            revealSafeTiles(prevTile)
            return
        }
        var remainingTiles = tiles
        let tile = remainingTiles.removeFirst()
        if tile.isFlagged() {
            self.flagMinesRecursively(remainingTiles, prevTile)
            return
        }
        print("AUTOPLAY: flag \(tile.idx())")
        moveAndClick(on: tile.idx(), right: true, clb: {
            self.flagMinesRecursively(remainingTiles, prevTile)
        })
    }
    
    private func revealSafeTiles(_ prevTile: Tile?) {
        guard let gameBoard = gameBoard else { return }
        var tiles = gameBoard.knownSafeTiles()
        if let prevTile = prevTile {
            tiles.sort {
                manhattanDistance(from: $0, to: prevTile) <
                manhattanDistance(from: $1, to: prevTile)
            }
        }
        if var nextTile = tiles.first {
            let multi = nextTile.extendedNeighbors()
                .filter { $0.IsDiscovered() }
                .sorted(by: { $0.knownSafe().count > $1.knownSafe().count })
                .filter { $0.knownSafe().count >= 2 }
                .filter { gameBoard.countFlags(around: $0) == $0.minesAround }
            if let tile = multi.first {
                nextTile = tile
            }
            print("AUTOPLAY: click on \(nextTile.idx())")
            moveAndClick(on: nextTile.idx(), clb: {
                self.flagMinesRecursively(gameBoard.knownMines(), nextTile)
            })
        } else {
            var nextTile: Tile?
            if let tile = gameBoard.halfPairs.first?.a {
                nextTile = tile
                print("AUTOPLAY: take 50/50 on \(tile.idx())")
            } else if let tile = gameBoard.tiles.first(where: { $0.isFound() }) {
                nextTile = tile
                print("AUTOPLAY: take guess on \(tile.idx())")
            } else if let tile = gameBoard.tiles.first(where: { $0.isUnfound() }) {
                nextTile = tile
                print("AUTOPLAY: take guess on unfound tile \(tile.idx())")
            } else {
                print("AUTOPLAY: noting to click on")
                isPlaying = false
                gameView?.hideCursor()
                return
            }
            if let nextTile = nextTile {
                moveAndClick(on: nextTile.idx(), clb: {
                    self.flagMinesRecursively(gameBoard.knownMines(), nextTile)
                })
            }
        }
    }
    
    private func moveAndClick(on idx: Int, right: Bool = false, clb: @escaping () -> Void = {}) {
        gameView?.moveCursor(to: gameView!.pointFromIdx(idx), duration: moveCursorDuration, completion: {
            self.gameView?.clickAnim(at: idx, rightClick: right)
            if right {
                self.gameBoard?.handleRightClick(at: idx)
            } else {
                self.gameBoard?.handleLeftClick(at: idx)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                clb()
            }
        })
    }
    
}
