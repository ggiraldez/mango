require "lib_gl"
require "crystglfw"
require "./shader"

include CrystGLFW

def resize_window(size)
  # TODO: handle the window aspect ratio
  LibGL.viewport(0, 0, size[:width], size[:height])
end

def process_input(window)
  if window.key_pressed?(Key::Escape)
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
    -0.5, -0.5, 0.0, 1.0, 0.0, 0.0, 2.0,  # bottom left
    0.0, -0.5, 0.0, 0.0, 1.0, 0.0,  4.0,  # bottom center
    0.5, -0.5, 0.0, 0.0, 0.0, 1.0,  3.0,  # bottom right
    0.0, 0.5, 0.0, 1.0, 1.0, 1.0,   6.0   # top
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

  stride = 7
  LibGL.vertex_attrib_pointer(0, 3, LibGL::FLOAT, LibGL::FALSE,
                              stride * sizeof(LibGL::Float),
                              Pointer(Void).new(0))
  LibGL.enable_vertex_attrib_array(0)

  LibGL.vertex_attrib_pointer(1, 3, LibGL::FLOAT, LibGL::FALSE,
                              stride * sizeof(LibGL::Float),
                              Pointer(Void).new(3 * sizeof(LibGL::Float)))
  LibGL.enable_vertex_attrib_array(1)

  LibGL.vertex_attrib_pointer(2, 1, LibGL::FLOAT, LibGL::FALSE,
                              stride * sizeof(LibGL::Float),
                              Pointer(Void).new(6 * sizeof(LibGL::Float)))
  LibGL.enable_vertex_attrib_array(2)

  vbo
end

def render(program : ShaderProgram, vao)
  LibGL.clear_color(0.2, 0.3, 0.3, 1.0)
  LibGL.clear(LibGL::COLOR_BUFFER_BIT)

  program.use

  time_value = CrystGLFW.time
  program.set_uniform "time", time_value.to_f32 * 5.0_f32
  program.set_uniform "jitter_radius", 0.05

  # render the triangles
  LibGL.bind_vertex_array vao
  LibGL.draw_elements(LibGL::TRIANGLES, 6,
                      LibGL::UNSIGNED_INT,
                      Pointer(Void).new(0))
  LibGL.bind_vertex_array 0
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
  # this is to setup the initial viewport
  resize_window(window.size)

  window.on_framebuffer_resize do |event|
    # update the viewport if the window was resized
    resize_window(event.size)
  end

  program = ShaderProgram.build(File.read("shaders/vertex.glsl"),
                                File.read("shaders/fragment.glsl"))

  # setup Vertex Attribute Object for the triangles
  vao = setup_vao
  # setup Vertex Buffer Object
  setup_vbo

  # find out the max number of attributes supported by the driver/hardware
  LibGL.get_integer_v(LibGL::MAX_VERTEX_ATTRIBS, out max_attribs)
  puts "Max number of attributes #{max_attribs}"

  # NEXT: for loading textures, use stumpy_png

  until window.should_close?
    CrystGLFW.poll_events
    process_input window

    render program, vao

    window.swap_buffers
  end

  window.destroy
end
