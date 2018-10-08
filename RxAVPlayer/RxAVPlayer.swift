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
    case stalled
    case deadend
    case failed
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
    
    var offset: Float = 0.0
    var autoplay = false
    var mute: Bool = false {
        didSet {
            player?.isMuted = mute
        }
    }
    private(set) var totalDate = Date.distantPast
    
    private let disposebag = DisposeBag()
    private let statusRelay = BehaviorRelay<RxPlayerStatus>(value: .prepare)
    var statusObservable: Observable<RxPlayerStatus> {
        return statusRelay.asObservable()
    }
    private let progressRelay = PublishRelay<CMTime>()
    var progressObservable: Observable<CMTime> {
        return progressRelay.asObservable()
    }
    
    private let movieEndRelay = PublishRelay<Void>()
    private lazy var seekRelay = BehaviorRelay<Float>(value: 0)
    var seekObservable: Observable<Float> {
        return seekRelay.asObservable()
    }
    
    lazy var customEventRelay = PublishRelay<Any>()
    
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
            guard let movieURL = url else {
                statusRelay.accept(.failed)
                return
            }
            if movieURL.isFileURL {
                guard let check = try? movieURL.checkResourceIsReachable(), check else {
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
    
    var userInfo: Any?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        registerNotifications()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        registerNotifications()
    }
    
    override func removeFromSuperview() {
        if let observer = periodicTimeObserver {
            player?.removeTimeObserver(observer)
        }
        super.removeFromSuperview()
    }
    
    private func setPlayer(controlView: UIView?) {
        var control = controlView as? RxAVPlayerControllable
        if control != nil {
            control?.player = self
        }
    }
    
    private func registerNotifications() {
        NotificationCenter.default.rx.notification(AVAudioSession.interruptionNotification).bind { [weak self] (notify) in
            let status = self?.statusRelay.value
            if status == .playing {
                guard let interruption = notify.userInfo?[AVAudioSessionInterruptionTypeKey] as? AVAudioSession.InterruptionType else { return }
                switch interruption {
                case .began:
                    self?.statusRelay.accept(.pause)
                case .ended:
                    self?.play()
                }
            }
        }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(AVAudioSession.routeChangeNotification).bind { [weak self] (notify) in
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
            self?.statusRelay.accept(.stalled)
        }.disposed(by: disposebag)

        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).bind { [weak self] (notify) in
            if self?.statusRelay.value == .playing {
                self?.pause()
            }
        }.disposed(by: disposebag)
        
        NotificationCenter.default.rx.notification(UIApplication.willEnterForegroundNotification).bind { [weak self] (notify) in
            if self?.statusRelay.value == .pause {
                self?.play()
            }
        }.disposed(by: disposebag)
    }
    
    private func registerTimeObserver(_ player: AVPlayer) {
        periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 10), queue: DispatchQueue.main) { [weak self] (time) in
            guard let weakSelf = self else { return }
            weakSelf.progressRelay.accept(time)
            var hasSeekbar = false
            if let controls = weakSelf.controls {
                for view in controls where view is RxAVPlayerTimeControllable {
                    if let control = view as? RxAVPlayerTimeControllable {
                        control.updateDate(time)
                        if control.seekBar != nil {
                            hasSeekbar = true
                        }
                    }
                }
            }
            if hasSeekbar {
                let date = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(time) ))
                let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                let delta = round(weakSelf.totalDate.timeIntervalSince(date))
                let percent = 1.0 - delta / totalInterval
                weakSelf.seekRelay.accept(Float(percent))
            }
        }
    }

    private func bind() {
        if let pl = player, let item = pl.currentItem {
            bindStatus()
            
            item.rx.playbackBufferEmpty.bind { [weak self] (empty) in
                guard let weakSelf = self else { return }
                if let item = weakSelf.player?.currentItem, !item.isPlaybackBufferFull {
                    if !empty, weakSelf.player?.currentTime() != CMTime.zero {
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
            }).disposed(by: disposebag)
        }
    }

    private func bindStatus() {
        statusRelay.subscribe(onNext: { [weak self] (status) in
            var category: PlayerControlCategory?
            switch status {
            case .prepare, .ready:
                category = .initialize
            case .playing:
                category = .play
            case .pause:
                category = .pause
            case .deadend:
                category = .finish
            case .failed:
                category = .failed
            case .stalled:
                category = .stall
            default:
                return
            }
            if let targetCategory = category {
                self?.controls?.forEach({ (view) in
                    if let control = view as? RxAVPlayerControllable, control.category.contains(targetCategory) {
                        view.isHidden = false
                    } else {
                        view.isHidden = true
                    }
                })
            }
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
                    }
                    
                    if let p = weakSelf.player {
                        if let total = p.currentItem?.duration {
                            weakSelf.totalDate = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(total) ))
                            weakSelf.controls?.forEach({ (view) in
                                if let timecontrol = view as? RxAVPlayerTimeControllable {
                                    timecontrol.updateDate(CMTime.zero)
                                }
                            })
                        }
                        if weakSelf.offset > 0 {
                            weakSelf.seek(weakSelf.offset)
                            weakSelf.autoplay = false
                            weakSelf.offset = 0
                            weakSelf.statusRelay.accept(.ready)
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
                            timecontrol.updateDate(sbar.value)
                        }
                    })
                }
            }.disposed(by: disposebag)
            
            seek.rx.controlEvent([.touchUpInside, .touchUpOutside]).bind { [weak self] (_) in
                guard let weakSelf = self else { return }
                if let sbar = timecontrol.seekBar, weakSelf.totalDate.compare(Date.distantPast) != .orderedSame {
                    weakSelf.seek(sbar.value)
                }
            }.disposed(by: disposebag)
        }
    }
    
    func seek(_ percent: Float) {
        let totalInterval = totalDate.timeIntervalSince1970
        let target = totalInterval * TimeInterval(percent)
        let time = CMTimeMakeWithSeconds(Float64(target), preferredTimescale: Int32(NSEC_PER_SEC))
        seek(distance: time)
    }
    
    func seek(distance: CMTime) {
        statusRelay.accept(.seeking)
        if let pl = player {
            pl.seek(to: distance, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: { [weak self] (completion) in
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
                let time = CMTimeMakeWithSeconds(0, preferredTimescale: 1)
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
