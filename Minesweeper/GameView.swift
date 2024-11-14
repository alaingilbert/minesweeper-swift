//
//  GameView.swift
//  Minesweeper
//
//  Created by Alain Gilbert on 3/10/18.
//  Copyright © 2018 None. All rights reserved.
//

import Foundation
import AppKit

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
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        tiles = (0..<nbTiles()).map { idx in
            let (x, y) = coordFromIdx(idx)
            return Tile(x: x, y: y, size: tileSize)
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
        tiles.forEach { tile in
            tile.state = .Empty
            tile.isMine = false
        }
    }

    func coordFromPoint(_ point: NSPoint) -> (Int, Int) {
        let x = Int(floor(point.x / CGFloat(tileSize)))
        let y = Int(floor((point.y - 20) / CGFloat(tileSize)))
        return (x, y)
    }

    func neighborIdx(_ idx: Int) -> [Int] {
        let (x, y) = coordFromIdx(idx)
        return neighborCoord(x: x, y: y).map { (nx, ny) in idxFromCoordinate(nx, ny) }
    }
    
    // Return true if `idx` is `(x,y)` or a neighbor of it
    func around(idx: Int, x: Int, y: Int) -> Bool {
        let initialClickPosition = idxFromCoordinate(x, y)
        let neighborsIndexes = neighborIdx(initialClickPosition)
        return neighborsIndexes.contains(idx) ||
               idx == initialClickPosition ||
               isMine(idx)
    }
    
    func initBoard(x: Int, y: Int) {
        for _ in 0..<nbMines {
            var position: Int
            repeat {
                position = Int(arc4random_uniform(UInt32(nbTiles())))
            } while around(idx: position, x: x, y: y)
            tiles[position].isMine = true
        }
    }
    
    func isMine(_ idx: Int) -> Bool {
        tiles[idx].isMine
    }
    
    func isFlag(_ idx: Int) -> Bool {
        tiles[idx].state == .Flagged
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
    
    func isValidPosition(x: Int, y: Int) -> Bool {
        return x >= 0 && x < nbHorizontalTiles &&
               y >= 0 && y < nbVerticalTiles
    }
    
    func neighborCoord(x: Int, y: Int) -> [(Int, Int)] {
        var res: [(Int, Int)] = []
        for dx in -1...1 {
            for dy in -1...1 {
                if (dx != 0 || dy != 0) && isValidPosition(x: x + dx, y: y + dy) {
                    res.append((x + dx, y + dy))
                }
            }
        }
        return res
    }
    
    func countMinesAround(x: Int, y: Int) -> Int {
        countAround(x, y, isMine)
    }
    
    func countFlagsAround(x: Int, y: Int) -> Int {
        countAround(x, y, isFlag)
    }
    
    func countAround(_ x: Int, _ y: Int, _ clb: (Int) -> Bool) -> Int {
        neighborCoord(x: x, y: y).reduce(0) { acc, coord in
            acc + (clb(idxFromCoordinate(coord.0, coord.1)) ? 1 : 0)
        }
    }
    
    func showTile(x: Int, y: Int) -> Int {
        let tileIdx = idxFromCoordinate(x, y)
        let tile = tiles[tileIdx]
        
        guard tile.state == .Empty else { return 0 }
        
        let nbMinesAround = countMinesAround(x: x, y: y)
        tile.discover(nbMinesAround)
        
        if nbMinesAround > 0 {
            return 1
        }
        
        return neighborCoord(x: x, y: y).reduce(1) { acc, neighbor in
            acc + showTile(x: neighbor.0, y: neighbor.1)
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
    
    func checkGameOver(_ tilesToShow: [(Int, Int)]) -> Bool {
        for (x, y) in tilesToShow {
            let tileIdx = idxFromCoordinate(x, y)
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
            for i in 0...nbTiles()-1 {
                tiles[i].render(ctx: ctx)
            }
            if state == .Win {
                win(ctx: ctx)
            }
        }
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
        
        let (tileX, tileY) = coordFromPoint(event.locationInWindow)
        let tileIdx = idxFromCoordinate(tileX, tileY)
        let tile = tiles[tileIdx]
        if state == .Waiting {
            initBoard(x: tileX, y: tileY)
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
            state = .Playing
        }
        
        if state == .Playing {
            var tilesToShow = [(tileX, tileY)]
            if tile.state == .Discovered && countFlagsAround(x: tileX, y: tileY) == countMinesAround(x: tileX, y: tileY) {
                tilesToShow.append(contentsOf: neighborCoord(x: tileX, y: tileY))
            }
            if !checkGameOver(tilesToShow) {
                for (x, y) in tilesToShow {
                    safe += showTile(x: x, y: y)
                }
                if safe == tiles.count - nbMines {
                    state = .Win
                }
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
}
