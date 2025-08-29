
#version 410 core
in vec3 aPos;
in vec3 fragPos;

uniform vec3 normal;
uniform vec3 lightPos;
uniform vec4 lightColor;
uniform vec4 objectColor;

out vec4 FragColor;

void main() {
    vec3 viewDir = lightPos - fragPos;
    FragColor = vec4(dot(viewDir, normal))*objectColor*lightColor;

}
