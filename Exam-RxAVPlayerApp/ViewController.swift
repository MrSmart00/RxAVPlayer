//
//  ViewController.swift
//  Exam-RxAVPlayerApp
//
//  Created by HINOMORI HIROYA on 2018/07/04.
//  Copyright © 2018年 HINOMORI HIROYA. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var player: RxAVPlayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        player.autoplay = true
        player.visibleSkipSeconds = 2.0
        player.mute = true
        player.url = URL(string: "https://s3.us-east-2.amazonaws.com/vjs-nuevo/hls/m3u8/playlist.m3u8")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}
