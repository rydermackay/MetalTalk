//
//  Shaders.metal
//  MetalPaint
//
//  Created by Ryder Mackay on 2015-09-06.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

/*
    In Metal, the origin of the pixel coordinate system of a texture or a framebuffer attachment is defined at the top-left corner.
 */

struct Vertex {
    float4 position;
    float2 texCoords;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewProjectionMatrix;
};

vertex VertexOut myVertexFunction(constant Vertex *vertices [[buffer(0)]],
                                  constant Uniforms &uniforms [[buffer(1)]],
                                  uint vid [[vertex_id]]) {
    VertexOut v;
    v.position = uniforms.viewProjectionMatrix * uniforms.modelMatrix * vertices[vid].position;
    v.texCoords = vertices[vid].texCoords;
    return v;
}

fragment float4 myFragmentFunction(VertexOut vert [[stage_in]],
                                   sampler samplr [[sampler(0)]],
                                   texture2d<float, access::sample> texture [[texture(0)]]) {
    return texture.sample(samplr, vert.texCoords);
}

// c.f. http://www.informit.com/articles/article.aspx?p=1946398

fragment float4 fragChromaKey(VertexOut vert [[stage_in]],
                              sampler samplr [[sampler(0)]],
                              texture2d<float, access::sample> texture [[texture(0)]]) {
    float4 frag = texture.sample(samplr, vert.texCoords);
    float delta = frag.g - (frag.r + frag.b) / 2;
    frag.a = 1 - smoothstep(0.075, 0.1, delta);
    frag.a = pow(frag.a, 3);
    
    return frag;
}
