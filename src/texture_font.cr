require "./mate"
require "./ft/lib_ft.cr"

class TextureFont
  record Character,
    texture_id : UInt32,
    size : Vec2i,
    bearing : Vec2i,
    advance : UInt32

  @characters = Hash(Char, Character).new
  @glyph_vao : UInt32 = 0
  @glyph_vbo : UInt32 = 0

  def initialize(filename : String, size : Int32)
    prepare_glyph_vao
    load_font_into_textures(filename, size)
  end

  private def check_ft_call(error : LibFreeType::Error)
    raise "error in FreeType #{error}" unless error == LibFreeType::Error::OK
  end

  private def load_font_into_textures(filename : String, size : Int32)
    check_ft_call LibFreeType.init_free_type(out ft)
    check_ft_call LibFreeType.new_face(ft, filename, 0, out face)
    check_ft_call LibFreeType.set_pixel_sizes(face, 0, size)

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
                         glyph.value.bitmap.buffer)
      LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_S, LibGL::CLAMP_TO_EDGE)
      LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_T, LibGL::CLAMP_TO_EDGE)
      LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::LINEAR)
      LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::LINEAR)

      puts "Character #{c.unsafe_chr} (ord #{c}): #{glyph.value.bitmap.width}x#{glyph.value.bitmap.rows}" if c > 32

      @characters[c.unsafe_chr] = Character.new(texture_id: texture,
                                                size: Vec2i.new(glyph.value.bitmap.width.to_i32,
                                                                glyph.value.bitmap.rows.to_i32),
                                                bearing: Vec2i.new(glyph.value.bitmap_left,
                                                                   glyph.value.bitmap_top),
                                                advance: glyph.value.advance.x.to_u32)
    end

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

    text.each_char do |c|
      ch = @characters[c]

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
      LibGL.bind_buffer(LibGL::ARRAY_BUFFER, @glyph_vbo)
      LibGL.buffer_sub_data(LibGL::ARRAY_BUFFER, 0, sizeof(Float32) * vertices.size, vertices)
      LibGL.bind_buffer(LibGL::ARRAY_BUFFER, 0)
      LibGL.draw_arrays(LibGL::TRIANGLES, 0, 6)
      x += (ch.advance >> 6) * scale
    end

    LibGL.bind_vertex_array(0)
    LibGL.bind_texture(LibGL::TEXTURE_2D, 0)
  end
end
