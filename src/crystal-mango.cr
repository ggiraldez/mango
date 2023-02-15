require "lib_gl"
require "crystglfw"
require "stumpy_png"
require "./shader"
require "./texture_font"
require "./paragraph"

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

def render_text(texture_font : TextureFont, program : ShaderProgram, size)
  program.use
  projection = Mat4f.ortho(0, size[:width].to_f32, 0, size[:height].to_f32)
  color = Vec3f.new(0.5, 0.8, 0.2)
  program.set_uniform "projection", projection
  program.set_uniform "textColor", color

  texture_font.render_text("Hello World!", 25.0_f32, 25.0_f32, 1.0_f32)
  texture_font.render_text(('a'..'z').join, 25.0_f32, (25 + texture_font.height).to_f32, 1.0_f32)
end

def render_para(texture_font : TextureFont,
                renderer : GlyphRenderer,
                para : String,
                size)
  LibGL.active_texture(LibGL::TEXTURE0)
  LibGL.bind_texture(LibGL::TEXTURE_2D, texture_font)

  p = Paragraph.new(texture_font)
  p.set_origin(Vec2f.new(12_f32, (size[:height] - texture_font.height).to_f32))

  projection = Mat4f.ortho(0, size[:width].to_f32, 0, size[:height].to_f32)
  color = Vec3f.new(0.9, 0.9, 0.9)
  renderer.program.use
  renderer.program.set_uniform "projection", projection
  renderer.program.set_uniform "textColor", color

  p.render renderer, para
  renderer.flush
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

  # max texture size
  LibGL.get_integer_v(LibGL::MAX_TEXTURE_SIZE, out max_texture_size)
  puts "Max 1D/2D texture size #{max_texture_size}"

  texture_font = TextureFont.new("fonts/RobotoMono-Regular.ttf", 18)

  puts texture_font.line_metrics("Hello world!")
  puts texture_font.line_metrics(('a'..'z').join)
  puts texture_font.line_metrics(('A'..'Z').join)

  glyph_renderer = GlyphRenderer.new

  lines = File.read("src/crystal-mango.cr")

  LibGL.enable(LibGL::BLEND)
  LibGL.blend_func(LibGL::SRC_ALPHA, LibGL::ONE_MINUS_SRC_ALPHA)

  until window.should_close?
    CrystGLFW.poll_events
    process_input window

    LibGL.clear_color(0.2, 0.3, 0.3, 1.0)
    LibGL.clear(LibGL::COLOR_BUFFER_BIT)

    aspect_ratio = window.size[:width].to_f32 / window.size[:height].to_f32
    render program, vao, texture1, texture2, aspect_ratio
    # render_text texture_font, glyph_program, window.size
    render_para texture_font, glyph_renderer, lines, window.size

    window.swap_buffers
  end

  window.destroy
end
