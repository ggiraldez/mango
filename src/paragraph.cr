require "lib_gl"
require "./mate"
require "./texture_font"
require "./shader"

macro void_checked(call)
  {{call}}
  if (error = LibGL.get_error) != LibGL::NO_ERROR
    raise "OpenGL call failed (#{error}): " + {{call.stringify}}
  end
end

macro checked(call)
  value = {{call}}
  if (error = LibGL.get_error) != LibGL::NO_ERROR
    raise "OpenGL call failed (#{error}): " + {{call.stringify}}
  end
  value
end

struct RenderGlyph
  @pos : Vec2f
  @size : Vec2f
  @tex_top_left : Vec2f
  @tex_bottom_right : Vec2f
  @color : Vec3f
  @tex_selector : Int32

  def initialize(@pos, @size, @tex_top_left, @tex_bottom_right, @color, @tex_selector)
  end

  Empty = new(Vec2f.new(0), Vec2f.new(0), Vec2f.new(0), Vec2f.new(0), Vec3f.new(0), 0)
end

class RenderGlyphVao
  @vao : UInt32 = 0

  def initialize(vbo : RenderGlyphVbo)
    LibGL.bind_buffer(LibGL::ARRAY_BUFFER, vbo)
    LibGL.gen_vertex_arrays(1, pointerof(@vao))
    LibGL.bind_vertex_array(@vao)

    # position attribute (vec2f)
    LibGL.vertex_attrib_pointer(0, 2, LibGL::FLOAT, LibGL::FALSE,
                                sizeof(RenderGlyph),
                                Pointer(Void).new(offsetof(RenderGlyph, @pos)))
    LibGL.enable_vertex_attrib_array(0)

    # glyph size attribute (vec2f)
    LibGL.vertex_attrib_pointer(1, 2, LibGL::FLOAT, LibGL::FALSE,
                                sizeof(RenderGlyph),
                                Pointer(Void).new(offsetof(RenderGlyph, @size)))
    LibGL.enable_vertex_attrib_array(1)

    # texture top left coords
    LibGL.vertex_attrib_pointer(2, 2, LibGL::FLOAT, LibGL::FALSE,
                                sizeof(RenderGlyph),
                                Pointer(Void).new(offsetof(RenderGlyph, @tex_top_left)))
    LibGL.enable_vertex_attrib_array(2)

    # texture bottom right coords
    LibGL.vertex_attrib_pointer(3, 2, LibGL::FLOAT, LibGL::FALSE,
                                sizeof(RenderGlyph),
                                Pointer(Void).new(offsetof(RenderGlyph, @tex_bottom_right)))
    LibGL.enable_vertex_attrib_array(3)

    # color
    LibGL.vertex_attrib_pointer(4, 3, LibGL::FLOAT, LibGL::FALSE,
                                sizeof(RenderGlyph),
                                Pointer(Void).new(offsetof(RenderGlyph, @color)))
    LibGL.enable_vertex_attrib_array(4)

    # texture selector
    LibGL.vertex_attrib_i_pointer(5, 1, LibGL::INT,
                                  sizeof(RenderGlyph),
                                  Pointer(Void).new(offsetof(RenderGlyph, @tex_selector)))
    LibGL.enable_vertex_attrib_array(5)
  end

  def use
    LibGL.bind_vertex_array(@vao)
  end

  def to_unsafe
    @vao
  end

  def destroy
    LibGL.delete_vertex_arrays(1, pointerof(@vao))
    @vao = 0
  end

  def finalize
    destroy
  end
end

class RenderGlyphVbo
  @vbo : UInt32 = 0
  @buffer : Slice(RenderGlyph)
  @index : Int32 = 0

  getter index

  def initialize(size : Int32)
    @buffer = Slice(RenderGlyph).new(size) { RenderGlyph::Empty }
    LibGL.gen_buffers(1, pointerof(@vbo))
    LibGL.bind_buffer(LibGL::ARRAY_BUFFER, @vbo)
    LibGL.buffer_data(LibGL::ARRAY_BUFFER,
                      sizeof(RenderGlyph) * @buffer.size,
                      @buffer,
                      LibGL::DYNAMIC_DRAW)
  end

  def full?
    @index >= @buffer.size
  end

  def <<(render_glyph : RenderGlyph)
    return if full?
    @buffer[@index] = render_glyph
    @index += 1
  end

  def reset
    @index = 0
  end

  def update_buffer : Int32
    LibGL.bind_buffer(LibGL::ARRAY_BUFFER, @vbo)
    LibGL.buffer_sub_data(LibGL::ARRAY_BUFFER, 0, @index * sizeof(RenderGlyph), @buffer)
    @index
  end

  def to_unsafe
    @vbo
  end

  def destroy
    LibGL.delete_buffers(1, pointerof(@vbo))
    @vbo = 0
  end

  def finalize
    destroy
  end
end

class GlyphRenderer
  @vbo : RenderGlyphVbo
  @vao : RenderGlyphVao
  @program : ShaderProgram

  getter program

  def initialize
    @vbo = checked RenderGlyphVbo.new(1024)
    @vao = checked RenderGlyphVao.new(@vbo)
    @program = checked ShaderProgram.build(vertex: File.read("shaders/glyph/vertex.glsl"),
                                           fragment: File.read("shaders/glyph/fragment.glsl"),
                                           geometry: File.read("shaders/glyph/geometry.glsl"))
  end

  def <<(render_glyph : RenderGlyph)
    if @vbo.full?
      flush
    end
    @vbo << render_glyph
  end

  def flush
    @program.use
    @vao.use
    count = @vbo.update_buffer

    LibGL.draw_arrays(LibGL::POINTS, 0, count)

    @vbo.reset
  end
end

class Paragraph
  @x : Float32 = 0
  @y : Float32 = 0
  @origin = Vec2f.new(0)
  @scale = 1_f32

  @fonts = [] of TextureFont

  def initialize(*fonts)
    if fonts.size <= 0
      raise "at least one font is required"
    end

    fonts.each do |font|
      @fonts << font
    end
  end

  def set_origin(@origin : Vec2f)
    @x = @origin.x
    @y = @origin.y
  end

  def newline(which_font : Int32 = 0)
    @y -= @fonts[which_font].height
    @x = @origin.x
  end

  def add_span(renderer : GlyphRenderer, text : String, color : Vec3f, which_font : Int32 = 0)
    font = @fonts[which_font]

    text.each_char do |c|
      if c == '\n'
        newline which_font
        next
      end

      next unless font.has_key?(c)
      ch = font[c]

      if c != ' '
        pos = Vec2f.new(@x + ch.bearing.x * @scale,
                        @y - (ch.size.y - ch.bearing.y) * @scale)
        size = Vec2f.new(ch.size.x * @scale,
                         ch.size.y * @scale)

        renderer << RenderGlyph.new(pos, size, ch.top_left, ch.bottom_right, color, which_font)
      end

      @x += (ch.advance >> 6) * @scale
    end
  end
end
