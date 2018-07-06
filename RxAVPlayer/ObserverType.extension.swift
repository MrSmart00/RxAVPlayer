//
//  ObserverType.extension.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/06.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import Foundation
import RxSwift

extension ObserverType where E == Void {
    public func onNext() {
        onNext(())
    }
}
