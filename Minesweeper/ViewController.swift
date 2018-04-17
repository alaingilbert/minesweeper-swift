//
//  ViewController.swift
//  Minesweeper
//
//  Created by Alain Gilbert on 3/10/18.
//  Copyright © 2018 None. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        gameView.flagsLbL = flagsLbl
        gameView.timerLbl = timerLbl
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBOutlet weak var timerLbl: NSTextField!
    @IBOutlet weak var flagsLbl: NSTextField!
    @IBOutlet weak var gameView: GameView!
    
}

