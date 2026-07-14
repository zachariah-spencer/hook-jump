class Hook
  attr_dr

  DEFAULT_HOOK_SIZE = 24
  WIDE_HOOK_SIZE = 64
  MAX_LENGTH = 256.0
  MAX_DURATION = 0.4.seconds
  RECOVERY_DURATION = 6
  HOOK_SHOT_FRAME_COUNT = 9
  HOOK_WIDTH = 256
  HOOK_HEIGHT = 128
  
  def initialize(x, y)
    @x = x
    @y = y
    @w = 40
    @h = DEFAULT_HOOK_SIZE
    @direction = 1
    @hit_target = nil
    @shot_started_tick = nil
    @shot_recovery_tick = nil
  end

  def calc(owner:)
    expire_shot_if_needed
    cleanup_animation

    return unless shooting?
    @y = owner.y + (owner.h / 2 - @h / 2)
    base_x = 
      if @direction > 0
        owner.x + owner.w
      else
        owner.x - @w
      end

    ease_percentage = Easing.smooth_stop(start_at: @shot_started_tick,
                                duration: MAX_DURATION,
                                tick_count: Kernel.tick_count,
                                power: 1)
    
    hook_offset = 0.lerp(MAX_LENGTH * @direction, ease_percentage)
    @x = base_x + hook_offset
  end

  def shoot(direction:)
    @direction = direction
    @shot_started_tick = Kernel.tick_count
    @shot_recovery_tick = nil
  end

  def active?
    shooting?
  end

  def cancel_shot
    return unless shooting?

    @shot_recovery_tick ||= Kernel.tick_count
    @shot_started_tick = nil
  end

  def shooting?
    return false unless @shot_started_tick
    @shot_started_tick.elapsed_time <= MAX_DURATION
  end

  def animating?
    @shot_started_tick || @shot_recovery_tick
  end

  def frame_index
    if @shot_recovery_tick
      recovery_frame_index = Numeric.frame_index(
        start_at: @shot_recovery_tick,
        count: 2,
        hold_for: 3,
        repeat: false
        )

        recovery_frame_index + 7 if recovery_frame_index
    elsif @shot_started_tick
      Numeric.frame_index(
        start_at: @shot_started_tick,
        count: Hook::HOOK_SHOT_FRAME_COUNT,
        hold_for: 5,
        repeat: false
      )
    end
  end

  def expire_shot_if_needed
    return unless @shot_started_tick
    return if shooting?

    @shot_recovery_tick ||= Kernel.tick_count
    @shot_started_tick = nil
  end

  def cleanup_animation
    return unless @shot_recovery_tick
    return unless @shot_recovery_tick.elapsed_time >= RECOVERY_DURATION

    @shot_recovery_tick = nil
  end

  def primitives(owner:)
    primitives_array = []
    return primitives_array unless animating?

    if frame_index
      primitives_array << {
        x: @direction > 0 ? owner.x + owner.w : owner.x - HOOK_WIDTH,
        y: owner.y + (owner.h - HOOK_HEIGHT) / 2,
        w: HOOK_WIDTH,
        h: HOOK_HEIGHT,
        path: "sprites/hook/hook_shot/hook_shot#{frame_index.to_s.rjust(4, "0")}.png",
        flip_horizontally: @direction < 0,
      }
    end

    primitives_array
  end
end
