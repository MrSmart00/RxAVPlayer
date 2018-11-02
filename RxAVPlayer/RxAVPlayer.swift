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
    case prepare
    case ready
    case playing
    case pause
    case seeking
    case stalled
    case finished
    case failed
}

@objcMembers class RxAVPlayer: UIView {
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    private(set) var url: URL?
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
    
    private let disposeBag = DisposeBag()
    private var statusRelay = BehaviorRelay<RxPlayerStatus>(value: .prepare)
    var statusObservable: Observable<RxPlayerStatus> {
        return statusRelay.asObservable()
    }
    private var progressRelay = PublishRelay<CMTime>()
    var progressObservable: Observable<CMTime> {
        return progressRelay.asObservable()
    }
    
    private var movieEndRelay = PublishRelay<Bool>()
    private lazy var seekRelay = BehaviorRelay<Float>(value: 0)
    var seekObservable: Observable<Float> {
        return seekRelay.asObservable()
    }
    
    private(set) var eventObservable: Observable<RxAVPlayerEvent>?

    @IBOutlet var controlViews: [UIView]? {
        didSet {
            setPlayer()
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

    func convertControls<E>() -> [E] {
        return controlViews?.map { $0 as? E }.filter { $0 != nil } as? [E] ?? []
    }

    func load(_ url: URL?, mute: Bool? = nil, autoPlay: Bool? = nil, offset: Float? = nil) {

        if let p = player {
            if let observer = periodicTimeObserver {
                p.removeTimeObserver(observer)
                periodicTimeObserver = nil
            }
            statusRelay = BehaviorRelay<RxPlayerStatus>(value: .prepare)
            progressRelay = PublishRelay<CMTime>()
            movieEndRelay = PublishRelay<Bool>()
            seekRelay = BehaviorRelay<Float>(value: 0)
        }

        player = createPlayer(url)
        if let soundMute = mute {
            self.mute = soundMute
        }
        if let auto = autoPlay {
            self.autoplay = auto
        }
        if let timeOffsset = offset {
            self.offset = timeOffsset
        }
        bind()
    }

    func createPlayer(_ url: URL?) -> AVPlayer? {
        self.url = url
        guard validate(url: url) else {
            statusRelay.accept(.failed)
            return nil
        }
        guard let movieUrl = url else { return nil }
        let asset = AVAsset(url: movieUrl)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        registerTimeObserver(player)
        return player
    }

    func validate(url: URL?) -> Bool {
        guard let movieURL = url else { return false }
        if movieURL.isFileURL {
            guard let check = try? movieURL.checkResourceIsReachable(), check else { return false }
        }
        return true
    }

    private func setPlayer() {
        let list: [RxAVPlayerControllable] = convertControls()
        list.forEach { $0.player = self }
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
        }.disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(AVAudioSession.routeChangeNotification).bind { [weak self] (notify) in
            if self?.statusRelay.value == .playing {
                self?.play()
            }
        }.disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(.AVPlayerItemDidPlayToEndTime).bind { [weak self] (notify) in
            guard let item = notify.object as? AVPlayerItem, item == self?.player?.currentItem else { return }
            self?.movieEndRelay.accept(true)
        }.disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(.AVPlayerItemFailedToPlayToEndTime).bind { [weak self] (notify) in
            self?.statusRelay.accept(.failed)
        }.disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(.AVPlayerItemPlaybackStalled).bind { [weak self] (notify) in
            self?.statusRelay.accept(.stalled)
        }.disposed(by: disposeBag)

        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).bind { [weak self] (notify) in
            if self?.statusRelay.value == .playing {
                self?.pause()
            }
        }.disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(UIApplication.willEnterForegroundNotification).bind { [weak self] (notify) in
            if self?.statusRelay.value == .pause {
                self?.play()
            }
        }.disposed(by: disposeBag)
    }
    
    private func registerTimeObserver(_ player: AVPlayer) {
        periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 10), queue: DispatchQueue.main) { [weak self] (time) in
            guard let weakSelf = self else { return }
            weakSelf.progressRelay.accept(time)
            let controls: [RxAVPlayerTimeControllable] = weakSelf.convertControls()
            controls.forEach { $0.updateDate(time) }
            if !controls.allSatisfy { $0.seekBar == nil } {
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
                if let item = self?.player?.currentItem, !item.isPlaybackBufferFull {
                    if !empty, self?.player?.currentTime() != .zero, let value = self?.statusRelay.value {
                        self?.statusRelay.accept(value)
                    }
                }
            }.disposed(by: disposeBag)

            bindPlayable()
            
            var eventObservables = [Observable<RxAVPlayerEvent>]()
            let controls: [RxAVPlayerControllable] = convertControls()
            controls.forEach { bindControlView($0, eventList: &eventObservables) }
            if !eventObservables.isEmpty {
                eventObservable = Observable.merge(eventObservables)
            }

            pl.rx.rate.map { $0 > 0 }.bind { [weak self] (progressive) in
                if progressive {
                    self?.statusRelay.accept(.playing)
                } else if self?.statusRelay.value != .finished, self?.statusRelay.value != .prepare {
                    if self?.player?.currentTime() != self?.player?.currentItem?.duration {
                        self?.statusRelay.accept(.pause)
                    }
                }
            }.disposed(by: disposeBag)

            movieEndRelay.subscribe(onNext: { [weak self] (completion) in
                self?.statusRelay.accept(.finished)
            }).disposed(by: disposeBag)
        }
    }

    private func bindStatus() {
        statusRelay.subscribe(onNext: { [weak self] (status) in
            if let targetCategory = self?.convertStatus(status) {
                self?.controlViews?.forEach({ (view) in
                    if let control = view as? RxAVPlayerControllable, control.category.contains(targetCategory) {
                        view.isHidden = false
                    } else {
                        view.isHidden = true
                    }
                })
            }
        }).disposed(by: disposeBag)
    }

    private func convertStatus(_ status: RxPlayerStatus) -> PlayerControlCategory? {
        var category: PlayerControlCategory?
        switch status {
        case .prepare, .ready:
            category = .initialize
        case .playing:
            category = .play
        case .pause:
            category = .pause
        case .finished:
            category = .finish
        case .failed:
            category = .failed
        case .stalled:
            category = .stall
        default:
            return nil
        }
        return category
    }

    private func bindPlayable() {
        if let pl = player, let item = pl.currentItem {
            Observable
                .combineLatest([item.rx.playbackLikelyToKeepUp,
                                pl.rx.status.map { $0 == .readyToPlay }])
                .map { $0.allSatisfy { $0 } }
                .bind { [weak self] (playable) in
                    guard let weakSelf = self else { return }
                    if playable {
                        let status = weakSelf.statusRelay.value
                        guard status == .prepare else { return }
                        if let total = weakSelf.player?.currentItem?.duration {
                            weakSelf.totalDate = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(total) ))
                            let controls: [RxAVPlayerTimeControllable] = weakSelf.convertControls()
                            controls.forEach { $0.updateDate(.zero) }
                        }
                        if weakSelf.offset > 0 {
                            weakSelf.seek(percent: weakSelf.offset, { (completion) in
                                weakSelf.statusRelay.accept(.ready)
                                weakSelf.offset = 0
                                if weakSelf.autoplay {
                                    weakSelf.play()
                                }
                            })
                        } else {
                            weakSelf.statusRelay.accept(.ready)
                            if weakSelf.autoplay, status != .finished {
                                weakSelf.play()
                            }
                        }
                    }
                }.disposed(by: disposeBag)
        }
    }

    private func bindControlView(_ control: RxAVPlayerControllable?, eventList: inout [Observable<RxAVPlayerEvent>]) {
        if let event = control?.eventObservable {
            eventList.append(event)
        }
        if let timecontrol = control as? RxAVPlayerTimeControllable, let seek = timecontrol.seekBar {
            Observable.combineLatest(statusRelay, seekRelay)
                .asDriver(onErrorDriveWith: .empty())
                .drive(onNext: { [weak seek] (status, value) in
                    if status != .seeking, seek?.isTracking == false {
                        seek?.value = value
                    }
                }).disposed(by: disposeBag)
            seek.rx.value
                .asDriver(onErrorDriveWith: .empty())
                .drive(onNext: { [weak self] (value) in
                    if let sbar = timecontrol.seekBar {
                        self?.seekRelay.accept(sbar.value)
                        let controls: [RxAVPlayerTimeControllable]? = self?.convertControls()
                        controls?.forEach { $0.updateDate(sbar.value) }
                    }
                }).disposed(by: disposeBag)
            seek.rx.controlEvent([.touchUpInside, .touchUpOutside])
                .asDriver(onErrorDriveWith: .empty())
                .drive(onNext: { [weak self] (_) in
                    if let sbar = timecontrol.seekBar, self?.totalDate.compare(.distantPast) != .orderedSame {
                        self?.seek(percent: sbar.value)
                    }
                }).disposed(by: disposeBag)
        }
    }
    
    func seek(percent: Float, _ completionHandler:((Bool) -> ())? = nil) {
        let totalInterval = totalDate.timeIntervalSince1970
        let target = totalInterval * TimeInterval(percent)
        let time = CMTimeMakeWithSeconds(Float64(target), preferredTimescale: Int32(NSEC_PER_SEC))
        seek(distance: time, completionHandler)
    }
    
    func seek(distance: CMTime, _ completionHandler:((Bool) -> ())? = nil) {
        statusRelay.accept(.seeking)
        if let pl = player {
            pl.seek(to: distance, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { [weak self] (completion) in
                if completion {
                    if let handler = completionHandler {
                        handler(completion)
                    } else {
                        self?.play()
                    }
                }
            })
        }
    }
    
    func play() {
        if statusRelay.value == .finished {
            statusRelay.accept(.prepare)
            if totalDate.compare(.distantPast) != .orderedSame {
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
