//
//  CustomPlayerTests.swift
//  Exam-RxAVPlayerAppTests
//
//  Created by HINOMORI HIROYA on 2018/09/13.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import XCTest
import RxSwift
import RxCocoa
import RxTest
import RxBlocking
import AVFoundation

// TODO: [*] 再生開始後にViewableイベントが発生する
// TODO: [*] 再生中ロケーションステータスが発行される

class CustomPlayerTests: XCTestCase {
    
    let player = CustomPlayer(frame: .zero)
    let disposebag = DisposeBag()
//    let testURL = URL(string: "https://s3.us-east-2.amazonaws.com/vjs-nuevo/hls/m3u8/playlist.m3u8")
    let testURL = URL(string: "http://comicimg.comico.jp/voicecomic/26819/2/5d0e1b6d_1532597166720.mp4/mp4hls/index.m3u8")
    var expection: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        URLCache.shared.removeAllCachedResponses()
        player.url = testURL
        player.autoplay = true
        expection = expectation(description: "CustomPlayer Check")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testViewable() {
        player.viewableObservable.bind { [weak self] (_) in
            self?.expection?.fulfill()
        }.disposed(by: disposebag)
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    var prevLocation: CustomPlayerStatus = .prepare
    func testLocationEvent() {
        player.currentStatusObservable.subscribe(onNext: { [unowned self] (status) in
            if self.prevLocation.rawValue > status.rawValue {
                XCTAssert(false, "Illegal Stream")
            } else if status == .completion {
                self.expection?.fulfill()
            }
        }, onError: { (error) in
            XCTAssertNil(error, error.localizedDescription)
        }, onCompleted: {
            XCTAssert(false, "** COMPLETED")
        }) {
            XCTAssert(false, "** DISPOSED")
        }.disposed(by: disposebag)
        waitForExpectations(timeout: 200, handler: nil)
    }
}
