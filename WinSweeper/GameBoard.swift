import Foundation
import GameplayKit

class GameBoard: TileContext {
    
    weak var delegate: GameBoardDelegate?
    
    enum State {
        case Waiting, GameOver, Win, Playing
    }
    
    var state = State.Waiting
    var seconds: Int = 0
    let nbMines = 50
    var tiles: [Tile] = []
    var halfPairs: Set<Pair<Tile>> = []
    var seed: UInt64 = 0
    private let width: Int
    private let height: Int
    private var undoStack: [([Tile], Set<Pair<Tile>>, GKMersenneTwisterRandomSource)] = []
    private var redoStack: [([Tile], Set<Pair<Tile>>, GKMersenneTwisterRandomSource)] = []
    private var generator = GKMersenneTwisterRandomSource(seed: 0)
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        tiles = (0..<nbTiles()).map { Tile(ctx: self, idx: $0) }
    }
    
    func initBoard(seed newSeed: UInt64, _ idx: Int) {
        seed = newSeed
        print("seed: \(seed) idx: \(idx)")
        generator = GKMersenneTwisterRandomSource(seed: seed)
        for _ in 0..<nbMines {
            var position: Int
            repeat {
                position = generator.nextInt(upperBound: nbTiles())
            } while around(is: position, around: idx) || isMine(position)
            tiles[position].isMine = true
        }
    }
    
    func copy() -> GameBoard {
        let gb = GameBoard(width: width, height: height)
        gb.seed = seed
        gb.tiles = tiles.map { $0.copy(ctx: gb) }
        gb.halfPairs = copyHalfPairs(gb.tiles, halfPairs)
        return gb
    }
    
    private func copyHalfPairs(_ tiles: [Tile], _ halfPairs: Set<Pair<Tile>>) -> Set<Pair<Tile>> {
        Set(halfPairs.map { Pair(a: tiles[$0.a.idx()], b: tiles[$0.b.idx()]) })
    }
    
    func tick() -> Int {
        seconds += 1
        return seconds
    }
    
    func handleRightClick(at idx: Int) {
        if state == .Playing {
            let tile = tiles[idx]
            guard tile.IsUndiscovered() else { return }
            toggleFlag(tiles[idx])
            delegate?.gameBoardDidUpdate()
        }
    }
    
    private func showMines(deadIdx: Int? = nil) {
        for tile in tiles {
            let tileIdx = tile.idx()
            if tile.idx() == deadIdx {
                tile.state = .ExplodedMine
            } else if isMine(tileIdx) && isFlag(tileIdx) {
                tile.state = .FlaggedMine
            } else if isFlag(tileIdx) {
                tile.state = .BadFlag
            } else if isMine(tileIdx) {
                tile.state = .Mine
            }
        }
    }
    
    private func gameOver(_ tile: Tile) {
        state = .GameOver
        showMines(deadIdx: tile.idx());
    }
    
    private func checkGameOver(_ tilesToShow: [Tile]) -> Bool {
        if let tile = tilesToShow.first(where: { $0.state == .Empty && $0.isMine }) {
            gameOver(tile)
            return true
        }
        return false
    }
    
    private func blessing(_ tile: Tile) {
        saveState()
        // No blessing if there was a 50/50 and you didn't click one
        guard halfPairs.isEmpty || tile.getProb() == 0.5 else { return }
        if let pair = halfPairs.first(tile) {
            if swapMines(pair: pair) || handleSquareCase() {
                return
            }
        }
        if !rebalance(tile) {
            fatalError("failed to rebalance")
        }
    }
    
    // Handle the case where only two mines are remaining and 4 unknown tiles in a 2x2 shape
    private func handleSquareCase() -> Bool {
        if countUnknownMines() == 2 {
            let ut = unknownTiles()
            // 4 tiles in a 2x2 square with 2 mines, swap mines location
            if isSquare(tiles: ut) {
                ut.toggleMines()
                return true
            }
        }
        return false
    }
    
    private func swapMines(pair: Pair<Tile>) -> Bool {
        // Swap mines if the board stays valid
        pair.toggleMines()
        if isValid() {
            return true
        }
        // Otherwise, revert the change
        pair.toggleMines()
        return false
    }
    
    func isSquare(tiles: [Tile]) -> Bool {
        guard tiles.count == 4 else { return false }
        let tiles = tiles.sorted()
        return tiles[0].idx()+1     == tiles[1].idx() &&
               tiles[2].idx()+1     == tiles[3].idx() &&
               tiles[0].idx()+width == tiles[2].idx()
    }
    
    func handleLeftClick(at idx: Int) {
        let tile = tiles[idx]
        if state == .Waiting {
            let seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)
            initBoard(seed: seed, tile.idx())
            state = .Playing
            delegate?.gameBoardGameStarted()
        }
        
        if state == .Playing {
            // Game will make the odds works for you if there is no more safe square to click
            if tile.isMine &&               // cliked a mine
                !tile.IsProbMine() &&       // that is not `known`
                knownSafeTiles().count == 0 // and there is no safe tile remaining
            {
                blessing(tile)
            }
            var tilesToShow = [tile]
            if tile.IsDiscovered() && countFlags(around: tile) == countMines(around: tile) {
                tilesToShow.append(contentsOf: tile.neighbors())
            }
            if !checkGameOver(tilesToShow) {
                showTiles(tilesToShow)
                if didWin() {
                    state = .Win
                    showMines()
                }
            }
        } else if state == .GameOver || state == .Win {
            reset()
            state = .Waiting
            delegate?.gameBoardGameReset()
        }
        
        if state == .GameOver || state == .Win {
            delegate?.gameBoardGameEnded()
        }
        delegate?.gameBoardDidUpdate()
    }
    
    private func toggleFlag(_ tile: Tile) {
        guard state == .Playing else { return }
        tile.state = tile.state == .Empty ? .Flagged : .Empty
    }
    
    private func nbTiles() -> Int { width * height }
    
    private func indicesInRange(idx: Int, range: Int) -> [Int] {
        indicesInRangeUtils(idx: idx, range: range, width: width, height: height)
    }
    
    private func tilesInRange(for tile: Tile, range: Int) -> [Tile] {
        tilesFromIndices(indicesInRange(idx: tile.idx(), range: range))
    }
    
    private func neighborIndices(of idx: Int) -> [Int] { indicesInRange(idx: idx, range: 1) }
    
    func neighbors(of tile: Tile) -> [Tile] {
        tilesInRange(for: tile, range: 1)
    }
    
    func extendedNeighbors(of tile: Tile) -> [Tile] {
        tilesInRange(for: tile, range: 2)
    }
    
    func knownMines(of tile: Tile) -> [Tile] {
        knownMinesAround(for: tile)
    }
    
    func knownSafe(of tile: Tile) -> [Tile] {
        knownSafeAround(for: tile)
    }
    
    func unknownTiles(of tile: Tile) -> [Tile] {
        getUnknownTiles(for: tile)
    }
    
    func unknownMines(of tile: Tile) -> Int {
        countUnknownMines(for: tile)
    }
    
    func isNeighbor(is a: Int, of b: Int) -> Bool { neighborIndices(of: b).contains(a) }
    
    // Return true if `a` is `b` or a neighbor of it
    func around(is a: Int, around b: Int) -> Bool {
        return isNeighbor(is: a, of: b) || a == b
    }
    
    // Verify that the discovered tiles have the right amount of mines around them
    func isValid() -> Bool {
        discoveredTiles().allSatisfy { isValid(tile: $0) }
    }
    
    private func minedNeighbors(of tile: Tile) -> [Tile] {
        tile.neighbors().filter { $0.isMine }
    }
    
    // Verify that the tile has the right amount of mines around it
    private func isValid(tile: Tile) -> Bool {
        minedNeighbors(of: tile).count == tile.minesAround
    }
    
    private func isTilePartialValid(tile: Tile) -> Bool {
        minedNeighbors(of: tile).count <= tile.minesAround
    }
    
    // Verify that the probs are valid for all discovered tiles
    func isProbValid() -> Bool {
        discoveredTiles().allSatisfy { isProbValid(tile: $0) }
    }
    
    // Verify that the probs are valid for a given tile
    private func isProbValid(tile: Tile) -> Bool {
        let (knownMines, unknown) = countMinesNUnknown(tiles: tile.neighbors())
        return knownMines <= tile.minesAround && unknown + knownMines >= tile.minesAround
    }
    
    func getAllUnknownTilesMines() -> (Int, Int) {
        let (knownMines, unknownTiles) = countMinesNUnknown(tiles: tiles)
        return (unknownTiles, nbMines - knownMines)
    }
    
    // Count all `known mines` and `unknown tiles` in one go
    private func countMinesNUnknown(tiles: [Tile]) -> (Int, Int) {
        tiles.reduce((0, 0)) { counts, tile in
            var (knownMines, unknownTiles) = counts
            if tile.IsUnknown() {
                unknownTiles += 1
            } else if isKnownMine(tile) {
                knownMines += 1
            }
            return (knownMines, unknownTiles)
        }
    }
    
    func knownMinesAround(for tile: Tile) -> Int {
        knownMinesAround(for: tile).count
    }

    func knownSafeAround(for tile: Tile) -> Int {
        knownSafeAround(for: tile).count
    }
    
    func isKnownSafe(_ tile: Tile) -> Bool { tile.IsUndiscovered() && tile.IsProbNoMine() }
    func isKnownMine(_ tile: Tile) -> Bool { tile.IsUndiscovered() && tile.IsProbMine() }
    func isUnknown  (_ tile: Tile) -> Bool { tile.IsUndiscovered() && tile.IsUnknown() }
    
    func knownSafeTiles() -> [Tile] {
        tiles.filter { isKnownSafe($0) }
    }
    
    func knownSafeAround(for tile: Tile) -> [Tile] {
        tile.neighbors().filter { isKnownSafe($0) }
    }
    
    func knownMinesAround(for tile: Tile) -> [Tile] {
        tile.neighbors().filter { isKnownMine($0) }
    }
    
    func getUnknownTiles(for tile: Tile) -> [Tile] {
        tile.neighbors().filter { isUnknown($0) }
    }
    
    func countUnknownMines(for tile: Tile) -> Int {
        tile.minesAround - knownMinesAround(for: tile)
    }
    
    func unknownTiles() -> [Tile] {
        tiles.filter { $0.IsUnknown() }
    }
    
    func discoveredTiles() -> [Tile] {
        tiles.filter { $0.IsDiscovered() }
    }
    
    func serialize() -> String {
        tiles.map {
            $0.isMine ? "*" : ($0.state != .Discovered ? "@" : "\($0.minesAround)")
        }.joined()
    }
    
    func load(_ ser: String) {
        tiles.forEach { $0.reset() }
        for (i, c) in ser.enumerated() {
            if c == "*" {
                tiles[i].isMine = true
            } else if let n = Int(String(c)) {
                tiles[i].discover(n)
            }
        }
    }
    
    func tilesFromIndices<T: Sequence>(_ iterable: T) -> [Tile] where T.Element == Int {
        iterable.map { tiles[$0] }
    }
    
    func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
        halfPairs.removeAll()
        tiles.forEach { $0.reset() }
        seconds = 0
        state = .Waiting
        delegate?.gameBoardGameReset()
        delegate?.gameBoardDidUpdate()
    }
    
    // Return how many mines remain to be known, based on probabilities
    func countUnknownMines() -> Int {
        return nbMines - countKnownMines()
    }
    
    // Count mines that we know based on probabilities
    func countKnownMines() -> Int {
        knownMines().count
    }
    
    func knownMines() -> [Tile] {
        tiles.filter { $0.IsProbMine() }
    }
    
    func countFlags() -> Int {
        tiles.filter { $0.isFlagged() }.count
    }
    
    func isMine(_ idx: Int) -> Bool { tiles[idx].isMine }
    func isFlag(_ idx: Int) -> Bool { tiles[idx].state == .Flagged }
    func countMines() -> Int { tiles.filter { $0.isMine }.count }
    func countMines(around tile: Tile) -> Int { countAround(tile.idx(), isMine) }
    func countFlags(around tile: Tile) -> Int { countAround(tile.idx(), isFlag) }
    func countAround(_ idx: Int, _ clb: (Int) -> Bool) -> Int {
        neighborIndices(of: idx).reduce(0) { $0 + (clb($1) ? 1 : 0) }
    }
    
    private func showTile(_ tile: Tile) {
        guard tile.state == .Empty else { return }
        let nbMinesAround = countMines(around: tile)
        tile.discover(nbMinesAround)
        if nbMinesAround == 0 {
            tile.neighbors().forEach { showTile($0) }
        }
    }
    
    func showTiles(_ tiles: [Tile]) {
        let tiles = tiles.filter { $0.IsUndiscovered() && !$0.isFlagged() }
        guard !tiles.isEmpty else { return }
        saveState()
        tiles.forEach { showTile($0) }
        try! calcProb(gameBoard: self)
    }
    
    func showTiles(_ indices: [Int]) {
        showTiles(tilesFromIndices(indices))
    }
    
    func showSafeTiles() {
        guard state == .Playing else { return }
        showTiles(knownSafeTiles())
        delegate?.gameBoardDidUpdate()
    }
    
    private func didWin() -> Bool {
        discoveredTiles().count == tiles.count - nbMines
    }
    
    func flagKnownMines() {
        guard state == .Playing else { return }
        knownMines().forEach { $0.state = .Flagged }
        delegate?.gameBoardDidUpdate()
    }
    
    func coord(of tile: Tile) -> (Int, Int) {
        coordFromIdx(tile.idx())
    }
    
    private func coordFromIdx(_ idx: Int) -> (Int, Int) {
        coordFromIdxUtils(idx, width: width)
    }
    
    private func saveState() {
        undoStack.append(createState())
        redoStack.removeAll()
    }
    
    private func createState() -> ([Tile], Set<Pair<Tile>>, GKMersenneTwisterRandomSource) {
        let newTiles = tiles.map { $0.copy(ctx: self) }
        let newHalfPairs = copyHalfPairs(newTiles, halfPairs)
        return (newTiles, newHalfPairs, generator.copy() as! GKMersenneTwisterRandomSource)
    }
    
    func undo() {
        guard state == .Playing else { return }
        guard let (newTiles, newPairs, gen) = undoStack.popLast() else { return }
        redoStack.append(createState())
        tiles = newTiles
        halfPairs = newPairs
        generator = gen
    }
    
    func redo() {
        guard state == .Playing else { return }
        guard let (newTiles, newPairs, gen) = redoStack.popLast() else { return }
        undoStack.append(createState())
        tiles = newTiles
        halfPairs = newPairs
        generator = gen
    }
    
    private func createGroups(_ tiles: [Tile]) -> [[Tile]] {
        var remainingTiles = tiles
        var groups: [[Tile]] = []
        while !remainingTiles.isEmpty {
            let first = remainingTiles.removeFirst()
            var group = [first]
            remainingTiles = remainingTiles.sorted {
                let a = manhattanDistance(from: first, to: $0)
                let b = manhattanDistance(from: first, to: $1)
                return a < b
            }
            var i = 0
            while i < remainingTiles.count {
                let tile = remainingTiles[i]
                if group.contains(where: { chebyshevDistance(from: tile, to: $0) <= 2 }) {
                    group.append(tile)
                    remainingTiles.remove(at: i)
                    i = 0
                } else {
                    i += 1
                }
            }
            groups.append(group)
        }
        return groups
    }
    
    // Validate that all discovered tiles next to the group are valid (mines count)
    private func validateGroup(_ group: [Tile]) -> Bool {
        group.flatMap { $0.neighborsDiscovered() }.allSatisfy { isValid(tile: $0) }
    }
    
    func rebalance(_ tile: Tile) -> Bool {
        let startTime = Date()
        
        var eligibleTiles = eligibleTilesForRebalance(tile)

        if let otherTile = halfPairs.firstComplement(of: tile) {
            otherTile.isMine = true
            eligibleTiles.remove(otherTile)
            try! otherTile.SetProbMine()
            
        } else if let otherTile = tile.unknownNeighbors().first(where: { !$0.isMine && $0.isFound() }) {
            otherTile.isMine = true
            eligibleTiles.remove(otherTile)
        } else {
            tiles.first { !$0.isMine && $0.isUnfound() }?.isMine.toggle()
        }
        
        tile.isMine = false
        try! tile.SetProbNoMine()
        
        // Recalculare the probs after adding the "no-mine" prob for the tile we clicked
        // We might discover new safe tiles, and won't need to find their values in the depth-first algo below
        try! calcProb(gameBoard: self, recurs: true)
        
        tiles.filter { $0.IsKnown() }.forEach { $0.isMine = $0.IsProbMine() }
        eligibleTiles.removeAll(where: { $0.IsKnown() })
        
        let groups = createGroups(eligibleTiles)
        
        for group in groups where !validateGroup(group) {
            if !rebalanceHelper(eligibleTiles: group, group, group.mineMap()) {
                return false
            }
        }
        
        let minesDelta = countMines() - nbMines
        for _ in 0..<abs(minesDelta) {
            let eligibleTiles = tiles.filter { $0.isUnfound() && $0.isMine == (minesDelta > 0) }
            if !eligibleTiles.isEmpty {
                let position = generator.nextInt(upperBound: eligibleTiles.count)
                eligibleTiles[position].isMine.toggle()
            } else if minesDelta > 0 ? tryMergeMines() : trySplitMine() {
                continue
            } else {
                print("failed to add/remove mine")
                return false
            }
        }
        
        let timeInterval = Date().timeIntervalSince(startTime)
        print("Rebalance took: \(String(format: "%.3f", timeInterval)) seconds")
        return true
    }
    
    private func rebalanceHelper(eligibleTiles: [Tile], _ origin: [Tile], _ originalMinesMap: [Int: Bool]) -> Bool {
        if eligibleTiles.isEmpty {
            return validateGroup(origin)
        }
        
        // Test the path created so far with the remaining tiles in their original state
        eligibleTiles.forEach { $0.isMine = originalMinesMap[$0.idx()]! }
        if validateGroup(origin) {
            return true
        }
        eligibleTiles.forEach { $0.isMine = false }
        
        var eligibleTiles = eligibleTiles
        let tile = eligibleTiles.removeFirst()
        for isMine in [true, false] {
             tile.isMine = isMine
             if tile.neighborsDiscovered().allSatisfy({ isTilePartialValid(tile: $0) }) &&
                 rebalanceHelper(eligibleTiles: eligibleTiles, origin, originalMinesMap) {
                 return true
             }
         }
         return false
    }
    
    private func tryMergeOrSplitMines(isMerging: Bool) -> Bool {
        let intersectingPairs = findIntersectingPairs(halfPairs)
        for (pair1, pair2) in intersectingPairs {
            let tiles = [pair1, pair2].tiles()
            let mineTiles = tiles.filter { $0.isMine }
            let minesCount = mineTiles.count
            let targetCount = isMerging ? 2 : 1
            if minesCount == targetCount {
                mineTiles.forEach { $0.isMine.toggle() }
                let tile = commonElement(in: pair1, and: pair2)!
                if isMerging {
                    tile.isMine.toggle()
                } else {
                    tiles.subtracting([tile]).toggleMines()
                }
                return true
            }
        }
        return false
    }

    private func tryMergeMines() -> Bool {
        return tryMergeOrSplitMines(isMerging: true)
    }

    private func trySplitMine() -> Bool {
        return tryMergeOrSplitMines(isMerging: false)
    }
}

func eligibleTilesForRebalance(_ tile: Tile) -> [Tile] {
    var seen: Set<Tile> = []
    
    func helper(_ tile: Tile) -> [Tile] {
        // Avoid reprocessing the same tile
        guard seen.insert(tile).inserted else { return [] }
        // Start with the current tile if it meets eligibility criteria
        var res: [Tile] = []
        if tile.isFound() {
            res.append(tile)
        }
        // Recurse for eligible neighbors
        let neighbors = tile.extendedNeighbors().filter { $0.isFound() }.sorted {
            let distanceA = manhattanDistance(from: $0, to: tile)
            let distanceB = manhattanDistance(from: $1, to: tile)
            return (distanceA, $0) < (distanceB, $1)
        }
        for neighbor in neighbors {
            res.append(contentsOf: helper(neighbor))
        }
        return res
    }

    return helper(tile)
}
