//
//  RxAVPlayerControllable.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/05.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit

enum RxAVPlayerControlStatus {
    case none
    case initialize
    case play
    case pause
    case finish
    case stall
    case fail
}
protocol RxAVPlayerControllable {
    var status: RxAVPlayerControlStatus { get }
    var player: RxAVPlayer? { get set }
}
