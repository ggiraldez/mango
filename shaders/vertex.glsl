#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
layout (location = 2) in float jitterSpeed;

out vec3 ourColor;

uniform float time;
uniform float jitter_radius;

void main()
{
  gl_Position = vec4(aPos.x + jitter_radius * cos(jitterSpeed * time),
                     aPos.y + jitter_radius * sin(jitterSpeed * time),
                     aPos.z, 1.0);
  ourColor = aColor;
}
