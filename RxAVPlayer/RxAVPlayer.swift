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

@objc
enum RxPlayerStatus: Int {
    case prepare
    case ready
    case playing
    case pause
    case seeking
    case deadend
    case failed
}

@objc
enum RxPlayerProgressStatus: Int {
    case prepare
    case impression
    case viewable
    case firstQ
    case secondQ
    case thirdQ
    case completion
}

@objcMembers
class RxAVPlayer: UIView {
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var player: AVPlayer? {
        get {
            guard let pl = layer as? AVPlayerLayer else { return nil }
            return pl.player
        }
        set {
            guard let pl = layer as? AVPlayerLayer else { return }
            pl.player = newValue
        }
    }
    private var periodicTimeObserver: Any?
    
    var offset: CGFloat = 0.0
    var autoplay = false
    var mute: Bool = false {
        didSet {
            player?.isMuted = mute
        }
    }
    var visibleSkipSeconds: Float = -1
    
    var dateFormatString = "mm:ss" {
        didSet {
            formatter.dateFormat = dateFormatString
            let defaultText = formatter.string(from: Date(timeIntervalSince1970: 0))
            if let cntls = controls {
                for control in cntls where control is RxAVPlayerTimeControllable {
                    if let timecontrol = control as? RxAVPlayerTimeControllable {
                        if let label = timecontrol.remainingTimeLabel, (label.text == nil || label.text == "Label") {
                            label.text = defaultText
                        }
                        if let label = timecontrol.currentTimeLabel, (label.text == nil || label.text == "Label") {
                            label.text = defaultText
                        }
                        if let label = timecontrol.totalTimeLabel, (label.text == nil || label.text == "Label") {
                            label.text = defaultText
                        }
                    }
                }
            }
        }
    }
    private(set) var totalDate = Date.distantPast
    private let formatter = DateFormatter()
    
    private let disposebag = DisposeBag()
    private let statusRelay = BehaviorRelay<RxPlayerStatus>(value: .prepare)
    var statusObservable: Observable<RxPlayerStatus> {
        return statusRelay.asObservable()
    }
    private let progressRelay = BehaviorRelay<RxPlayerProgressStatus>(value: .prepare)
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
    
    private lazy var closeRelay = PublishRelay<Void>()
    var closeObservable: Observable<Void> {
        return closeRelay.asObservable()
    }
    
    private var viewableObservable: Observable<Int>?
    
    @IBOutlet var controls: [UIView]? {
        didSet {
            controls?.forEach({ (view) in
                if view is RxAVPlayerControllable {
                    setPlayer(controlView: view)
                }
            })
        }
    }
    
    var url: URL? {
        didSet {
            statusRelay.accept(.prepare)
            skipVisibleRelay.accept(false)
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
            guard let endControl = controls?.filter({ (view) -> Bool in
                if let control = view as? RxAVPlayerControllable, control.status == .finish {
                    return true
                }
                return false
            }).first else { return }
            
            if let url = endcardImageURL, endControl is RxAVPlayerEndControllable {
                URLSession(configuration: .default).dataTask(with: url) { [weak endControl] (data, _, error) in
                    if let imgdata = data, let image = UIImage(data: imgdata), let endcard = endControl as? RxAVPlayerEndControllable {
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
    
    override func removeFromSuperview() {
        if let observer = periodicTimeObserver {
            player?.removeTimeObserver(observer)
        }
        super.removeFromSuperview()
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
            let status = self?.statusRelay.value
            if status == .playing {
                guard let interruption = notify.userInfo?[AVAudioSessionInterruptionTypeKey] as? AVAudioSessionInterruptionType else { return }
                switch interruption {
                case .began:
                    self?.statusRelay.accept(.pause)
                case .ended:
                    self?.play()
                }
            }
        }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.AVAudioSessionRouteChange).bind { [weak self] (notify) in
            if self?.statusRelay.value == .playing {
                self?.play()
            }
        }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.AVPlayerItemDidPlayToEndTime).bind { [weak self] (notify) in
            guard let item = notify.object as? AVPlayerItem, item == self?.player?.currentItem else { return }
            self?.movieEndRelay.accept()
        }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.AVPlayerItemFailedToPlayToEndTime).bind { [weak self] (notify) in
            self?.statusRelay.accept(.failed)
        }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.AVPlayerItemPlaybackStalled).bind { [weak self] (notify) in
            self?.controls?.forEach({ (view) in
                if let control = view as? RxAVPlayerControllable, control.status == .stall {
                    view.isHidden = false
                } else {
                    view.isHidden = true
                }
            })
        }.disposed(by: disposebag)

        NotificationCenter.default.rx.notification(.UIApplicationDidEnterBackground).bind { [weak self] (notify) in
            if self?.statusRelay.value == .playing {
                self?.pause()
            }
        }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(.UIApplicationWillEnterForeground).bind { [weak self] (notify) in
            if self?.statusRelay.value == .pause {
                self?.play()
            }
        }.disposed(by: disposebag)
    }
    
    private func registerTimeObserver(_ player: AVPlayer) {
        periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 10), queue: DispatchQueue.main) { [weak self] (time) in
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
                weakSelf.controls?.forEach({ (view) in
                    if let timecontrol = view as? RxAVPlayerTimeControllable {
                        guard let tracking = timecontrol.seekBar?.isTracking, !tracking else { return }
                        guard weakSelf.statusRelay.value != .seeking else { return }
                        timecontrol.currentTimeLabel?.text = weakSelf.formatter.string(from: date)
                        timecontrol.remainingTimeLabel?.text = weakSelf.formatter.string(from: remainDate)
                        hasSeekbar = true
                    }
                })
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
        case 1 where progressRelay.value != .completion:
            progressRelay.accept(.completion)
        case 0.25..<0.5:
            progressRelay.accept(.firstQ)
        case 0.5..<0.75:
            progressRelay.accept(.secondQ)
        case 0.75..<1:
            progressRelay.accept(.thirdQ)
        default:
            let currentProgress = progressRelay.value
            progressRelay.accept(currentProgress)
            break
        }
    }

    private func bind() {
        if let pl = player, let item = pl.currentItem {
            bindStatus()
            
            item.rx.playbackBufferEmpty.bind { [weak self] (empty) in
                guard let weakSelf = self else { return }
                if let item = weakSelf.player?.currentItem, !item.isPlaybackBufferFull {
                    if !empty, weakSelf.player?.currentTime() != kCMTimeZero {
                        weakSelf.statusRelay.accept(weakSelf.statusRelay.value)
                    }
                }
            }.disposed(by: disposebag)

            bindPlayable()
            
            controls?.map { $0 as? RxAVPlayerControllable }.forEach { bindControlView($0) }
            
            pl.rx.rate.map { $0 > 0 }.bind { [weak self] (progressive) in
                if progressive {
                    self?.statusRelay.accept(.playing)
                } else if self?.statusRelay.value != .deadend, self?.statusRelay.value != .prepare {
                    self?.statusRelay.accept(.pause)
                }
            }.disposed(by: disposebag)
            
            movieEndRelay.subscribe(onNext: { [weak self] in
                self?.statusRelay.accept(.deadend)
                if self?.progressRelay.value != .completion {
                    self?.progressRelay.accept(.completion)
                }
            }).disposed(by: disposebag)
        }
    }
    
    private func bindStatus() {
        statusRelay.subscribe(onNext: { [weak self] (status) in
            var target: RxAVPlayerControlStatus = .none
            switch status {
            case .prepare, .ready:
                target = .initialize
            case .playing:
                target = .play
            case .pause:
                target = .pause
            case .deadend:
                target = .finish
            case .failed:
                target = .fail
            default:
                return
            }
            self?.controls?.forEach({ (view) in
                if let control = view as? RxAVPlayerControllable, control.status == target {
                    view.isHidden = false
                } else {
                    view.isHidden = true
                }
            })
        }).disposed(by: disposebag)
    }

    private func bindPlayable() {
        if let pl = player, let item = pl.currentItem {
            let obs1 = item.rx.playbackLikelyToKeepUp
            let obs2 = pl.rx.status.map { $0 == .readyToPlay }
            Observable.combineLatest([obs1, obs2]).map { (list) -> Bool in
                for result in list where !result {
                    return false
                }
                return true
            }.bind { [weak self] (playable) in
                guard let weakSelf = self else { return }
                if playable {
                    let status = weakSelf.statusRelay.value
                    if status == .prepare, weakSelf.offset == 0 {
                        weakSelf.statusRelay.accept(.ready)
                        weakSelf.progressRelay.accept(.impression)
                    }
                    
                    if let p = weakSelf.player {
                        if let total = p.currentItem?.duration {
                            weakSelf.totalDate = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(total) ))
                            weakSelf.controls?.forEach({ (view) in
                                if let timecontrol = view as? RxAVPlayerTimeControllable {
                                    timecontrol.totalTimeLabel?.text = weakSelf.formatter.string(from: weakSelf.totalDate)
                                }
                            })
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
        }
    }
    
    private func bindControlView(_ control: RxAVPlayerControllable?) {
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
                    weakSelf.controls?.forEach({ (view) in
                        if let timecontrol = view as? RxAVPlayerTimeControllable {
                            let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                            let target = totalInterval * TimeInterval(sbar.value)
                            let date = Date(timeIntervalSince1970: target)
                            timecontrol.currentTimeLabel?.text = weakSelf.formatter.string(from: date)
                        }
                    })
                }
            }.disposed(by: disposebag)
            
            seek.rx.controlEvent([.touchUpInside, .touchUpOutside]).bind { [weak self] (_) in
                guard let weakSelf = self else { return }
                if let sbar = timecontrol.seekBar, weakSelf.totalDate.compare(Date.distantPast) != .orderedSame {
                    let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                    let target = totalInterval * TimeInterval(sbar.value)
                    let time = CMTimeMakeWithSeconds(Float64(target), Int32(NSEC_PER_SEC))
                    weakSelf.seek(distance: time)
                }
            }.disposed(by: disposebag)
        }
        
        if let closeControl = control as? RxAVPlayerClosable {
            closeControl.closeButton?.rx.tap.bind(onNext: { [weak self] (_) in
                self?.closeRelay.accept()
            }).disposed(by: disposebag)
        }
    }
    
    func seek(distance: CMTime) {
        statusRelay.accept(.seeking)
        if let pl = player {
            pl.seek(to: distance, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self] (completion) in
                if completion {
                    self?.play()
                }
            })
        }
    }
    
    func play() {
        if statusRelay.value == .deadend {
            statusRelay.accept(.prepare)
            if totalDate.compare(Date.distantPast) != .orderedSame {
                let time = CMTimeMakeWithSeconds(0, 1)
                seek(distance: time)
            }
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
