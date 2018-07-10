//
//  EndcardControlView.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/06.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit

class EndcardControlView: UIView, RxAVPlayerControllable, RxAVPlayerTouchable, RxAVPlayerClosable {
    @IBOutlet weak var closeButton: UIButton?
    
    @IBOutlet weak var contentButton: UIButton?
    
    var player: RxAVPlayer?
    
    var muteButton: UIButton?
    
    var remainingTimeLabel: UILabel?
    
    func setPlayer(_ player: RxAVPlayer?) {
        self.player = player
    }
    
    func mute() {

    }
    
    @IBAction func play() {
        if let p = player {
            p.play()
        }
    }

}
