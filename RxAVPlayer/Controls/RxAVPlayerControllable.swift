//
//  RxAVPlayerControllable.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/05.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import AVFoundation
import UIKit

protocol RxAVPlayerControllable {
    
    var player: RxAVPlayer? { get set }
    
    var muteButton: UIButton? { get }
    var seekBar: UISlider? { get }
    var currentTimeLabel: UILabel? { get }
    var totalTimeLabel: UILabel? { get }
    var remainingTimeLabel: UILabel? { get }
    
    func setPlayer(_ player: RxAVPlayer?)
    func mute()
    func seek(_ value: Float)
}

extension RxAVPlayerControllable {
    
    func seek(_ value: Float) {
        if let p = player {
            let totalInterval = p.totalDate.timeIntervalSince1970
            let target = totalInterval * TimeInterval(value)
            let time = CMTimeMakeWithSeconds(Float64(target), Int32(NSEC_PER_SEC))
            p.seek(distance: time, skip: false)
        }
    }
    
}
