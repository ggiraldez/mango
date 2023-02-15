@[Link(ldflags: "`command -v pkg-config > /dev/null && pkg-config --libs freetype2 2> /dev/null|| printf %s '-lfreetype'`")]
lib LibFreeType
  alias Library = Pointer(Void)      # opaque FT_LibraryRec_
  alias Face = Pointer(FaceRec)
  alias CharMap = Pointer(Void)      # FT_CharMapRec_
  alias GlyphSlot = Pointer(GlyphSlotRec)
  alias SubGlyph = Pointer(Void)     # opaque FT_SubGlyphRec_
  alias SlotInternal = Pointer(Void) # opaque FT_SlotInternalRec_
  alias SizeInternal = Pointer(Void) # opaque FT_SizeInternalRec_
  alias Size = Pointer(SizeRec)
  alias Short = LibC::Short
  alias UShort = LibC::UShort
  alias Long = LibC::Long
  alias ULong = LibC::ULong
  alias Int = LibC::Int
  alias UInt = LibC::UInt
  alias FT_String = LibC::Char
  alias Pos = LibC::Long
  alias Fixed = LibC::Long

  alias GenericFinalizer = Pointer(Void) -> Void

  enum GlyphFormat
    NONE = 0
    COMPOSITE = 0x636f6d70 # comp
    BITMAP    = 0x62697473 # bits
    OUTLINE   = 0x6f75746c # outl
    PLOTTER   = 0x706c6f74 # plot
  end

  struct Bitmap
    rows : LibC::UInt
    width : LibC::UInt
    pitch : LibC::Int
    buffer : Pointer(LibC::UChar)
    num_grays : LibC::UShort
    pixel_mode : LibC::UChar
    palette_mode : LibC::UChar
    palette : Pointer(Void)
  end

  struct Outline
    n_contours : LibC::Short
    n_points : LibC::Short

    points : Pointer(Vector)
    tags : Pointer(LibC::Char)
    contours : Pointer(LibC::Short)

    flags : LibC::Int
  end

  struct Vector
    x : Pos
    y : Pos
  end

  struct SizeRec
    face : Face
    generic : Generic
    metrics : SizeMetrics
    internal : SizeInternal
  end

  struct SizeMetrics
    x_ppem : UShort
    y_ppem : UShort

    x_scale : Fixed
    y_scale : Fixed

    ascender : Pos
    descender : Pos
    height : Pos
    max_advance : Pos
  end

  struct GlyphMetrics
    width : Pos
    height : Pos

    hori_bearing_x : Pos
    hori_bearing_y : Pos
    hori_advance : Pos

    vert_bearing_x : Pos
    vert_bearing_y : Pos
    vert_advance : Pos
  end

  struct GlyphSlotRec
    library : Library
    face : Face
    next : GlyphSlot
    glyph_index : UInt
    generic : Generic

    metris : GlyphMetrics
    linear_hori_advance : Fixed
    linear_vert_advance : Fixed
    advance : Vector

    format : GlyphFormat

    bitmap : Bitmap
    bitmap_left : Int
    bitmap_top : Int

    outline : Outline

    num_subglyphs : UInt
    subglyphs : SubGlyph

    control_data : Pointer(Void)
    control_len : LibC::Long

    lsb_delta : Pos
    rsb_delta : Pos

    other : Pointer(Void)

    internal : SlotInternal
  end

  struct BBox
    x_min : Pos
    y_min : Pos
    x_max : Pos
    y_max : Pos
  end

  struct Generic
    data : Pointer(Void)
    finalizer : GenericFinalizer
  end

  struct BitmapSize
    height : Short
    width : Short

    size : Pos

    x_ppem : Pos
    y_ppem : Pos
  end

  struct FaceRec
    num_faces : Long
    face_index : Long

    face_flags : Long
    style_flags : Long

    num_glyphs : Long

    family_name : FT_String*
    style_name : FT_String*

    num_fixed_sizes : Int
    available_sizes : BitmapSize*

    num_charmaps : Int
    charmaps : CharMap*

    generic : Generic

    bbox : BBox

    units_per_EM : UShort
    ascender : Short
    descender : Short
    height : Short

    max_advance_width : Short
    max_advance_height : Short

    underline_position : Short
    underline_thickness : Short

    glyph : GlyphSlot
    size : Size
    charmap : CharMap

    # private fields follow
  end

  enum Error
    OK = 0x00
    UnknownFileFormat = 0x02
    InvalidFileFormat = 0x03
  end

  @[Flags]
  enum LoadFlags
    DEFAULT = 0
    NO_SCALE = 1
    NO_HINTING = 2
    RENDER = 4
    NO_BITMAP = 8
    VERTICAL_LAYOUT = 16
    FORCE_AUTOHINT = 32
    CROP_BITMAP = 64
  end

  fun init_free_type = FT_Init_FreeType(library : Library*) : Error
  fun done_free_type = FT_Done_FreeType(library : Library) : Error
  fun new_face = FT_New_Face(library : Library, filename : LibC::Char*, face_index : Long, aface : Face*) : Error
  fun done_face = FT_Done_Face(face : Face) : Error
  fun set_pixel_sizes = FT_Set_Pixel_Sizes(face : Face, pixel_width : UInt, pixel_height : UInt) : Error
  fun load_char = FT_Load_Char(face : Face, char_code : ULong, flags : LoadFlags) : Error
end


# result = LibFreeType.init_free_type(out library)
# raise "failed to initialize FreeType" unless result == LibFreeType::Error::OK

# result = LibFreeType.new_face(library, "fonts/RobotoMono-Regular.ttf", 0, out face)
# raise "failed to load font" unless result == LibFreeType::Error::OK

# result = LibFreeType.set_pixel_sizes(face, 0, 48)
# puts result

# result = LibFreeType.load_char(face, 'X'.ord, LibFreeType::LoadFlags::RENDER)
# puts result

# pp face.value.glyph.value.bitmap
