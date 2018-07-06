//
//  RxAVPlayerPlayControlView.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/05.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import AVFoundation
import UIKit
import RxSwift
import RxCocoa

class RxAVPlayerPlayControlView: UIView, RxAVPlayerControllable, RxAVPlayerTimeControllable {
    
    var player: RxAVPlayer?
    
    @IBOutlet weak var muteButton: UIButton?
    
    @IBOutlet weak var seekBar: UISlider?
    
    @IBOutlet weak var currentTimeLabel: UILabel?
    
    @IBOutlet weak var totalTimeLabel: UILabel?
    
    var remainingTimeLabel: UILabel?

    @IBOutlet weak var forwardButton: UIButton?
    
    @IBOutlet weak var rewindButton: UIButton?

    @IBOutlet weak var skipButton: UIButton?
    
    private let disposebag = DisposeBag()
    
    func setPlayer(_ player: RxAVPlayer?) {
        self.player = player
        if let button = skipButton {
            self.player?.skipObservable.map { !$0 }.bind(to: button.rx.isHidden).disposed(by: disposebag)
        }
    }
    
    @IBAction func forward() {
        if let p = player {
            p.forward()
        }
    }
    
    @IBAction func rewind() {
        if let p = player {
            p.rewind()
        }
    }
    
    @IBAction func mute() {
        if let p = player {
            p.changeMute()
        }
    }
    
    @IBAction func pause() {
        if let p = player {
            p.pause()
        }
    }
    
    @IBAction func seek(_ value: Float) {
        if let bar = seekBar , let p = player {
            let totalInterval = p.totalDate.timeIntervalSince1970
            let target = totalInterval * TimeInterval(bar.value)
            let time = CMTimeMakeWithSeconds(Float64(target), Int32(NSEC_PER_SEC))
            p.seek(distance: time, skip: false)
        }
    }

    @IBAction func skip() {
        if let p = player {
            p.skip()
        }
    }
}
