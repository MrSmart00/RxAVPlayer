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

    @IBOutlet weak var player: CustomPlayer!
    
    private let disposebag = DisposeBag()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        player.autoplay = true
        player.userInfo = "あああああああああああああああああああああああああああああああああああ"
        player.mute = true
        player.url = URL(string: "http://sample.vodobox.net/skate_phantom_flex_4k/skate_phantom_flex_4k.m3u8")
        
        player.statusObservable.bind { (status) in
            print("🍺  \(status.rawValue)")
        }.disposed(by: disposebag)
        player.currentStatusObservable.bind { (status) in
            print("🍻  \(status.rawValue)")
        }.disposed(by: disposebag)
        player.viewableObservable.bind { (_) in
            print("🍻🍻🍻🍻🍻")
        }.disposed(by: disposebag)
        player.customEventRelay.subscribe(onNext: { (value) in
            print(value)
        }).disposed(by: disposebag)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

