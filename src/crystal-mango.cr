require "lib_gl"
require "crystglfw"
require "stumpy_png"
require "./shader"
require "./ft/lib_ft.cr"

include CrystGLFW

def process_input(window)
  if window.key_pressed?(Key::Escape)
    puts "Exiting"
    window.should_close
  end

  # render polygons in wire-mode
  if window.key_pressed?(Key::W)
    LibGL.polygon_mode(LibGL::FRONT_AND_BACK, LibGL::LINE)
  else
    LibGL.polygon_mode(LibGL::FRONT_AND_BACK, LibGL::FILL)
  end
end

def setup_vao
  LibGL.gen_vertex_arrays(1, out vao)
  LibGL.bind_vertex_array(vao)
  vao
end

def setup_vbo
  vertices = [
    # positions       # colors        # texture  # other
    -0.5, -0.5, 0.0,  1.0, 0.0, 0.0,  0.0, 0.0,  2.0,  # bottom left
    +0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  1.0, 0.0,  4.0,  # bottom right
    +0.5, +0.5, 0.0,  0.0, 0.0, 1.0,  1.0, 1.0,  3.0,  # top right
    -0.5, +0.5, 0.0,  1.0, 1.0, 1.0,  0.0, 1.0,  6.0   # top left
  ] of LibGL::Float

  indices = [
    0, 1, 3,
    1, 2, 3
  ] of LibGL::UInt

  LibGL.gen_buffers(1, out vbo)
  LibGL.bind_buffer(LibGL::ARRAY_BUFFER, vbo)
  LibGL.buffer_data(LibGL::ARRAY_BUFFER,
                    vertices.size * sizeof(LibGL::Float),
                    vertices,
                    LibGL::STATIC_DRAW)

  LibGL.gen_buffers(1, out ebo)
  LibGL.bind_buffer(LibGL::ELEMENT_ARRAY_BUFFER, ebo)
  LibGL.buffer_data(LibGL::ELEMENT_ARRAY_BUFFER,
                    indices.size * sizeof(LibGL::UInt),
                    indices,
                    LibGL::STATIC_DRAW)

  stride = 9

  # position attribute
  LibGL.vertex_attrib_pointer(0, 3, LibGL::FLOAT, LibGL::FALSE,
                              stride * sizeof(LibGL::Float),
                              Pointer(Void).new(0))
  LibGL.enable_vertex_attrib_array(0)

  # color attribute
  LibGL.vertex_attrib_pointer(1, 3, LibGL::FLOAT, LibGL::FALSE,
                              stride * sizeof(LibGL::Float),
                              Pointer(Void).new(3 * sizeof(LibGL::Float)))
  LibGL.enable_vertex_attrib_array(1)

  # texture attribute
  LibGL.vertex_attrib_pointer(2, 2, LibGL::FLOAT, LibGL::FALSE,
                              stride * sizeof(LibGL::Float),
                              Pointer(Void).new(6 * sizeof(LibGL::Float)))
  LibGL.enable_vertex_attrib_array(2)

  # other attribute
  LibGL.vertex_attrib_pointer(3, 1, LibGL::FLOAT, LibGL::FALSE,
                              stride * sizeof(LibGL::Float),
                              Pointer(Void).new(8 * sizeof(LibGL::Float)))
  LibGL.enable_vertex_attrib_array(3)

  vbo
end

class StumpyCore::Canvas
  def flip!
    (0...@height // 2).each do |y|
      (0...@width).each do |x|
        tmp = self[x, y]
        self[x, y] = self[x, @height - y - 1]
        self[x, @height - y - 1] = tmp
      end
    end
  end
end

def load_texture(texture_filename, flipped = false)
  LibGL.gen_textures(1, out texture)

  canvas = StumpyPNG.read(texture_filename)
  canvas.flip! if flipped

  LibGL.bind_texture(LibGL::TEXTURE_2D, texture)
  LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_S, LibGL::REPEAT)
  LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_T, LibGL::REPEAT)
  LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::LINEAR_MIPMAP_LINEAR)
  LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::LINEAR)

  LibGL.tex_image_2d(LibGL::TEXTURE_2D,     # texture type
                     0,                     # mipmap level
                     LibGL::RGB,            # format for the texture
                     canvas.width,
                     canvas.height,         # size of the texture
                     0,
                     # Stumpy's pixels are RGBA with 16-bit values
                     LibGL::RGBA,           # format of the data
                     LibGL::UNSIGNED_SHORT, # datatype of the data
                     canvas.pixels)
  LibGL.generate_mipmap(LibGL::TEXTURE_2D)

  texture
end

record Character,
  texture_id : UInt32,
  size : Vec2i,
  bearing : Vec2i,
  advance : UInt32

def check_ft_call(error : LibFreeType::Error)
  raise "error in FreeType #{error}" unless error == LibFreeType::Error::OK
end

def load_font_into_textures(filename : String) : Hash(Char, Character)
  characters = Hash(Char, Character).new

  check_ft_call LibFreeType.init_free_type(out ft)
  check_ft_call LibFreeType.new_face(ft, filename, 0, out face)
  check_ft_call LibFreeType.set_pixel_sizes(face, 0, 48)

  LibGL.pixel_store_i(LibGL::UNPACK_ALIGNMENT, 1)

  (0...128).each do |c|
    if LibFreeType.load_char(face, c, LibFreeType::LoadFlags::RENDER) != LibFreeType::Error::OK
      puts "error loading character #{c}"
      next
    end

    glyph = face.value.glyph

    LibGL.gen_textures(1, out texture)
    LibGL.bind_texture(LibGL::TEXTURE_2D, texture)
    LibGL.tex_image_2d(LibGL::TEXTURE_2D, 0, LibGL::RED,
                       glyph.value.bitmap.width,
                       glyph.value.bitmap.rows,
                       0,
                       LibGL::RED,
                       LibGL::UNSIGNED_BYTE,
                       face.value.glyph.value.bitmap.buffer)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_S, LibGL::CLAMP_TO_EDGE)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_T, LibGL::CLAMP_TO_EDGE)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::LINEAR)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::LINEAR)

    characters[c.unsafe_chr] = Character.new(texture_id: texture,
                                             size: Vec2i.new(glyph.value.bitmap.width.to_i32,
                                                             glyph.value.bitmap.rows.to_i32),
                                             bearing: Vec2i.new(glyph.value.bitmap_left,
                                                                glyph.value.bitmap_top),
                                             advance: glyph.value.advance.x.to_u32)
  end

  check_ft_call LibFreeType.done_face(face)
  check_ft_call LibFreeType.done_free_type(ft)

  characters
end

def render(program : ShaderProgram, vao, texture1, texture2, aspect_ratio)
  time_value = CrystGLFW.time.to_f32

  transform = Mat4f.new(1)

  # transform = transform.scale(Vec3f.new(0.5, 0.5, 1.0))
  # transform = transform.rotate(time_value, Vec3f.new(0.0, 0.0, 1.0))
  # transform = transform.translate(Vec3f.new(0.5, -0.5, 0.0))

  transform = transform.rotate(-55.0_f32.to_radians, Vec3f.new(1, 0, 0))
  transform = transform.translate(Vec3f.new(0, 0, -3))

  # projection = if aspect_ratio >= 1
  #                Mat4f.ortho(-1, 1, -1 / aspect_ratio, 1 / aspect_ratio, -1, 1)
  #              else
  #                Mat4f.ortho(-aspect_ratio, aspect_ratio, -1, 1, -1, 1)
  #              end

  # projection = Mat4f.perspective((Math::PI / 4).to_f32, aspect_ratio, 0.1, 100)
  projection = if aspect_ratio >= 1
                 Mat4f.frustum(-1, 1, -1 / aspect_ratio, 1 / aspect_ratio, 2, 5)
               else
                 Mat4f.frustum(-aspect_ratio, aspect_ratio, -1, 1, 2, 5)
               end

  program.use

  program.set_uniform "time", time_value * 5.0_f32
  program.set_uniform "jitter_radius", 0.01
  program.set_uniform "transform", projection * transform

  # render the triangles
  LibGL.active_texture(LibGL::TEXTURE0)
  LibGL.bind_texture(LibGL::TEXTURE_2D, texture1)

  LibGL.active_texture(LibGL::TEXTURE1)
  LibGL.bind_texture(LibGL::TEXTURE_2D, texture2)

  LibGL.bind_vertex_array vao
  LibGL.draw_elements(LibGL::TRIANGLES, 6,
                      LibGL::UNSIGNED_INT,
                      Pointer(Void).new(0))
  LibGL.bind_vertex_array 0
end

def render_text(program : ShaderProgram, glyph_vao : GlyphVAO, chars : Hash(Char, Character),
                text : String, x : Float32, y : Float32, scale : Float32, color : Vec3f)
  program.use
  program.set_uniform "textColor", color

  LibGL.active_texture(LibGL::TEXTURE0)
  LibGL.bind_vertex_array(glyph_vao[:vao])

  text.each_char do |c|
    ch = chars[c]

    xpos = x + ch.bearing.x * scale
    ypos = y - (ch.size.y - ch.bearing.y) * scale
    w = ch.size.x * scale
    h = ch.size.y * scale

    vertices = [
      xpos,     ypos + h, 0, 0,
      xpos,     ypos,     0, 1,
      xpos + w, ypos,     1, 1,
      xpos,     ypos + h, 0, 0,
      xpos + w, ypos,     1, 1,
      xpos + w, ypos + h, 1, 0
    ] of Float32

    LibGL.bind_texture(LibGL::TEXTURE_2D, ch.texture_id)
    LibGL.bind_buffer(LibGL::ARRAY_BUFFER, glyph_vao[:vbo])
    LibGL.buffer_sub_data(LibGL::ARRAY_BUFFER, 0, sizeof(Float32) * vertices.size, vertices)
    LibGL.bind_buffer(LibGL::ARRAY_BUFFER, 0)
    LibGL.draw_arrays(LibGL::TRIANGLES, 0, 6)
    x += (ch.advance >> 6) * scale
  end

  LibGL.bind_vertex_array(0)
  LibGL.bind_texture(LibGL::TEXTURE_2D, 0)
end

def render_text(program : ShaderProgram, glyph_vao : GlyphVAO, chars, width, height)
  LibGL.enable(LibGL::BLEND)
  LibGL.blend_func(LibGL::SRC_ALPHA, LibGL::ONE_MINUS_SRC_ALPHA)

  projection = Mat4f.ortho(0, width.to_f32, 0, height.to_f32)
  program.use
  program.set_uniform "projection", projection

  color = Vec3f.new(0.5, 0.8, 0.2)
  render_text(program, glyph_vao, chars, "Hello World!", 25.0_f32, 25.0_f32, 1.0_f32, color)

end

alias GlyphVAO = NamedTuple(vao: UInt32, vbo: UInt32)

def prepare_glyph_vao : GlyphVAO
  LibGL.gen_vertex_arrays(1, out vao)
  LibGL.gen_buffers(1, out vbo)
  LibGL.bind_vertex_array(vao)
  LibGL.bind_buffer(LibGL::ARRAY_BUFFER, vbo)
  LibGL.buffer_data(LibGL::ARRAY_BUFFER, sizeof(Float32) * 6 * 4,
                    Pointer(Void).new(0), LibGL::DYNAMIC_DRAW)
  LibGL.enable_vertex_attrib_array(0)
  LibGL.vertex_attrib_pointer(0, 4, LibGL::FLOAT, LibGL::FALSE, 4 * sizeof(Float32),
                              Pointer(Void).new(0))
  LibGL.bind_buffer(LibGL::ARRAY_BUFFER, 0)
  LibGL.bind_vertex_array(0)

  GlyphVAO.new(vao: vao, vbo: vbo)
end

CrystGLFW.run do
  # Request a specific version of OpenGL in core profile mode with forward
  # compatibility.
  hints = {
    Window::HintLabel::ContextVersionMajor => 3,
    Window::HintLabel::ContextVersionMinor => 3,
    Window::HintLabel::OpenGLForwardCompat => true,
    Window::HintLabel::ClientAPI => ClientAPI::OpenGL,
    Window::HintLabel::OpenGLProfile => OpenGLProfile::Core
  }

  window = Window.new title: "Crystal Mango", hints: hints
  window.make_context_current

  window.on_framebuffer_resize do |event|
    # update the viewport if the window was resized
    LibGL.viewport(0, 0, event.size[:width], event.size[:height])
  end

  program = ShaderProgram.build(File.read("shaders/vertex.glsl"),
                                File.read("shaders/fragment.glsl"))

  glyph_program = ShaderProgram.build(File.read("shaders/glyph_vertex.glsl"),
                                      File.read("shaders/glyph_fragment.glsl"))

  program.use
  program.set_uniform("texture1", 0)
  program.set_uniform("texture2", 1)

  texture1 = load_texture("textures/wall.png")
  texture2 = load_texture("textures/awesomeface.png", true)

  # setup Vertex Attribute Object for the triangles
  vao = setup_vao
  # setup Vertex Buffer Object
  setup_vbo

  # find out the max number of attributes supported by the driver/hardware
  LibGL.get_integer_v(LibGL::MAX_VERTEX_ATTRIBS, out max_attribs)
  puts "Max number of attributes #{max_attribs}"

  chars = load_font_into_textures("fonts/RobotoMono-Regular.ttf")
  glyph_vao = prepare_glyph_vao

  until window.should_close?
    CrystGLFW.poll_events
    process_input window

    LibGL.clear_color(0.2, 0.3, 0.3, 1.0)
    LibGL.clear(LibGL::COLOR_BUFFER_BIT)

    aspect_ratio = window.size[:width].to_f32 / window.size[:height].to_f32
    render program, vao, texture1, texture2, aspect_ratio
    render_text glyph_program, glyph_vao, chars, window.size[:width], window.size[:height]

    window.swap_buffers
  end

  window.destroy
end
