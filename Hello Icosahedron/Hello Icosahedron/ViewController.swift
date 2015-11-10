//
//  ViewController.swift
//  Hello Icosahedron
//
//  Created by Ryder Mackay on 2015-08-25.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import Cocoa
import Metal
import simd

struct Position4 {
    let x, y, z, w: Float32
}
struct Color4 {
    let r, g, b, a: Float32
}

struct Vertex {
    var position: Position4
    var color: Color4
}


func icosahedron() -> [Vertex] {
    

    let aVertex = Vertex(position: Position4(x: 0, y: 0, z: 0, w: 1), color: Color4(r: 1, g: 0, b: 0, a: 1))
    var vertices = Array(count: 12, repeatedValue: aVertex)
    
    let phiaa: Float32 = 26.56505 // ???
    let r: Float32 = 1.0 // radius of inscription
    let phia = Float32(M_PI) * phiaa / 180.0 // 2 sets of four points
    let theb = Float32(M_PI) * 36.0 / 180.0 // offset second set 36 degres
    let the72 = Float32(M_PI) * 72.0 / 180.0 // step 72 degrees
    
    vertices[0].position = Position4(x: 0, y: 0, z: r, w: 1)
    vertices[0].color = Color4(r: 0, g: 0, b: r, a: 1)
    vertices[11].position = Position4(x: 0, y: 0, z: -r, w: 1)
    vertices[11].color = Color4(r: 0, g: 0, b: -r, a: 1)
    
    var the: Float32 = 0.0;
    
    for (var i = 1; i < 6; i++) {
        let x = r * cos(the) * cos(phia)
        let y = r * sin(the) * cos(phia)
        let z = r * sin(phia)
        vertices[i].position = Position4(x: x, y: y, z: z, w: 1)
        vertices[i].color = Color4(r: x, g: y, b: z, a: 1) //Color4(r: Float32(i)/6, g: 0.5, b: 0, a: 1)
        the += the72
    }
    
    the = theb
    for (var i = 6; i < 11; i++) {
        let x = r * cos(the) * cos(-phia)
        let y = r * sin(the) * cos(-phia)
        let z = r * sin(-phia)
        vertices[i].position = Position4(x: x, y: y, z: z, w: 1)
        vertices[i].color = Color4(r: x, g: y, b: z, a: 1) //Color4(r: 0, g: 0.5, b: Float32(i)/6, a: 1)
        the += the72
    }
    
    for v in vertices {
        print(v.position)
    }
    
    func polygon(a: Int, _ b: Int, _ c: Int) -> [Vertex] {
        return [vertices[a], vertices[b], vertices[c]]
    }
    
    let faces = [
        polygon(0,1,2),
        polygon(0,2,3),
        polygon(0,3,4),
        polygon(0,4,5),
        polygon(0,5,1),
        polygon(6,11,7),
        polygon(7,11,8),
        polygon(8,11,9),
        polygon(9,11,10),
        polygon(10,11,6),
        polygon(1,6,2),
        polygon(2,7,3),
        polygon(3,8,4),
        polygon(4,9,5),
        polygon(5,10,1),
        polygon(2,6,7),
        polygon(3,7,8),
        polygon(4,8,9),
        polygon(5,9,10),
        polygon(1,10,6),
    ]
    
    return faces.flatMap { $0 }
    
    
    
    /*
    Icosahedron

The "C" pseudo code to generate the vertices is:

  double vertices[12][3]; /* 12 vertices with x, y, z coordinates */
  double Pi = 3.141592653589793238462643383279502884197;

  double phiaa  = 26.56505; /* phi needed for generation */
  r = 1.0; /* any radius in which the polyhedron is inscribed */
  phia = Pi*phiaa/180.0; /* 2 sets of four points */
  theb = Pi*36.0/180.0;  /* offset second set 36 degrees */
  the72 = Pi*72.0/180;   /* step 72 degrees */
  vertices[0][0]=0.0;
  vertices[0][1]=0.0;
  vertices[0][2]=r;
  vertices[11][0]=0.0;
  vertices[11][1]=0.0;
  vertices[11][2]=-r;
  the = 0.0;
  for(i=1; i<6; i++)
  {
    vertices[i][0]=r*cos(the)*cos(phia);
    vertices[i][1]=r*sin(the)*cos(phia);
    vertices[i][2]=r*sin(phia);
    the = the+the72;
  }
  the=theb;
  for(i=6; i<11; i++)
  {
    vertices[i][0]=r*cos(the)*cos(-phia);
    vertices[i][1]=r*sin(the)*cos(-phia);
    vertices[i][2]=r*sin(-phia);
    the = the+the72;
  }

  /* map vertices to 20 faces */
  polygon(0,1,2);
  polygon(0,2,3);
  polygon(0,3,4);
  polygon(0,4,5);
  polygon(0,5,1);
  polygon(11,6,7);
  polygon(11,7,8);
  polygon(11,8,9);
  polygon(11,9,10);
  polygon(11,10,6);
  polygon(1,2,6);
  polygon(2,3,7);
  polygon(3,4,8);
  polygon(4,5,9);
  polygon(5,1,10);
  polygon(6,7,2);
  polygon(7,8,3);
  polygon(8,9,4);
  polygon(9,10,5);
  polygon(10,6,1);

The icosahedron coordinates:

 Vertex       coordinate
   0,  x= 0.000, y= 0.000, z= 1.000 
   1,  x= 0.894, y= 0.000, z= 0.447 
   2,  x= 0.276, y= 0.851, z= 0.447 
   3,  x=-0.724, y= 0.526, z= 0.447 
   4,  x=-0.724, y=-0.526, z= 0.447 
   5,  x= 0.276, y=-0.851, z= 0.447 
   6,  x= 0.724, y= 0.526, z=-0.447 
   7,  x=-0.276, y= 0.851, z=-0.447 
   8,  x=-0.894, y= 0.000, z=-0.447 
   9,  x=-0.276, y=-0.851, z=-0.447 
  10,  x= 0.724, y=-0.526, z=-0.447 
  11,  x= 0.000, y= 0.000, z=-1.000 

Length of each edge 1.0514622
    */
}


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
        
        var vertexData = icosahedron()
        
        vertexBuffer = device.newBufferWithBytes(&vertexData, length: strideof(Vertex) * vertexData.count, options: [])

        commandQueue = device.newCommandQueue()
        
        let library = device.newDefaultLibrary()!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = library.newFunctionWithName("vertex_main")
        renderPipelineDescriptor.fragmentFunction = library.newFunctionWithName("fragment_main")
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        renderPipelineDescriptor.vertexDescriptor = {
            let vertexDescriptor = MTLVertexDescriptor()
            
            vertexDescriptor.attributes[0].format = .Float4
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[0].offset = 0
            
            vertexDescriptor.attributes[1].format = .Float4
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.attributes[1].offset = strideof(Float32) * 4
            
            vertexDescriptor.layouts[0].stride = strideof(Float32) * 8
            vertexDescriptor.layouts[0].stepFunction = .PerVertex
            
            return vertexDescriptor
        }()
        
        renderPipelineState = try! device.newRenderPipelineStateWithDescriptor(renderPipelineDescriptor)
        
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .Less
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
        
        let renderCommandEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderCommandEncoder.setDepthStencilState(depthStencilState)
        renderCommandEncoder.setFrontFacingWinding(.CounterClockwise)
        renderCommandEncoder.setCullMode(.Back)
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        renderCommandEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
        renderCommandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, atIndex: 0)
        renderCommandEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: vertexBuffer.length / strideof(Vertex))
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
        var modelMatrix = float4x4(1)
        modelMatrix = rotation(yAxis, angle: Float(-angle.x)) * modelMatrix
        modelMatrix = rotation(xAxis, angle: Float(-angle.y)) * modelMatrix
        
        var viewMatrix = float4x4(1)
        viewMatrix[3].z = -1.8
        
        let near: Float = 0.1
        let far: Float = 100
        let aspect = Float(view.bounds.width / view.bounds.height)
        
        let degrees = 75.0
        let radiansPerDegree = M_PI / 180.0
        let fovy = Float(radiansPerDegree * degrees)
        let projectionMatrix = float4x4(aspect: aspect, fovy: fovy, near: near, far: far)
        
        let modelView = viewMatrix * modelMatrix
        let modelViewProj = projectionMatrix * modelView
        let normalMatrix = float3x3([float3(modelView[0].x, modelView[0].y, modelView[0].z),
                                     float3(modelView[1].x, modelView[1].y, modelView[1].z),
                                     float3(modelView[2].x, modelView[2].y, modelView[2].z)])
        
        uniforms = Uniform(modelViewProjectionMatrix: modelViewProj,
                                     modelViewMatrix: modelView,
                                        normalMatrix: normalMatrix.inverse.transpose)
        
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
        (nextResponder as! ViewController).render()
    }
    
    override func setFrameSize(newSize: NSSize) {
        super.setFrameSize(newSize)
        metalLayer.drawableSize = convertRectToBacking(bounds).size
        (nextResponder as! ViewController).render()
    }
}


func *(size: CGSize, scale: CGFloat) -> CGSize {
    return CGSize(width: size.width * scale, height: size.height * scale)
}


