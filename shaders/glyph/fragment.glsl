#version 330 core

in vec2 tex_coords;
in vec3 text_color;
flat in int tex_selector;

out vec4 frag_color;

uniform sampler2D font_0;
uniform sampler2D font_1;
uniform sampler2D font_2;
uniform sampler2D font_3;

void main()
{
  float r = 0;
  if (tex_selector == 1) {
    r = texture(font_1, tex_coords).r;
  } else if (tex_selector == 2) {
    r = texture(font_2, tex_coords).r;
  } else if (tex_selector == 3) {
    r = texture(font_3, tex_coords).r;
  } else {
    r = texture(font_0, tex_coords).r;
  }

  frag_color = vec4(text_color, r);
}
