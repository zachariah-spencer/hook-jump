class Camera
  def initialize(x:, y:, screen_x:, screen_y:)
    @x = x
    @y = y
    @screen_x = screen_x
    @screen_y = screen_y

    @zoom = 1.0
    @zoom_start =  1.0
    @zoom_target = 1.0
    @zoom_started_tick = nil
    @zoom_in_duration = 0
    @zoom_out_duration = 0
    @shake_x = 0.0
    @shake_y = 0.0
    @shake_time = 0.0
    @shake_duration = 1
    @shake_strength = 0
  end

  def tick
    calc_shake
    calc_zoom
  end

  def transform_rect(rect)
    world_center_x = rect.x + (rect.w / 2)
    world_center_y = rect.y + (rect.h / 2)

    screen_center_x =
      ((world_center_x - @x) * @zoom) + @screen_x + @shake_x

    screen_center_y =
      ((world_center_y - @y) * @zoom) + @screen_y + @shake_y

    rect.merge(
      x: screen_center_x - (rect.w * @zoom / 2),
      y: screen_center_y - (rect.h * @zoom / 2),
      w: rect.w * @zoom,
      h: rect.h * @zoom,
    )
  end

  def world_to_screen(x:, y:)
    {
      x: ((x - @x) * @zoom) + @screen_x + @shake_x,
      y: ((y - @y) * @zoom) + @screen_y + @shake_y
    }
  end

  def shake(strength:, duration:)
    @shake_strength = strength
    @shake_duration = duration
    @shake_time = duration
  end

  def zoom_to(target:, zoom_in_duration:, zoom_out_duration:)
    @zoom_start = @zoom
    @zoom_target = target
    @zoom_started_tick = Kernel.tick_count
    @zoom_in_duration = zoom_in_duration
    @zoom_out_duration = zoom_out_duration
  end

  private

  def calc_shake
    if @shake_time > 0.0
      current_strength = @shake_strength * @shake_time / @shake_duration
      angle = Numeric.rand * Math::PI * 2
      distance = Numeric.rand * current_strength

      @shake_x = Math.sin(angle) * distance
      @shake_y = Math.cos(angle) * distance

      @shake_time -= 1.0
    else
      @shake_x = 0
      @shake_y = 0
    end
  end

  def calc_zoom
    return unless @zoom_started_tick
    elapsed = @zoom_started_tick.elapsed_time

    zoom_in_end_tick = @zoom_in_duration
    zoom_out_end_tick = zoom_in_end_tick + @zoom_out_duration

    if elapsed < zoom_in_end_tick
      progress = elapsed.fdiv(@zoom_in_duration)
      @zoom = @zoom_start.lerp(@zoom_target, progress)
    elsif elapsed < zoom_out_end_tick
      zoom_out_elapsed = elapsed - zoom_in_end_tick
      progress = zoom_out_elapsed.fdiv(@zoom_out_duration)
      @zoom = @zoom_target.lerp(1.0, progress)
    else
      @zoom = 1.0
      @zoom_started_tick = nil
    end
  end

end