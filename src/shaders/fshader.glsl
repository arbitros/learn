
#version 410 core
in vec3 aPos;
in vec3 fragPos;

uniform vec3 normal;
uniform vec3 lightPos;
uniform vec3 lightColor;
uniform vec3 objectColor;

out vec4 FragColor;

void main() {
    float ambientStrength = 0.1;
    vec3 ambient = ambientStrength * lightColor;
  	
    vec3 norm = normalize(normal);
    vec3 lightDir = normalize(lightPos - fragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * lightColor;
            
    vec3 result = (ambient + diffuse) * objectColor;
    FragColor = vec4(result, 1.0);
}
