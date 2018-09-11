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

class RxAVPlayerTests: XCTestCase {
    
    let player = RxAVPlayer(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let disposebag = DisposeBag()
    let testURL = URL(string: "http://hogehoge/index.m3u8")

    override func setUp() {
        super.setUp()
        player.autoplay = true
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCheckStatus() {
        let expection = expectation(description: "Player Status Check")
        player.url = testURL
        bindStatus(exp: expection)
        waitForExpectations(timeout: 300, handler: nil)
    }

    func testCheckProgress() {
        let expection = expectation(description: "Player Progress Check")
        player.url = testURL
        bindProgressStatus(exp: expection)
        waitForExpectations(timeout: 300, handler: nil)
    }
    
    func testCheckSkippable() {
        let expection = expectation(description: "Player Skippable Check")
        player.url = testURL
        bindSkippable(exp: expection, seconds: 3)
        waitForExpectations(timeout: 4, handler: nil)
    }

    func bindStatus(exp: XCTestExpectation?) {
        player.statusObservable.subscribe(onNext: { (status) in
            print("@@@  \(status.rawValue)")
            if status == RxPlayerStatus.deadend {
                exp?.fulfill()
            }
        }, onError: { (error) in
            XCTAssertNotNil(error, error.localizedDescription)
        }, onCompleted: {
            XCTAssertTrue(true, "++ COMPLETED")
        }) {
            XCTAssertTrue(true, "++ DISPOSED")
        }.disposed(by: disposebag)
    }
    
    func bindProgressStatus(exp: XCTestExpectation?) {
        var prev: CMTime = kCMTimeZero
        player.progressObservable.subscribe(onNext: { (time) in
            print(time)
            if time.timescale == prev.timescale, time != kCMTimeZero {
                XCTAssertFalse(prev > time, "Illegal Stream.  \(time) : \(prev)")
            }
            if let duration = self.player.player?.currentItem?.duration, 0 > CMTimeCompare(duration, time)  {
                exp?.fulfill()
            }
            prev = time
        }, onError: { (error) in
            XCTAssertNotNil(error, error.localizedDescription)
        }, onCompleted: {
            
        }) {
            
        }.disposed(by: disposebag)
    }
    
    func bindSkippable(exp: XCTestExpectation?, seconds: Float) {
        player.visibleSkipSeconds = seconds
        var startDate: Date?
        player.statusObservable.bind { (status) in
            if status == RxPlayerStatus.playing, startDate == nil {
                startDate = Date()
            }
        }.disposed(by: disposebag)
        player.skipObservable.subscribe(onNext: { (skippable) in
            if skippable, let date = startDate {
                let delta = Float(Date().timeIntervalSince(date))
                XCTAssertLessThanOrEqual(seconds, delta, "Less than skippable time..")
                XCTAssertGreaterThanOrEqual(seconds + 0.5, delta, "Greater than skippable time..")
                self.skip()
                exp?.fulfill()
            }
        }, onError: { (error) in
            XCTAssertNotNil(error, error.localizedDescription)
        }, onCompleted: {
            
        }) {
            
        }.disposed(by: disposebag)
    }
    
    func skip() {
        if let p = player.player, let time = p.currentItem?.duration {
            let distanceTime = CMTimeMake(time.value, time.timescale)
            player.seek(distance: distanceTime)
        }
    }

    func testPerformanceDownloadM3U8() {
        measure {
            player.autoplay = false
            let expection = expectation(description: "Player Performance Check")
            player.url = testURL
            player.statusObservable.subscribe(onNext: { (status) in
                if status == RxPlayerStatus.ready {
                    expection.fulfill()
                }
            }, onError: { (error) in
                XCTAssertNotNil(error, error.localizedDescription)
            }, onCompleted: {
                XCTAssertTrue(true, "** COMPLETED")
            }, onDisposed: {
                XCTAssertTrue(true, "** DISPOSED")
            }).disposed(by: disposebag)
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
}
