//
//  RxAVPlayerControllable.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/05.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit

protocol RxAVPlayerControllable {
    
    var player: RxAVPlayer? { get set }
    var muteButton: UIButton? { get }
    var remainingTimeLabel: UILabel? { get }
    
    func bind()
    
}
