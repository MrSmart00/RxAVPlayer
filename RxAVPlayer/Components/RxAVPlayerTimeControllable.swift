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
    var formatter: DateFormatter? { get }
    var seekBar: UISlider? { get }
    var currentTimeLabel: UILabel? { get }
    var totalTimeLabel: UILabel? { get }
    var remainingTimeLabel: UILabel? { get }
    var forwardButton: UIButton? { get }
    var rewindButton: UIButton? { get }
    
    func updateDate(_ time: CMTime)
    func updateDate(_ percent: Float)
    func forward(_ seconds: Int64)
    func rewind(_ seconds: Int64)
}

extension RxAVPlayerTimeControllable {
    func updateDate(_ time: CMTime) {
        if seekBar != nil {
            guard let tracking = seekBar?.isTracking, !tracking else { return }
        }
        if let totalDate = player?.totalDate {
            let date = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(time) ))
            currentTimeLabel?.text = formatter?.string(from: date)
            totalTimeLabel?.text = formatter?.string(from: totalDate)
            if remainingTimeLabel != nil {
                let delta = round(totalDate.timeIntervalSince(date))
                let remainDate = Date(timeIntervalSince1970: delta)
                remainingTimeLabel?.text = formatter?.string(from: remainDate)
            }
        }
    }
    
    func updateDate(_ percent: Float) {
        if let totalDate = player?.totalDate {
            let totalInterval = totalDate.timeIntervalSince1970
            let target = totalInterval * TimeInterval(percent)
            let date = Date(timeIntervalSince1970: target)
            if currentTimeLabel != nil {
                currentTimeLabel?.text = formatter?.string(from: date)
            }
            if remainingTimeLabel != nil {
                let delta = round(totalDate.timeIntervalSince(date))
                let remainDate = Date(timeIntervalSince1970: delta)
                remainingTimeLabel?.text = formatter?.string(from: remainDate)
            }
        }
    }
    
    func forward(_ seconds: Int64) {
        guard let currentTime = player?.player?.currentTime() else { return }
        let delta = CMTimeGetSeconds(currentTime) + Float64(seconds)
        player?.seek(distance: CMTimeMake(value: Int64(delta), timescale: 1))
    }
    
    func rewind(_ seconds: Int64) {
        guard let currentTime = player?.player?.currentTime() else { return }
        let delta = CMTimeGetSeconds(currentTime) - Float64(seconds)
        player?.seek(distance: CMTimeMake(value: Int64(delta), timescale: 1))
    }
}

