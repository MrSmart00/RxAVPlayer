//
//  RxAVPlayerTests.swift
//  RxAVPlayerTests
//
//  Created by HINOMORI HIROYA on 2018/07/04.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import XCTest
@testable import RxAVPlayer
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
// TODO: [*] 最後まで再生できる


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
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStart() {
        let expection = expectation(description: "Player Start Check")
        player.statusObservable.subscribe(onNext: { [weak self] (status) in
            switch status {
            case .ready:
                self?.player.play()
            case .playing:
                expection.fulfill()
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
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testAutoStart() {
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
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testPause() {
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
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testSeek() {
        let expection = expectation(description: "Player Seek Check")
        player.autoplay = true
        var seeked = false
        player.statusObservable.subscribe(onNext: { (status) in
            switch status {
            case .playing:
                if !seeked {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        self?.player.seek(0.9)
                    }
                }
            case .seeking:
                seeked = true
            case .deadend:
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
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testOffsetTimePlay() {
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
            case .deadend:
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
        waitForExpectations(timeout: 3, handler: nil)
    }

    func testAllThrough() {
        let expection = expectation(description: "Player Through Check")
        player.statusObservable.subscribe(onNext: { [weak self] (status) in
            switch status {
            case .ready:
                self?.player.play()
            case .deadend:
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
        waitForExpectations(timeout: 10, handler: nil)
    }

}
