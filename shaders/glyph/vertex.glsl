#version 330 core

layout (location = 0) in vec2 vertex;
layout (location = 1) in vec2 size;
layout (location = 2) in vec2 tex_top_left;
layout (location = 3) in vec2 tex_bottom_right;

out VS_OUT {
  vec4 top_right;
  vec4 tex_box;
} vs_out;

uniform mat4 projection;

void main()
{
  gl_Position = projection * vec4(vertex, 0.0, 1.0);
  vs_out.top_right = projection * vec4(vertex + size, 0.0, 1.0);
  vs_out.tex_box = vec4(tex_top_left, tex_bottom_right);
}
