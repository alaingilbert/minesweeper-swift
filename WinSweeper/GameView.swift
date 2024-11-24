import Foundation
import AppKit
import GameplayKit

@IBDesignable
class GameView : NSView {
    
    weak var delegate: GameViewDelegate?
    weak var gameBoard: GameBoard?
    
    var flagsLbl = NSTextField()
    var timerLbl = NSTextField()
    var safeSqLbl = NSTextField()
    
    let tileSize = 40
    let nbHorizontalTiles = 19
    let nbVerticalTiles = 13
    var tilesView: [TileView] = []
    var debugMines = false
    var dbgIdx = false
    var dbgProb = false
    private let cursorLayer = CAShapeLayer()
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setupCursorLayer()
    }
    
    func showCursor() {
        cursorLayer.isHidden = false
    }
    
    func hideCursor() {
        cursorLayer.isHidden = true
    }
    
    func clickAnim(at idx: Int, rightClick: Bool) {
        let initialPosition = pointFromIdx(idx)
        // Create the ripple layer
        let rippleLayer = CALayer()
        let initialSize: CGFloat = 80
        rippleLayer.bounds = CGRect(x: 0, y: 0, width: initialSize, height: initialSize)
        rippleLayer.position = initialPosition
        rippleLayer.cornerRadius = initialSize / 2
        rippleLayer.borderWidth = 5.0
        rippleLayer.borderColor = rightClick ? NSColor.red.cgColor : NSColor.systemBlue.cgColor
        rippleLayer.opacity = 1.0
        self.layer?.addSublayer(rippleLayer)

        let totalDuration: CFTimeInterval = 0.6
        let fadeDelay: CFTimeInterval = totalDuration / 2

        // Animation to scale the ripple
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.0
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = totalDuration

        // Animation to fade out the ripple
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 1.0
        fadeAnimation.toValue = 0.0
        fadeAnimation.duration = totalDuration - fadeDelay
        fadeAnimation.beginTime = fadeDelay

        // Combine animations in a group
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, fadeAnimation]
        animationGroup.duration = totalDuration
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animationGroup.isRemovedOnCompletion = false
        animationGroup.fillMode = .forwards

        // Add a completion block to clean up
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            rippleLayer.removeFromSuperlayer()
        }
        rippleLayer.add(animationGroup, forKey: "rippleEffect")
        CATransaction.commit()
    }
    
    private func setupCursorLayer() {
        self.wantsLayer = true
        self.layer?.addSublayer(cursorLayer)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: -10))
        path.addLine(to: CGPoint(x: 5.8, y: -10))
        path.addLine(to: CGPoint(x: 8, y: -15))
        path.addLine(to: CGPoint(x: 5.5, y: -16.5))
        path.addLine(to: CGPoint(x: 3, y: -11))
        path.addLine(to: CGPoint(x: 0, y: -14))
        path.closeSubpath()
        
        cursorLayer.shadowColor = NSColor.black.cgColor
        cursorLayer.shadowOpacity = 0.5
        cursorLayer.shadowOffset = CGSize(width: 0, height: -1)
        cursorLayer.shadowRadius = 1.0
        
        cursorLayer.path = path
        cursorLayer.fillColor = NSColor.black.cgColor
        cursorLayer.strokeColor = NSColor.white.cgColor
        cursorLayer.position = CGPoint(x: 100, y: 100)
        cursorLayer.isHidden = true
    }
    
    func moveCursor(to newPosition: CGPoint, duration: Double = 0.3, completion: @escaping () -> Void = {}) {
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = cursorLayer.position
        animation.toValue = newPosition
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cursorLayer.position = newPosition
        // Add a completion block to clean up
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            completion()
        }
        cursorLayer.add(animation, forKey: "position")
        CATransaction.commit()
    }
    
    func initTilesView() {
        tilesView = gameBoard!.tiles.map { TileView(tile: $0, coord: coordFromIdx($0.idx()), size: tileSize) }
    }
    
    func horizontalSize() -> Int { return nbHorizontalTiles * tileSize }
    func verticalSize() -> Int { return nbVerticalTiles * tileSize }
    func nbTiles() -> Int { return nbHorizontalTiles * nbVerticalTiles }
    func idxFromCoordinate(_ x: Int, _ y: Int) -> Int { y * nbHorizontalTiles + x }

    func coordFromIdx(_ idx: Int) -> (Int, Int) {
        coordFromIdxUtils(idx, width: nbHorizontalTiles)
    }

    func coordFromPoint(_ point: NSPoint) -> (Int, Int) {
        let x = Int(floor( point.x       / CGFloat(tileSize)))
        let y = Int(floor((point.y - 20) / CGFloat(tileSize)))
        return (x, y)
    }
    
    func pointFromCoord(_ point: NSPoint) -> (Int, Int) {
        let x = Int(floor( point.x       / CGFloat(tileSize)))
        let y = Int(floor((point.y - 20) / CGFloat(tileSize)))
        return (x, y)
    }
    
    func idxFromPoint(_ point: NSPoint) -> Int {
        let (x, y) = coordFromPoint(point)
        return idxFromCoordinate(x, y)
    }
    
    func pointFromIdx(_ idx: Int) -> CGPoint {
        let (x, y) = coordFromIdxUtils(idx, width: nbHorizontalTiles)
        return CGPoint(x: x*tileSize + tileSize/2, y: y*tileSize + tileSize/2)
    }
    
    func refreshTimerLabel(seconds: Int) {
        timerLbl.stringValue = String(format: "Time: %d", seconds)
    }
    
    func drawWin(ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.7))
        ctx.fill(bounds)
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
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect);
        NSColor.white.setFill()
        dirtyRect.fill()
        if let ctx = NSGraphicsContext.current?.cgContext {
            for tileView in tilesView {
                tileView.render(ctx: ctx, debugMines: debugMines, dbgIdx: dbgIdx, dbgProb: dbgProb)
            }
            if gameBoard!.state == .Win {
                drawWin(ctx: ctx)
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
        let tileIdx = idxFromPoint(event.locationInWindow)
        delegate?.gameView(self, didLeftClickTileAt: tileIdx)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        if !checkBounds(event) {
            return
        }
        super.rightMouseUp(with: event)
        let tileIdx = idxFromPoint(event.locationInWindow)
        delegate?.gameView(self, didRightClickTileAt: tileIdx)
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
        guard let gameBoard = gameBoard else { return }
        flagsLbl.stringValue = String(format: "Flags: %d/%d", gameBoard.countFlags(), gameBoard.nbMines)
        safeSqLbl.stringValue = String(format: "Safe: %d", gameBoard.knownSafeTiles().count)
        setNeedsDisplay(bounds)
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
        get { return true }
    }
    
    override func keyDown(with event: NSEvent) {
        guard let gameBoard = gameBoard else { return }
        guard let character = event.characters else { return }
        switch character.lowercased() {
        case "1":
            let tileIdx = idxFromPoint(event.locationInWindow)
            try! gameBoard.tiles[tileIdx].SetProbMine()
            try! calcProb(gameBoard: gameBoard)
            redraw()
        case "0":
            let tileIdx = idxFromPoint(event.locationInWindow)
            try! gameBoard.tiles[tileIdx].SetProbNoMine()
            try! calcProb(gameBoard: gameBoard)
            redraw()
        case "a":
            delegate?.gameViewToggleAutoPlay()
        case "m":
            debugMines.toggle()
            redraw()
        case "i":
            dbgIdx.toggle()
            redraw()
        case "p":
            dbgProb.toggle()
            redraw()
        case "f":
            gameBoard.flagKnownMines()
        case "c":
            gameBoard.showSafeTiles()
        case "s":
            print("Known mines:", gameBoard.countKnownMines())
            print("Unknown mines:", gameBoard.countUnknownMines())
            print("Discovered:", gameBoard.discoveredTiles().map { $0.idx() })
            print("Serialized:", gameBoard.serialize())
            print("Seed:", gameBoard.seed)
        case "r":
            gameBoard.reset()
        case "z":
            if event.modifierFlags.contains(.shift) {
                gameBoard.redo()
            } else {
                gameBoard.undo()
            }
            tilesView = gameBoard.tiles.map { TileView(tile: $0, coord: coordFromIdx($0.idx()), size: tileSize) }
            redraw()
        default:
            break
        }
    }
    
    func createExplosion(at position: CGPoint) {
        self.wantsLayer = true

        // Shockwave layer
        let shockwaveLayer = CALayer()
        let initialSize: CGFloat = 20
        shockwaveLayer.bounds = CGRect(x: 0, y: 0, width: initialSize, height: initialSize)
        shockwaveLayer.position = position
        shockwaveLayer.cornerRadius = initialSize / 2
        shockwaveLayer.borderWidth = 2.0
        shockwaveLayer.borderColor = NSColor.red.cgColor
        shockwaveLayer.opacity = 0.8
        self.layer?.addSublayer(shockwaveLayer)

        // Shockwave scale animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 4.0
        scaleAnimation.duration = 0.4

        // Shockwave fade animation
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.8
        fadeAnimation.toValue = 0.0
        fadeAnimation.duration = 0.4

        // Group animations for shockwave
        let shockwaveGroup = CAAnimationGroup()
        shockwaveGroup.animations = [scaleAnimation, fadeAnimation]
        shockwaveGroup.duration = 0.4
        shockwaveGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shockwaveGroup.isRemovedOnCompletion = false
        shockwaveGroup.fillMode = .forwards

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            shockwaveLayer.removeFromSuperlayer()
        }
        shockwaveLayer.add(shockwaveGroup, forKey: "shockwaveEffect")
        CATransaction.commit()

        // Particle emitter for explosion fragments
        let particleEmitter = CAEmitterLayer()
        particleEmitter.emitterPosition = position
        particleEmitter.emitterShape = .circle
        particleEmitter.emitterSize = CGSize(width: 10, height: 10)
        particleEmitter.emitterMode = .outline
        particleEmitter.birthRate = 10 // Emit particles only in a burst

        // Create a circular particle image
        let particleImage = createCircularParticleImage(radius: 5, color: .orange)

        // Particle cell
        let particle = CAEmitterCell()
        particle.birthRate = 200
        particle.lifetime = 0.5
        particle.velocity = 150
        particle.velocityRange = 50
        particle.scale = 0.1
        particle.scaleRange = 0.1
        particle.emissionRange = .pi * 2
        particle.contents = particleImage
        particle.alphaSpeed = -0.8

        // Add particle to emitter
        particleEmitter.emitterCells = [particle]
        self.layer?.addSublayer(particleEmitter)

        // Disable emission after initial burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            particleEmitter.birthRate = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                particleEmitter.removeFromSuperlayer()
            }
        }
    }

    // Helper function to create a circular CGImage for particles
    func createCircularParticleImage(radius: CGFloat, color: NSColor) -> CGImage? {
        let size = CGSize(width: radius * 2, height: radius * 2)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        let path = NSBezierPath(ovalIn: CGRect(origin: .zero, size: size))
        path.fill()
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
