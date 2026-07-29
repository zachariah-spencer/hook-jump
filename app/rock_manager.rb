class RockManager

  EASY_TO_MEDIUM_DIFFICULTY_DURATION = 35.seconds
  MEDIUM_TO_HARD_DIFFICULTY_DURATION = 70.seconds

  EASY_MIN_ROCK_SPAWN_DELAY = 0.22.seconds
  EASY_MAX_ROCK_SPAWN_DELAY = 0.42.seconds
  EASY_MIN_DOWN_ROCK_SPAWN_COUNTDOWN = 12
  EASY_MAX_DOWN_ROCK_SPAWN_COUNTDOWN = 16
  EASY_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN = 8
  EASY_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN = 12
  EASY_MIN_ROCK_FALL_SPEED = 3.8
  EASY_MAX_ROCK_FALL_SPEED = 5.3

  MEDIUM_MIN_ROCK_SPAWN_DELAY = 0.18.seconds
  MEDIUM_MAX_ROCK_SPAWN_DELAY = 0.34.seconds
  MEDIUM_MIN_DOWN_ROCK_SPAWN_COUNTDOWN = 7
  MEDIUM_MAX_DOWN_ROCK_SPAWN_COUNTDOWN = 10
  MEDIUM_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN = 7
  MEDIUM_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN = 10
  MEDIUM_MIN_ROCK_FALL_SPEED = 4.6
  MEDIUM_MAX_ROCK_FALL_SPEED = 6.2

  HARD_MIN_ROCK_SPAWN_DELAY = 0.14.seconds
  HARD_MAX_ROCK_SPAWN_DELAY = 0.26.seconds
  HARD_MIN_DOWN_ROCK_SPAWN_COUNTDOWN = 4
  HARD_MAX_DOWN_ROCK_SPAWN_COUNTDOWN = 7
  HARD_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN = 6
  HARD_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN = 9
  HARD_MIN_ROCK_FALL_SPEED = 5.2
  HARD_MAX_ROCK_FALL_SPEED = 7.2

  MIN_SHOP_ROCK_SPAWN_COUNTDOWN = 20
  MAX_SHOP_ROCK_SPAWN_COUNTDOWN = 40
  ROCK_BREAK_FRAME_COUNT = 5
  ROCK_BREAK_FRAME_HOLD = 3
  SPECIAL_ROCK_TYPES = [:up, :bomb, :gold]

  def initialize(spawn_x:, spawn_y:, expired:)
    @difficulty = difficulty_at(0)
    @spawn_x = spawn_x
    @spawn_y = spawn_y
    @expired = expired
    @spawn_scheduler = SpawnScheduler.new(
      delay: lambda {
        Numeric.rand(@difficulty.min_rock_spawn_delay..@difficulty.max_rock_spawn_delay)
      }
    )
    @rocks = []
    @next_special_rock_spawn_countdown = Numeric.rand(@difficulty.min_special_rock_spawn_countdown..@difficulty.max_special_rock_spawn_countdown)
    @next_down_rock_spawn_countdown = Numeric.rand(@difficulty.min_down_rock_spawn_countdown..@difficulty.max_down_rock_spawn_countdown)
    @next_shop_rock_spawn_countdown = Numeric.rand(MIN_SHOP_ROCK_SPAWN_COUNTDOWN..MAX_SHOP_ROCK_SPAWN_COUNTDOWN)
    @only_spawn_up_rocks = false
    reset_spawn_variables
  end

  def tick(elapsed:)
    @difficulty = difficulty_at(elapsed)
    spawn_if_ready
    move_rocks
    remove_expired_rocks
  end

  def primitives
    @rocks.map do |rock|
        rock.merge(path: sprite_path(rock))
    end
  end

  def break(rock)
    rock.break_started_tick ||= Kernel.tick_count
  end

  def only_spawn_up_rocks?
    @only_spawn_up_rocks
  end

  def only_spawn_up_rocks!
    @only_spawn_up_rocks = true
  end

  def restore_normal_spawning!
    @only_spawn_up_rocks = false
  end

  def intersecting_rocks(rect)
    @rocks.select do |rock|
      collidable?(rock) && Geometry.intersect_rect?(rect, rock)
    end
  end

  def within_radius(target_rock:, radius:)
    @rocks.select do |rock|
        rock != target_rock &&
          collidable?(rock) &&
          Geometry.distance(target_rock, rock) <= radius
    end
  end

  private

  def reset_spawn_variables
    @next_rock_spawn_x = @spawn_x.call
    @next_rock_spawn_y = @spawn_y.call
    @next_rock_dy = Numeric.rand(@difficulty.min_rock_fall_speed..@difficulty.max_rock_fall_speed)
  end

  def break_animation_complete?(rock)
    return false unless rock.break_started_tick

    Numeric.frame_index(
      start_at: rock.break_started_tick,
      count: ROCK_BREAK_FRAME_COUNT,
      hold_for: ROCK_BREAK_FRAME_HOLD,
      repeat: false,
    ).nil?
  end

  def sprite_path(rock)
    return rock.path unless rock.break_started_tick

    frame_index = Numeric.frame_index(
      start_at: rock.break_started_tick,
      count: ROCK_BREAK_FRAME_COUNT,
      hold_for: ROCK_BREAK_FRAME_HOLD,
      repeat: false,
    )

    "sprites/rocks/rock_break/rock_break_#{frame_index.to_s.rjust(4, "0")}.png"
  end

  def select_type
      return :up if @only_spawn_up_rocks

      @next_shop_rock_spawn_countdown -= 1
      @next_special_rock_spawn_countdown -= 1
      @next_down_rock_spawn_countdown -= 1

      if @next_shop_rock_spawn_countdown <= 0
        @next_shop_rock_spawn_countdown = Numeric.rand(MIN_SHOP_ROCK_SPAWN_COUNTDOWN..MAX_SHOP_ROCK_SPAWN_COUNTDOWN)
        return :shop
      end

      if @next_down_rock_spawn_countdown <= 0
        @next_down_rock_spawn_countdown = Numeric.rand(@difficulty.min_down_rock_spawn_countdown..@difficulty.max_down_rock_spawn_countdown)
        return :down
      end

      if @next_special_rock_spawn_countdown <= 0
        @next_special_rock_spawn_countdown = Numeric.rand(@difficulty.min_special_rock_spawn_countdown..@difficulty.max_special_rock_spawn_countdown)
        return SPECIAL_ROCK_TYPES.sample
      end

      :basic
  end

  def collidable?(rock)
    !rock.break_started_tick
  end

  def difficulty_at(elapsed)
    if elapsed < EASY_TO_MEDIUM_DIFFICULTY_DURATION
      t = elapsed.fdiv(EASY_TO_MEDIUM_DIFFICULTY_DURATION).clamp(0, 1)

      {
        min_rock_spawn_delay: EASY_MIN_ROCK_SPAWN_DELAY.lerp(MEDIUM_MIN_ROCK_SPAWN_DELAY, t),
        max_rock_spawn_delay: EASY_MAX_ROCK_SPAWN_DELAY.lerp(MEDIUM_MAX_ROCK_SPAWN_DELAY, t),
        min_down_rock_spawn_countdown: EASY_MIN_DOWN_ROCK_SPAWN_COUNTDOWN.lerp(MEDIUM_MIN_DOWN_ROCK_SPAWN_COUNTDOWN, t).round,
        max_down_rock_spawn_countdown: EASY_MAX_DOWN_ROCK_SPAWN_COUNTDOWN.lerp(MEDIUM_MAX_DOWN_ROCK_SPAWN_COUNTDOWN, t).round,
        min_special_rock_spawn_countdown: EASY_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN.lerp(MEDIUM_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN, t).round,
        max_special_rock_spawn_countdown: EASY_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN.lerp(MEDIUM_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN, t).round,
        min_rock_fall_speed: EASY_MIN_ROCK_FALL_SPEED.lerp(MEDIUM_MIN_ROCK_FALL_SPEED, t),
        max_rock_fall_speed: EASY_MAX_ROCK_FALL_SPEED.lerp(MEDIUM_MAX_ROCK_FALL_SPEED, t),
      }
    else
      t = (elapsed - EASY_TO_MEDIUM_DIFFICULTY_DURATION).fdiv(MEDIUM_TO_HARD_DIFFICULTY_DURATION).clamp(0, 1)

      {
        min_rock_spawn_delay: MEDIUM_MIN_ROCK_SPAWN_DELAY.lerp(HARD_MIN_ROCK_SPAWN_DELAY, t),
        max_rock_spawn_delay: MEDIUM_MAX_ROCK_SPAWN_DELAY.lerp(HARD_MAX_ROCK_SPAWN_DELAY, t),
        min_down_rock_spawn_countdown: MEDIUM_MIN_DOWN_ROCK_SPAWN_COUNTDOWN.lerp(HARD_MIN_DOWN_ROCK_SPAWN_COUNTDOWN, t).round,
        max_down_rock_spawn_countdown: MEDIUM_MAX_DOWN_ROCK_SPAWN_COUNTDOWN.lerp(HARD_MAX_DOWN_ROCK_SPAWN_COUNTDOWN, t).round,
        min_special_rock_spawn_countdown: MEDIUM_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN.lerp(HARD_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN, t).round,
        max_special_rock_spawn_countdown: MEDIUM_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN.lerp(HARD_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN, t).round,
        min_rock_fall_speed: MEDIUM_MIN_ROCK_FALL_SPEED.lerp(HARD_MIN_ROCK_FALL_SPEED, t),
        max_rock_fall_speed: MEDIUM_MAX_ROCK_FALL_SPEED.lerp(HARD_MAX_ROCK_FALL_SPEED, t),
      }
    end
  end

  def spawn_if_ready
    return unless @spawn_scheduler.ready?
    selected_rock_type = select_type
    reset_spawn_variables
    new_rock = Rocks.build(
      type: selected_rock_type,
      spawn_x: @next_rock_spawn_x,
      spawn_y: @next_rock_spawn_y,
      fall_speed: @next_rock_dy
    )
    @rocks << new_rock
    @spawn_scheduler.reset!
  end

  def move_rocks
    @rocks.each do |r|
      r.y -= r.dy unless r.break_started_tick
      r.angle += r.dang if r.type == :basic && !r.break_started_tick
    end
  end

  def remove_expired_rocks
    @rocks.reject! do |rock|
      @expired.call(rock) || break_animation_complete?(rock)
    end
  end
end