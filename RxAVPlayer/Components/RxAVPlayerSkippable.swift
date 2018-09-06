//
//  RxAVSkippable.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/09/06.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit
import AVFoundation

protocol RxAVPlayerSkippable: RxAVPlayerControllable {
    var skipButton: UIButton? { get }
    func skip()
}

extension RxAVPlayerSkippable {
    func skip() {
        if let p = player?.player, let time = p.currentItem?.duration {
            let distanceTime = CMTimeMake(time.value - 1, time.timescale)
            player?.seek(distance: distanceTime)
        }
    }
}
