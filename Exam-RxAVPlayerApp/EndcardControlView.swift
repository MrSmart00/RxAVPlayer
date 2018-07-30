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

class EndcardControlView: UIView, RxAVPlayerControllable, RxAVPlayerTouchable, RxAVPlayerClosable {
    
    private let disposebag = DisposeBag()
    
    func bind() {
        guard let player = self.player else { return }
        playButton.rx.controlEvent([.touchUpInside]).bind(to: player.rx.play()).disposed(by: disposebag)
    }

    @IBOutlet weak var closeButton: UIButton?
    
    @IBOutlet weak var contentButton: UIButton?
    
    @IBOutlet weak var playButton: UIButton!
    
    var player: RxAVPlayer?
    
    var muteButton: UIButton?
    
    var remainingTimeLabel: UILabel?
    
}
