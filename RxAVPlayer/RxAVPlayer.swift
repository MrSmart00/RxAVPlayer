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

class RxAVPlayer: UIView {

    @IBOutlet weak var playButton: UIButton?
    @IBOutlet weak var pauseButton: UIButton?
    @IBOutlet weak var replayButton: UIButton?
    @IBOutlet weak var muteButton: UIButton?
    @IBOutlet weak var remainTimeLabel: UILabel?
    @IBOutlet weak var timeOffsetLabel: UILabel?
    @IBOutlet weak var endTimeLabel: UILabel?
    @IBOutlet weak var skipButton: UIButton?
    @IBOutlet weak var seekbar: UISlider?
    
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
    private lazy var progressSubject = BehaviorSubject<Float>(value: 0)
    private var skipObservable: Observable<Bool>?
    private let disposebag = DisposeBag()
    private var totalDate = Date.distantPast
    private let formatter = DateFormatter()
    
    var url: URL? {
        didSet {
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
        if let button = muteButton {
            button.isExclusiveTouch = true
            button.addTarget(self, action: #selector(changeMute), for: .touchUpInside)
        }
        if let button = playButton {
            button.isExclusiveTouch = true
            button.addTarget(self, action: #selector(play), for: .touchUpInside)
        }
        if let button = pauseButton {
            button.isExclusiveTouch = true
            button.addTarget(self, action: #selector(pause), for: .touchUpInside)
        }
        if let button = replayButton {
            button.isExclusiveTouch = true
            button.addTarget(self, action: #selector(replay), for: .touchUpInside)
        }
        if let button = skipButton {
            button.isExclusiveTouch = true
            button.isHidden = true
            button.addTarget(self, action: #selector(skip), for: .touchUpInside)
        }
        if let seek = seekbar {
            seek.isExclusiveTouch = true
        }
        formatter.dateFormat = "mm:ss"
        timeOffsetLabel?.text = "00:00"
        endTimeLabel?.text = "00:00"
        remainTimeLabel?.text = "00:00"
        
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
                if time.value == 0, weakSelf.skipObservable == nil {
                    if let button = weakSelf.skipButton, weakSelf.visibleSkipSeconds > -1 {
                        let obs1 = Observable<Int>.timer(RxTimeInterval(weakSelf.visibleSkipSeconds), scheduler: MainScheduler.asyncInstance).map { _ in false }
                        let combine = Observable.combineLatest([weakSelf.movieEndSubject, obs1]).map({ (list) -> Bool in
                            for result in list {
                                if result {
                                    return true
                                }
                            }
                            return false
                        })
                        combine.subscribe(onNext: { (hidden) in
                            button.isHidden = hidden
                        }, onError: nil, onCompleted: nil, onDisposed: {
                            weakSelf.skipObservable = nil
                        }).disposed(by: weakSelf.disposebag)
                        weakSelf.skipObservable = combine
                    }
                }
                
                let date = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(time) ))
                weakSelf.timeOffsetLabel?.text = weakSelf.formatter.string(from: date)
                
                let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                let delta = round(weakSelf.totalDate.timeIntervalSince(date))
                let percent = 1.0 - delta / totalInterval
                weakSelf.progressSubject.onNext(Float(percent))
                
                if let remain = weakSelf.remainTimeLabel {
                    let remainDate = Date(timeIntervalSince1970: delta)
                    remain.text = weakSelf.formatter.string(from: remainDate)
                }
            }
        }
    }
    
    private func bind() {
        if let pl = player, let item = pl.currentItem {
            
            let obs1 = item.rx.playbackLikelyToKeepUp
            let obs2 = pl.rx.status.map { ($0 == .readyToPlay) }
            
            Observable.combineLatest([obs1, obs2]).map { (list) -> Bool in
                for result in list {
                    if !result {
                        return false
                    }
                }
                return true
            }.bind { (playable) in
                if playable {
                    self.movieEndSubject.onNext(false)
                    if let total = self.player?.currentItem?.duration {
                        self.totalDate = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(total) ))
                        self.endTimeLabel?.text = self.formatter.string(from: self.totalDate)
                    }
                    if self.autoplay {
                        pl.play()
                    }
                }
            }.disposed(by: disposebag)

            if let button = muteButton {
                pl.rx.mute.bind(to: button.rx.isSelected).disposed(by: disposebag)
            }
            
            if let button = playButton {
                let obs1 = pl.rx.rate.map { $0 > 0 }
                let obs2 = movieEndSubject.map { $0 }
                Observable.combineLatest([obs1, obs2]).map { (list) -> Bool in
                    for result in list {
                        if result {
                            return true
                        }
                    }
                    return false
                }.bind(to: button.rx.isHidden).disposed(by: disposebag)
            }
            
            if let button = pauseButton {
                let obs1 = pl.rx.rate.map { $0 == 0 }
                let obs2 = movieEndSubject.map { $0 }
                Observable.combineLatest([obs1, obs2]).map { (list) -> Bool in
                    for result in list {
                        if result {
                            return true
                        }
                    }
                    return false
                }.bind(to: button.rx.isHidden).disposed(by: disposebag)
            }
            
            if let button = replayButton {
                movieEndSubject.map { !$0 }.bind(to: button.rx.isHidden).disposed(by: disposebag)
            }
            
            if let seek = seekbar {
                progressSubject.bind { (value) in
                    if !seek.isTracking, let rate = self.player?.rate, rate > 0.0 {
                        seek.value = value
                    }
                }.disposed(by: disposebag)

                seek.rx.controlEvent([.touchUpInside, .touchUpOutside]).subscribe(onNext: {
                    if self.totalDate.compare(Date.distantPast) != .orderedSame {
                        self.progressSubject.onNext(seek.value)
                        let totalInterval = self.totalDate.timeIntervalSince1970
                        let target = totalInterval * TimeInterval(seek.value)
                        let time = CMTimeMakeWithSeconds(Float64(target), Int32(NSEC_PER_SEC))
                        self.seek(distance: time, skip: false)
                    }
                }).disposed(by: disposebag)
            }
        }
    }
    
    private func seek(distance: CMTime, skip: Bool) {
        self.pause()
        if skip {
            self.player?.seek(to: distance, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { (completion) in
                if completion {
                    self.play()
                }
            })
        } else {
            self.player?.seek(to: distance, completionHandler: { (completion) in
                if completion {
                    self.play()
                }
            })
        }
    }
    
    @objc private func changeMute() {
        if let pl = player {
            pl.isMuted = !pl.isMuted
        }
    }
    
    @objc private func skip() {
        if totalDate.compare(Date.distantPast) != .orderedSame {
            let time = CMTimeMakeWithSeconds(totalDate.timeIntervalSince1970, Int32(NSEC_PER_SEC))
            self.seek(distance: time, skip: true)
        }
    }
    
    @objc private func replay() {
        if totalDate.compare(Date.distantPast) != .orderedSame {
            let time = CMTimeMakeWithSeconds(0, Int32(NSEC_PER_SEC))
            self.seek(distance: time, skip: false)
        }
    }
    
    @objc func play() {
        player?.play()
    }
    
    @objc func pause() {
        player?.pause()
    }
}
