//
//  RxAVPlayerTimeControllable.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/06.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit

protocol RxAVPlayerTimeControllable {
    
    var seekBar: UISlider? { get }
    var currentTimeLabel: UILabel? { get }
    var totalTimeLabel: UILabel? { get }
    var forwardButton: UIButton? { get }
    var rewindButton: UIButton? { get }

}
