#version 330 core
out vec4 FragColor;
in vec3 ourColor;
in vec2 TexCoord;

uniform sampler2D texture1;
uniform sampler2D texture2;
uniform float time;

void main()
{
  float v = (sin(time) + 1) / 2;
  FragColor = mix(texture(texture1, TexCoord), texture(texture2, TexCoord), v)
    * vec4(ourColor, 1.0);
}
