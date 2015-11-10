//
//  ViewController.swift
//  Hello Triangle
//
//  Created by Ryder Mackay on 2015-08-25.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import Cocoa
import Metal

class ViewController: NSViewController {
    
    var renderer: Renderer!
    let device = MTLCreateSystemDefaultDevice()!
    
    var metalView: MetalView { return view as! MetalView }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal not supported :(")
            return
        }
        
        metalView.metalLayer.device = device
        
        do {
            renderer = try TriangleRenderer(device: device)
            renderer.renderInLayer(metalView.metalLayer)
        } catch {
            print("Error creating renderer: \(error)")
        }
    }
}
