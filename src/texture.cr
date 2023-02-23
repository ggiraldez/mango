require "lib_gl"
require "stumpy_png"

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

class Texture
  @handle : UInt32 = 0

  def initialize(@handle)
  end

  def to_unsafe
    @handle
  end

  def self.load_from_png(texture_filename, flipped = false)
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

    Texture.new(texture)
  end
end
