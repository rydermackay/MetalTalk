//
//  MetalView.swift
//  Hello Triangle
//
//  Created by Ryder Mackay on 2015-09-08.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

#if os(OSX)
    
    import Cocoa
    
    class MetalView: NSView {
        
        var metalLayer: CAMetalLayer { return layer as! CAMetalLayer }
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
        }
        
        override func makeBackingLayer() -> CALayer {
            return CAMetalLayer()
        }
    }
    
#else
    
    import UIKit
    
    class MetalView: UIView {
        
        var metalLayer: CAMetalLayer { return layer as! CAMetalLayer }
        
        override class func layerClass() -> AnyClass {
            return CAMetalLayer.self
        }
    }
    
#endif
