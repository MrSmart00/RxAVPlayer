//
//  EndcardControlView.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/06.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit

class EndcardControlView: UIView, RxAVPlayerControllable, RxAVPlayerTouchable {
    @IBOutlet weak var contentButton: UIButton?
    
    var touchableUserInfo: Any?
    
    @IBAction func touchContent() {
        print(touchableUserInfo)
    }
    
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
