struct Float32
  def to_radians : Float32
    (self * Math::PI) / 180.0_f32
  end
end

struct Float64
  def to_radians : Float64
    (self * Math::PI) / 180.0_f64
  end
end

struct Vec2(T)
  @data = StaticArray(T, 2).new(0)
  getter data

  delegate :[], :[]=, to: @data

  def initialize(x : T, y : T)
    @data[0] = x
    @data[1] = y
  end

  def self.new(x : T) : Vec2(T)
    new x, x
  end

  def x
    @data[0]
  end

  def y
    @data[1]
  end
end

alias Vec2i = Vec2(Int32)

struct Vec3(T)
  @data = StaticArray(T, 3).new(0)
  getter data

  delegate :[], :[]=, to: @data

  def initialize(x : T, y : T, z : T)
    @data[0] = x
    @data[1] = y
    @data[2] = z
  end

  def self.new(x : T) : Vec3(T)
    new x, x, x
  end

  def x
    @data[0]
  end

  def y
    @data[1]
  end

  def z
    @data[2]
  end
end

alias Vec3f = Vec3(Float32)

struct Mat4(T)
  # data is stored in column-major order
  # throughout the class, i denotes row and j denotes column
  # coordinate pair is given in row,column order, so i,j
  @data = StaticArray(T, 16).new(0)
  getter data

  def initialize(x : T)
    @data[0] = @data[5] = @data[10] = @data[15] = x
  end

  def self.new(& : (Int32, Int32) -> T) : Mat4(T)
    m = new(0)
    0.upto(3) do |i|
      0.upto(3) do |j|
        m[i, j] = yield i, j
      end
    end
    m
  end

  def to_unsafe : Pointer(T)
    @data.to_unsafe
  end

  def [](i, j)
    @data[i + 4 * j]
  end

  def []=(i, j, value : T)
    @data[i + 4 * j] = value
  end

  def *(other : Mat4(T))
    Mat4(T).new do |i, j|
      self[i, 0] * other[0, j] +
        self[i, 1] * other[1, j] +
        self[i, 2] * other[2, j] +
        self[i, 3] * other[3, j]
    end
  end

  def self.translation(offset : Vec3(T))
    tm = new(1)
    tm[0, 3] = offset[0]
    tm[1, 3] = offset[1]
    tm[2, 3] = offset[2]
    tm
  end

  def translate(offset : Vec3(T))
    Mat4(T).translation(offset) * self
  end

  def self.scaling(scale : Vec3(T))
    sm = new(1)
    sm[0, 0] = scale[0]
    sm[1, 1] = scale[1]
    sm[2, 2] = scale[2]
    sm
  end

  def scale(scale : Vec3(T))
    Mat4(T).scaling(scale) * self
  end

  def self.rotation(radians : T, axis : Vec3(T))
    ct = Math.cos(radians)
    st = Math.sin(radians)

    rm = new(0)

    rm[0, 0] = ct + axis[0] * axis[0] * (1 - ct)
    rm[0, 1] = axis[0] * axis[1] * (1 - ct) - axis[2] * st
    rm[0, 2] = axis[0] * axis[2] * (1 - ct) + axis[1] * st
    rm[0, 3] = 0

    rm[1, 0] = axis[1] * axis[2] * (1 - ct) + axis[2] * st
    rm[1, 1] = ct + axis[1] * axis[1] * (1 - ct)
    rm[1, 2] = axis[1] * axis[2] * (1 - ct) + axis[0] * st
    rm[1, 3] = 0

    rm[2, 0] = axis[0] * axis[2] * (1 - ct) + axis[1] * st
    rm[2, 1] = axis[1] * axis[2] * (1 - ct) + axis[0] * st
    rm[2, 2] = ct + axis[2] * axis[2] * (1 - ct)
    rm[2, 3] = 0

    rm[3, 0] = 0
    rm[3, 1] = 0
    rm[3, 2] = 0
    rm[3, 3] = 1

    rm
  end

  def rotate(radians : T, axis : Vec3(T))
    Mat4(T).rotation(radians, axis) * self
  end

  def self.ortho(left : T, right : T, bottom : T, top : T) : Mat4(T)
    self.ortho(left, right, bottom, top, -1, 1)
  end

  def self.ortho(left : T, right : T,
                 bottom : T, top : T,
                 near : T, far : T) : Mat4(T)
    # returns an orthographic projection matrix for a right-handed coordinate
    # system
    two : T = 2
    m = Mat4(T).new(1)
    m[0, 0] = two / (right - left)
    m[1, 1] = two / (top - bottom)
    m[2, 2] = -two / (far - near)
    m[0, 3] = -(right + left) / (right - left)
    m[1, 3] = -(top + bottom) / (top - bottom)
    m[2, 3] = -(far + near) / (far - near)
    m
  end

  def self.perspective(fov_y : T, aspect_ratio : T, near : T, far : T) : Mat4(T)
    # returns a perspective projection matrix given the FOV and aspect ratio,
    # for a right-handed coordinate system
    two : T = 2
    m = Mat4(T).new(0)
    tanHalfFovy = Math.tan(fov_y / two)
    m[0, 0] = 1 / (aspect_ratio * tanHalfFovy)
    m[1, 1] = 1 / tanHalfFovy
    m[2, 2] = -(far + near) / (far - near)
    m[2, 3] = - two * far * near / (far - near)
    m[3, 2] = -1
    m
  end

  def self.frustum(left : T, right : T,
                   bottom : T, top : T,
                   near : T, far : T) : Mat4(T)
    two : T = 2
    m = Mat4(T).new(0)
    m[0, 0] = two * near / (right - left)
    m[0, 2] = (right + left) / (right - left)
    m[1, 1] = two * near / (top - bottom)
    m[1, 2] = (top + bottom) / (top - bottom)
    m[2, 2] = -(far + near) / (far - near)
    m[2, 3] = -(two * far * near) / (far - near)
    m[3, 2] = -1
    m
  end

end

alias Mat4f = Mat4(Float32)
