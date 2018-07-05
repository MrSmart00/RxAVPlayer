//
//  RxAVPlayerPauseControlView.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/05.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import AVFoundation
import UIKit
import RxSwift
import RxCocoa

class RxAVPlayerPauseControlView: UIView, RxAVPlayerControllable {
    
    var player: RxAVPlayer?
    
    @IBOutlet weak var muteButton: UIButton?
    
    @IBOutlet weak var seekBar: UISlider?

    @IBOutlet weak var currentTimeLabel: UILabel?
    
    @IBOutlet weak var totalTimeLabel: UILabel?
    
    var remainingTimeLabel: UILabel?

    @IBOutlet weak var skipButton: UIButton?
    
    private let disposebag = DisposeBag()

    func setPlayer(_ player: RxAVPlayer?) {
        self.player = player
        if let button = skipButton {
            self.player?.skipObservable.map { !$0 }.bind(to: button.rx.isHidden).disposed(by: disposebag)
        }
    }
    
    @IBAction func mute() {
        if let p = player {
            p.changeMute()
        }
    }

    @IBAction func play() {
        if let p = player {
            p.play()
        }
    }
    
    @IBAction func changeSeek() {
        if let bar = seekBar {
            seek(bar.value)
        }
    }

    @IBAction func skip() {
        if let p = player {
            p.skip()
        }
    }
}
