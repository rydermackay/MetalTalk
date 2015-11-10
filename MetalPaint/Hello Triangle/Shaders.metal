//
//  Shaders.metal
//  Hello Triangle
//
//  Created by Ryder Mackay on 2015-08-25.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position;
    float4 color;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut myCoolVertexFunction(constant VertexIn *vertexArray [[ buffer(0) ]],
                                      uint vid [[ vertex_id ]]) {
    VertexOut out;
    out.position = vertexArray[vid].position;
    out.color = vertexArray[vid].color;
    return out;
}

fragment float4 myCoolFragmentFunction(VertexOut vert [[stage_in]]) {
    return vert.color;
}
