require "lib_gl"
require "crystglfw"
require "./mate"
require "./shader"
require "./texture"

class WavyQuad
  @vbo : UInt32 = 0
  @vao : UInt32 = 0
  @ebo : UInt32 = 0
  @program : ShaderProgram
  @texture1 : Texture
  @texture2 : Texture

  def initialize
    setup_buffers

    @program = ShaderProgram.build(
      File.read("shaders/wavy_quad/vertex.glsl"),
      File.read("shaders/wavy_quad/fragment.glsl")
    )

    @program.use
    @program.set_uniform("texture1", 0)
    @program.set_uniform("texture2", 1)

    @texture1 = Texture.load_from_png("textures/wall.png")
    @texture2 = Texture.load_from_png("textures/awesomeface.png", true)
  end

  def setup_buffers
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

    LibGL.gen_vertex_arrays(1, pointerof(@vao))
    LibGL.bind_vertex_array(@vao)

    LibGL.gen_buffers(1, pointerof(@vbo))
    LibGL.bind_buffer(LibGL::ARRAY_BUFFER, @vbo)
    LibGL.buffer_data(LibGL::ARRAY_BUFFER,
                      vertices.size * sizeof(LibGL::Float),
                      vertices,
                      LibGL::STATIC_DRAW)

    LibGL.gen_buffers(1, pointerof(@ebo))
    LibGL.bind_buffer(LibGL::ELEMENT_ARRAY_BUFFER, @ebo)
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
  end

  def render(aspect_ratio)
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

    @program.use

    @program.set_uniform "time", time_value * 5.0_f32
    @program.set_uniform "jitter_radius", 0.01
    @program.set_uniform "transform", projection * transform

    # render the triangles
    LibGL.active_texture(LibGL::TEXTURE0)
    LibGL.bind_texture(LibGL::TEXTURE_2D, @texture1)

    LibGL.active_texture(LibGL::TEXTURE1)
    LibGL.bind_texture(LibGL::TEXTURE_2D, @texture2)

    LibGL.bind_vertex_array @vao
    LibGL.draw_elements(LibGL::TRIANGLES, 6,
                        LibGL::UNSIGNED_INT,
                        Pointer(Void).new(0))
    LibGL.bind_vertex_array 0
  end
end
