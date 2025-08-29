#version 410 core
layout (location = 0) in vec3 aPos;

uniform usampler3D chunkData; // the sampler transforms 1D to 3D and fills starts with filling rows, then columns then z. (1,2,3,4,5,6,7,8,9) -> (1,2,3;4,5,6;7,8,9)
uniform int chunkSize;
uniform vec3 chunkPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 fragPos;

void main() 
{
    int voxelIndex = gl_InstanceID;
    int row = voxelIndex % chunkSize;
    int col = (int(voxelIndex / chunkSize))%chunkSize;
    int height = int(voxelIndex / pow(chunkSize,2));
    ivec3 voxPos = ivec3(row, col, height);
    uvec4 voxelType = texelFetch(chunkData, voxPos, 0);

    if (voxelType.r == 0u) {
        gl_Position = vec4(0,0,0,-1);
        return;
    }

    gl_Position = projection * view * model * vec4(chunkPos + aPos + voxPos, 1.0);
    fragPos = vec3(model * vec4(chunkPos + aPos + voxPos, 1.0));
}
