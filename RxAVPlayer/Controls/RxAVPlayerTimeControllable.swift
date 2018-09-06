//
//  RxAVPlayerTimeControllable.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/06.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit
import AVFoundation

protocol RxAVPlayerTimeControllable: RxAVPlayerControllable {
    var seekBar: UISlider? { get }
    var currentTimeLabel: UILabel? { get }
    var totalTimeLabel: UILabel? { get }
    var remainingTimeLabel: UILabel? { get }
    var forwardButton: UIButton? { get }
    var rewindButton: UIButton? { get }
    func forward(_ seconds: Int64)
    func rewind(_ seconds: Int64)
}

extension RxAVPlayerTimeControllable {
    func forward(_ seconds: Int64) {
        guard let currentTime = player?.player?.currentTime() else { return }
        let delta = CMTimeGetSeconds(currentTime) + Float64(seconds)
        player?.seek(distance: CMTimeMake(Int64(delta), 1))
    }
    
    func rewind(_ seconds: Int64) {
        guard let currentTime = player?.player?.currentTime() else { return }
        let delta = CMTimeGetSeconds(currentTime) - Float64(seconds)
        player?.seek(distance: CMTimeMake(Int64(delta), 1))
    }
}
