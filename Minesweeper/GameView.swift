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
        case Waiting
        case GameOver
        case Win
        case Playing
    }
    
    var flagsLbL: NSTextField = NSTextField()
    var timerLbl: NSTextField = NSTextField()
    
    var timer = Timer()
    var seconds = 0
    var flags = 0
    let tileSize = 40
    let nbMines = 50
    let nbHorizontalTiles = 19
    let nbVerticalTiles = 13
    var state = State.Waiting
    var data: [Bool] = Array(repeating: false, count: 19*13)
    var tiles: [Tile] = []
    var safe: Int = 0
    
    required init?(coder decoder: NSCoder) {
        let nbTiles = nbHorizontalTiles * nbVerticalTiles
        for i in 0..<nbTiles {
            let y: Int = i / nbHorizontalTiles
            let x: Int = i - y * nbHorizontalTiles
            let t = Tile(x: x, y: y)
            tiles.append(t)
        }
        super.init(coder: decoder)
    }
    
    func reset() {
        seconds = 0
        safe = 0
        flags = 0
        flagsLbL.stringValue = "Flags: 0/50"
        timerLbl.stringValue = "Time: 0"
        let nbTiles = nbHorizontalTiles * nbVerticalTiles;
        for i in 0..<nbTiles {
            data[i] = false
            tiles[i].state = .Empty
        }
    }
    
    func idxFromCoordinate(x: Int, y: Int) -> Int {
        return y * nbHorizontalTiles + x
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect);
        
        NSColor.white.setFill()
        //let rect = NSRect(bounds)
        //let rect = NSRect(x: 0, y: 0, width: 100, height: 100)
        dirtyRect.fill()
        
        let ctx = NSGraphicsContext.current?.cgContext
        let nbTiles = nbHorizontalTiles * nbVerticalTiles
        for i in 0...nbTiles-1 {
            tiles[i].render(ctx: ctx)
        }
        
        if state == .Win {
            win(ctx: ctx)
        }
    }
    
    func coordFromIdx(idx: Int) -> (Int, Int) {
        let y = idx / nbHorizontalTiles
        let x = idx - y * nbHorizontalTiles
        return (x, y)
    }
    
    func neighborIdx(idx: Int) -> [Int] {
        let (x, y) = coordFromIdx(idx: idx)
        let neighbors = neighborCoord(x: x, y: y)
        var res: [Int] = []
        for (nx, ny) in neighbors {
            res.append(idxFromCoordinate(x: nx, y: ny))
        }
        return res
    }
    
    func around(idx: Int, x: Int, y: Int) -> Bool {
        let initialClickPosition = idxFromCoordinate(x: x, y: y)
        let neighborsIndexes = neighborIdx(idx: initialClickPosition)
        return neighborsIndexes.index(of: idx) != nil ||
               idx == initialClickPosition ||
               isMine(idx: idx)
    }
    
    func initBoard(x: Int, y: Int) {
        var val: Int = 0
        for _ in 0..<nbMines {
            while true {
                val = Int(arc4random_uniform(UInt32(nbHorizontalTiles * nbVerticalTiles)))
                if !around(idx: val, x: x, y: y) {
                    break
                }
            }
            data[val] = true
        }
        state = State.Playing
    }
    
    func isMine(idx: Int) -> Bool {
        return data[idx]
    }
    
    func isFlag(idx: Int) -> Bool {
        return tiles[idx].state == .Flagged
    }
    
    func showMines(deadIdx: Int) {
        for i in 0..<tiles.count {
            if isMine(idx: i) || isFlag(idx: i) {
                if i == deadIdx {
                    tiles[i].state = .ExplodedMine
                } else if isMine(idx: i) && isFlag(idx: i) {
                    tiles[i].state = .FlaggedMine
                } else if isFlag(idx: i) {
                    tiles[i].state = .BadFlag
                } else {
                    tiles[i].state = .Mine
                }
            }
        }
    }
    
    func gameOver(idx: Int) {
        state = State.GameOver
        showMines(deadIdx: idx);
    }
    
    func win(ctx: CGContext?) {
        showMines(deadIdx: -1)
        ctx?.saveGState()
        ctx?.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.7))
        ctx?.move(to: CGPoint(x: 0, y: 0))
        ctx?.addLine(to: CGPoint(x: tileSize * 19, y: 0))
        ctx?.addLine(to: CGPoint(x: tileSize * 19, y: tileSize * 13))
        ctx?.addLine(to: CGPoint(x: 0, y: tileSize * 13))
        ctx?.addLine(to: CGPoint(x: 0, y: 0))
        ctx?.fillPath()
        ctx?.restoreGState()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let label = "Win"
        let font = NSFont(name: "Arial", size: 40)!
        let attrs = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.paragraphStyle: paragraphStyle,
            NSAttributedStringKey.foregroundColor: NSColor(calibratedRed: 0, green: 0.502, blue: 0, alpha: 1),
            ]
        label.draw(with: CGRect(x: 0, y: ((tileSize*nbVerticalTiles) + 40) / 2, width: tileSize*nbHorizontalTiles, height: 40), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
    func isValidPosition(x: Int, y: Int) -> Bool {
        return x >= 0 && x < nbHorizontalTiles &&
               y >= 0 && y < nbVerticalTiles
    }
    
    func neighborCoord(x: Int, y: Int) -> [(Int, Int)] {
        var res: [(Int, Int)] = []
        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 {
                    continue
                }
                if !isValidPosition(x: x + dx, y: y + dy) {
                    continue
                }
                res.append((x + dx, y + dy))
            }
        }
        return res
    }
    
    func countMinesAround(x: Int, y: Int) -> Int {
        var nbMines = 0
        for (nx, ny) in neighborCoord(x: x, y: y) {
            if isMine(idx: idxFromCoordinate(x: nx, y: ny)) {
                nbMines += 1
            }
        }
        return nbMines
    }
    
    func countFlagsAround(x: Int, y: Int) -> Int {
        var nbFlags = 0
        for (nx, ny) in neighborCoord(x: x, y: y) {
            if isFlag(idx: idxFromCoordinate(x: nx, y: ny)) {
                nbFlags += 1
            }
        }
        return nbFlags
    }
    
    func showTile(x: Int, y: Int) {
        let tileIdx = idxFromCoordinate(x: x, y: y)
        let tile = tiles[tileIdx]
        
        if tile.state == .Discovered || tile.state == .Flagged {
            return
        }
        
        if isMine(idx: tileIdx) {
            gameOver(idx: tileIdx)
            return
        }
        
        let nbMinesAround = countMinesAround(x: x, y: y)
        safe += 1
        tile.minesAround = nbMinesAround
        tile.state = .Discovered
        
        if nbMinesAround == 0 {
            for (nx, ny) in neighborCoord(x: x, y: y) {
                showTile(x: nx, y: ny)
            }
        }
    }
    
    @objc func updateTimer() {
        seconds += 1
        timerLbl.stringValue = String(format: "Time: %d", seconds)
    }
    
    override func mouseUp(with event: NSEvent) {
        if (event.modifierFlags.contains(.command)) {
            rightMouseUp(with: event)
            return
        }
        
        super.mouseUp(with: event)
        
        let tileX = Int(floor(event.locationInWindow.x / 40))
        let tileY = Int(floor((event.locationInWindow.y - 20) / 40))
        let tileIdx = idxFromCoordinate(x: tileX, y: tileY)
        let tile = tiles[tileIdx]
        if state == State.Waiting {
            initBoard(x: tileX, y: tileY)
            timer = Timer.scheduledTimer(timeInterval: 1, target: self,   selector: (#selector(self.updateTimer)), userInfo: nil, repeats: true)
        }
        
        if state == State.Playing {
            if tile.state == .Discovered {
                if countFlagsAround(x: tileX, y: tileY) == countMinesAround(x: tileX, y: tileY) {
                    for (nx, ny) in neighborCoord(x: tileX, y: tileY) {
                        showTile(x: nx, y: ny)
                    }
                }
            } else {
                showTile(x: tileX, y: tileY)
            }
            if safe == tiles.count - nbMines {
                state = .Win
            }
        } else if state == .GameOver || state == .Win {
            reset()
            state = .Waiting
        }
        
        if state == .GameOver || state == .Win {
            timer.invalidate()
        }
        
        self.setNeedsDisplay(NSRect(x: 0, y: 0, width: 760, height: 520))
    }
    
    func toggleFlag(x: Int, y: Int) {
        let tileIdx = idxFromCoordinate(x: x, y: y)
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
    
    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
        let tileX = Int(floor(event.locationInWindow.x / 40))
        let tileY = Int(floor((event.locationInWindow.y - 20) / 40))
        if state == State.Playing {
            toggleFlag(x: tileX, y: tileY)
        }
        self.setNeedsDisplay(NSRect(x: 0, y: 0, width: 760, height: 520))
    }
}
