//
//  Renderer.swift
//  Hello Triangle
//
//  Created by Ryder Mackay on 2015-09-08.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import Metal
import QuartzCore

struct Position4 {
    let x, y, z, w: Float
}
struct Color4 {
    let r, g, b, a: Float
}

struct Vertex {
    let position: Position4
    let color: Color4
    
    init(x: Float, y: Float, r: Float, g: Float, b: Float) {
        position = Position4(x: x, y: y, z: 1, w: 1)
        color = Color4(r: r, g: g, b: b, a: 1)
    }
}

protocol Renderer {
    init(device: MTLDevice) throws
    
    func renderInLayer(layer: CAMetalLayer)
}

final class TriangleRenderer: Renderer {
    
    let device: MTLDevice
    let triangleVertexBuffer: MTLBuffer
    let renderPipelineState: MTLRenderPipelineState!
    let commandQueue: MTLCommandQueue
    
    enum RendererError: ErrorType {
        case NilLibrary
    }
    
    init(device d: MTLDevice) throws {
        
        device = d
        
        commandQueue = device.newCommandQueue()
        
        let a = Vertex(x:  0, y:  1, r: 1, g: 0, b: 0)  // top middle, red
        let b = Vertex(x:  1, y: -1, r: 0, g: 1, b: 0)  // bottom right, green
        let c = Vertex(x: -1, y: -1, r: 0, g: 0, b: 1)  // bottom left, blue
        var vertices = [a, b, c]
        triangleVertexBuffer = device.newBufferWithBytes(&vertices, length: vertices.count * strideof(Vertex), options: [])
        
        guard let library = device.newDefaultLibrary() else {
            renderPipelineState = nil // wat
            throw RendererError.NilLibrary
        }
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = library.newFunctionWithName("myCoolVertexFunction")
        renderPipelineDescriptor.fragmentFunction = library.newFunctionWithName("myCoolFragmentFunction")

        // this *must* match the pixel format of the CAMetalLayer we'll be drawing into (BGRA8Unorm or BGRA8Unorm_sRGB)
        // Metal API Validation will catch this (on by default, see run scheme options)
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm // little endian, alpha first, 8-bit unsigned integer components, normalized (0.0–1.0)
        
        do {
            renderPipelineState = try device.newRenderPipelineStateWithDescriptor(renderPipelineDescriptor)
        } catch {
            renderPipelineState = nil // Swift's initialization rules require that all properties be initialized before throwing :|
            throw error
        }
    }
    
    func renderInLayer(layer: CAMetalLayer) {
        
        guard let drawable = layer.nextDrawable() else {
            print("Drawable pool exhausted!")
            return
        }
        
        // we are going to draw into the layer's framebuffer;
        // set its texture as the render target and ask metal to fill it w/ grey on load
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture // texture's pixel format must match pipeline state's expectations
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        
        let commandBuffer = commandQueue.commandBuffer()
        
        let renderCommandEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)

        // set our pipeline state: which vertex & fragment functions to use and the format of the destination
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        
        // vertices will come from our triangle buffer
        // index 0 matches [[ buffer(0) ]] qualifier of pointer to vertex array in vertex function's parameter list
        renderCommandEncoder.setVertexBuffer(triangleVertexBuffer, offset: 0, atIndex: 0)
        
        // draw a triangle using our three vertices
        renderCommandEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: triangleVertexBuffer.length / strideof(Vertex))
        
        // mark the encoder finished; only one RCE can be active at a time per command buffer
        renderCommandEncoder.endEncoding()
        
        // schedule display of result on the screen
        commandBuffer.presentDrawable(drawable)
        
        // actually submit the work to the GPU
        commandBuffer.commit()
    }
}
