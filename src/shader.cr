require "lib_gl"

struct ShaderProgram
  @handle : LibGL::UInt

  private def self.compile_shader(type : LibGL::UInt, source : String)
    tmp_source = source.to_unsafe
    shader = LibGL.create_shader(type)
    LibGL.shader_source(shader, 1, pointerof(tmp_source), nil)
    LibGL.compile_shader(shader)

    LibGL.get_shader_iv(shader, LibGL::COMPILE_STATUS, out success)
    if success == 0
      info_log = StaticArray(UInt8, 512).new(0)
      LibGL.get_shader_info_log(shader, info_log.size, nil, info_log.to_unsafe)
      raise "Error compiling shader: #{String.new(info_log.to_slice)}"
    end
    shader
  end

  def self.build(vertex_shader_source, fragment_shader_source)
    program = LibGL.create_program

    vertex_shader = compile_shader(LibGL::VERTEX_SHADER,
                                   vertex_shader_source)
    LibGL.attach_shader program, vertex_shader
    fragment_shader = compile_shader(LibGL::FRAGMENT_SHADER,
                                     fragment_shader_source)
    LibGL.attach_shader program, fragment_shader

    LibGL.link_program program

    LibGL.get_program_iv(program, LibGL::LINK_STATUS, out success)
    if success == 0
      info_log = StaticArray(UInt8, 512).new(0)
      LibGL.get_program_info_log(program, info_log.size,
                                 nil, info_log.to_unsafe)
      raise "Error linking shader program: #{String.new(info_log.to_slice)}"
    end

    LibGL.delete_shader vertex_shader
    LibGL.delete_shader fragment_shader

    new(program)
  end

  private def initialize(@handle)
  end

  def use
    LibGL.use_program @handle
  end

  def set_uniform(name : String, value : LibGL::UInt)
    location = LibGL.get_uniform_location(@handle, name)
    LibGL.uniform_1ui(location, value)
  end

  def set_uniform(name : String, value : LibGL::Float)
    location = LibGL.get_uniform_location(@handle, name)
    LibGL.uniform_1f(location, value)
  end
end
