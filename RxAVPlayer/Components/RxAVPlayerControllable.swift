//
//  RxAVPlayerControllable.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/05.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit

struct PlayerControlCategory: OptionSet {
    typealias RawValue = Int
    let rawValue: Int
    static let initialize = PlayerControlCategory(rawValue: 1 << 0)
    static let play = PlayerControlCategory(rawValue: 1 << 1)
    static let pause = PlayerControlCategory(rawValue: 1 << 2)
    static let finish = PlayerControlCategory(rawValue: 1 << 3)
    static let stall = PlayerControlCategory(rawValue: 1 << 4)
    static let failed = PlayerControlCategory(rawValue: 1 << 5)
    init(rawValue: PlayerControlCategory.RawValue) {
        self.rawValue = rawValue
    }
}

protocol RxAVPlayerControllable {
    var category: PlayerControlCategory { get }
    var player: RxAVPlayer? { get set }
}
