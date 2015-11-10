//
//  ViewController.swift
//  MetalPaint
//
//  Created by Ryder Mackay on 2015-09-06.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import Cocoa
import MetalKit
import simd
import AVFoundation
import CoreMedia

enum Demo {
    case Paint
    case CoreVideo
    case CoreImage
}

let demo = Demo.Paint


enum Error: ErrorType {
    case FailedToCreateCVMetalTextureCache(CVReturn)
    case FailedToCreateCVMetalTexture(CVReturn)
}

extension CVMetalTextureCacheRef {
    class func textureCacheWithAttributes(cacheAttributes: [String: AnyObject], metalDevice: MTLDevice, textureAttributes: [String: AnyObject]) throws -> CVMetalTextureCacheRef {
        var cache: Unmanaged<CVMetalTextureCacheRef>?
        let result = CVMetalTextureCacheCreate(nil, cacheAttributes, metalDevice, textureAttributes, &cache)
        guard result == kCVReturnSuccess else {
            throw Error.FailedToCreateCVMetalTextureCache(result)
        }
        return cache!.takeRetainedValue()
    }
    
    func createTextureFromImage(imageBuffer: CVImageBuffer, metalPixelFormat: MTLPixelFormat, width: Int, height: Int, plane: Int) throws -> CVMetalTexture {
        var texture: Unmanaged<CVMetalTexture>?
        let result = CVMetalTextureCacheCreateTextureFromImage(nil, self, imageBuffer, [:], metalPixelFormat, width, height, plane, &texture)
        guard result == kCVReturnSuccess else {
            throw Error.FailedToCreateCVMetalTexture(result)
        }
        return texture!.takeRetainedValue()
    }
}

final class CaptureController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let captureSession = AVCaptureSession()
    let captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    let captureDeviceInput: AVCaptureDeviceInput
    let captureVideoDataOutput = AVCaptureVideoDataOutput()
    
    let captureSessionQueue = dispatch_queue_create("com.rydermackay.CaptureSessionQueue", DISPATCH_QUEUE_SERIAL)
    let sampleBufferQueue = dispatch_queue_create("com.rydermackay.SampleBufferDelegateQueue", DISPATCH_QUEUE_SERIAL)
    
    let device: MTLDevice
    let metalTextureCache: CVMetalTextureCache
    
    init(device: MTLDevice) {
        self.device = device
        let cacheAttributes: [String: AnyObject] = [:]
        let textureAttributes: [String: AnyObject] = [:]
        metalTextureCache = try! CVMetalTextureCacheRef.textureCacheWithAttributes(cacheAttributes, metalDevice: device, textureAttributes: textureAttributes)
        captureDeviceInput = try! AVCaptureDeviceInput(device: captureDevice)
        
        super.init()
        
        let videoSettings: [String: AnyObject] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                                                  kCVPixelBufferMetalCompatibilityKey as String: true]
        captureVideoDataOutput.videoSettings = videoSettings
        captureVideoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        captureVideoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        
        dispatch_async(captureSessionQueue) {
            self.captureSession.beginConfiguration()
            self.captureSession.addInput(self.captureDeviceInput)
            self.captureSession.addOutput(self.captureVideoDataOutput)
            self.captureSession.commitConfiguration()
            
            self.captureSession.startRunning()
        }
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        CVMetalTextureCacheFlush(metalTextureCache, 0)
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let size = CVImageBufferGetDisplaySize(imageBuffer)
        let texture = try! metalTextureCache.createTextureFromImage(imageBuffer, metalPixelFormat: .BGRA8Unorm, width: Int(size.width), height: Int(size.height), plane: 0)
        viewController.paintController.backingTexture = CVMetalTextureGetTexture(texture)!
        viewController.metalView.draw()
    }
    
    var viewController: ViewController!
}

class ViewController: NSViewController {
    
    let device = MTLCopyAllDevices().filter { $0.lowPower }.first!
//    let device = MTLCreateSystemDefaultDevice()!
    var metalView: MTKView { return view as! MTKView }
    lazy var commandQueue: MTLCommandQueue = { self.device.newCommandQueue() } ()
    
    var captureController: CaptureController!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        metalView.device = device
        metalView.delegate = self
        
        metalView.enableSetNeedsDisplay = false
        metalView.paused = true
        
        setupStuff()
        
        metalView.draw()
        
        if demo == .CoreVideo {
            captureController = CaptureController(device: device)
            captureController.viewController = self
        }
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    var paintController: PaintController!
    
    
    
    func setupStuff() {
        let library = device.newDefaultLibrary()!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        renderPipelineDescriptor.colorAttachments[0].blendingEnabled = true
        
        
        // r = (s * s.a) + d * (1 - s.a)
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .Add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .Add
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .SourceAlpha
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .SourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .OneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .OneMinusSourceAlpha
        
        renderPipelineDescriptor.vertexFunction = library.newFunctionWithName("myVertexFunction")
        renderPipelineDescriptor.fragmentFunction = demo == .CoreVideo ? library.newFunctionWithName("fragChromaKey") : library.newFunctionWithName("myFragmentFunction")
        renderPipelineDescriptor.inputPrimitiveTopology = .Triangle
        
        renderPipelineState = try! device.newRenderPipelineStateWithDescriptor(renderPipelineDescriptor)
        
        
        if demo == .CoreImage {
            metalView.framebufferOnly = false   // allows Core Image to read the contents in a shader
        }
        
        
        var vertices = [
            Vertex(x: -1, y:  1, u: 0, v: 0),   // top left
            Vertex(x: -1, y: -1, u: 0, v: 1),   // bottom left
            Vertex(x:  1, y: -1, u: 1, v: 1),   // bottom right
            Vertex(x:  1, y: -1, u: 1, v: 1),   // bottom right
            Vertex(x:  1, y:  1, u: 1, v: 0),   // top right
            Vertex(x: -1, y:  1, u: 0, v: 0),   // top left
        ]
        
        vertexBuffer = device.newBufferWithBytes(&vertices, length: vertices.count * strideof(Vertex), options: [])
        
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .Linear
        samplerDescriptor.magFilter = .Linear
//        samplerDescriptor.sAddressMode = .MirrorRepeat // x
//        samplerDescriptor.tAddressMode = .MirrorClampToEdge // y
        samplerState = device.newSamplerStateWithDescriptor(samplerDescriptor)
        
        
        var uniforms = [Uniforms(modelMatrix: float4x4(1), viewProjectionMatrix: float4x4(1))]
        uniformBuffer = device.newBufferWithBytes(&uniforms, length: uniforms.count * strideof(Uniforms), options: [])
    }
    
    var renderPipelineState: MTLRenderPipelineState!
    var samplerState: MTLSamplerState!
    var vertexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    
    var texture: MTLTexture!
    
    
    let useTextureLoader = false
    lazy var textureLoader: MTKTextureLoader = { return MTKTextureLoader(device: self.device) }()
    
    func loadTextureFromURL(URL: NSURL) {
        let usage: MTLTextureUsage = [.RenderTarget, .ShaderRead]
        
        let texture: MTLTexture
        
        if useTextureLoader {
            texture = try! textureLoader.newTextureWithContentsOfURL(URL, options: [MTKTextureLoaderOptionTextureUsage: usage.rawValue])
        } else {
            let imageSource = CGImageSourceCreateWithURL(URL, nil)!
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)!
            texture = textureFromCGImage(image, usage: usage)
        }
        
        paintController.backingTexture = texture
        metalView.draw()
    }
    
    func loadTextureFromImage(image: NSImage) {
        let cgimage = image.CGImageForProposedRect(nil, context: nil, hints: nil)!
        let usage: MTLTextureUsage = [.RenderTarget, .ShaderRead]
        let texture: MTLTexture
        if useTextureLoader {
            texture = try! textureLoader.newTextureWithCGImage(cgimage, options: [MTKTextureLoaderOptionTextureUsage: usage.rawValue])
        } else {
            texture = textureFromCGImage(cgimage, usage: usage)
        }
        paintController.backingTexture = texture
        metalView.draw()
    }
    
    func textureFromCGImage(image: CGImage, usage: MTLTextureUsage) -> MTLTexture {
        let info = CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue
        let ctx = CGBitmapContextCreate(nil, image.width, image.height, 8, 0, CGColorSpaceCreateDeviceRGB(), info)
        CGContextDrawImage(ctx, CGRect(x: 0, y: 0, width: image.width, height: image.height), image)
        let bytes = CGBitmapContextGetData(ctx)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.BGRA8Unorm, width: image.width, height: image.height, mipmapped: false)
        descriptor.usage = usage
        
        var region = MTLRegion()
        region.size = MTLSizeMake(CGImageGetWidth(image), CGImageGetHeight(image), 1)
        let texture = device.newTextureWithDescriptor(descriptor)
        texture.replaceRegion(region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: CGBitmapContextGetBytesPerRow(ctx))
        return texture
    }
    
    
    
    
    
    lazy var cicontext: CIContext = { return CIContext(MTLDevice: self.device) }()
}

extension CGImage {
    var width: Int { return CGImageGetWidth(self) }
    var height: Int { return CGImageGetHeight(self) }
}

struct Vertex: ArrayLiteralConvertible {
    typealias Element = float4
    init(arrayLiteral elements: Vertex.Element...) {
        position = elements[0]
        textureCoordinates = elements[1]
    }
    let position: float4
    let textureCoordinates: float4
    
    init(x: Float, y: Float, u: Float, v: Float) {
        position = float4(x, y, 0, 1)
        textureCoordinates = float4(u, v, 0, 0)
    }
}

final class View : MTKView {
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInit()
    }
    func commonInit() {
        let types = [kUTTypeImage as String, kUTTypeFileURL as String]
        registerForDraggedTypes(types)
    }
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        let options = [NSPasteboardURLReadingFileURLsOnlyKey: true, NSPasteboardURLReadingContentsConformToTypesKey: [kUTTypeImage as String]]
        if sender.draggingPasteboard().canReadObjectForClasses([NSImage.self, NSURL.self], options: options) {
            return .Copy
        }
        return .None
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        
        let options = [NSPasteboardURLReadingFileURLsOnlyKey: true, NSPasteboardURLReadingContentsConformToTypesKey: [kUTTypeImage as String]]
        let objects = sender.draggingPasteboard().readObjectsForClasses([NSImage.self, NSURL.self], options: options)
        if let anyObject = objects?.first {
            switch anyObject {
            case let image as NSImage:
                viewController.loadTextureFromImage(image)
                return true
            case let URL as NSURL:
                viewController.loadTextureFromURL(URL)
                return true
            default:
                break
            }
        }
        
        return false
    }
    
    var viewController: ViewController { return nextResponder as! ViewController }
    
    override func mouseDown(theEvent: NSEvent) {
        guard demo != .CoreVideo else { return }
        // convert point to normalized canvas coordinates
        let pointInViewCoordinates = convertPoint(theEvent.locationInWindow, fromView: nil)
        let pointInBackingCoordinates = convertPointToBacking(pointInViewCoordinates)
        let normalizedPoint = self.normalizedPoint(pointInBackingCoordinates)
        viewController.paintController.stampPoint(normalizedPoint)
        viewController.metalView.draw()
    }
    
    override func mouseDragged(theEvent: NSEvent) {
        guard demo != .CoreVideo else { return }
        // convert point to normalized canvas coordinates
        let pointInViewCoordinates = convertPoint(theEvent.locationInWindow, fromView: nil)
        let pointInBackingCoordinates = convertPointToBacking(pointInViewCoordinates)
        let normalizedPoint = self.normalizedPoint(pointInBackingCoordinates)
        viewController.paintController.stampPoint(normalizedPoint)
        viewController.metalView.draw()
    }
    
    func normalizedPoint(pointInBackingCoordinates: NSPoint) -> NSPoint {
        // assumes bounds origin is 0,0
        let viewport = viewController.viewport
        var p =  CGPoint(x: (-CGFloat(viewport.originX) + pointInBackingCoordinates.x) / CGFloat(viewport.width),
                         y: (-CGFloat(viewport.originY) + pointInBackingCoordinates.y) / CGFloat(viewport.height))
        p.x = p.x * 2 - 1
        p.y = p.y * 2 - 1
        return p
    }
    
    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        enableSetNeedsDisplay = true
    }
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        enableSetNeedsDisplay = false
    }
    
    override func setFrameSize(newSize: NSSize) {
        super.setFrameSize(newSize)
        if inLiveResize {
            needsDisplay = true
        } else {
            draw()
        }
    }
}

extension ViewController : MTKViewDelegate {
    
    
    var viewport: MTLViewport {
        let bounds = metalView.convertRectToBacking(metalView.bounds)
        let x = Double(bounds.midX) - Double(paintController.backingTexture.width) * 0.5
        let y = Double(bounds.midY) - Double(paintController.backingTexture.height) * 0.5
        return MTLViewport(originX: x, originY: y, width: Double(paintController.backingTexture.width), height: Double(paintController.backingTexture.height), znear: 1, zfar: 0)
    }
    
    func drawInMTKView(view: MTKView) {
        if paintController == nil {
            paintController = PaintController(device: device)
        }
        
        if texture == nil {
            texture = paintController.paintbrushTexture
        }
        
        let commandBuffer = commandQueue.commandBuffer()
        
        
        
        
        
        
        guard let drawable = view.currentDrawable else {
            return
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .Store
        
        // draw quad to screen using texture
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        
        renderEncoder.setViewport(viewport)
//        print(viewport)
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
        renderEncoder.setFragmentSamplerState(samplerState, atIndex: 0)
        renderEncoder.setFragmentTexture(paintController.backingTexture, atIndex: 0)
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: vertexBuffer.length / strideof(Vertex))
        renderEncoder.endEncoding()
        
        if demo == .CoreImage {
            let imageInputTexture = drawable.texture
            let filter = CIFilter(name: "CISepiaTone")!
            filter.setDefaults()
            let image = CIImage(MTLTexture: imageInputTexture, options: [:])
            filter.setValue(image, forKey: kCIInputImageKey)
            let outputImage = filter.outputImage!
            
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.BGRA8Unorm, width: imageInputTexture.width, height: imageInputTexture.height, mipmapped: false)
            textureDescriptor.usage = [.RenderTarget, .ShaderRead, .ShaderWrite]
            let outputTexture = device.newTextureWithDescriptor(textureDescriptor)
            
            cicontext.render(outputImage, toMTLTexture: outputTexture, commandBuffer: commandBuffer, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB()!)
            
            let blitEncoder = commandBuffer.blitCommandEncoder()
            blitEncoder.copyFromTexture(outputTexture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: outputTexture.width, height: outputTexture.height, depth: outputTexture.depth), toTexture: drawable.texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            blitEncoder.endEncoding()
        }
        
        
        // blit the output to the framebuffer
        
        commandBuffer.presentDrawable(drawable)
        
        commandBuffer.commit()
    }
    
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}


struct Uniforms {
    let modelMatrix: float4x4
    let viewProjectionMatrix: float4x4
}


final class PaintController {
    let device: MTLDevice
    let paintbrushTexture: MTLTexture
    var backingTexture: MTLTexture
    lazy var commandQueue: MTLCommandQueue = { self.device.newCommandQueue() } ()
    
    let renderPipelineState: MTLRenderPipelineState
    let samplerState: MTLSamplerState
    
    let vertexBuffer: MTLBuffer
    var uniformBuffer: MTLBuffer!
    
    init(device: MTLDevice) {
        self.device = device
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.BGRA8Unorm, width: 1280, height: 720, mipmapped: false)
        descriptor.usage = [.RenderTarget, .ShaderRead]
        self.backingTexture = device.newTextureWithDescriptor(descriptor)
        
        let URL = NSBundle.mainBundle().URLForResource("Mushroom-128", withExtension: "png")!
        self.paintbrushTexture = try! MTKTextureLoader(device: device).newTextureWithContentsOfURL(URL, options: nil)
        
        
        let library = device.newDefaultLibrary()!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        renderPipelineDescriptor.colorAttachments[0].blendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .Add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .Add
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .SourceAlpha
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .SourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .OneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .OneMinusSourceAlpha
        renderPipelineDescriptor.vertexFunction = library.newFunctionWithName("myVertexFunction")
        renderPipelineDescriptor.fragmentFunction = library.newFunctionWithName("myFragmentFunction")
        renderPipelineDescriptor.inputPrimitiveTopology = .Triangle
        
        renderPipelineState = try! device.newRenderPipelineStateWithDescriptor(renderPipelineDescriptor)
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .Nearest
        samplerDescriptor.magFilter = .Nearest
        
        samplerState = device.newSamplerStateWithDescriptor(samplerDescriptor)
        
        // mushroom is flipped for some reason
        var vertices = [
            Vertex(x: -1, y:  1, u: 0, v: 1),   // top left
            Vertex(x: -1, y: -1, u: 0, v: 0),   // bottom left
            Vertex(x:  1, y: -1, u: 1, v: 0),   // bottom right
            Vertex(x:  1, y: -1, u: 1, v: 0),   // bottom right
            Vertex(x:  1, y:  1, u: 1, v: 1),   // top right
            Vertex(x: -1, y:  1, u: 0, v: 1),   // top left
        ]
        vertexBuffer = device.newBufferWithBytes(&vertices, length: vertices.count * strideof(Vertex), options: [])
        
        
        //////// clear backing texture
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = backingTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].storeAction = .Store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        let commandBuffer = commandQueue.commandBuffer()
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func stampPoint(point: CGPoint) {
        
        // target size: 128x128
        
        // update uniforms for stamp scale + translation
        var modelMatrix = float4x4(1)
        modelMatrix[0].x = Float(paintbrushTexture.width) / Float(backingTexture.width)    // scale x
        modelMatrix[1].y = Float(paintbrushTexture.height) / Float(backingTexture.height)   // scale y
        modelMatrix[3].x = Float(point.x)                       // translate x
        modelMatrix[3].y = Float(point.y)                       // translate y
        var uniforms = [Uniforms(modelMatrix: modelMatrix, viewProjectionMatrix: float4x4(1))]
        if uniformBuffer == nil {
            uniformBuffer = device.newBufferWithBytes(&uniforms, length: uniforms.count * strideof(Uniforms), options: [])
        } else {
            let length = uniforms.count * strideof(Uniforms)
            memcpy(uniformBuffer.contents(), &uniforms, length)
        }
        
        let commandBuffer = commandQueue.commandBuffer()
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = backingTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .Load // preserve existing contents
        renderPassDescriptor.colorAttachments[0].storeAction = .Store // preserve drawn contents
        
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setFragmentSamplerState(samplerState, atIndex: 0)
        renderEncoder.setFragmentTexture(paintbrushTexture, atIndex: 0)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: vertexBuffer.length / strideof(Vertex))
        renderEncoder.endEncoding()
        
        commandBuffer.commit()
    }
}
