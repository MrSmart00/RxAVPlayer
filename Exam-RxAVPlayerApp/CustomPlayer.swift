//
//  CustomPlayer.swift
//  Exam-RxAVPlayerApp
//
//  Created by HINOMORI HIROYA on 2018/09/11.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import AVFoundation

@objc
enum CustomPlayerStatus: Int {
    case prepare
    case impression
    case firstQ
    case secondQ
    case thirdQ
    case completion
}

class CustomPlayer: RxAVPlayer {

    private let disposebag = DisposeBag()
    private let currentStatusRelay = BehaviorRelay<CustomPlayerStatus>(value: .prepare)
    var currentStatusObservable: Observable<CustomPlayerStatus> {
        return currentStatusRelay.asObservable()
    }
    private var onceTimerObservable: Observable<Int>?
    private let viewableRelay = PublishRelay<Void>()
    var viewableObservable: Observable<Void> {
        return viewableRelay.asObservable()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        progressObservable.subscribe(onNext: { [weak self] (time) in
            guard let weakSelf = self else { return }
            if let status = weakSelf.translateStatus(current: time) {
                weakSelf.currentStatusRelay.accept(status)
            }
            if weakSelf.onceTimerObservable == nil {
                let obs = Observable<Int>
                    .interval(1, scheduler: MainScheduler.asyncInstance)
                    .single()
                obs.subscribe(onNext: { (_) in
                    weakSelf.viewableRelay.accept()
                }).disposed(by: weakSelf.disposebag)
                weakSelf.onceTimerObservable = obs
            }
        }).disposed(by: disposebag)
    }
    
    private func translateStatus(current: CMTime) -> CustomPlayerStatus? {
        var status: CustomPlayerStatus? = nil
        guard let duration = player?.currentItem?.duration else { return status }
        let elapse = CMTimeGetSeconds(current)
        let completion = CMTimeGetSeconds(duration)
        let percent = elapse / completion
        switch percent {
        case 0:
            status = .prepare
        case ..<0.25:
            status = .impression
        case 0.25..<0.5:
            status = .firstQ
        case 0.5..<0.75:
            status = .secondQ
        case 0.75..<1:
            status = .thirdQ
        default:
            status = .completion
        }
        return status
    }
}
