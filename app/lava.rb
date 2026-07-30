class Lava
  attr_reader :surface_y

  PIXELS_PER_METER = 32.0

  def initialize(surface_y:, start_speed:, max_speed:, ramp_duration:)
    @initial_surface_y = surface_y
    @surface_y = surface_y

    @start_speed = start_speed
    @max_speed = max_speed
    @ramp_duration = ramp_duration
  end

  def tick(elapsed:)
    elapsed_seconds = elapsed / 60.0
    progress = elapsed_seconds.fdiv(@ramp_duration)
    progress = progress.clamp(0.0, 1.0)

    current_speed = @start_speed.lerp(@max_speed, progress)
    @surface_y += current_speed
  end

  def primitives(view:)
    bottom = view.y
    height = @surface_y - bottom

    return [] if height <= 0

    [
      # Main lava body
      {
        x: view.x,
        y: bottom,
        w: view.w,
        h: height,
        r: 89,
        g: 23,
        b: 122,
        a: 230
      },

      # Bright surface band
      {
        x: view.x,
        y: @surface_y - 10,
        w: view.w,
        h: 10,
        r: 169,
        g: 3,
        b: 252,
        a: 255
      },

      # Hot leading edge
      {
        x: view.x,
        y: @surface_y - 3,
        w: view.w,
        h: 3,
        r: 221,
        g: 153,
        b: 255,
        a: 255
      }
    ]
  end

  def intersect_rect?(rect)
    rect.y + (rect.h * 0.4) <= @surface_y
  end

  def reset!
    @surface_y = @initial_surface_y
  end

end