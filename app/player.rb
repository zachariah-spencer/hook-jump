class Player
  include Powerups
  attr_dr

  MAX_FALL_SPEED = 2.5
  FALL_ACCELERATION = 0.8
  FAST_FALL_RECOVERY = 0.33
  MOVE_ACCELERATION = 0.6
  MOVE_DECELERATION = 0.35
  JUMP_VELOCITY = 22.0
  BOOSTED_JUMP_VELOCITY = JUMP_VELOCITY * 1.5
  JUMP_SPRITE_DURATION = 0.5.seconds
  GRAPPLE_DURATION = 0.25.seconds
  MAX_SPEED = 5.0
  EAGLE_MOVE_SPEED = MAX_SPEED * 1.75


  def initialize
    @x = (Grid.w / 2) - 16
    @y = Grid.h - 128
    @w = 64
    @h = 64
    @acceleration = 0.6
    @deceleration = 0.35
    @max_speed = 5.0
    @gold = 0
    @powerups = []

    @hook = Hook.new((@x / 2) - 4, (@y / 2) - 4)
    @jump_sprite_started_tick = nil
    @grappling_tick = nil
    @dx = 0
    @dy = 0
    @face_direction = 1
    @move_direction_x = 0
    @move_direction_y = 0
    @grapple_start_x = 0
    @carried_by_eagle = false

    @offscreen_indicator = {
      x: 50,
      y: Grid.h - 64,
      w: 64,
      h: 64,
      anchor_x: 0.5,
      anchor_y: 0.5,
      path: "sprites/triangle/equilateral/blue.png",
      angle: 0,
    }
  end

  def tick
    calc
  end

  def calc
    @move_direction_x = state.move_direction_x
    @move_direction_y = state.move_direction_y
    @face_direction = facing_direction

    unless @carried_by_eagle
      target_dx = @move_direction_x * @max_speed

      if @dx < target_dx
        @dx = [@dx + @acceleration, target_dx].min
      elsif @dx > target_dx
        @dx = [@dx - @deceleration, target_dx].max
      end

      applied_player_fall_speed = @move_direction_y == -1 ? (MAX_FALL_SPEED * 1.5) : MAX_FALL_SPEED
      if @dy < -MAX_FALL_SPEED
        @dy = [@dy + FAST_FALL_RECOVERY, -applied_player_fall_speed].min
      else
        @dy = [@dy - FALL_ACCELERATION, -applied_player_fall_speed].max
      end
    else
      if @dx < @move_direction_x * EAGLE_MOVE_SPEED
        @dx = [@dx + (MOVE_ACCELERATION * 1.5), @move_direction_x * EAGLE_MOVE_SPEED].min
      elsif @dx > @move_direction_x * EAGLE_MOVE_SPEED
        @dx = [@dx - (MOVE_DECELERATION * 1.5), @move_direction_x * EAGLE_MOVE_SPEED].max
      end

      if @dy < @move_direction_y * EAGLE_MOVE_SPEED
        @dy = [@dy + (MOVE_ACCELERATION * 1.5), @move_direction_y * EAGLE_MOVE_SPEED].min
      elsif @dy > @move_direction_y * EAGLE_MOVE_SPEED
        @dy = [@dy - (MOVE_DECELERATION * 1.5), @move_direction_y * EAGLE_MOVE_SPEED].max
      end
    end

    @x += @dx
    @y += @dy

    # calc attacking
    if state.hook_input_pressed && can_shoot_hook?
      @hook.shoot(direction: @face_direction)
      @jump_sprite_started_tick = nil
    end

    @hook.cancel_shot if state.hook_input_released

    @hook.calc(owner: self)

    calc_offscreen_indicator

    return unless grappling?
    grapple

  end

  def start_grapple(target_rock)
    @hook.hit_target = target_rock
    @grappling_tick = Kernel.tick_count
    @grapple_start_x = @x
    @hook.cancel_shot
  end

  def grapple
    target_rock = @hook.hit_target
    target_rock.dy = -@dy

    ease_percentage = Easing.smooth_stop(start_at: @grappling_tick,
                                duration: GRAPPLE_DURATION,
                                tick_count: Kernel.tick_count,
                                power: 3)
    @x = @grapple_start_x.lerp(target_rock.x, ease_percentage) if target_rock

    if @grappling_tick.elapsed_time >= GRAPPLE_DURATION
      reset_grapple_variables
      return target_rock
    end
    return nil
  end

  def grapple_duration
    GRAPPLE_DURATION
  end

  def calc_offscreen_indicator
    if @y >= Grid.h
      # x position
      @offscreen_indicator.x = @x + (@w / 2) - (@offscreen_indicator.w / 2)

      # angle
      center_x = @offscreen_indicator.x + (@offscreen_indicator.w / 2)
      progress = center_x.fdiv(1280).clamp(0, 1)
      angle = (30.0).lerp(-30.0, progress)
      @offscreen_indicator.angle = angle

      # scale
      distance_above = @y - Grid.h
      progress = distance_above.fdiv(1024).clamp(0, 1)
      size = 64.lerp(16, progress)
      @offscreen_indicator.w = size
      @offscreen_indicator.h = size
    end
  end

  #TODO: Implement this check in Game
  def dead?
    @y <= -@h
  end

  def facing_direction
    if @move_direction_x > 0
      1
    elsif @move_direction_x < 0
      -1
    else
      @face_direction
    end
  end

  def jump!
    @dy += JUMP_VELOCITY
  end

  def boosted_jump!
    @dy += BOOSTED_JUMP_VELOCITY
  end

  def knock_down!
    @dy -= JUMP_VELOCITY / 2
  end

  def start_jump_animation
    @jump_sprite_started_tick = Kernel.tick_count
  end

  def can_shoot_hook?
    !grappling? && !@hook.shooting?
  end

  def grappling?
    @grappling_tick
  end

  def finite_powerups
    @powerups.select { |p| p.duration > 0 }
  end

  def add_powerup(powerup_type:)

    new_powerup = Powerups.build(type: powerup_type)

    existing_powerup = @powerups.find do |powerup|
      powerup.type == new_powerup.type
    end

    if existing_powerup
      existing_powerup.start_tick = new_powerup.start_tick
    else
      @powerups << new_powerup
    end
  end

  def sprite_path
    return "sprites/player/grabbing_rock_player.png" if grappling?

    if @jump_sprite_started_tick &&
        @jump_sprite_started_tick.elapsed_time < JUMP_SPRITE_DURATION
      return "sprites/player/jumping_player.png"
    end

    "sprites/player/idle_player.png"
  end

  def reset_grapple_variables
    @grappling_tick = nil
    @hook.hit_target = nil
    #TODO: Decouple input enable/disable
    # enable_input
  end

  def primitives
    primitives_array = []
    primitives_array << {
      x: @x,
      y: @y,
      w: @w,
      h: @h,
      path: sprite_path,
      flip_horizontally: @face_direction < 0
    }

    primitives_array.concat(@hook.primitives(owner: self))

    primitives_array << @offscreen_indicator if @y >= Grid.h

    primitives_array
  end
end
