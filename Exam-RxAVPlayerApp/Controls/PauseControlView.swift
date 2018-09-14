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

class PauseControlView: UIView, RxAVPlayerControllable, RxAVPlayerTimeControllable, RxAVPlayerSoundMutable, RxAVPlayerSkippable {
    var formatter: DateFormatter? = DateFormatter()
    
    var category: PlayerControlCategory = [.initialize, .pause]
    
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
    
    private var initialize = true
    
    override func awakeFromNib() {
        guard let player = self.player else { return }
        muteButton?.rx.tap.bind { [weak self] in
            self?.changeMute()
        }.disposed(by: disposebag)
        forwardButton?.rx.tap.bind { [weak self] in
            self?.forward(10)
        }.disposed(by: disposebag)
        rewindButton?.rx.tap.bind { [weak self] in
            self?.rewind(10)
        }.disposed(by: disposebag)
        skipButton?.rx.tap.bind { [weak self] in
            self?.skip()
        }.disposed(by: disposebag)

        playButton?.rx.tap.bind(to: player.rx.play()).disposed(by: disposebag)
        
        if let btn = skipButton {
            player.seekObservable.map { !($0 > 0.2) }.bind(to: btn.rx.isHidden).disposed(by: disposebag)
        }
        
        formatter?.dateFormat = "mm:ss"
        let defaultText = formatter?.string(from: Date(timeIntervalSince1970: 0))
        remainingTimeLabel?.text = defaultText
        currentTimeLabel?.text = defaultText
        totalTimeLabel?.text = defaultText
    }
    
    override var isHidden: Bool {
        didSet {
            if !isHidden {
                if initialize, let p = player?.player {
                    initialize = false
                    p.rx.mute.bind { [weak self] (enable) in
                        if enable {
                            self?.muteButton?.setTitle("🔈", for: .normal)
                        } else {
                            self?.muteButton?.setTitle("🔇", for: .normal)
                        }
                        }.disposed(by: disposebag)
                }
            }
        }
    }
}
