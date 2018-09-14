//
//  SoundMutable.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/09/06.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit
import AVFoundation

protocol RxAVPlayerSoundMutable: RxAVPlayerControllable {
    var muteButton: UIButton? { get }
    func changeMute()
}

extension RxAVPlayerSoundMutable {
    func changeMute() {
        if let p = player {
            p.mute = !p.mute
        }
    }
}
