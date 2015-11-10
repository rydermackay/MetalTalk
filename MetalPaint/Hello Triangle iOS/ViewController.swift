//
//  ViewController.swift
//  Hello Triangle iOS
//
//  Created by Ryder Mackay on 2015-09-08.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var metalView: MetalView { return view as! MetalView }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal not supported :(")
            return
        }
        
        do {
            let renderer = try TriangleRenderer(device: device)
            renderer.renderInLayer(metalView.metalLayer)
        } catch {
            print("Error creating renderer: \(error)")
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
}

