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

class RxAVPlayerPauseControlView: UIView, RxAVPlayerControllable, RxAVPlayerTimeControllable {
    
    private let disposebag = DisposeBag()

    @IBOutlet weak var seekBar: UISlider?
    
    @IBOutlet weak var currentTimeLabel: UILabel?
    
    @IBOutlet weak var totalTimeLabel: UILabel?
    
    @IBOutlet weak var forwardButton: UIButton?
    
    @IBOutlet weak var rewindButton: UIButton?
    
    var player: RxAVPlayer?
    
    @IBOutlet weak var muteButton: UIButton?
    
    var remainingTimeLabel: UILabel?
    
    @IBOutlet weak var skipButton: UIButton?
    
    @IBOutlet weak var playButton: UIButton?
    
    override func awakeFromNib() {
        guard let player = self.player else { return }
        muteButton?.rx.tap.bind(to: player.rx.changeMute()).disposed(by: disposebag)
        forwardButton?.rx.tap.bind(to: player.rx.forward()).disposed(by: disposebag)
        rewindButton?.rx.tap.bind(to: player.rx.rewind()).disposed(by: disposebag)
        skipButton?.rx.tap.bind(to: player.rx.skip()).disposed(by: disposebag)
        playButton?.rx.tap.bind(to: player.rx.play()).disposed(by: disposebag)
    }
}
