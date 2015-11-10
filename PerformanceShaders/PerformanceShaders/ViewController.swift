//
//  ViewController.swift
//  MetalPerf
//
//  Created by Ryder Mackay on 2015-09-03.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import UIKit
import Metal
import MetalKit
import MetalPerformanceShaders

class ViewController: UIViewController {

    var device: MTLDevice { return metalView.device! }
    var metalView: MTKView { return view as! MTKView }
    
    var commandQueue: MTLCommandQueue!
    var sourceTexture: MTLTexture!
    var destinationTexture: MTLTexture!
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.framebufferOnly = false
        metalView.delegate = self
        
        commandQueue = device.newCommandQueue()
    }
    
    func imageWithSize(size: CGSize, scale: CGFloat) -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(size, true, scale)
        
        let rect = CGRect(origin: .zero, size: size)
        
        UIColor.redColor().setFill()
        UIBezierPath(ovalInRect: rect).fill()
        
        let text = NSString(string: "🤘METAL!!🤘")
        
        let attributes = [NSFontAttributeName : UIFont.boldSystemFontOfSize(128 * scale)]
        
        let textSize = text.sizeWithAttributes(attributes)
        let textFrame = CGRect(x: rect.midX - textSize.width * 0.5, y: rect.midY - textSize.height * 0.5, width: textSize.width, height: textSize.height)
        text.drawInRect(textFrame, withAttributes: attributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image
    }
    
    
    var s: Float = 0
    var rate: Float = 0.5
}

extension ViewController : MTKViewDelegate {

    func drawInMTKView(view: MTKView) {
        
        if s > 40 || s < 0 {
            rate *= -1
        }
        
        s += rate
        
        guard let mps = Optional(MPSImageGaussianBlur(device: device, sigma: s)) else {
            fatalError("Metal Performance Shaders require A8(x) devices")
        }
        
        // source texture == screenshot
        // destination texture == current drawable
        
        
        let commandBuffer = commandQueue.commandBuffer()
        
        if let drawable = view.currentDrawable {
            // iOS 9.0.1? 9.1?? broke the ability to use MPS to render directly to drawable's texture >:|
            mps.encodeToCommandBuffer(commandBuffer, sourceTexture: sourceTexture, destinationTexture: destinationTexture)
            
            // …so we need an additional step to blit the result to the framebuffer
            let blit = commandBuffer.blitCommandEncoder()
            blit.copyFromTexture(destinationTexture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: destinationTexture.width, height: destinationTexture.height, depth: 1), toTexture: drawable.texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin())
            blit.endEncoding()
            
            commandBuffer.presentDrawable(drawable)
            commandBuffer.commit()
        }
    }
    
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(metalView.colorPixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false)
        sourceTexture = device.newTextureWithDescriptor(descriptor)
        destinationTexture = device.newTextureWithDescriptor(descriptor)
        
        uploadImage(imageWithSize(size, scale: 1), toTexture: sourceTexture)
    }
    
    func uploadImage(image: UIImage, toTexture texture: MTLTexture) {
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)
        let ctx = CGBitmapContextCreate(nil, region.size.width, region.size.height, 8, 0, CGColorSpaceCreateDeviceRGB(), bitmapInfo.rawValue)!
        CGContextTranslateCTM(ctx, 0, CGFloat(region.size.height))
        CGContextScaleCTM(ctx, 1, -1)
        UIGraphicsPushContext(ctx)
        image.drawInRect(CGRect(x: 0, y: 0, width: texture.width, height: texture.height))
        UIGraphicsPopContext()
        let bytes = CGBitmapContextGetData(ctx)
        texture.replaceRegion(region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: CGBitmapContextGetBytesPerRow(ctx))
    }
}

