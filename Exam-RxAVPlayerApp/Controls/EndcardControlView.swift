//
//  EndcardControlView.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/06.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class EndcardControlView: UIView, RxAVPlayerControllable {
    var category: PlayerControlCategory = [.finish]
    
    private let disposebag = DisposeBag()
    
    @IBOutlet weak var closeButton: UIButton?
    
    @IBOutlet weak var contentButton: UIButton?
    
    @IBOutlet weak var playButton: UIButton!
    
    var player: RxAVPlayer?
    
    var muteButton: UIButton?
    
    var remainingTimeLabel: UILabel?
    
    var count: Int = 0
    
    override func awakeFromNib() {
        guard let player = self.player else { return }
        playButton.rx.tap.bind(to: player.rx.play()).disposed(by: disposebag)
        
        closeButton?.rx.tap.subscribe(onNext: { [weak self] (_) in
            self?.player?.customEventRelay.accept(["close": "hogehoge \(self?.count)"])
            self?.count += 1
        }).disposed(by: disposebag)
        contentButton?.rx.tap.subscribe(onNext: { [weak self] (_) in
            self?.player?.customEventRelay.accept(["touch": "hugahugahuga"])
        }).disposed(by: disposebag)

    }
}
