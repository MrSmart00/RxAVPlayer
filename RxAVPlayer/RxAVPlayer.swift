//
//  RxAVPlayer.swift
//  RxAVPlayer
//
//  Created by HINOMORI HIROYA on 2018/07/04.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit
import AVFoundation
import RxSwift
import RxCocoa

enum PlayerStatus: Int {
    case none
    case ready
    case playing
    case pause
    case seeking
    case deadend
    case failed
}

enum ViewableStatus: Int {
    case none
    case impression
    case viewable
    case firstQ
    case secondQ
    case thirdQ
    case completion
}

class RxAVPlayer: UIView {

    let statusSubject = BehaviorSubject<PlayerStatus>(value: .none)
    var status: PlayerStatus = .none {
        didSet {
            if status != oldValue {
                statusSubject.onNext(status)
            }
        }
    }
    
    let viewStatusSubject = BehaviorSubject<ViewableStatus>(value: .none)
    var viewStatus: ViewableStatus = .none {
        didSet {
            if viewStatus != oldValue {
                viewStatusSubject.onNext(viewStatus)
            }
        }
    }
    
    var autoplay = false
    var mute: Bool = false {
        didSet {
            player?.isMuted = mute
        }
    }
    var visibleSkipSeconds: Float = -1

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    private var player: AVPlayer? {
        get {
            guard let pl = layer as? AVPlayerLayer else { return nil }
            return pl.player
        }
        set {
            guard let pl = layer as? AVPlayerLayer else { return }
            pl.player = newValue
        }
    }
    
    private let movieEndSubject = BehaviorSubject<Bool>(value: false)
    private lazy var seekbarSubject = BehaviorSubject<Float>(value: 0)
    var skipObservable: Observable<Bool> {
        return skipBehavior
    }
    private let skipBehavior = BehaviorSubject<Bool>(value: false)
    private let disposebag = DisposeBag()
    
    private(set) var totalDate = Date.distantPast
    private let formatter = DateFormatter()
    
    @IBOutlet weak var initialControlView: UIView?
    @IBOutlet weak var playControlView: UIView?
    @IBOutlet weak var pauseControlView: UIView?
    @IBOutlet weak var deadendControlView: UIView?
    
    private var allControls: [RxAVPlayerControllable] {
        var list = [RxAVPlayerControllable]()
        if let view = initialControlView as? RxAVPlayerControllable {
            list.append(view)
        }
        if let view = playControlView as? RxAVPlayerControllable {
            list.append(view)
        }
        if let view = pauseControlView as? RxAVPlayerControllable {
            list.append(view)
        }
        if let view = deadendControlView as? RxAVPlayerControllable {
            list.append(view)
        }
        return list
    }
    
    var url: URL? {
        didSet {
            status = .none
            guard let movieURL = url else { return }
            if movieURL.isFileURL {
                guard let check = try? movieURL.checkResourceIsReachable() else { return }
                guard check else { return }
            }
            let asset = AVAsset(url: movieURL)
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            registerTimeObserver(player)
            player.isMuted = mute
            self.player = player
            bind()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        status = .none
        viewStatus = .none
        
        formatter.dateFormat = "mm:ss"

        allControls.forEach { (control) in
            control.setPlayer(self)
            control.currentTimeLabel?.text = "00:00"
            control.remainingTimeLabel?.text = "00:00"
            control.totalTimeLabel?.text = "00:00"
            if let view = control as? UIView {
                view.isHidden = true
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: OperationQueue.main) { [weak self] (notify) in
            if let weakSelf = self {
                weakSelf.movieEndSubject.onNext(true)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled, object: nil, queue: OperationQueue.main) { (notify) in
            
        }
    }
    
    private func registerTimeObserver(_ player: AVPlayer) {
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 10), queue: DispatchQueue.main) { [weak self] (time) in
            if let weakSelf = self {
                if time.value == 0, weakSelf.visibleSkipSeconds > -1 {
                    Observable<Int>.timer(RxTimeInterval(weakSelf.visibleSkipSeconds), scheduler: MainScheduler.asyncInstance).bind(onNext: { [weak self] (_) in
                        if let weakSelf = self {
                            weakSelf.skipBehavior.onNext(true)
                        }
                    }).disposed(by: weakSelf.disposebag)
                }

                if let p = weakSelf.player, let item = p.currentItem {
                    weakSelf.manageTimeStatus(current: time, duration: item.duration)
                    let date = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(time) ))
                    let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                    let delta = round(weakSelf.totalDate.timeIntervalSince(date))
                    let percent = 1.0 - delta / totalInterval
                    weakSelf.seekbarSubject.onNext(Float(percent))

                    let remainDate = Date(timeIntervalSince1970: delta)
                    
                    weakSelf.allControls.forEach { (control) in
                        control.currentTimeLabel?.text = weakSelf.formatter.string(from: date)
                        control.remainingTimeLabel?.text = weakSelf.formatter.string(from: remainDate)
                    }
                }
            }
        }
    }
    
    private func manageTimeStatus(current: CMTime, duration: CMTime) {
        let elapse = CMTimeGetSeconds(current)
        let completion = CMTimeGetSeconds(duration)
        
        let percent = elapse / completion
        switch percent {
        case 1:
            viewStatus = .completion
        case 0.25..<0.5:
            viewStatus = .firstQ
        case 0.5..<0.75:
            viewStatus = .secondQ
        case 0.75..<1:
            viewStatus = .thirdQ
        default:
            break
        }
    }
    
    private func bind() {
        if let pl = player, let item = pl.currentItem {
            statusSubject.subscribe(onNext: { [weak self] (st) in
                if let weakSelf = self {
                    print("VIEWABLE SCORE : \(st)")
                    weakSelf.allControls.forEach({ (control) in
                        if let view = control as? UIView {
                            view.isHidden = true
                        }
                    })
                    switch st {
                    case .none, .ready:
                        (weakSelf.initialControlView ?? weakSelf.pauseControlView)?.isHidden = false
                    case .playing, .seeking:
                        weakSelf.playControlView?.isHidden = false
                    case .pause:
                        (weakSelf.pauseControlView ?? weakSelf.initialControlView)?.isHidden = false
                    case .deadend:
                        (weakSelf.deadendControlView ?? weakSelf.initialControlView ?? weakSelf.pauseControlView)?.isHidden = false
                    default:
                        break
                    }
                }
            }).disposed(by: disposebag)
            
            viewStatusSubject.subscribe(onNext: { (sc) in
                print("VIEWABLE SCORE : \(sc)")
            }).disposed(by: disposebag)
            
            let obs1 = item.rx.playbackLikelyToKeepUp
            let obs2 = pl.rx.status.map { $0 == .readyToPlay }
            Observable.combineLatest([obs1, obs2]).map { (list) -> Bool in
                for result in list {
                    if !result {
                        return false
                    }
                }
                return true
            }.bind { [weak self] (playable) in
                if let weakSelf = self {
                    if playable {
                        if weakSelf.status == .none {
                            weakSelf.status = .ready
                            weakSelf.viewStatus = .impression
                        }
                        
                        weakSelf.movieEndSubject.onNext(false)
                        if let p = weakSelf.player {
                            if let total = p.currentItem?.duration {
                                weakSelf.totalDate = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(total) ))
                                weakSelf.allControls.forEach { (control) in
                                    control.totalTimeLabel?.text = weakSelf.formatter.string(from: weakSelf.totalDate)
                                }
                            }
                            if weakSelf.autoplay {
                                p.play()
                            }
                        }
                    }
                }
            }.disposed(by: disposebag)

            allControls.forEach { (control) in
                if let button = control.muteButton {
                    pl.rx.mute.bind(to: button.rx.isSelected).disposed(by: disposebag)
                }
                
                if let seek = control.seekBar {
                    seekbarSubject.bind { [weak self] (value) in
                        if let weakSelf = self, weakSelf.status != .seeking, let sbar = control.seekBar, !sbar.isTracking {
                            sbar.value = value
                        }
                    }.disposed(by: disposebag)
                    
                    seek.rx.controlEvent([.touchUpInside, .touchUpOutside]).bind { [weak self] (_) in
                        if let weakSelf = self, let sbar = control.seekBar {
                            if weakSelf.totalDate.compare(Date.distantPast) != .orderedSame {
                                weakSelf.seekbarSubject.onNext(sbar.value)
                                let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                                let target = totalInterval * TimeInterval(sbar.value)
                                let time = CMTimeMakeWithSeconds(Float64(target), Int32(NSEC_PER_SEC))
                                weakSelf.seek(distance: time, skip: false)
                            }
                        }
                    }.disposed(by: disposebag)
                }
            }
            
            let obs3 = pl.rx.rate.map { $0 > 0 }
            let obs4 = movieEndSubject.map { $0 }
            Observable.combineLatest([obs3, obs4]).map { (list) -> Bool in
                for result in list {
                    if result {
                        return true
                    }
                }
                return false
            }.bind { [weak self] (playing) in
                if let weakSelf = self, weakSelf.status != .deadend {
                    if playing {
                        weakSelf.status = .playing
                    } else {
                        weakSelf.status = .pause
                    }
                }
            }.disposed(by: disposebag)
            
            movieEndSubject.bind { [weak self] (completion) in
                if let weakSelf = self, completion {
                    weakSelf.status = .deadend
                }
            }.disposed(by: disposebag)
        }
    }
    
    func seek(distance: CMTime, skip: Bool) {
        status = .seeking
        if let pl = player {
            if skip {
                pl.seek(to: distance, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self] (completion) in
                    if let weakSelf = self {
                        if completion {
                            weakSelf.play()
                        }
                    }
                })
            } else {
                pl.seek(to: distance, completionHandler: { [weak self] (completion) in
                    if let weakSelf = self {
                        if completion {
                            weakSelf.play()
                        }
                    }
                })
            }
        }

    }
    
    @objc func changeMute() {
        if let pl = player {
            pl.isMuted = !pl.isMuted
        }
    }
    
    @objc func skip() {
        if let pl = player, let time = pl.currentItem?.duration {
            let distanceTime = CMTimeMake(time.value - 1, time.timescale)
            seek(distance: distanceTime, skip: true)
        }
    }
    
    @objc func replay() {
        if totalDate.compare(Date.distantPast) != .orderedSame {
            let time = CMTimeMakeWithSeconds(0, Int32(NSEC_PER_SEC))
            seek(distance: time, skip: false)
        }
    }
    
    @objc func play() {
        if status == .deadend {
            status = .none
            replay()
        } else {
            player?.play()
        }
    }
    
    @objc func pause() {
        player?.pause()
    }
}
