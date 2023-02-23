require "lib_gl"
require "crystglfw"
require "./shader"
require "./texture_font"
require "./paragraph"
require "./wavy_quad"

include CrystGLFW

class App
  @window : CrystGLFW::Window?
  @renderer : GlyphRenderer?

  def window
    @window.not_nil!
  end

  def renderer
    @renderer.not_nil!
  end

  def create_window
    # Request a specific version of OpenGL in core profile mode with forward
    # compatibility.
    hints = {
      Window::HintLabel::ContextVersionMajor => 3,
      Window::HintLabel::ContextVersionMinor => 3,
      Window::HintLabel::OpenGLForwardCompat => true,
      Window::HintLabel::ClientAPI => ClientAPI::OpenGL,
      Window::HintLabel::OpenGLProfile => OpenGLProfile::Core
    }

    @window = Window.new title: "Crystal Mango", hints: hints
    window.make_context_current

    window.on_framebuffer_resize do |event|
      # update the viewport if the window was resized
      LibGL.viewport(0, 0, event.size[:width], event.size[:height])
    end
  end

  def render_para(para : String, size)
    p = renderer.new_paragraph
    p.set_origin(Vec2f.new(12_f32, (size[:height] - renderer.font_family.regular.height).to_f32))

    projection = Mat4f.ortho(0, size[:width].to_f32, 0, size[:height].to_f32)
    renderer.program.use
    renderer.program.set_uniform "projection", projection

    colors = [Vec3f.new(0.9, 0.9, 0.9),
              Vec3f.new(0.9, 0.9, 0.1),
              Vec3f.new(0.1, 0.9, 0.1)]
    para.split(" ").each_with_index do |span, i|
      p.add_span span + " ", colors[i % 3], FontFamily::Variant.new(i % FontFamily::Variant.values.size)
    end
    renderer.flush
  end

  def process_input
    if window.key_pressed?(Key::Escape) || window.key_pressed?(Key::Q)
      puts "Exiting"
      window.should_close
      return
    end

    # render polygons in wire-mode
    if window.key_pressed?(Key::W)
      LibGL.polygon_mode(LibGL::FRONT_AND_BACK, LibGL::LINE)
    else
      LibGL.polygon_mode(LibGL::FRONT_AND_BACK, LibGL::FILL)
    end
  end

  def query_info
    # find out the max number of attributes supported by the driver/hardware
    LibGL.get_integer_v(LibGL::MAX_VERTEX_ATTRIBS, out max_attribs)
    puts "Max number of attributes #{max_attribs}"

    # max texture size
    LibGL.get_integer_v(LibGL::MAX_TEXTURE_SIZE, out max_texture_size)
    puts "Max 1D/2D texture size #{max_texture_size}"

    # max texture units
    LibGL.get_integer_v(LibGL::MAX_TEXTURE_IMAGE_UNITS, out max_texture_units)
    puts "Max texture units #{max_texture_units}"
  end

  def run
    CrystGLFW.run do
      create_window

      query_info

      wavy_quad = WavyQuad.new

      fonts = FontFamily.load(18,
                              "fonts/RobotoMono-Regular.ttf",
                              "fonts/RobotoMono-Bold.ttf",
                              "fonts/RobotoMono-Italic.ttf",
                              "fonts/RobotoMono-BoldItalic.ttf")

      @renderer = GlyphRenderer.new(fonts)

      lines = File.read("src/crystal-mango.cr")

      LibGL.enable(LibGL::BLEND)
      LibGL.blend_func(LibGL::SRC_ALPHA, LibGL::ONE_MINUS_SRC_ALPHA)

      until window.should_close?
        CrystGLFW.poll_events
        process_input

        LibGL.clear_color(0.2, 0.3, 0.3, 1.0)
        LibGL.clear(LibGL::COLOR_BUFFER_BIT)

        aspect_ratio = window.size[:width].to_f32 / window.size[:height].to_f32
        wavy_quad.render aspect_ratio
        render_para lines, window.size

        window.swap_buffers
      end

      window.destroy
    end
  end
end

App.new.run
