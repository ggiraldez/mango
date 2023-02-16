require "./mate"
require "./ft/lib_ft.cr"

class TextureFont
  record Character,
    size : Vec2i,
    bearing : Vec2i,
    advance : UInt32,
    top_left : Vec2f,
    bottom_right : Vec2f

  @characters = Hash(Char, Character).new
  @glyph_vao : UInt32 = 0
  @glyph_vbo : UInt32 = 0
  @texture : UInt32 = 0
  @height : UInt32 = 0

  getter height
  delegate :[], :has_key?, to: @characters

  def initialize(filename : String, size : Int32)
    prepare_glyph_vao
    load_font_into_textures(filename, size)
  end

  def to_unsafe
    @texture
  end

  private def check_ft_call(error : LibFreeType::Error)
    raise "error in FreeType #{error}" unless error == LibFreeType::Error::OK
  end

  private def load_font_into_textures(filename : String, size : Int32)
    check_ft_call LibFreeType.init_free_type(out ft)
    check_ft_call LibFreeType.new_face(ft, filename, 0, out face)
    check_ft_call LibFreeType.set_pixel_sizes(face, 0, size)

    LibGL.pixel_store_i(LibGL::UNPACK_ALIGNMENT, 1)

    buf_width = 512
    buf_height = 512
    buffer = Slice(UInt8).new(buf_width * buf_height)
    buf_x = 0
    buf_y = 0
    buf_row_height = 0

    (0...256).each do |c|
      if LibFreeType.load_char(face, c, LibFreeType::LoadFlags::RENDER) != LibFreeType::Error::OK
        puts "error loading character #{c}"
        next
      end

      glyph = face.value.glyph
      bitmap = glyph.value.bitmap

      if buf_x + bitmap.width > buf_width
        buf_x = 0
        buf_y += buf_row_height
      end
      if buf_y + bitmap.rows > buf_height
        puts "no room left to accomodate character #{c}"
        next
      end

      (0...bitmap.rows).each do |row|
        buf_pos = buf_width * (buf_y + row) + buf_x
        bitmap_pos = bitmap.width * row
        (0...bitmap.width).each do |col|
          buffer[buf_pos + col] = bitmap.buffer[bitmap_pos + col]
        end
      end

      top_left = Vec2f.new(buf_x.to_f32 / buf_width,
                           buf_y.to_f32 / buf_height)
      bottom_right = Vec2f.new((buf_x + bitmap.width).to_f32 / buf_width,
                               (buf_y + bitmap.rows).to_f32 / buf_height)

      @characters[c.unsafe_chr] = Character.new(size: Vec2i.new(bitmap.width.to_i32, bitmap.rows.to_i32),
                                                bearing: Vec2i.new(glyph.value.bitmap_left,
                                                                   glyph.value.bitmap_top),
                                                advance: glyph.value.advance.x.to_u32,
                                                top_left: top_left,
                                                bottom_right: bottom_right)

      buf_x += bitmap.width
      buf_row_height = [buf_row_height, bitmap.rows].max
    end

    puts "Final buffer position: #{buf_x},#{buf_y}"

    LibGL.gen_textures(1, out texture)
    LibGL.bind_texture(LibGL::TEXTURE_2D, texture)
    LibGL.tex_image_2d(LibGL::TEXTURE_2D, 0, LibGL::RED,
                       buf_width, buf_height,
                       0, LibGL::RED, LibGL::UNSIGNED_BYTE, buffer)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_S, LibGL::CLAMP_TO_EDGE)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_T, LibGL::CLAMP_TO_EDGE)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::LINEAR)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::LINEAR)
    @texture = texture
    @height = (face.value.size.value.metrics.height >> 6).to_u32

    check_ft_call LibFreeType.done_face(face)
    check_ft_call LibFreeType.done_free_type(ft)
  end

  def prepare_glyph_vao
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

    @glyph_vao = vao
    @glyph_vbo = vbo
  end

  def render_text(text : String, x : Float32, y : Float32, scale : Float32)
    LibGL.active_texture(LibGL::TEXTURE0)
    LibGL.bind_vertex_array(@glyph_vao)

    LibGL.bind_texture(LibGL::TEXTURE_2D, @texture)
    LibGL.bind_buffer(LibGL::ARRAY_BUFFER, @glyph_vbo)

    text.each_char do |c|
      ch = @characters[c]

      xpos = x + ch.bearing.x * scale
      ypos = y - (ch.size.y - ch.bearing.y) * scale
      w = ch.size.x * scale
      h = ch.size.y * scale
      tl = ch.top_left
      br = ch.bottom_right

      vertices = [
        xpos,     ypos + h, tl.x, tl.y,
        xpos,     ypos,     tl.x, br.y,
        xpos + w, ypos,     br.x, br.y,
        xpos,     ypos + h, tl.x, tl.y,
        xpos + w, ypos,     br.x, br.y,
        xpos + w, ypos + h, br.x, tl.y
      ] of Float32

      LibGL.buffer_sub_data(LibGL::ARRAY_BUFFER, 0, sizeof(Float32) * vertices.size, vertices)
      LibGL.draw_arrays(LibGL::TRIANGLES, 0, 6)
      x += (ch.advance >> 6) * scale
    end

    LibGL.bind_buffer(LibGL::ARRAY_BUFFER, 0)
    LibGL.bind_vertex_array(0)
    LibGL.bind_texture(LibGL::TEXTURE_2D, 0)
  end

  def line_metrics(text : String) : Vec2f
    width = 0_f32
    text.each_char do |c|
      ch = @characters[c]
      width += (ch.advance >> 6)
    end
    Vec2f.new(width, @height.to_f32)
  end
end

class FontFamily
  getter regular, bold, italic, bold_italic

  def initialize(@regular : TextureFont,
                 @bold : TextureFont,
                 @italic : TextureFont,
                 @bold_italic : TextureFont)
  end

  def self.load(size : Int32,
                regular_filename,
                bold_filename,
                italic_filename,
                bold_italic_filename)
    regular = TextureFont.new(regular_filename, size)
    bold = if bold_filename
             TextureFont.new(bold_filename, size)
           else
             regular
           end
    italic = if italic_filename
               TextureFont.new(italic_filename, size)
             else
               regular
             end
    bold_italic = if bold_italic_filename
                    TextureFont.new(bold_italic_filename, size)
                  elsif italic_filename
                    italic
                  else
                    bold
                  end
    FontFamily.new(regular, bold, italic, bold_italic)
  end
end
