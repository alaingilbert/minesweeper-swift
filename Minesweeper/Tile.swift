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
        case Empty
        case Discovered
        case Flagged
        case BadFlag
        case ExplodedMine
        case Mine
        case FlaggedMine
    }
    
    let size = 40
    var x: Int
    var y: Int
    var state = State.Empty
    var minesAround = 0
    
    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    
    func renderEmpty(ctx: CGContext?) {
        let sizef = CGFloat(size)
        ctx?.saveGState()
        ctx?.translateBy(x: CGFloat(x * size), y: CGFloat(y * size))
        ctx?.setLineWidth(1)
        ctx?.setFillColor(CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1))
        ctx?.setStrokeColor(CGColor(red: 0.502, green: 0.502, blue: 0.502, alpha: 1))
        ctx?.move(to: CGPoint(x: 0, y: 0))
        ctx?.addLine(to: CGPoint(x: sizef, y: 0))
        ctx?.addLine(to: CGPoint(x: sizef, y: sizef))
        ctx?.addLine(to: CGPoint(x: 0, y: sizef))
        ctx?.addLine(to: CGPoint(x: 0, y: 0))
        ctx?.drawPath(using: .fillStroke)
        ctx?.restoreGState()
    }
    
    func renderFlag(ctx: CGContext?) {
        let sizef = CGFloat(size)
        ctx?.saveGState()
        
        ctx?.translateBy(x: CGFloat(x * size), y: CGFloat(y * size))
        
        // Red flag
        ctx?.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx?.move(to: CGPoint(x: sizef/3.0, y: sizef/2.0))
        ctx?.addLine(to: CGPoint(x: sizef/3.0*2, y: sizef/3.0))
        ctx?.addLine(to: CGPoint(x: sizef/3.0*2, y: sizef/3.0*2))
        ctx?.fillPath()
        
        // Black pole
        ctx?.setLineWidth(2)
        ctx?.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx?.move(to: CGPoint(x: sizef/3.0*2, y: sizef-sizef/3.0))
        ctx?.addLine(to: CGPoint(x: sizef/3.0*2, y: sizef/4.0))
        ctx?.addLine(to: CGPoint(x: sizef/2.0, y: sizef/4.0))
        ctx?.addLine(to: CGPoint(x: sizef-sizef/5.0, y: sizef/4.0))
        ctx?.strokePath()
        
        ctx?.restoreGState()
    }
    
    func renderExplodedMine(ctx: CGContext?) {
        let sizef = CGFloat(size)
        ctx?.saveGState()
        ctx?.translateBy(x: CGFloat(x * size), y: CGFloat(y * size))
        ctx?.setStrokeColor(CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1))
        ctx?.setFillColor(CGColor(red: 0.8, green: 0, blue: 0, alpha: 1))
        ctx?.addArc(center: CGPoint(x: sizef/2, y: sizef/2), radius: sizef/4, startAngle: 0, endAngle: CGFloat(2 * Double.pi), clockwise: true)
        ctx?.drawPath(using: .fillStroke)
        ctx?.restoreGState()
    }
    
    func renderMine(ctx: CGContext?) {
        let sizef = CGFloat(size)
        ctx?.saveGState()
        ctx?.translateBy(x: CGFloat(x * size), y: CGFloat(y * size))
        ctx?.setStrokeColor(CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1))
        ctx?.setFillColor(CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1))
        ctx?.addArc(center: CGPoint(x: sizef/2, y: sizef/2), radius: sizef/4, startAngle: 0, endAngle: CGFloat(2 * Double.pi), clockwise: true)
        ctx?.drawPath(using: .fillStroke)
        ctx?.restoreGState()
    }
    
    func renderCross(ctx: CGContext?) {
        let sizef = CGFloat(size)
        ctx?.saveGState()
        ctx?.translateBy(x: CGFloat(x * size), y: CGFloat(y * size))
        ctx?.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx?.setLineWidth(2)
        ctx?.move(to: CGPoint(x: sizef/5, y: sizef/5))
        ctx?.addLine(to: CGPoint(x: sizef-sizef/5, y: sizef-sizef/5))
        ctx?.move(to: CGPoint(x: sizef/5, y: sizef-sizef/5))
        ctx?.addLine(to: CGPoint(x: sizef-sizef/5, y: sizef/5))
        ctx?.strokePath()
        ctx?.restoreGState()
    }
    
    func renderDiscovered(ctx: CGContext?) {
        let sizef = CGFloat(size)
        ctx?.saveGState()
        ctx?.translateBy(x: CGFloat(x * size), y: CGFloat(y * size))
        ctx?.setLineWidth(1)
        ctx?.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx?.setStrokeColor(CGColor(red: 0.502, green: 0.502, blue: 0.502, alpha: 1))
        ctx?.move(to: CGPoint(x: 0, y: 0))
        ctx?.addLine(to: CGPoint(x: sizef, y: 0))
        ctx?.addLine(to: CGPoint(x: sizef, y: sizef))
        ctx?.addLine(to: CGPoint(x: 0, y: sizef))
        ctx?.addLine(to: CGPoint(x: 0, y: 0))
        ctx?.drawPath(using: .fillStroke)
        ctx?.restoreGState()
        
        if minesAround == 0 {
            return
        }
        
        let colors: [NSColor] = [
            NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1),         // Blue
            NSColor(calibratedRed: 0, green: 0.502, blue: 0, alpha: 1),     // Green
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1),         // Red
            NSColor(calibratedRed: 0, green: 0, blue: 0.502, alpha: 1),     // Navy
            NSColor(calibratedRed: 0.502, green: 0, blue: 0, alpha: 1),     // Maroon
            NSColor(calibratedRed: 0, green: 1, blue: 1, alpha: 1),         // Aqua
            NSColor(calibratedRed: 0.502, green: 0, blue: 0.502, alpha: 1), // Purple
            NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1),         // Black
        ]
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let label = String(minesAround)
        let font = NSFont(name: "Arial", size: 38)!
        let attrs = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.paragraphStyle: paragraphStyle,
            NSAttributedStringKey.foregroundColor: colors[minesAround-1],
        ]
        label.draw(with: CGRect(x: x*size, y: y*size, width: size, height: size), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
    func render(ctx: CGContext?) {
        switch state {
        case .Empty:
            renderEmpty(ctx: ctx)
        case .Flagged:
            renderEmpty(ctx: ctx)
            renderFlag(ctx: ctx)
        case .Discovered:
            renderDiscovered(ctx: ctx)
        case .ExplodedMine:
            renderEmpty(ctx: ctx)
            renderExplodedMine(ctx: ctx)
        case .BadFlag:
            renderEmpty(ctx: ctx)
            renderFlag(ctx: ctx)
            renderCross(ctx: ctx)
        case .Mine:
            renderEmpty(ctx: ctx)
            renderMine(ctx: ctx)
        case .FlaggedMine:
            renderEmpty(ctx: ctx)
            renderMine(ctx: ctx)
            renderFlag(ctx: ctx)
        }
    }
}
