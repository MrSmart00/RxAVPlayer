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

@objc enum RxPlayerStatus: Int {
    case none
    case ready
    case playing
    case pause
    case seeking
    case skipping
    case deadend
    case failed
}

@objc enum RxPlayerProgressStatus: Int {
    case none
    case impression
    case viewable
    case firstQ
    case secondQ
    case thirdQ
    case completion
}

@objcMembers class RxAVPlayer: UIView {
    
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
    
    var autoplay = false
    var mute: Bool = false {
        didSet {
            player?.isMuted = mute
        }
    }
    var visibleSkipSeconds: Float = -1
    var forwordSeconds: Int64 = 10
    var rewindSeconds: Int64 = 10
    var dateFormatString = "mm:ss" {
        didSet {
            formatter.dateFormat = dateFormatString
            allControls.forEach { (control) in
                if let label = control.remainingTimeLabel, (label.text == nil || label.text == "Label") {
                    label.text = formatter.string(from: Date(timeIntervalSince1970: 0))
                }
                if let timecontrol = control as? RxAVPlayerTimeControllable {
                    if let label = timecontrol.currentTimeLabel, (label.text == nil || label.text == "Label") {
                        label.text = formatter.string(from: Date(timeIntervalSince1970: 0))
                    }
                    if let label = timecontrol.totalTimeLabel, (label.text == nil || label.text == "Label") {
                        label.text = formatter.string(from: Date(timeIntervalSince1970: 0))
                    }
                }
                
            }
        }
    }
    private(set) var totalDate = Date.distantPast
    private let formatter = DateFormatter()
    
    private let disposebag = DisposeBag()
    private let statusSubject = BehaviorSubject<RxPlayerStatus>(value: .none)
    var statusObservable: Observable<RxPlayerStatus> {
        return statusSubject
    }
    private let progressSubject = BehaviorSubject<RxPlayerProgressStatus>(value: .none)
    var progressObservable: Observable<RxPlayerProgressStatus> {
        return progressSubject
    }
    private let movieEndSubject = BehaviorSubject<Bool>(value: false)
    private lazy var seekbarSubject = BehaviorSubject<Float>(value: 0)
    private lazy var skipVisibleBehavior = BehaviorSubject<Bool>(value: false)
    var skipObservable: Observable<Bool> {
        return skipVisibleBehavior
    }
    
    private var viewableObservable: Observable<Int>?
    
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
            statusSubject.onNext(.none)
            guard let movieURL = url else {
                statusSubject.onNext(.failed)
                return
            }
            if movieURL.isFileURL {
                guard let check = try? movieURL.checkResourceIsReachable() else {
                    statusSubject.onNext(.failed)
                    return
                }
                guard check else {
                    statusSubject.onNext(.failed)
                    return
                }
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
    
    var endcardImageURL: URL? {
        didSet {
            if let url = endcardImageURL, deadendControlView is RxAVPlayerEndControllable {
                URLSession(configuration: .default).dataTask(with: url) { [weak self] (data, _, error) in
                    guard let weakSelf = self else { return }
                    if let imgdata = data, let image = UIImage(data: imgdata), let endcard = weakSelf.deadendControlView as? RxAVPlayerEndControllable {
                        DispatchQueue.main.async {
                            endcard.endcardImage?.image = image
                        }
                    }
                    }.resume()
            }
        }
    }
    
    var userInfo: Any?
    private lazy var touchSubject = PublishSubject<Any?>()
    var touchObservable: Observable<Any?> {
        return touchSubject
    }
    
    private lazy var closeSubject = PublishSubject<Void>()
    var closeObservable: Observable<Void> {
        return closeSubject
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        formatter.dateFormat = dateFormatString
        
        allControls.forEach { (control) in
            control.setPlayer(self)
            if let view = control as? UIView {
                view.isHidden = true
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: OperationQueue.main) { [weak self] (notify) in
            guard let weakSelf = self else { return }
            weakSelf.movieEndSubject.onNext(true)
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled, object: nil, queue: OperationQueue.main) { (notify) in
            
        }
    }
    
    private func registerTimeObserver(_ player: AVPlayer) {
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 10), queue: DispatchQueue.main) { [weak self] (time) in
            guard let weakSelf = self else { return }
            if CMTimeGetSeconds(time) > Float64(weakSelf.visibleSkipSeconds), !weakSelf.skipVisibleBehavior.isDisposed {
                weakSelf.skipVisibleBehavior.onNext(true)
                weakSelf.skipVisibleBehavior.onCompleted()
            }
            if weakSelf.viewableObservable == nil {
                let timerObs = Observable<Int>.timer(1.0, scheduler: MainScheduler.asyncInstance)
                timerObs.subscribe(onNext: { (_) in
                    weakSelf.progressSubject.onNext(.viewable)
                }).disposed(by: weakSelf.disposebag)
                weakSelf.viewableObservable = timerObs
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
                    if let timecontrol = control as? RxAVPlayerTimeControllable {
                        timecontrol.currentTimeLabel?.text = weakSelf.formatter.string(from: date)
                    }
                    control.remainingTimeLabel?.text = weakSelf.formatter.string(from: remainDate)
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
            progressSubject.onNext(.completion)
        case 0.25..<0.5:
            progressSubject.onNext(.firstQ)
        case 0.5..<0.75:
            progressSubject.onNext(.secondQ)
        case 0.75..<1:
            progressSubject.onNext(.thirdQ)
        default:
            break
        }
    }
    
    private func bind() {
        if let pl = player, let item = pl.currentItem {
            statusSubject.subscribe(onNext: { [weak self] (st) in
                guard let weakSelf = self else { return }
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
                    guard let weakSelf = self else { return }
                    if playable {
                        if let status = try? weakSelf.statusSubject.value() {
                            if status == .none {
                                weakSelf.statusSubject.onNext(.ready)
                                weakSelf.progressSubject.onNext(.impression)
                            }
                            
                            weakSelf.movieEndSubject.onNext(false)
                            if let p = weakSelf.player {
                                if let total = p.currentItem?.duration {
                                    weakSelf.totalDate = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(total) ))
                                    weakSelf.allControls.forEach { (control) in
                                        if let timecontrol = control as? RxAVPlayerTimeControllable {
                                            timecontrol.totalTimeLabel?.text = weakSelf.formatter.string(from: weakSelf.totalDate)
                                        }
                                    }
                                }
                                if weakSelf.autoplay, status != .deadend {
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
                
                if let timecontrol = control as? RxAVPlayerTimeControllable, let seek = timecontrol.seekBar {
                    Observable.combineLatest(statusSubject, seekbarSubject, resultSelector: { ($0, $1) }).bind(onNext: { [weak seek] (status, value) in
                        guard let weakSeak = seek else { return }
                        if status != .seeking, !weakSeak.isTracking {
                            weakSeak.value = value
                        }
                    }).disposed(by: disposebag)
                    
                    seek.rx.controlEvent([.touchUpInside, .touchUpOutside]).bind { [weak self] (_) in
                        guard let weakSelf = self else { return }
                        if let sbar = timecontrol.seekBar {
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
                if let touchControl = control as? RxAVPlayerTouchable {
                    touchControl.contentButton?.rx.controlEvent(.touchUpInside).bind(onNext: { [weak self] (_) in
                        guard let weakSelf = self else { return }
                        weakSelf.touchSubject.onNext(weakSelf.userInfo)
                    }).disposed(by: disposebag)
                }
                if let closeControl = control as? RxAVPlayerClosable {
                    closeControl.closeButton?.rx.controlEvent(.touchUpInside).bind(onNext: { [weak self] (_) in
                        guard let weakSelf = self else { return }
                        weakSelf.closeSubject.onNext()
                    }).disposed(by: disposebag)
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
                    guard let weakSelf = self else { return }
                    if let status = try? weakSelf.statusSubject.value(), status != .deadend, status != .none {
                        if playing {
                            weakSelf.statusSubject.onNext(.playing)
                        } else {
                            weakSelf.statusSubject.onNext(.pause)
                        }
                    }
                }.disposed(by: disposebag)
            
            movieEndSubject.bind { [weak self] (completion) in
                guard let weakSelf = self else { return }
                if completion {
                    weakSelf.statusSubject.onNext(.deadend)
                }
                }.disposed(by: disposebag)
        }
    }
    
    func seek(distance: CMTime, skip: Bool) {
        var needsPlay = false
        if let status = try? statusSubject.value(), status != .deadend {
            if status != .skipping {
                statusSubject.onNext(.seeking)
            }
            needsPlay = true
        }
        if let pl = player {
            if skip {
                pl.seek(to: distance, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self] (completion) in
                    guard let weakSelf = self else { return }
                    if completion {
                        if needsPlay {
                            weakSelf.play()
                        } else {
                            weakSelf.pause()
                        }
                    }
                })
            } else {
                pl.seek(to: distance, completionHandler: { [weak self] (completion) in
                    guard let weakSelf = self else { return }
                    if completion {
                        if needsPlay {
                            weakSelf.play()
                        } else {
                            weakSelf.pause()
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
            statusSubject.onNext(.skipping)
            let distanceTime = CMTimeMake(time.value - 1, time.timescale)
            seek(distance: distanceTime, skip: true)
        }
    }
    
    @objc func rewind() {
        if let pl = player {
            let delta = CMTimeGetSeconds(pl.currentTime()) - Float64(rewindSeconds)
            seek(distance: CMTimeMake(Int64(delta), 1), skip: false)
        }
    }
    
    @objc func forward() {
        if let pl = player {
            let delta = CMTimeGetSeconds(pl.currentTime()) + Float64(forwordSeconds)
            seek(distance: CMTimeMake(Int64(delta), 1), skip: false)
        }
    }
    
    @objc func replay() {
        if totalDate.compare(Date.distantPast) != .orderedSame {
            let time = CMTimeMakeWithSeconds(0, Int32(NSEC_PER_SEC))
            seek(distance: time, skip: false)
        }
    }
    
    @objc func play() {
        if let status = try? statusSubject.value(), status == .deadend {
            statusSubject.onNext(.none)
            replay()
        } else {
            player?.play()
        }
    }
    
    @objc func pause() {
        player?.pause()
    }
}
