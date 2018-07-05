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

    @IBOutlet weak var playButton: UIButton?
    @IBOutlet weak var pauseButton: UIButton?
    @IBOutlet weak var replayButton: UIButton?
    @IBOutlet weak var muteButton: UIButton?
    @IBOutlet weak var remainTimeLabel: UILabel?
    @IBOutlet weak var timeOffsetLabel: UILabel?
    @IBOutlet weak var endTimeLabel: UILabel?
    @IBOutlet weak var skipButton: UIButton?
    @IBOutlet weak var seekbar: UISlider?
    
    private let statusSubject = BehaviorSubject<PlayerStatus>(value: .none)
    var status: PlayerStatus = .none {
        didSet {
            if status != oldValue {
                statusSubject.onNext(status)
            }
        }
    }
    
    private let viewStatusSubject = BehaviorSubject<ViewableStatus>(value: .none)
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
    private var skipObservable: Observable<Bool>?
    private let disposebag = DisposeBag()
    private var totalDate = Date.distantPast
    private let formatter = DateFormatter()
    
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
        
        if let button = muteButton {
            button.addTarget(self, action: #selector(changeMute), for: .touchUpInside)
        }
        if let button = playButton {
            button.addTarget(self, action: #selector(play), for: .touchUpInside)
        }
        if let button = pauseButton {
            button.addTarget(self, action: #selector(pause), for: .touchUpInside)
        }
        if let button = replayButton {
            button.addTarget(self, action: #selector(replay), for: .touchUpInside)
        }
        if let button = skipButton {
            button.addTarget(self, action: #selector(skip), for: .touchUpInside)
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
                if let p = weakSelf.player, let item = p.currentItem {
                    weakSelf.manageTimeStatus(current: time, duration: item.duration)
                    let date = Date(timeIntervalSince1970: TimeInterval( CMTimeGetSeconds(time) ))
                    weakSelf.timeOffsetLabel?.text = weakSelf.formatter.string(from: date)
                    
                    let totalInterval = weakSelf.totalDate.timeIntervalSince1970
                    let delta = round(weakSelf.totalDate.timeIntervalSince(date))
                    let percent = 1.0 - delta / totalInterval
                    weakSelf.seekbarSubject.onNext(Float(percent))
                    
                    if let remain = weakSelf.remainTimeLabel {
                        let remainDate = Date(timeIntervalSince1970: delta)
                        remain.text = weakSelf.formatter.string(from: remainDate)
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
            
            statusSubject.subscribe(onNext: { (st) in
                print("PLAYER STATUS : \(st)")
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
                                weakSelf.endTimeLabel?.text = weakSelf.formatter.string(from: weakSelf.totalDate)
                            }
                            if weakSelf.autoplay {
                                p.play()
                            }
                        }
                    }
                }
            }.disposed(by: disposebag)

            if let button = muteButton {
                pl.rx.mute.bind(to: button.rx.isSelected).disposed(by: disposebag)
            }
            
            if playButton != nil {
                let obs1 = pl.rx.rate.map { $0 > 0 }
                let obs2 = movieEndSubject.map { $0 }
                Observable.combineLatest([obs1, obs2]).map { (list) -> Bool in
                    for result in list {
                        if result {
                            return true
                        }
                    }
                    return false
                }.bind { [weak self] (hidden) in
                    if let weakSelf = self, let btn = weakSelf.playButton {
                        btn.isHidden = hidden
                        if !hidden {
                            weakSelf.status = .pause
                        }
                    }
                }.disposed(by: disposebag)
            }
            
            if pauseButton != nil {
                let obs1 = pl.rx.rate.map { $0 == 0 }
                let obs2 = movieEndSubject.map { $0 }
                Observable.combineLatest([obs1, obs2]).map { (list) -> Bool in
                    for result in list {
                        if result {
                            return true
                        }
                    }
                    return false
                }.bind { [weak self] (hidden) in
                    if let weakSelf = self, let btn = weakSelf.pauseButton {
                        btn.isHidden = hidden
                        if !hidden {
                            weakSelf.status = .playing
                        }
                    }
                }.disposed(by: disposebag)
            }
            
            if replayButton != nil {
                movieEndSubject.bind { [weak self] (completion) in
                    if let weakSelf = self, let btn = weakSelf.replayButton {
                        btn.isHidden = !completion
                        if completion {
                            weakSelf.status = .pause
                            weakSelf.viewStatus = .completion
                        }
                    }
                }.disposed(by: disposebag)
            }
            
            if let seek = seekbar {
                seekbarSubject.bind { [weak self] (value) in
                    if let weakSelf = self, let sbar = weakSelf.seekbar {
                        if !sbar.isTracking, let rate = weakSelf.player?.rate, rate > 0.0 {
                            sbar.value = value
                        }
                    }
                }.disposed(by: disposebag)

                seek.rx.controlEvent([.touchUpInside, .touchUpOutside]).bind { [weak self] (_) in
                    if let weakSelf = self, let sbar = weakSelf.seekbar {
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
    }
    
    private func seek(distance: CMTime, skip: Bool) {
        pause()
        if let pl = player {
            if skip {
                pl.seek(to: distance, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self] (completion) in
                    if let weakSelf = self {
                        if completion, !skip {
                            weakSelf.play()
                        }
                    }
                })
            } else {
                player?.seek(to: distance, completionHandler: { [weak self] (completion) in
                    if let weakSelf = self {
                        if completion {
                            weakSelf.play()
                        }
                    }
                })
            }
        }

    }
    
    @objc private func changeMute() {
        if let pl = player {
            pl.isMuted = !pl.isMuted
        }
    }
    
    @objc private func skip() {
        if let pl = player, let time = pl.currentItem?.duration {
            let distanceTime = CMTimeMake(time.value - 1, time.timescale)
            seek(distance: distanceTime, skip: true)
        }
    }
    
    @objc private func replay() {
        if totalDate.compare(Date.distantPast) != .orderedSame {
            let time = CMTimeMakeWithSeconds(0, Int32(NSEC_PER_SEC))
            seek(distance: time, skip: false)
        }
    }
    
    @objc func play() {
        player?.play()
    }
    
    @objc func pause() {
        player?.pause()
    }
}
