#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
layout (location = 2) in vec2 aTexCoord;
layout (location = 3) in float jitterSpeed;

out vec3 ourColor;
out vec2 TexCoord;

uniform float time;
uniform float jitter_radius;
uniform mat4 transform;

void main()
{
  gl_Position = transform *
    vec4(aPos.x + jitter_radius * cos(jitterSpeed * time),
         aPos.y + jitter_radius * sin(jitterSpeed * time),
         aPos.z, 1.0);
  ourColor = aColor;
  TexCoord = aTexCoord;
}
