//
//  RxAVPlayerTouchable.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/06.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit

protocol RxAVPlayerTouchable {
    
    var contentButton: UIButton? { get }
    var touchableUserInfo: Any? { get set }
    
    func touchContent()
    
}
