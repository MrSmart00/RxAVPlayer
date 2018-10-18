//
//  MockControlableView.swift
//  RxAVPlayerTests
//
//  Created by HINOMORI HIROYA on 2018/10/18.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit
import RxSwift

class MockControlableView: UIView, RxAVPlayerControllable {
    var category: PlayerControlCategory = .initialize

    var player: RxAVPlayer?

    var eventObservable: Observable<RxAVPlayerEvent>?


    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
