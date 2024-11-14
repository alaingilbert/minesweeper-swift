//
//  GameView.swift
//  Minesweeper
//
//  Created by Alain Gilbert on 3/10/18.
//  Copyright © 2018 None. All rights reserved.
//

import Foundation
import AppKit
import GameplayKit

@IBDesignable
class GameView : NSView {
    
    enum State {
        case Waiting, GameOver, Win, Playing
    }
    
    var flagsLbL = NSTextField()
    var timerLbl = NSTextField()
    
    var timer = Timer()
    var seconds = 0
    var flags = 0
    let tileSize = 40
    let nbMines = 50
    let nbHorizontalTiles = 19
    let nbVerticalTiles = 13
    var state = State.Waiting
    var tiles: [Tile] = []
    var safe: Int = 0
    var debugMines = true
    var dbgIdx = false
    var dbgProb = true
    var halfPairs: Set<[Int]> = []
    var knownSafeCount = 0
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        tiles = (0..<nbTiles()).map { idx in
            let (x, y) = coordFromIdx(idx)
            return Tile(idx: idx, x: x, y: y, size: tileSize)
        }
    }
    
    func horizontalSize() -> Int { return nbHorizontalTiles * tileSize }
    func verticalSize() -> Int { return nbVerticalTiles * tileSize }
    func nbTiles() -> Int { return nbHorizontalTiles * nbVerticalTiles }
    func idxFromCoordinate(_ x: Int, _ y: Int) -> Int { y * nbHorizontalTiles + x }

    func coordFromIdx(_ idx: Int) -> (Int, Int) {
        (idx % nbHorizontalTiles, idx / nbHorizontalTiles)
    }

    func reset() {
        seconds = 0
        safe = 0
        flags = 0
        flagsLbL.stringValue = "Flags: 0/50"
        timerLbl.stringValue = "Time: 0"
        halfPairs.removeAll()
        knownSafeCount = 0
        tiles.forEach { $0.reset() }
    }

    func coordFromPoint(_ point: NSPoint) -> (Int, Int) {
        let x = Int(floor(point.x / CGFloat(tileSize)))
        let y = Int(floor((point.y - 20) / CGFloat(tileSize)))
        return (x, y)
    }
    
    func tilesFromIndices<T: Sequence>(_ iterable: T) -> [Tile] where T.Element == Int {
        iterable.map { tiles[$0] }
    }
    
    func isValidPosition(x: Int, y: Int) -> Bool {
        return x >= 0 && x < nbHorizontalTiles &&
               y >= 0 && y < nbVerticalTiles
    }
    
    func indicesInRange(idx: Int, range: Int) -> [Int] {
        let r = range
        var res: [Int] = []
        let (x, y) = coordFromIdx(idx)
        for dx in -r...r {
            for dy in -r...r {
                let (nx, ny) = (x + dx, y + dy)
                if (dx != 0 || dy != 0) && isValidPosition(x: nx, y: ny) {
                    res.append(idxFromCoordinate(nx, ny))
                }
            }
        }
        return res
    }
    
    func neighborCoords(x: Int, y: Int) -> [(Int, Int)] {
        indicesInRange(idx: idxFromCoordinate(x, y), range: 1).map { coordFromIdx($0) }
    }

    func neighborIndices(_ idx: Int) -> [Int] {
        let (x, y) = coordFromIdx(idx)
        return neighborCoords(x: x, y: y).map { (nx, ny) in idxFromCoordinate(nx, ny) }
    }
    
    func neighbors(_ idx: Int) -> [Tile] {
        neighborIndices(idx).map { tiles[$0] }
    }
    
    // Return true if `idx` is `(x,y)` or a neighbor of it
    func around(idx: Int, x: Int, y: Int) -> Bool {
        let initialClickPosition = idxFromCoordinate(x, y)
        let neighborsIndexes = neighborIndices(initialClickPosition)
        return neighborsIndexes.contains(idx) ||
               idx == initialClickPosition ||
               isMine(idx)
    }
    
    func initBoard(x: Int, y: Int) {
        var seed: UInt64 = UInt64(arc4random_uniform(UInt32.max)) << 32 | UInt64(arc4random_uniform(UInt32.max))
        seed = 9849085840355923398
        print("seed: ", seed)
        let generator = GKMersenneTwisterRandomSource(seed: seed)
        for _ in 0..<nbMines {
            var position: Int
            repeat {
                position = Int(generator.nextInt(upperBound: nbTiles()))
            } while around(idx: position, x: x, y: y)
            tiles[position].isMine = true
        }
    }
    
    func showMines(deadIdx: Int) {
        for i in 0..<tiles.count {
            if i == deadIdx {
                tiles[i].state = .ExplodedMine
            } else if isMine(i) && isFlag(i) {
                tiles[i].state = .FlaggedMine
            } else if isFlag(i) {
                tiles[i].state = .BadFlag
            } else if isMine(i) {
                tiles[i].state = .Mine
            }
        }
    }
    
    func gameOver(idx: Int) {
        state = .GameOver
        showMines(deadIdx: idx);
    }
    
    func win(ctx: CGContext) {
        showMines(deadIdx: -1)
        ctx.saveGState()
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.7))
        ctx.fill(CGRect(x: 0, y: 0, width: horizontalSize(), height: verticalSize()))
        ctx.restoreGState()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Arial", size: 40)!,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor(calibratedRed: 0, green: 0.502, blue: 0, alpha: 1),
        ]
        "Win".draw(with: CGRect(x: 0, y: ((verticalSize()) + tileSize) / 2, width: horizontalSize(), height: tileSize), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
    func isMine(_ idx: Int) -> Bool { tiles[idx].isMine }
    func isFlag(_ idx: Int) -> Bool { tiles[idx].state == .Flagged }
    func countMinesAround(idx: Int) -> Int { countAround(idx, isMine) }
    func countFlagsAround(idx: Int) -> Int { countAround(idx, isFlag) }
    func countAround(_ idx: Int, _ clb: (Int) -> Bool) -> Int {
        neighborIndices(idx).reduce(0) { acc, nidx in
            acc + (clb(nidx) ? 1 : 0)
        }
    }

    func getUnknownIndices(idx: Int) -> Set<Int> {
        Set(neighborIndices(idx).filter { tiles[$0].IsUndiscovered() && tiles[$0].IsUnknown() })
    }
    
    func countUnknownMines(for idx: Int) -> Int {
        tiles[idx].minesAround - knownMinesAround(idx: idx)
    }
    
    func knownMinesAround(idx: Int) -> Int {
        neighborIndices(idx).reduce(0) { result, idx in
            result + ((tiles[idx].state == .Empty || tiles[idx].state == .Flagged) && tiles[idx].IsProbMine() ? 1 : 0)
        }
    }
    
    func knownNoMinesAround(idx: Int) -> Int {
        neighborIndices(idx).reduce(0) { result, idx in
            result + ((tiles[idx].state == .Empty || tiles[idx].state == .Flagged) && tiles[idx].IsProbNoMine() ? 1 : 0)
        }
    }
    
    // Count mines that we know based on probabilities
    func countKnownMines() -> Int {
        tiles.filter { $0.IsProbMine() }.count
    }
    
    func countSafeTiles() -> Int {
        tiles.filter { $0.IsProbNoMine() }.count
    }
    
    // Return how many mines remain to be known, based on probabilities
    func countUnknownMines() -> Int {
        return nbMines - countKnownMines()
    }
    
    func showTile(idx: Int) -> Int {
        let tile = tiles[idx]
        
        guard tile.state == .Empty else { return 0 }
        
        let nbMinesAround = countMinesAround(idx: idx)
        tile.discover(nbMinesAround)
        
        if nbMinesAround > 0 {
            return 1
        }
        
        return neighborIndices(idx).reduce(1) { acc, neighborIdx in
            acc + showTile(idx: neighborIdx)
        }
    }
    
    func toggleFlag(x: Int, y: Int) {
        let tileIdx = idxFromCoordinate(x, y)
        let tile = tiles[tileIdx]
        if tile.state == .Empty {
            tile.state = .Flagged
            flags += 1
        } else if tile.state == .Flagged {
            tile.state = .Empty
            flags -= 1
        }
        flagsLbL.stringValue = String(format: "Flags: %d/50", flags)
    }
    
    func checkGameOver(_ tilesToShow: [Int]) -> Bool {
        for tileIdx in tilesToShow {
            let tile = tiles[tileIdx]
            guard tile.state == .Empty else { continue }
            if isMine(tileIdx) {
                gameOver(idx: tileIdx)
                return true
            }
        }
        return false
    }
    
    @objc func updateTimer() {
        seconds += 1
        timerLbl.stringValue = String(format: "Time: %d", seconds)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect);
        NSColor.white.setFill()
        dirtyRect.fill()
        if let ctx = NSGraphicsContext.current?.cgContext {
            for tile in tiles {
                tile.render(ctx: ctx, debugMines: debugMines, dbgIdx: dbgIdx, dbgProb: dbgProb)
            }
            if state == .Win {
                win(ctx: ctx)
            }
        }
    }
    
    func blessing(_ tileIdx: Int) -> Int {
        if let pair = halfPairs.first(where: { $0.contains(tileIdx) }) {
            let (first, second) = (pair[0], pair[1])
            if first == tileIdx {
                return second
            } else {
                return first
            }
        }
        return tileIdx
//        if let pair = halfPairs.first(where: { $0.contains(tileIdx) }) {
//            let (first, second) = (pair[0], pair[1])
//            if first == tileIdx {
//                tiles[first].isMine = false
//                tiles[first].SetProbNoMine()
//                tiles[second].isMine = true
//            } else {
//                tiles[first].isMine = true
//                tiles[second].isMine = false
//                tiles[second].SetProbNoMine()
//            }
//        }
//
//        // Reset remaining probs
//        halfPairs.removeAll()
//        for tile in tiles where tile.IsUndiscovered() && tile.IsUnknown() {
//            tile.SetProb(-1)
//        }
//        // Recalibrate board
//        calcProb()
//        var added = 0
//        for tile in tiles {
//            if tile.IsProbMine() && !tile.isMine {
//                tile.isMine = true
//                added += 1
//            } else if tile.IsProbNoMine() && tile.isMine {
//                tile.isMine = false
//                added -= 1
//            }
//        }
//        // add/remove extra/missing mines
//        for tile in tiles {
//            if added < 0, tile.IsUnknown(), !tile.isMine {
//                tile.isMine = true
//                added += 1
//            } else if added > 0, tile.IsUnknown(), tile.isMine {
//                tile.isMine = false
//                added -= 1
//            }
//            // Stop the loop early if `added` has been balanced
//            if added == 0 { break }
//        }
//
//        if added != 0 {
//            print("added is not 0")
//        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if !checkBounds(event) {
            return
        }
        if event.modifierFlags.contains(.command) {
            rightMouseUp(with: event)
            return
        }
        
        super.mouseUp(with: event)
        
        var (tileX, tileY) = coordFromPoint(event.locationInWindow)
        var tileIdx = idxFromCoordinate(tileX, tileY)
        var tile = tiles[tileIdx]
        if state == .Waiting {
            initBoard(x: tileX, y: tileY)
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
            state = .Playing
        }
        
        if state == .Playing {
            // Game will make the odds works for you if there is no more safe square to click
            if knownSafeCount == 0 && halfPairs.count > 0 && tile.GetProb() == 0.5 && tile.isMine {
                tileIdx = blessing(tileIdx)
                tile = tiles[tileIdx]
                tileX = tile.x
                tileY = tile.y
            }
            
            var tilesToShow = [tileIdx]
            if tile.IsDiscovered() && countFlagsAround(idx: tileIdx) == countMinesAround(idx: tileIdx) {
                tilesToShow.append(contentsOf: neighborIndices(tileIdx))
            }
            if !checkGameOver(tilesToShow) {
                for idx in tilesToShow {
                    safe += showTile(idx: idx)
                }
                if safe == tiles.count - nbMines {
                    state = .Win
                }
            }
            if state == .Playing {
                calcProb()
            }
        } else if state == .GameOver || state == .Win {
            reset()
            state = .Waiting
        }
        
        if state == .GameOver || state == .Win {
            timer.invalidate()
        }
        
        redraw()
    }
    
    private func neighborSets(for idxA: Int, _ idxB: Int) -> (Set<Int>, Set<Int>) {
        let setA = Set(neighborIndices(idxA))
        let setB = Set(neighborIndices(idxB))
        return (setA, setB)
    }
    
    func neighborsIntersection(idxA: Int, idxB: Int) -> Set<Int> {
        let (setA, setB) = neighborSets(for: idxA, idxB)
        return setA.intersection(setB)
    }
    
    func neighborsIsSuperset(idxA: Int, idxB: Int) -> Bool {
        let (setA, setB) = neighborSets(for: idxA, idxB)
        return setA.isSuperset(of: setB)
    }
    
    func neighborsDifference(idxA: Int, idxB: Int) -> Set<Int> {
        let (setA, setB) = neighborSets(for: idxA, idxB)
        return setA.subtracting(setB)
    }
    
    // if tile empty sq is superset of neighbor empty sq and neighbor only has 1 mine
    func a(_ idx: Int, _ tileUnknown: Set<Int>, _ nbUnknownMines: Int) -> Bool {
        var out = false
        for neighborIdx in neighborIndices(idx) {
            let nUnknown = getUnknownIndices(idx: neighborIdx)
            let nNbUnknownMines = countUnknownMines(for: neighborIdx)
            guard !nUnknown.isEmpty, tileUnknown.isSuperset(of: nUnknown), nNbUnknownMines == 1 else { continue }
            let remain = tileUnknown.subtracting(nUnknown)
            if remain.count == nbUnknownMines-1 {
                for tile in tilesFromIndices(remain) {
                    tile.SetProbMine()
                    out = true
                }
            }
        }
        return out
    }
    
    
    // Should figure out `1|2|1` patterns
    func oneTwoOnePattern(_ idx: Int, _ tileUnknown: Set<Int>, _ nbUnknownMines: Int) -> Bool {
        var out = false
        if nbUnknownMines == 2 && tileUnknown.count == 3 {
            for ni in neighborIndices(idx) {
                let nUnknown = getUnknownIndices(idx: ni)
                let nNbUnknownMines = countUnknownMines(for: ni)
                if nNbUnknownMines == 1 && tileUnknown.intersection(nUnknown).count == 2 {
                    for tile in tilesFromIndices(tileUnknown.subtracting(nUnknown)) {
                        tile.SetProbMine()
                        out = true
                    }
                }
            }
        }
        return out
    }
    
    // If a tile has all the remaining unknown mines in its neighbors, then all other tiles have prob 0
    func c(_ idx: Int, _ tileUnknown: Set<Int>, _ nbUnknownMines: Int) -> Bool {
        var out = false
        if nbUnknownMines == countUnknownMines() {
            let nindicesSet = Set(neighborIndices(idx))
            for tile in tiles {
                if !nindicesSet.contains(tile.idx()) && tile.IsUnknown() {
                    tile.SetProbNoMine()
                    out = true
                }
            }
        }
        return out
    }
    
    // tile A has 3 unknown neighbors and 2 unfound mines, tile B with 1 unfound mine share two of the three neighbors of A,
    // then B other neighbors are set to no-mine, and the third neighbor A set to "mine".
    func d(_ idx: Int,_ tileUnknown: Set<Int>, _ nbUnknownMines: Int) -> Bool {
        guard nbUnknownMines == 2 && tileUnknown.count == 3 else { return false }
        var out = false
        for tile in tilesFromIndices(indicesInRange(idx: idx, range: 2)) {
            if countUnknownMines(for: tile.idx()) == 1 {
                let tn = Set(neighborIndices(tile.idx()))
                let intersect = tileUnknown.intersection(tn)
                if intersect.count == 2 {
                    for el in tn.subtracting(intersect) {
                        tiles[el].SetProbNoMine()
                    }
                    if let el = tileUnknown.subtracting(intersect).first {
                        tiles[el].SetProbMine()
                    }
                    out = true
                }
            }
        }
        return out
    }
    
    // tile A with 1 unfound mine... tile B with 1 unfound mine share all of A's unknown neighbors, so all other neighbors of B are "no-mine"
    func e(_ idx: Int, _ tileUnknown: Set<Int>, _ nbUnknownMines: Int) -> Bool {
        guard nbUnknownMines == 1 else { return false }
        var out = false
        for tile in tilesFromIndices(indicesInRange(idx: idx, range: 2)) {
            if countUnknownMines(for: tile.idx()) == 1 {
                let bUnknown = getUnknownIndices(idx: tile.idx())
                if bUnknown.isSuperset(of: tileUnknown) {
                    let diff = bUnknown.subtracting(tileUnknown)
                    if diff.count > 0 {
                        for el in diff {
                            tiles[el].SetProbNoMine()
                        }
                        out = true
                    }
                }
            }
        }
        return out
    }
    
    func calcProb() {
        let startTime = Date()
        var loopIdx = 0
        var stable = false
        outerLoop: repeat {
            loopIdx += 1
            if loopIdx > 20 {
                print("???NOT GOOD")
                break
            }
            stable = true
            for idx in 0..<nbTiles() {
                let tile = tiles[idx]
                guard tile.IsDiscovered() else { continue }
                let nbUnknownMines = countUnknownMines(for: idx)
                let tileUnknown = getUnknownIndices(idx: idx)
                let prob = Double(nbUnknownMines) / Double(tileUnknown.count) //  1/2  2/4  4/8  ->  0.5
                let tileUnknownArr = Array(tileUnknown).sorted()
                if prob == 0.5 && tileUnknown.count == 2 && !halfPairs.contains(tileUnknownArr) {
                    halfPairs.insert(tileUnknownArr)
                    stable = false
                } else if prob == 0.5 && tileUnknown.count == 4 {
                    for pair in halfPairs {
                        let otherPair = Array(tileUnknown.subtracting(pair).sorted())
                        if tileUnknown.isSuperset(of: pair) && !halfPairs.contains(otherPair) {
                            halfPairs.insert(otherPair)
                            stable = false
                            break
                        }
                    }
                }
                
                for pair in halfPairs {
                    if tiles[pair[0]].IsKnown() || tiles[pair[1]].IsKnown() {
                        halfPairs.remove(pair)
                    }
                }
                
                if a(idx, tileUnknown, nbUnknownMines) ||
                    oneTwoOnePattern(idx, tileUnknown, nbUnknownMines) ||
                    c(idx, tileUnknown, nbUnknownMines) ||
                    d(idx, tileUnknown, nbUnknownMines) ||
                    e(idx, tileUnknown, nbUnknownMines) {
                    stable = false
                    continue outerLoop
                }
                
                // if tile's neighbors is superset of a halfPair, set the prob of the tile's neighbors that are not part of that pair
                let updateProb: (Double) -> Void = { probValue in
                    let neighborIndicesSet = Set(self.neighborIndices(idx))
                    for pair in self.halfPairs {
                        if neighborIndicesSet.isSuperset(of: pair) {
                            for i in neighborIndicesSet.subtracting(pair) {
                                let tile = self.tiles[i]
                                if tile.IsUnknown() {
                                    tile.SetProb(probValue)
                                    stable = false
                                }
                            }
                        }
                    }
                }
                if nbUnknownMines == 1 {
                    updateProb(0)
                } else if nbUnknownMines == 2 && tileUnknown.count == 3 {
                    updateProb(1)
                }
                
                for nTile in neighbors(idx) {
                    guard nTile.IsUnknown() else { continue }
                    if nbUnknownMines == 0 {
                        nTile.SetProbNoMine()
                        stable = false
                        continue
                    }
                    var newProb = max(nTile.GetProb(), prob)
                    if prob != 0 && prob != 1 && (nTile.GetProb() == 0.5 || prob == 0.5) {
                        newProb = 0.5
                    }
                    if nTile.GetProb() != newProb {
                        stable = false
                        nTile.SetProb(newProb)
                    }
                }
            }
        } while !stable
        
        // Update known safe tiles
        knownSafeCount = countSafeTiles()
        let timeInterval = Date().timeIntervalSince(startTime)
        print("Time taken: \(String(format: "%.3f", timeInterval)) seconds")
    }
    
    override func rightMouseUp(with event: NSEvent) {
        if !checkBounds(event) {
            return
        }
        super.rightMouseUp(with: event)
        let (tileX, tileY) = coordFromPoint(event.locationInWindow)
        if state == .Playing {
            toggleFlag(x: tileX, y: tileY)
        }
        redraw()
    }
    
    // Return true if the event is within the application bounds
    // It is possible to mousedown in the window and mouseup outside of it and still receive the event.
    // This will prevent processing events like mouseup that are out of bounds
    func checkBounds(_ event: NSEvent) -> Bool {
        var point = event.locationInWindow
        point.y -= 20
        return bounds.contains(point)
    }
    
    func redraw() {
        setNeedsDisplay(NSRect(x: 0, y: 0, width: horizontalSize(), height: verticalSize()))
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    
    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func keyDown(with event: NSEvent) {
        guard let character = event.characters else { return }
        switch character {
        case "m":
            debugMines = !debugMines
            redraw()
        case "i":
            dbgIdx.toggle()
            redraw()
        case "p":
            dbgProb.toggle()
            redraw()
        case "c":
            if state == .Playing {
                for tile in tiles where tile.IsUndiscovered() && tile.IsProbNoMine() {
                    safe += showTile(idx: tile.idx())
                }
                calcProb()
                redraw()
            }
        case "s":
            print("Known mines:", countKnownMines())
            print("Unknown mines:", countUnknownMines())
        case "r":
            timer.invalidate()
            reset()
            state = .Waiting
            redraw()
        default:
            break
        }
    }
}
