//
//  RxAVPlayerTests.swift
//  RxAVPlayerTests
//
//  Created by HINOMORI HIROYA on 2018/07/04.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import XCTest
import RxSwift
import RxCocoa
import RxTest
import RxBlocking
import AVFoundation

// TODO: [*] 再生できる
// TODO: [*] 自動再生できる
// TODO: [*] 停止できる
// TODO: [*] 指定時間までシーク移動できる
// TODO: [*] 再生開始時間を指定できる
// TODO: [*] 登録したコントローラViewにPlayerを渡す
// TODO: [*] 登録したViewのリストをControlのリストに変換できる

class RxAVPlayerTests: XCTestCase {
    
    let player = RxAVPlayer(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    let disposebag = DisposeBag()
    var videoURL: URL?

    override func setUp() {
        super.setUp()
        URLCache.shared.removeAllCachedResponses()
        do {
            if videoURL == nil {
                let bundle = Bundle(for: type(of: self))
                let asset = NSDataAsset(name: "SampleVideo", bundle: bundle)
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SampleVideo.mp4")
                try asset!.data.write(to: url)
                videoURL = url
            }
            player.url = videoURL
        } catch let error {
            XCTAssert(false, error.localizedDescription)
        }
    }
    
    func test_再生できる() {
        let expection = expectation(description: "Player Through Check")
        player.statusObservable.subscribe(onNext: { [weak self] (status) in
            switch status {
            case .ready:
                self?.player.play()
            case .finished:
                expection.fulfill()
            case .stalled:
                XCTAssert(false, "Stream Stalled..")
            case .failed:
                XCTAssert(false, "Player Failed..")
            default:
                break
            }
        }, onError: { (error) in
                XCTAssertNotNil(error, error.localizedDescription)
        }, onCompleted: {
            XCTAssert(false, "** COMPLETED")
        }, onDisposed: {
            XCTAssert(false, "** DISPOSED")
        }).disposed(by: disposebag)
        waitForExpectations(timeout: 100, handler: nil)
    }

    func test_自動再生できる() {
        let expection = expectation(description: "Player Auto-Start Check")
        player.autoplay = true
        player.statusObservable.subscribe(onNext: { (status) in
            if status == .playing {
                expection.fulfill()
            }
        }, onError: { (error) in
            XCTAssertNotNil(error, error.localizedDescription)
        }, onCompleted: {
            XCTAssert(false, "** COMPLETED")
        }, onDisposed: {
            XCTAssert(false, "** DISPOSED")
        }).disposed(by: disposebag)
        waitForExpectations(timeout: 100, handler: nil)
    }
    
    func test_停止できる() {
        let expection = expectation(description: "Player Pause Check")
        player.statusObservable.subscribe(onNext: { [weak self] (status) in
            switch status {
            case .ready:
                self?.player.play()
            case .playing:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
                    self?.player.pause()
                })
            case .pause:
                if status == RxPlayerStatus.pause {
                    expection.fulfill()
                }
            case .stalled:
                XCTAssert(false, "Stream Stalled..")
            case .failed:
                XCTAssert(false, "Player Failed..")
            default:
                break
            }
        }, onError: { (error) in
            XCTAssertNotNil(error, error.localizedDescription)
        }, onCompleted: {
            XCTAssert(false, "** COMPLETED")
        }, onDisposed: {
            XCTAssert(false, "** DISPOSED")
        }).disposed(by: disposebag)
        waitForExpectations(timeout: 100, handler: nil)
    }
    
    func test_指定時間までシーク移動できる() {
        let expection = expectation(description: "Player Seek Check")
        player.autoplay = true
        var seeked = false
        player.statusObservable.subscribe(onNext: { (status) in
            switch status {
            case .playing:
                if !seeked {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        self?.player.seek(percent: 0.9)
                    }
                }
            case .seeking:
                seeked = true
            case .finished:
                XCTAssert(seeked, "Not Seek..")
                expection.fulfill()
            case .stalled:
                XCTAssert(false, "Stream Stalled..")
            case .failed:
                XCTAssert(false, "Player Failed..")
            default:
                break
            }

        }, onError: { (error) in
            XCTAssertNotNil(error, error.localizedDescription)
        }, onCompleted: {
            XCTAssert(false, "** COMPLETED")
        }, onDisposed: {
            XCTAssert(false, "** DISPOSED")
        }).disposed(by: disposebag)
        
        waitForExpectations(timeout: 100, handler: nil)
    }
    
    func test_再生開始時間を指定できる() {
        let expection = expectation(description: "Player Offset Check")
        player.offset = 0.9
        var seeked = false
        player.statusObservable.subscribe(onNext: { [weak self] (status) in
            print(status.rawValue)
            switch status {
            case .ready:
                self?.player.play()
            case .seeking:
                seeked = true
            case .finished:
                XCTAssert(seeked, "Not Seek..")
                expection.fulfill()
            case .stalled:
                XCTAssert(false, "Stream Stalled..")
            case .failed:
                XCTAssert(false, "Player Failed..")
            default:
                break
            }
        }, onError: { (error) in
            XCTAssertNotNil(error, error.localizedDescription)
        }, onCompleted: {
            XCTAssert(false, "** COMPLETED")
        }, onDisposed: {
            XCTAssert(false, "** DISPOSED")
        }).disposed(by: disposebag)
        waitForExpectations(timeout: 100, handler: nil)
    }

    func test_登録したコントローラViewにPlayerを渡す() {
        let result = MockControlableView()
        player.controlViews = [result]
        XCTAssertNotNil(result.player)
    }

    func test_登録したViewのリストをControlのリストに変換できる() {
        let view = MockControlableView()
        player.controlViews = [view]
        let result: [RxAVPlayerControllable] = player.convertControls()
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(type(of: result) == [RxAVPlayerControllable].self)
    }
}
