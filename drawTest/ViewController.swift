//
//  ViewController.swift
//  drawTest
//
//  Created by Ciobanasu Ion on 02/08/2018.
//  Copyright © 2018 Ciobanasu Ion. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: FloodFillImageView!
    
    @IBOutlet var colorsButton: [UIButton]!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        imageView.tolorance = 100
        imageView.newcolor  = UIColor.red
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func chooseColorBtnPressed(_ sender: UIButton) {
        switch sender.tag {
        case 1:
            print("Red color")
            imageView.newcolor = UIColor.red
        case 2:
            print("Green color")
            imageView.newcolor = UIColor.green
        case 3:
            print("Blue color")
            imageView.newcolor = UIColor.blue
        case 4:
            print("Black color")
            imageView.newcolor = UIColor.black
        case 5:
            print("Gray color")
            imageView.newcolor = UIColor.darkGray
        default:
            print("NO")
            break
        }
    }
}

