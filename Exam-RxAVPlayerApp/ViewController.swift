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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        player.autoplay = true
        player.visibleSkipSeconds = 2.0
        player.dateFormatString = "m:ss"
        player.userInfo = "aaaa"
        player.mute = true
        player.url = URL(string: "https://hogehoge/playlist.m3u8")
        player.closeObservable.subscribe(onNext: { (_) in
            print("close!!")
        }).disposed(by: disposebag)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

