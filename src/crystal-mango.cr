require "lib_gl"
require "crystglfw"
require "./shader"
require "./texture_font"
require "./paragraph"
require "./highlighter"
require "./wavy_quad"

include CrystGLFW

class App
  getter! window : CrystGLFW::Window
  getter! renderer : GlyphRenderer

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

  @y : Float32 = 0

  def render_code(code : String, size)
    pad_x = 50_f32
    pad_y = 50_f32

    rect = RectF.new(pad_x, size[:height] - pad_y, size[:width] - pad_x, pad_y)
    LibGL.enable(LibGL::SCISSOR_TEST)
    LibGL.scissor(rect.left, rect.bottom, rect.width, rect.height)

    p = renderer.new_paragraph
    p.set_bbox(rect)
    p.set_offset_y(@y)

    projection = Mat4f.ortho(0, size[:width].to_f32, 0, size[:height].to_f32)
    renderer.program.use
    renderer.program.set_uniform "projection", projection

    highlighter = Highligher.new(p)
    highlighter.highlight(code)
    renderer.flush

    LibGL.disable(LibGL::SCISSOR_TEST)
  end

  @dy : Float32 = 0

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

    accel = 5_f32
    decel = 3_f32
    max_dy = 40_f32
    if window.key_pressed?(Key::PageUp)
      @dy = (@dy - accel).clamp(-max_dy, 0_f32)
    elsif window.key_pressed?(Key::PageDown)
      @dy = (@dy + accel).clamp(0_f32, max_dy)
    elsif @dy > 0
      @dy = (@dy - decel).clamp(0_f32, max_dy)
    elsif @dy < 0
      @dy = (@dy + decel).clamp(-max_dy, 0_f32)
    end
    @y += @dy
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

  def run(filename : String)
    source_code = File.read(filename)

    CrystGLFW.run do
      create_window

      query_info

      wavy_quad = WavyQuad.new

      fonts = FontFamily.load(16,
                              "fonts/RobotoMono-Regular.ttf",
                              "fonts/RobotoMono-Bold.ttf",
                              "fonts/RobotoMono-Italic.ttf",
                              "fonts/RobotoMono-BoldItalic.ttf")

      @renderer = GlyphRenderer.new(fonts)

      LibGL.enable(LibGL::BLEND)
      LibGL.blend_func(LibGL::SRC_ALPHA, LibGL::ONE_MINUS_SRC_ALPHA)

      frames = 0
      frames_begin = CrystGLFW.time

      until window.should_close?
        CrystGLFW.poll_events
        process_input

        LibGL.clear_color(0.2, 0.3, 0.3, 1.0)
        LibGL.clear(LibGL::COLOR_BUFFER_BIT)

        aspect_ratio = window.size[:width].to_f32 / window.size[:height].to_f32
        wavy_quad.render aspect_ratio
        render_code source_code, window.size

        window.swap_buffers

        frames += 1
        if frames > 30
          frames_end = CrystGLFW.time
          puts "FPS: #{frames / (frames_end - frames_begin)}; flushes: #{renderer.flushes / frames}/frame"
          renderer.reset_flushes
          frames_begin = frames_end
          frames = 0
        end
      end

      window.destroy
    end
  end
end

App.new.run(ARGV.first? || "src/crystal-mango.cr")
