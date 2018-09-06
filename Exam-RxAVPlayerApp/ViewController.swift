//
//  ViewController.swift
//  Exam-RxAVPlayerApp
//
//  Created by HINOMORI HIROYA on 2018/07/04.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit

import RxSwift

class ViewController: UIViewController {

    @IBOutlet weak var player: RxAVPlayer!
    
    private let disposebag = DisposeBag()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        player.autoplay = true
        player.visibleSkipSeconds = 2.0
        player.dateFormatString = "mm:ss"
        player.userInfo = "あああああああああああああああああああああああああああああああああああ"
        player.mute = true
        player.url = URL(string: "http://comicimg.comico.jp/voicecomic/26819/2/5d0e1b6d_1532597166720.mp4/mp4hls/index.m3u8")
        Observable.combineLatest(player.statusObservable, player.progressObservable) { (status, progress) -> (RxPlayerStatus, RxPlayerProgressStatus) in
            return (status, progress)
        }.bind { (status, progress) in
            print("\(status.rawValue): \(progress.rawValue)")
        }.disposed(by: disposebag)
        
        player.closeObservable.subscribe(onNext: { (_) in
            print("close!!")
        }).disposed(by: disposebag)
//        player.touchObservable.bind { (userinfo) in
//            print(userinfo)
//        }.disposed(by: disposebag)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

