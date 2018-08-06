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
    
    private let disposebag = DisposeBag()

    func bind() {
        guard let player = self.player else { return }
        muteButton?.rx.controlEvent([.touchUpInside]).bind(to: player.rx.changeMute()).disposed(by: disposebag)
        forwardButton?.rx.controlEvent([.touchUpInside]).bind(to: player.rx.forward()).disposed(by: disposebag)
        rewindButton?.rx.controlEvent([.touchUpInside]).bind(to: player.rx.rewind()).disposed(by: disposebag)
        skipButton?.rx.controlEvent([.touchUpInside]).bind(to: player.rx.skip()).disposed(by: disposebag)
        pauseButton.rx.controlEvent([.touchUpInside]).bind(to: player.rx.pause()).disposed(by: disposebag)
    }

    var player: RxAVPlayer?
    
    @IBOutlet weak var muteButton: UIButton?

    @IBOutlet weak var seekBar: UISlider?
    
    @IBOutlet weak var currentTimeLabel: UILabel?
    
    @IBOutlet weak var totalTimeLabel: UILabel?
    
    var remainingTimeLabel: UILabel?

    @IBOutlet weak var forwardButton: UIButton?
    
    @IBOutlet weak var rewindButton: UIButton?
    
    @IBOutlet weak var skipButton: UIButton?
    
    @IBOutlet weak var pauseButton: UIButton!

}
