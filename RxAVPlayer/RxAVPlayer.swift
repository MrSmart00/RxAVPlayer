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
    var offset: CGFloat = 0.0
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
    private let statusRelay = BehaviorRelay<RxPlayerStatus>(value: .none)
    var statusObservable: Observable<RxPlayerStatus> {
        return statusRelay.asObservable()
    }
    private let progressRelay = BehaviorRelay<RxPlayerProgressStatus>(value: .none)
    var progressObservable: Observable<RxPlayerProgressStatus> {
        return progressRelay.asObservable()
    }
    
    private let movieEndRelay = PublishRelay<Void>()
    private lazy var seekRelay = BehaviorRelay<Float>(value: 0)
    var seekObservable: Observable<Float> {
        return seekRelay.asObservable()
    }
    
    private var skipVisibleRelay = BehaviorRelay<Bool>(value: false)
    var skipObservable: Observable<Bool> {
        return skipVisibleRelay.asObservable()
    }
    
    private lazy var touchRelay = PublishRelay<Any?>()
    var touchObservable: Observable<Any?> {
        return touchRelay.asObservable()
    }
    private lazy var closeRelay = PublishRelay<Void>()
    var closeObservable: Observable<Void> {
        return closeRelay.asObservable()
    }
    
    private var viewableObservable: Observable<Int>?
    
    @IBOutlet weak var initialControlView: UIView? {
        didSet {
            setPlayer(controlView: initialControlView)
        }
    }
    @IBOutlet weak var playControlView: UIView? {
        didSet {
            setPlayer(controlView: playControlView)
        }
    }
    @IBOutlet weak var pauseControlView: UIView? {
        didSet {
            setPlayer(controlView: pauseControlView)
        }
    }
    @IBOutlet weak var deadendControlView: UIView? {
        didSet {
            setPlayer(controlView: deadendControlView)
        }
    }
    @IBOutlet weak var failedControlView: UIView? {
        didSet {
            setPlayer(controlView: failedControlView)
        }
    }
    @IBOutlet weak var stalledControlView: UIView? {
        didSet {
            setPlayer(controlView: stalledControlView)
        }
    }
    
    var allControls: [RxAVPlayerControllable] {
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
        if let view = stalledControlView as? RxAVPlayerControllable {
            list.append(view)
        }
        if let view = failedControlView as? RxAVPlayerControllable {
            list.append(view)
        }
        return list
    }
    
    var url: URL? {
        didSet {
            statusRelay.accept(.none)
            skipVisibleRelay = BehaviorRelay<Bool>(value: false)
            guard let movieURL = url else {
                statusRelay.accept(.failed)
                return
            }
            if movieURL.isFileURL {
                guard let check = try? movieURL.checkResourceIsReachable() else {
                    statusRelay.accept(.failed)
                    return
                }
                guard check else {
                    statusRelay.accept(.failed)
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    func initialize() {
        formatter.dateFormat = dateFormatString
        registerNotifications()
    }
    
    private func setPlayer(controlView: UIView?) {
        var control = controlView as? RxAVPlayerControllable
        if control != nil {
            control?.player = self
        }
    }
    
    private func registerNotifications() {
        NotificationCenter.default.rx.notification(.AVAudioSessionInterruption).bind { [weak self] (notify) in
            guard let weakSelf = self else { return }
            let status = weakSelf.statusRelay.value
            if status == .playing {
                guard let interruption = notify.userInfo?[AVAudioSessionInterruptionTypeKey] as? AVAudioSessionInterruptionType else { return }
                switch interruption {
                case .began:
                    weakSelf.statusRelay.accept(.pause)
                case .ended:
                    weakSelf.play()
                }
            }
            }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.AVAudioSessionRouteChange).bind { [weak self] (notify) in
            guard let weakSelf = self else { return }
            if weakSelf.statusRelay.value == .playing {
                weakSelf.play()
            }
            }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.AVPlayerItemDidPlayToEndTime).bind { [weak self] (notify) in
            guard let weakSelf = self else { return }
            guard let item = notify.object as? AVPlayerItem, item == weakSelf.player?.currentItem else { return }
            weakSelf.movieEndRelay.accept()
            }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.AVPlayerItemFailedToPlayToEndTime).bind { [weak self] (notify) in
            guard let weakSelf = self else { return }
            weakSelf.statusRelay.accept(.failed)
            }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.AVPlayerItemPlaybackStalled).bind { [weak self] (notify) in
            guard let weakSelf = self else { return }
            if let control = weakSelf.stalledControlView {
                weakSelf.allControls.forEach({ (control) in
                    if let view = control as? UIView {
                        view.isHidden = true
                    }
                })
                control.isHidden = false
            }
            }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.UIApplicationDidEnterBackground).bind { [weak self] (notify) in
            guard let weakSelf = self else { return }
            if weakSelf.statusRelay.value == .playing {
                weakSelf.pause()
            }
            }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.UIApplicationWillEnterForeground).bind { [weak self] (notify) in
            guard let weakSelf = self else { return }
            if weakSelf.statusRelay.value == .pause {
                weakSelf.play()
            }
            }.disposed(by: disposebag)
    }
    
    private func registerTimeObserver(_ player: AVPlayer) {
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 10), queue: DispatchQueue.main) { [weak self] (time) in
            guard let weakSelf = self else { return }
            if !weakSelf.skipVisibleRelay.value, CMTimeGetSeconds(time) > Float64(weakSelf.visibleSkipSeconds) {
                weakSelf.skipVisibleRelay.accept(true)
            }
            if weakSelf.viewableObservable == nil {
                let timerObs = Observable<Int>.timer(1.0, scheduler: MainScheduler.asyncInstance)
                timerObs.subscribe(onNext: { (_) in
                    weakSelf.progressRelay.accept(.viewable)
                }).disposed(by: weakSelf.disposebag)
                weakSelf.viewableObservable = timerObs
            }
            
            if let p = weakSelf.player, let item = p.currentItem {
                weakSelf.manageTimeStatus(current: time, duration: item.duration)
                let date = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(time) ))
                let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                let delta = round(weakSelf.totalDate.timeIntervalSince(date))
                
                let remainDate = Date(timeIntervalSince1970: delta)
                var hasSeekbar = false
                weakSelf.allControls.forEach { (control) in
                    if let timecontrol = control as? RxAVPlayerTimeControllable {
                        guard let tracking = timecontrol.seekBar?.isTracking, !tracking else { return }
                        guard weakSelf.statusRelay.value != .seeking else { return }
                        timecontrol.currentTimeLabel?.text = weakSelf.formatter.string(from: date)
                        hasSeekbar = true
                    }
                    control.remainingTimeLabel?.text = weakSelf.formatter.string(from: remainDate)
                }
                if hasSeekbar {
                    let percent = 1.0 - delta / totalInterval
                    weakSelf.seekRelay.accept(Float(percent))
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
            if progressRelay.value != .completion {
                progressRelay.accept(.completion)
            }
        case 0.25..<0.5:
            progressRelay.accept(.firstQ)
        case 0.5..<0.75:
            progressRelay.accept(.secondQ)
        case 0.75..<1:
            progressRelay.accept(.thirdQ)
        default:
            break
        }
    }
    
    private func bind() {
        if let pl = player, let item = pl.currentItem {
            statusRelay.subscribe(onNext: { [weak self] (st) in
                guard let weakSelf = self else { return }
                var targetView: UIView?
                switch st {
                case .none, .ready:
                    targetView = weakSelf.initialControlView
                case .playing:
                    targetView = weakSelf.playControlView
                case .pause:
                    targetView = weakSelf.pauseControlView
                case .deadend:
                    targetView = weakSelf.deadendControlView
                case .failed:
                    targetView = weakSelf.failedControlView
                default:
                    break
                }
                if let control = targetView {
                    weakSelf.allControls.forEach({ (control) in
                        if let view = control as? UIView {
                            view.isHidden = true
                        }
                    })
                    control.isHidden = false
                }
            }).disposed(by: disposebag)
            
            item.rx.playbackBufferEmpty.bind { [weak self] (empty) in
                guard let weakSelf = self else { return }
                if let item = weakSelf.player?.currentItem, !item.isPlaybackBufferFull {
                    if !empty {
                        weakSelf.statusRelay.accept(weakSelf.statusRelay.value)
                    }
                }
                }.disposed(by: disposebag)
            
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
                        let status = weakSelf.statusRelay.value
                        if status == .none, weakSelf.offset == 0 {
                            weakSelf.statusRelay.accept(.ready)
                            weakSelf.progressRelay.accept(.impression)
                        }
                        
                        if let p = weakSelf.player {
                            if let total = p.currentItem?.duration {
                                weakSelf.totalDate = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(total) ))
                                weakSelf.allControls.forEach { (control) in
                                    if let timecontrol = control as? RxAVPlayerTimeControllable {
                                        timecontrol.totalTimeLabel?.text = weakSelf.formatter.string(from: weakSelf.totalDate)
                                    }
                                }
                            }
                            if weakSelf.offset > 0 {
                                let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                                let target = totalInterval * TimeInterval(weakSelf.offset)
                                let time = CMTimeMakeWithSeconds(Float64(target), Int32(NSEC_PER_SEC))
                                weakSelf.seek(distance: time)
                                weakSelf.autoplay = false
                                weakSelf.offset = 0
                                weakSelf.statusRelay.accept(.ready)
                                weakSelf.progressRelay.accept(.impression)
                            } else if weakSelf.autoplay, status != .deadend {
                                weakSelf.play()
                            }
                        }
                    }
                }.disposed(by: disposebag)
            
            allControls.forEach { (control) in
                if let button = control.muteButton {
                    pl.rx.mute.bind(to: button.rx.isSelected).disposed(by: disposebag)
                }
                
                if let timecontrol = control as? RxAVPlayerTimeControllable, let seek = timecontrol.seekBar {
                    Observable.combineLatest(statusRelay, seekRelay, resultSelector: { ($0, $1) }).bind(onNext: { [weak seek] (status, value) in
                        guard let weakSeak = seek else { return }
                        if status != .seeking, !weakSeak.isTracking {
                            weakSeak.value = value
                        }
                    }).disposed(by: disposebag)
                    
                    seek.rx.controlEvent([.valueChanged]).bind { [weak self] in
                        guard let weakSelf = self else { return }
                        if let sbar = timecontrol.seekBar {
                            weakSelf.seekRelay.accept(sbar.value)
                            weakSelf.allControls.forEach { (control) in
                                if let timecontrol = control as? RxAVPlayerTimeControllable {
                                    let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                                    let target = totalInterval * TimeInterval(sbar.value)
                                    let date = Date(timeIntervalSince1970: target)
                                    timecontrol.currentTimeLabel?.text = weakSelf.formatter.string(from: date)
                                }
                            }
                        }
                        }.disposed(by: disposebag)
                    
                    seek.rx.controlEvent([.touchUpInside, .touchUpOutside]).bind { [weak self] (_) in
                        guard let weakSelf = self else { return }
                        if let sbar = timecontrol.seekBar {
                            if weakSelf.totalDate.compare(Date.distantPast) != .orderedSame {
                                let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                                let target = totalInterval * TimeInterval(sbar.value)
                                let time = CMTimeMakeWithSeconds(Float64(target), Int32(NSEC_PER_SEC))
                                weakSelf.seek(distance: time)
                            }
                        }
                        }.disposed(by: disposebag)
                }
                
                if let touchControl = control as? RxAVPlayerTouchable {
                    touchControl.contentButton?.rx.controlEvent(.touchUpInside).bind(onNext: { [weak self] (_) in
                        guard let weakSelf = self else { return }
                        weakSelf.touchRelay.accept(weakSelf.userInfo)
                    }).disposed(by: disposebag)
                }
                if let closeControl = control as? RxAVPlayerClosable {
                    closeControl.closeButton?.rx.controlEvent(.touchUpInside).bind(onNext: { [weak self] (_) in
                        guard let weakSelf = self else { return }
                        weakSelf.closeRelay.accept()
                    }).disposed(by: disposebag)
                }
            }
            
            pl.rx.rate.map { $0 > 0 }.bind { [weak self] (progressive) in
                guard let weakSelf = self else { return }
                if progressive {
                    weakSelf.statusRelay.accept(.playing)
                } else if weakSelf.statusRelay.value != .deadend, weakSelf.statusRelay.value != .none {
                    weakSelf.statusRelay.accept(.pause)
                }
                }.disposed(by: disposebag)
            
            movieEndRelay.subscribe(onNext: { [weak self] in
                guard let weakSelf = self else { return }
                weakSelf.statusRelay.accept(.deadend)
                if weakSelf.progressRelay.value != .completion {
                    weakSelf.progressRelay.accept(.completion)
                }
            }).disposed(by: disposebag)
        }
    }
    
    func seek(distance: CMTime) {
        statusRelay.accept(.seeking)
        if let pl = player {
            pl.seek(to: distance, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self] (completion) in
                guard let weakSelf = self else { return }
                if completion {
                    weakSelf.play()
                }
            })
        }
    }
    
    func skip() {
        if let pl = player, let time = pl.currentItem?.duration {
            let distanceTime = CMTimeMake(time.value - 1, time.timescale)
            seek(distance: distanceTime)
        }
    }
    
    func rewind() {
        if let pl = player {
            let delta = CMTimeGetSeconds(pl.currentTime()) - Float64(rewindSeconds)
            seek(distance: CMTimeMake(Int64(delta), 1))
        }
    }
    
    func forward() {
        if let pl = player {
            let delta = CMTimeGetSeconds(pl.currentTime()) + Float64(forwordSeconds)
            seek(distance: CMTimeMake(Int64(delta), 1))
        }
    }
    
    func replay() {
        if totalDate.compare(Date.distantPast) != .orderedSame {
            let time = CMTimeMakeWithSeconds(0, 1)
            seek(distance: time)
        }
    }
    
    func changeMute() {
        if let pl = player {
            pl.isMuted = !pl.isMuted
        }
    }
    
    func play() {
        if statusRelay.value == .deadend {
            statusRelay.accept(.none)
            replay()
        } else {
            autoplay = false
            player?.play()
        }
    }
    
    func pause() {
        if statusRelay.value == .playing {
            player?.pause()
        }
    }
}
