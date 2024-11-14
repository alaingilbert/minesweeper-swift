//
//  Tile.swift
//  Minesweeper
//
//  Created by Alain Gilbert on 3/10/18.
//  Copyright © 2018 None. All rights reserved.
//

import Foundation
import AppKit

class Tile {
    enum State {
        case Empty, Discovered, Flagged, BadFlag, ExplodedMine, Mine, FlaggedMine
    }
    
    private enum TileColor {
        static let empty         = CGColor(red: 0.8,   green: 0.8,   blue: 0.8,   alpha: 1)
        static let flagged       = CGColor(red: 1,     green: 0,     blue: 0,     alpha: 1)
        static let mineStroke    = CGColor(red: 0.2,   green: 0.2,   blue: 0.2,   alpha: 1)
        static let mineNormal    = CGColor(red: 0.4,   green: 0.4,   blue: 0.4,   alpha: 1)
        static let mineExploded  = CGColor(red: 0.8,   green: 0,     blue: 0,     alpha: 1)
        static let mineStrokeDbg = CGColor(red: 0.2,   green: 0.2,   blue: 0.2,   alpha: 0.2)
        static let mineDebug     = CGColor(red: 0.4,   green: 0.4,   blue: 0.4,   alpha: 0.2)
        static let discovered    = CGColor(red: 1,     green: 1,     blue: 1,     alpha: 1)
        static let stroke        = CGColor(red: 0.502, green: 0.502, blue: 0.502, alpha: 1)
    }
    
    let size: Int
    private let _idx: Int
    var x: Int
    var y: Int
    var state = State.Empty
    var isMine = false
    var minesAround = 0
    private var prob = -1.0
    var debugMines = false
    var dbgIdx = false
    
    init(idx: Int, x: Int, y: Int, size: Int) {
        self._idx = idx
        self.x = x
        self.y = y
        self.size = size
    }
    
    func reset() {
        state = .Empty
        isMine = false
        resetProb()
        minesAround = 0
    }
    
    func coord() -> (Int, Int) { (x, y) }
    
    func discover(_ nbMinesAround: Int) {
        minesAround = nbMinesAround
        state = .Discovered
        prob = 0
    }
    
    func IsDiscovered() -> Bool {
        state == .Discovered
    }
    func IsUndiscovered() -> Bool {
        state != .Discovered
    }
    func idx() -> Int { _idx }
    func SetProbMine() {
        if prob == 1 || prob == 0 {
            return
        }
        if !isMine {
            print("Set prob mine which is not a mine", idx())
        }
        prob = 1
    }
    func SetProbNoMine() {
        if prob == 1 || prob == 0 {
            return
        }
        if isMine {
            print("Set prob no mine which is a mine", idx())
        }
        prob = 0
    }
    func GetProb() -> Double {
        prob
    }
    func resetProb() {
        prob = -1
    }
    func SetProb(_ value: Double) {
        if prob == 1 || prob == 0 {
            return
        }
        if value == 1 {
            SetProbMine()
        } else if value == 0 {
            SetProbNoMine()
        } else {
            prob = value
        }
    }
    func IsProbMine() -> Bool { prob == 1 } // a Mine according to calculated probability
    func IsProbNoMine() -> Bool { prob == 0 } // not a Mine according to calculated probability
    func IsKnown() -> Bool { IsProbMine() || IsProbNoMine() }  // we know the tile value
    func IsUnknown() -> Bool { !IsKnown() } // we don't know the tile value
    
    private func tileDrawWrapper(_ ctx: CGContext, _ clb: () -> Void) {
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(x * size), y: CGFloat(y * size))
        clb()
        ctx.restoreGState()
    }
    
    private func renderTileBackground(_ ctx: CGContext, _ color: CGColor) {
        tileDrawWrapper(ctx, {
            let sizef = CGFloat(size)
            ctx.setLineWidth(1)
            ctx.setFillColor(color)
            ctx.setStrokeColor(TileColor.stroke)
            ctx.addRect(CGRect(x: 0, y: 0, width: sizef, height: sizef))
            ctx.drawPath(using: .fillStroke)
        })
    }
    
    private func renderTileNumber(_ ctx: CGContext) {
        if minesAround == 0 {
            return
        }
        let colors = [
            NSColor(calibratedRed: 0,     green: 0,     blue: 1,     alpha: 1), // Blue
            NSColor(calibratedRed: 0,     green: 0.502, blue: 0,     alpha: 1), // Green
            NSColor(calibratedRed: 1,     green: 0,     blue: 0,     alpha: 1), // Red
            NSColor(calibratedRed: 0,     green: 0,     blue: 0.502, alpha: 1), // Navy
            NSColor(calibratedRed: 0.502, green: 0,     blue: 0,     alpha: 1), // Maroon
            NSColor(calibratedRed: 0,     green: 1,     blue: 1,     alpha: 1), // Aqua
            NSColor(calibratedRed: 0.502, green: 0,     blue: 0.502, alpha: 1), // Purple
            NSColor(calibratedRed: 0,     green: 0,     blue: 0,     alpha: 1), // Black
        ]
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Arial", size: 38)!,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: colors[minesAround-1],
        ]
        String(minesAround).draw(with: CGRect(x: x*size, y: y*size, width: size, height: size), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
    private func renderProb(_ ctx: CGContext) {
        if dbgIdx {
            renderIdx(ctx)
        }
        if state == .Discovered || prob == -1 {
            return
        }
        let paragraphStyle = NSMutableParagraphStyle()
        var bgColor = NSColor.clear
        if prob == 1 {
            bgColor = NSColor.green
        } else if prob == 0 {
            bgColor = NSColor.red
        }
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Arial", size: 12)!,
            .backgroundColor: bgColor,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.black,
        ]
        String(format: "%.2f", prob).draw(with: CGRect(x: x*size, y: y*size, width: size, height: size), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
    private func renderIdx(_ ctx: CGContext) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Arial", size: 7)!,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.gray,
        ]
        String(y*19+x).draw(with: CGRect(x: x*size+1, y: y*size-32, width: size, height: size), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
    private func renderFlag(_ ctx: CGContext) {
        tileDrawWrapper(ctx, {
            let sizef = CGFloat(size)
            // Red flag
            ctx.setFillColor(TileColor.flagged)
            ctx.move   (to: CGPoint(x: sizef/3.0,   y: sizef/2.0))
            ctx.addLine(to: CGPoint(x: sizef/3.0*2, y: sizef/3.0))
            ctx.addLine(to: CGPoint(x: sizef/3.0*2, y: sizef/3.0*2))
            ctx.fillPath()
            // Black pole
            ctx.setLineWidth(2)
            ctx.setStrokeColor(CGColor.black)
            ctx.move   (to: CGPoint(x: sizef/3.0*2,     y: sizef-sizef/3.0))
            ctx.addLine(to: CGPoint(x: sizef/3.0*2,     y: sizef/4.0))
            ctx.addLine(to: CGPoint(x: sizef/2.0,       y: sizef/4.0))
            ctx.addLine(to: CGPoint(x: sizef-sizef/5.0, y: sizef/4.0))
            ctx.strokePath()
        })
    }
    
    private func renderMine(_ ctx: CGContext, exploded: Bool) {
        tileDrawWrapper(ctx, {
            let normalColor = TileColor.mineNormal
            let explodedColor = TileColor.mineExploded
            let sizef = CGFloat(size)
            ctx.setStrokeColor(TileColor.mineStroke)
            ctx.setFillColor(exploded ? explodedColor : normalColor)
            ctx.addArc(center: CGPoint(x: sizef/2, y: sizef/2), radius: sizef/4, startAngle: 0, endAngle: CGFloat(2 * Double.pi), clockwise: true)
            ctx.drawPath(using: .fillStroke)
        })
    }
    
    private func renderDebugMine(_ ctx: CGContext) {
        tileDrawWrapper(ctx, {
            let sizef = CGFloat(size)
            ctx.setStrokeColor(TileColor.mineStrokeDbg)
            ctx.setFillColor(TileColor.mineDebug)
            ctx.addArc(center: CGPoint(x: sizef/2, y: sizef/2), radius: sizef/4, startAngle: 0, endAngle: CGFloat(2 * Double.pi), clockwise: true)
            ctx.drawPath(using: .fillStroke)
        })
    }
    
    private func renderCross(_ ctx: CGContext) {
        tileDrawWrapper(ctx, {
            let sizef = CGFloat(size)
            ctx.setStrokeColor(CGColor.black)
            ctx.setLineWidth(2)
            ctx.move   (to: CGPoint(x: sizef/5,       y: sizef/5))
            ctx.addLine(to: CGPoint(x: sizef-sizef/5, y: sizef-sizef/5))
            ctx.move   (to: CGPoint(x: sizef/5,       y: sizef-sizef/5))
            ctx.addLine(to: CGPoint(x: sizef-sizef/5, y: sizef/5))
            ctx.strokePath()
        })
    }
    
    private func renderEmpty(_ ctx: CGContext) {
        renderTileBackground(ctx, TileColor.empty)
        if debugMines && isMine {
            renderDebugMine(ctx)
        }
    }
    
    private func renderDiscovered(_ ctx: CGContext) {
        renderTileBackground(ctx, TileColor.discovered)
        renderTileNumber(ctx)
    }
    
    private func renderFlagged(_ ctx: CGContext) {
        renderEmpty(ctx)
        renderFlag(ctx)
    }
    
    private func renderBadFlag(_ ctx: CGContext) {
        renderEmpty(ctx)
        renderFlag(ctx)
        renderCross(ctx)
    }
    
    private func renderMine(_ ctx: CGContext) {
        renderEmpty(ctx)
        renderMine(ctx, exploded: false)
    }
    
    private func renderExplodedMine(_ ctx: CGContext) {
        renderEmpty(ctx)
        renderMine(ctx, exploded: true)
    }
    
    private func renderFlaggedMine(_ ctx: CGContext) {
        renderEmpty(ctx)
        renderMine(ctx, exploded: false)
        renderFlag(ctx)
    }
    
    func render(ctx: CGContext, debugMines: Bool, dbgIdx: Bool, dbgProb: Bool) {
        self.debugMines = debugMines
        self.dbgIdx = dbgIdx
        switch state {
        case .Empty:        renderEmpty(ctx)
        case .Discovered:   renderDiscovered(ctx)
        case .Flagged:      renderFlagged(ctx)
        case .BadFlag:      renderBadFlag(ctx)
        case .Mine:         renderMine(ctx)
        case .ExplodedMine: renderExplodedMine(ctx)
        case .FlaggedMine:  renderFlaggedMine(ctx)
        }
        if dbgProb {
            renderProb(ctx)
        }
    }
}
