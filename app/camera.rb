class Camera

  def initialize(x:, y:, screen_x:, screen_y:, viewport_w:, viewport_h:)
    @x = x
    @y = y
    @screen_x = screen_x
    @screen_y = screen_y
    @viewport_w = viewport_w
    @viewport_h = viewport_h

    @zoom = 0.8
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
    @move_started_tick = nil
    @move_start_y = @y
    @move_target_y = @y
    @move_duration = 0
    @vertical_follow_direction = nil
    @last_vertical_follow_direction = nil
  end

  def tick
    calc_move
    calc_shake
    calc_zoom
  end

  def move_vertical_to(y:, duration:)
    @move_start_y = @y
    @move_target_y = y
    @move_duration = duration
    @move_started_tick = Kernel.tick_count
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

  def follow_vertical(target:, lower_threshold: 0.20, upper_threshold: 0.6, smoothing: 0.09, reversal_hysteresis: 0.1, min_y: nil)
    target_center_y = target.y + (target.h / 2)
    target_velocity_y = target.respond_to?(:dy) ? target.dy : 0

    visible = visible_world_rect
    lower_y = visible.y + (visible.h * lower_threshold)
    upper_y = visible.y + (visible.h * upper_threshold)
    reversal_buffer = visible.h * reversal_hysteresis

    if target_velocity_y > 0
      @vertical_follow_direction = nil if @vertical_follow_direction == :down
      upward_trigger_y = upper_y
      upward_trigger_y += reversal_buffer if @last_vertical_follow_direction == :down

      if @last_vertical_follow_direction == :up || target_center_y > upward_trigger_y
        @vertical_follow_direction = :up
        @last_vertical_follow_direction = :up
      end
    elsif target_velocity_y < 0
      @vertical_follow_direction = nil if @vertical_follow_direction == :up
      downward_trigger_y = lower_y
      downward_trigger_y -= reversal_buffer if @last_vertical_follow_direction == :up

      if @last_vertical_follow_direction == :down || target_center_y < downward_trigger_y
        @vertical_follow_direction = :down
        @last_vertical_follow_direction = :down
      end
    else
      @vertical_follow_direction = nil
    end

    target_camera_y =
      if @vertical_follow_direction == :up
        @y + (target_center_y - lower_y)
      elsif @vertical_follow_direction == :down
        @y + (target_center_y - upper_y)
      else
        @y
      end

    target_camera_y = [target_camera_y, min_y].max if min_y

    @y = @y.lerp(target_camera_y, smoothing)
  end

  def move_to(x: @x, y: @y)
    @x = x
    @y = y
  end

  def visible_world_rect
    world_w = @viewport_w.fdiv(@zoom)
    world_h = @viewport_h.fdiv(@zoom)

    {
      x: @x - (world_w / 2),
      y: @y - (world_h / 2),
      w: world_w,
      h: world_h
    }
  end

  def moving?
    @move_started_tick
  end

  private

  def calc_move
    return unless @move_started_tick

    progress = @move_started_tick.elapsed_time.fdiv(@move_duration).clamp(0.0, 1.0)

    eased_progress = Easing.smooth_step(
      initial: 0.0,
      final: 1.0,
      perc: progress,
      power: 3
    )

    @y = @move_start_y.lerp(@move_target_y, eased_progress)

    if progress >= 1.0
      @y = @move_target_y
      @move_started_tick = nil
    end
  end

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
      @zoom = @zoom_target.lerp(0.8, progress)
    else
      @zoom = 0.8
      @zoom_started_tick = nil
    end
  end

end
