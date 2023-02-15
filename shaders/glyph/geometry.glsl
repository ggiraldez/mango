#version 330 core

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

in VS_OUT {
  vec4 top_right;
  vec4 tex_box;
} gs_in[];

out vec2 tex_coords;

void main() {
  vec4 bottom_left = gl_in[0].gl_Position;
  vec4 top_right = gs_in[0].top_right;

  // bottom left
  gl_Position = bottom_left;
  tex_coords = vec2(gs_in[0].tex_box.x, gs_in[0].tex_box.w);
  EmitVertex();

  // bottom right
  gl_Position = vec4(top_right.x, bottom_left.yzw);
  tex_coords = vec2(gs_in[0].tex_box.z, gs_in[0].tex_box.w);
  EmitVertex();

  // top left
  gl_Position = vec4(bottom_left.x, top_right.y, bottom_left.zw);
  tex_coords = vec2(gs_in[0].tex_box.x, gs_in[0].tex_box.y);
  EmitVertex();

  // top right
  gl_Position = top_right;
  tex_coords = vec2(gs_in[0].tex_box.z, gs_in[0].tex_box.y);
  EmitVertex();

  EndPrimitive();
}
