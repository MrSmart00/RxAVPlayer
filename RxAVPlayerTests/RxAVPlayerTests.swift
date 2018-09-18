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

// TODO: [*] M3U8のURLから再生準備が完了できる
// TODO: [*] 再生できる
// TODO: [*] 自動再生できる
// TODO: [*] 停止できる
// TODO: [*] 指定時間までシーク移動できる
// TODO: [*] 再生開始時間を指定できる
// TODO: [*] 最後まで再生できる
// TODO: [*] 自動で最後まで再生できる


class RxAVPlayerTests: XCTestCase {
    
    let player = RxAVPlayer(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let disposebag = DisposeBag()
    let testURL = URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")

    override func setUp() {
        super.setUp()
        URLCache.shared.removeAllCachedResponses()
        player.url = testURL
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDownloadM3U8() {
        let expection = expectation(description: "M3U8 Download Check")
        player.statusObservable.subscribe(onNext: { (status) in
            if status == RxPlayerStatus.ready {
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
        waitForExpectations(timeout: 2, handler: nil)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.player.seek(0.999)
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
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testOffsetTimePlay() {
        let expection = expectation(description: "Player Offset Check")
        player.offset = 0.999
        var seeked = false
        player.statusObservable.subscribe(onNext: { [weak self] (status) in
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
        waitForExpectations(timeout: 30, handler: nil)
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
        waitForExpectations(timeout: 1200, handler: nil)
    }
    
    func testAutoAllThrough() {
        let expection = expectation(description: "Player Auto Through Check")
        player.autoplay = true
        player.statusObservable.subscribe(onNext: { (status) in
            switch status {
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
        waitForExpectations(timeout: 1200, handler: nil)
    }
    
    func testPerformanceDownloadM3U8() {
        measure {
            player.autoplay = false
            let expection = expectation(description: "Player Performance Check")
            player.statusObservable.subscribe(onNext: { (status) in
                if status == RxPlayerStatus.ready {
                    expection.fulfill()
                }
            }, onError: { (error) in
                XCTAssertNotNil(error, error.localizedDescription)
            }, onCompleted: {
                XCTAssert(false, "** COMPLETED")
            }, onDisposed: {
                XCTAssert(false, "** DISPOSED")
            }).disposed(by: disposebag)
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
}
