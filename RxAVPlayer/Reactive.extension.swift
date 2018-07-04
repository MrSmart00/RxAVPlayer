//
//  Reactive.extension.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/04.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import Foundation
import AVFoundation

import RxSwift
import RxCocoa


extension Reactive where Base: AVPlayer {
    
    var status: Observable<AVPlayerStatus> {
        return observe(AVPlayerStatus.self, #keyPath(AVPlayer.status)).map { $0 ?? .unknown }
    }
    
    var mute: Observable<Bool> {
        return observe(Bool.self, #keyPath(AVPlayer.isMuted)).map { $0 ?? false }
    }
    
    var rate: Observable<CGFloat> {
        return observe(CGFloat.self, #keyPath(AVPlayer.rate)).map { $0 ?? 0.0 }
    }
}

extension Reactive where Base: AVPlayerItem {
    
    var playbackLikelyToKeepUp: Observable<Bool> {
        return observe(Bool.self, #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp)).map { $0 ?? false }
    }
    
    var playbackBufferFull: Observable<Bool> {
        return observe(Bool.self, #keyPath(AVPlayerItem.isPlaybackBufferFull)).map { $0 ?? false }
    }
    
    var playbackBufferEmpty: Observable<Bool> {
        return observe(Bool.self, #keyPath(AVPlayerItem.isPlaybackBufferEmpty)).map { $0 ?? false }
    }
}
