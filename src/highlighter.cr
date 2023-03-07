require "crystal/syntax_highlighter"
require "./paragraph"

class Highligher < Crystal::SyntaxHighlighter
  property colors : Hash(TokenType, Vec3f) = {
    :comment           => Vec3f.new(0.5, 0.5, 0.5),
    :symbol            => Vec3f.new(0.9, 0.5, 0.5),
    :string            => Vec3f.new(0.1, 0.9, 0.1),
    :delimiter_start   => Vec3f.new(0.1, 0.9, 0.1),
    :delimiter_end     => Vec3f.new(0.1, 0.9, 0.1),
    :delimited_token   => Vec3f.new(0.1, 0.9, 0.1),
    :const             => Vec3f.new(0.9, 0.9, 0.1),
    :ident             => Vec3f.new(0.9, 0.9, 0.9),
    :keyword           => Vec3f.new(0.9, 0.9, 0.9),
    :operator          => Vec3f.new(0.7, 0.7, 0.9),
    :self              => Vec3f.new(0.7, 0.7, 0.9),
  } of TokenType => Vec3f

  property variants : Hash(TokenType, FontFamily::Variant) = {
    :comment  => :italic,
    :string   => :italic,
    :keyword  => :bold,
    :operator => :bold,
    :self     => :bold,
  } of TokenType => FontFamily::Variant

  getter default_color = Vec3f.new(0.9, 0.9, 0.9)
  getter default_variant = FontFamily::Variant::Regular

  def initialize(@paragraph : Paragraph)
  end

  def render(type : TokenType, value : String)
    color = colors[type]? || default_color
    variant = variants[type]? || default_variant
    @paragraph.add_span value, color, variant
  end

  def render_delimiter(&)
    yield
  end

  def render_interpolation(&)
    @paragraph.add_span "\#{", default_color, default_variant
    yield
    @paragraph.add_span "}", default_color, default_variant
  end

  def render_string_array(&)
    yield
  end

end
