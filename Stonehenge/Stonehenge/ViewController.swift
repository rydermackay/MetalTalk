//
//  ViewController.swift
//  Stonehenge
//
//  Created by Ryder Mackay on 2015-08-25.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import Cocoa
import Metal
import ModelIO
import MetalKit


class ViewController: NSViewController {
    
    let device = MTLCreateSystemDefaultDevice()!

    var metalView: MetalView { return view as! MetalView }
    
    var angle = CGPoint.zero
    var velocity = CGPoint.zero
    
    @IBAction func pan(sender: NSPanGestureRecognizer) {

        switch sender.state {
        case .Began:
            stopTicking()
        case .Ended, .Cancelled:
            startTicking()
        default:
            break
        }
        
        let scale: CGFloat = 0.005
        velocity = sender.velocityInView(view)
        velocity.x *= scale
        velocity.y *= scale
        
        updateMotion()
        render()
    }
    
    var timer: NSTimer?
    
    func startTicking() {
        timer?.invalidate()
        timer = NSTimer(timeInterval: 1/60, target: self, selector: "tick:", userInfo: nil, repeats: true)
        NSRunLoop.mainRunLoop().addTimer(timer!, forMode: NSRunLoopCommonModes)
    }
    
    func stopTicking() {
        timer?.invalidate()
        timer = nil
    }
    
    func tick(sender: NSTimer) {
        let decay: CGFloat = 0.025
        velocity = CGPoint(x: velocity.x * (1 - decay), y: velocity.y * (1 - decay))
        if abs(velocity.x) < 0.01 && abs(velocity.y) < 0.01 {
            stopTicking()
            velocity = .zero
        }
        updateMotion()
        render()
    }
    
    var lastTime: NSTimeInterval = 0
    
    func updateMotion() {
        let now = CACurrentMediaTime()
        let interval = CGFloat(now - lastTime)
        if interval > 0 {
            angle = CGPoint(x: angle.x + velocity.x * interval, y: angle.y - velocity.y * interval)
        }
        lastTime = now
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let pan = NSPanGestureRecognizer(target: self, action: "pan:")
        view.addGestureRecognizer(pan)

        metalView.metalLayer.device = device

        commandQueue = device.newCommandQueue()
        
        let library = device.newDefaultLibrary()!
        
        if mtkMesh == nil {
            let vertexDescriptor = MDLVertexDescriptor()
            vertexDescriptor.reset()
            var offset = 0
            let position = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .Float4, offset: offset, bufferIndex: 0)
            offset += strideof(float4)
            let normal = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .Float3, offset: offset, bufferIndex: 0)
            offset += strideof(float3)
            let texCoord = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .Float2, offset: offset, bufferIndex: 0)
            offset += strideof(float2)
            vertexDescriptor.attributes = [position, normal, texCoord]
            let layout = MDLVertexBufferLayout()
            layout.stride = offset
            vertexDescriptor.layouts = [layout]
            
            let URL = NSBundle.mainBundle().URLForResource("Stonehenge", withExtension: "obj")!
            let asset = MDLAsset(URL: URL, vertexDescriptor: vertexDescriptor, bufferAllocator: MTKMeshBufferAllocator(device: device))
            mdlMesh = asset.objectAtIndex(0) as! MDLMesh
            
            do {
                mtkMesh = try MTKMesh(mesh: mdlMesh, device: device)
            } catch {
                print("error loading meshes: \(error)")
            }
        }
        
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = library.newFunctionWithName("vertex_main")
        renderPipelineDescriptor.fragmentFunction = library.newFunctionWithName("fragment_main")
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        renderPipelineDescriptor.depthAttachmentPixelFormat = .Depth24Unorm_Stencil8
        renderPipelineDescriptor.stencilAttachmentPixelFormat = .Depth24Unorm_Stencil8
        renderPipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mtkMesh.vertexDescriptor)
        
        renderPipelineState = try! device.newRenderPipelineStateWithDescriptor(renderPipelineDescriptor)
        
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .LessEqual
        depthStencilDescriptor.depthWriteEnabled = true
        
        depthStencilState = device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
        
        updateMotion()
        render()
    }
    
    var uniformBuffer: MTLBuffer!
    var vertexBuffer: MTLBuffer!
    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
    var depthStencilState: MTLDepthStencilState!
    
    var mdlMesh: MDLMesh!
    var mtkMesh: MTKMesh!
    var depthStencilTexture: MTLTexture!
    var stoneTexture: MTLTexture!
    
    func render() {
        // drawing
        guard let drawable = metalView.metalLayer.nextDrawable() else {
            print("no available drawables!")
            return
        }
        
        updateUniforms()
        
        let commandBuffer = commandQueue.commandBuffer()
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        
        if depthStencilTexture == nil {
            
            let d = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.Depth24Unorm_Stencil8, width: drawable.texture.width, height: drawable.texture.height, mipmapped: false)
            d.storageMode = .Private
            d.usage = .RenderTarget
            depthStencilTexture = device.newTextureWithDescriptor(d)
        }
        renderPassDescriptor.depthAttachment.texture = depthStencilTexture
        renderPassDescriptor.stencilAttachment.texture = depthStencilTexture
        
        let renderCommandEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderCommandEncoder.setDepthStencilState(depthStencilState)
        renderCommandEncoder.setFrontFacingWinding(.CounterClockwise)
        renderCommandEncoder.setCullMode(.Back)
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
        renderCommandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, atIndex: 0)
        
        
        var idx = 0
        for (mtkMeshBuffer, mdlMeshBuffer) in zip(mtkMesh.vertexBuffers, mdlMesh.vertexBuffers) {
            switch mtkMeshBuffer.type {
            case .Vertex:
                renderCommandEncoder.setVertexBuffer(mtkMeshBuffer.buffer, offset: 0, atIndex: idx)
                idx++
            case .Index:
                break
            }
            for (mtkSubmesh, mdlSubmesh) in zip(mtkMesh.submeshes, mdlMesh.submeshes as! [MDLSubmesh]) {
                if stoneTexture == nil {
                    if let material = mdlSubmesh.material {
                        let p = material.propertyWithSemantic(.BaseColor)
                        let string = p!.stringValue!
//                        let URL = NSURL(fileURLWithPath: string)
                        let URL = NSBundle.mainBundle().URLForResource("free_stone_texture", withExtension: "jpg")! // I tried :|
                        stoneTexture = try! MTKTextureLoader(device: device).newTextureWithContentsOfURL(URL, options: [:])
                    }
                }
                renderCommandEncoder.setFragmentTexture(stoneTexture, atIndex: 0)
                renderCommandEncoder.drawIndexedPrimitives(mtkSubmesh.primitiveType, indexCount: mtkSubmesh.indexCount, indexType: mtkSubmesh.indexType, indexBuffer: mtkSubmesh.indexBuffer.buffer, indexBufferOffset: mtkSubmesh.indexBuffer.offset)
            }
        }
        
        renderCommandEncoder.endEncoding()
        
        commandBuffer.presentDrawable(drawable)
        
        commandBuffer.commit()
    }
    
    var uniforms: Uniform!
    struct Uniform {
        let modelViewProjectionMatrix: float4x4
        let modelViewMatrix: float4x4
        let normalMatrix: float3x3
    }
    
    func updateUniforms() {
        
        let xAxis = float3(1, 0, 0)
        let yAxis = float3(0, 1, 0)
        var modelMatrix = float4x4(0.01)
        modelMatrix = rotation(yAxis, angle: Float(-angle.x)) * modelMatrix
        modelMatrix = rotation(xAxis, angle: Float(-angle.y)) * modelMatrix
        modelMatrix[3].y = -1
        modelMatrix[3].w = 1
        
        var viewMatrix = float4x4(1)
        viewMatrix[3].z = -10
        
        let near: Float = 0.1
        let far: Float = 1000
        let aspect = Float(view.bounds.width / view.bounds.height)
        
        let degrees = 75.0
        let radiansPerDegree = M_PI / 180.0
        let fovy = Float(radiansPerDegree * degrees)
        let projectionMatrix = float4x4(aspect: aspect, fovy: fovy, near: near, far: far)
        
        let modelView = viewMatrix * modelMatrix
        let modelViewProj = projectionMatrix * modelView
        let normalMatrix = float3x3([float3(modelView[0].x, modelView[0].y, modelView[0].z),
                                     float3(modelView[1].x, modelView[1].y, modelView[1].z),
                                     float3(modelView[2].x, modelView[2].y, modelView[2].z)]).inverse.transpose
        
        uniforms = Uniform(modelViewProjectionMatrix: modelViewProj,
                                     modelViewMatrix: modelView,
                                        normalMatrix: normalMatrix)
        
        uniformBuffer = device.newBufferWithBytes(&uniforms, length: strideof(Uniform), options: [])
    }
}

func rotation(axis: float3, angle: Float) -> float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    
    var X = float4()
    X.x = axis.x * axis.x + (1 - axis.x * axis.x) * c
    X.y = axis.x * axis.y * (1 - c) - axis.z * s
    X.z = axis.x * axis.z * (1 - c) + axis.y * s
    
    var Y = float4()
    Y.x = axis.x * axis.y * (1 - c) + axis.z * s
    Y.y = axis.y * axis.y + (1 - axis.y * axis.y) * c
    Y.z = axis.y * axis.z * (1 - c) - axis.x * s
    
    var Z = float4()
    Z.x = axis.x * axis.z * (1 - c) - axis.y * s
    Z.y = axis.y * axis.z * (1 - c) + axis.x * s
    Z.z = axis.z * axis.z + (1 - axis.z * axis.z) * c
    
    var W = float4()
    W.w = 1.0
    
    return float4x4([X, Y, Z, W])
}

extension float4x4 {
    init(aspect: Float, fovy: Float, near: Float, far: Float) {
        let yScale = 1 / tan(fovy * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange
        
        let P = float4(xScale, 0, 0, 0)
        let Q = float4(0, yScale, 0, 0)
        let R = float4(0, 0, zScale, -1)
        let S = float4(0, 0, wzScale, 0)
        
        self = float4x4([P, Q, R, S])
    }
    
    mutating func rotate(axis: float3, angle: Float) {
        self = rotation(axis, angle: angle) * self
    }
}

class MetalView: NSView {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    func commonInit() {
        wantsLayer = true
    }
    
    override func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }
    
    var metalLayer: CAMetalLayer { return layer as! CAMetalLayer }
    
    override func setBoundsSize(newSize: NSSize) {
        super.setBoundsSize(newSize)
        metalLayer.drawableSize = convertRectToBacking(bounds).size
        (nextResponder as! ViewController).depthStencilTexture = nil
        (nextResponder as! ViewController).render()
    }
    
    override func setFrameSize(newSize: NSSize) {
        super.setFrameSize(newSize)
        metalLayer.drawableSize = convertRectToBacking(bounds).size
        (nextResponder as! ViewController).depthStencilTexture = nil
        (nextResponder as! ViewController).render()
    }
}


func *(size: CGSize, scale: CGFloat) -> CGSize {
    return CGSize(width: size.width * scale, height: size.height * scale)
}


