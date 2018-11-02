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
// TODO: [*] 再生中に別のMP4の再生を開始できる
// TODO: [*] 登録したコントローラViewにPlayerを渡す
// TODO: [*] 登録したViewのリストをControlのリストに変換できる

class RxAVPlayerTests: XCTestCase {
    
    let disposebag = DisposeBag()

    override func setUp() {
        super.setUp()
    }

    func createPlayer(autoplay: Bool) -> RxAVPlayer? {
        do {
            let player = RxAVPlayer(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            let bundle = Bundle(for: type(of: self))
            let asset = NSDataAsset(name: "SampleVideo", bundle: bundle)
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SampleVideo.mp4")
            try asset!.data.write(to: url)
            player.load(url, autoPlay: autoplay)
            return player
        } catch let error {
            XCTAssert(false, error.localizedDescription)
        }
        return nil
    }

    func test_再生できる() {
        let player = createPlayer(autoplay: false)
        XCTAssertEqual(RxPlayerStatus.ready,
                       try? player?
                        .statusObservable
                        .skip(1)
                        .toBlocking(timeout: 3)
                        .first())
        player?.play()
        XCTAssertEqual(RxPlayerStatus.playing,
                       try? player?
                        .statusObservable
                        .take(1)
                        .toBlocking(timeout: 3)
                        .first())
    }

    func test_自動再生できる() {
        let player = createPlayer(autoplay: true)
        XCTAssertEqual([RxPlayerStatus.prepare, RxPlayerStatus.ready, RxPlayerStatus.playing],
                       try? player?
                        .statusObservable
                        .take(3)
                        .toBlocking(timeout: 3)
                        .toArray())
    }

    func test_停止できる() {
        let player = createPlayer(autoplay: true)
        XCTAssertEqual([RxPlayerStatus.prepare, RxPlayerStatus.ready],
                       try? player?
                        .statusObservable
                        .take(2)
                        .toBlocking(timeout: 3)
                        .toArray())
        XCTAssertEqual(RxPlayerStatus.playing,
                       try? player?
                        .statusObservable
                        .delay(0.3, scheduler: MainScheduler.instance)
                        .toBlocking(timeout: 3)
                        .first())
        player?.pause()
        XCTAssertEqual(RxPlayerStatus.pause,
                       try? player?
                        .statusObservable
                        .take(1)
                        .toBlocking(timeout: 3)
                        .first())
    }

    func test_指定時間までシーク移動できる() {
        let player = createPlayer(autoplay: true)
        XCTAssertEqual([RxPlayerStatus.prepare, RxPlayerStatus.ready],
                       try? player?
                        .statusObservable
                        .take(2)
                        .toBlocking(timeout: 3)
                        .toArray())
        XCTAssertEqual(RxPlayerStatus.playing,
                       try? player?
                        .statusObservable
                        .delay(0.3, scheduler: MainScheduler.instance)
                        .toBlocking(timeout: 3)
                        .first())
        player?.seek(percent: 0.9)
        XCTAssertEqual([RxPlayerStatus.seeking, RxPlayerStatus.playing, RxPlayerStatus.finished],
                       try? player?
                        .statusObservable
                        .take(3)
                        .toBlocking(timeout: 3)
                        .toArray())
    }

    func test_再生開始時間を指定できる() {
        let player = createPlayer(autoplay: false)
        player?.offset = 0.9
        var result = try? player?
            .statusObservable
            .take(3)
            .toBlocking(timeout: 3)
            .toArray()
        XCTAssertEqual([RxPlayerStatus.prepare, RxPlayerStatus.seeking, RxPlayerStatus.ready],
                       result)
        player?.play()
        result = try? player?
            .statusObservable
            .take(2)
            .toBlocking(timeout: 3)
            .toArray()
        XCTAssertEqual([RxPlayerStatus.playing, RxPlayerStatus.finished],
                       result)
    }

    func test_再生中に別のMP4の再生を開始できる() {
        let player = createPlayer(autoplay: true)
        XCTAssertEqual([RxPlayerStatus.prepare, RxPlayerStatus.ready],
                       try? player?
                        .statusObservable
                        .take(2)
                        .toBlocking(timeout: 3)
                        .toArray())
        XCTAssertEqual(RxPlayerStatus.playing,
                       try? player?
                        .statusObservable
                        .delay(0.3, scheduler: MainScheduler.instance)
                        .toBlocking(timeout: 3)
                        .first())

        let asset = NSDataAsset(name: "SampleVideo2", bundle: Bundle(for: type(of: self)))
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SampleVideo2.mp4")
        try! asset!.data.write(to: url)
        player!.load(url, autoPlay: true, offset: 0.99)
        let result = try? player?
            .statusObservable
            .take(5)
            .toBlocking(timeout: 10)
            .toArray()
        XCTAssertEqual([RxPlayerStatus.prepare, RxPlayerStatus.seeking, RxPlayerStatus.ready, RxPlayerStatus.playing, RxPlayerStatus.finished],
                       result)
    }

    func test_登録したコントローラViewにPlayerを渡す() {
        let player = createPlayer(autoplay: false)!
        let result = MockControlableView()
        player.controlViews = [result]
        XCTAssertNotNil(result.player)
    }

    func test_登録したViewのリストをControlのリストに変換できる() {
        let player = createPlayer(autoplay: false)!
        let view = MockControlableView()
        player.controlViews = [view]
        let result: [RxAVPlayerControllable] = player.convertControls()
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(type(of: result) == [RxAVPlayerControllable].self)
    }
}
