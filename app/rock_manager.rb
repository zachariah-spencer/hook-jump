class RockManager
  HARD_MIN_SHOP_ROCK_SPAWN_COUNTDOWN = 20
  HARD_MAX_SHOP_ROCK_SPAWN_COUNTDOWN = 40
  ROCK_BREAK_FRAME_COUNT = 5
  ROCK_BREAK_FRAME_HOLD = 3
  SPECIAL_ROCK_TYPES = [:up, :bomb, :gold]

  def initialize(difficulty:, spawn_x:)
    @difficulty = difficulty
    @spawn_x = spawn_x
    @spawn_scheduler = SpawnScheduler.new(
      delay: lambda {
        Numeric.rand(@difficulty.min_rock_spawn_delay..@difficulty.max_rock_spawn_delay)
      }
    )
    @rocks = []
    @next_rock_spawn_x = @spawn_x.call
    @next_rock_dy = Numeric.rand(@difficulty.min_rock_fall_speed..@difficulty.max_rock_fall_speed)
    @next_special_rock_spawn_countdown = Numeric.rand(@difficulty.min_special_rock_spawn_countdown..@difficulty.max_special_rock_spawn_countdown)
    @next_down_rock_spawn_countdown = Numeric.rand(@difficulty.min_down_rock_spawn_countdown..@difficulty.max_down_rock_spawn_countdown)
    @next_shop_rock_spawn_countdown = Numeric.rand(HARD_MIN_SHOP_ROCK_SPAWN_COUNTDOWN..HARD_MAX_SHOP_ROCK_SPAWN_COUNTDOWN)
    @only_spawn_up_rocks = false
  end

  def tick(difficulty: @difficulty)
    @difficulty = difficulty
    calc
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
        @next_shop_rock_spawn_countdown = Numeric.rand(HARD_MIN_SHOP_ROCK_SPAWN_COUNTDOWN..HARD_MAX_SHOP_ROCK_SPAWN_COUNTDOWN)
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

  def calc
    if @spawn_scheduler.ready?
      selected_rock_type = select_type
      new_rock = Rocks.build(
        type: selected_rock_type,
        spawn_x: @next_rock_spawn_x,
        fall_speed: @next_rock_dy
      )
      @rocks << new_rock
      @spawn_scheduler.reset!
      reset_spawn_variables
    end

    @rocks.each do |r|
      r.y -= r.dy unless r.break_started_tick
      r.angle += r.dang if r.type == :basic && !r.break_started_tick
    end

    @rocks.reject! do |rock|
      rock.y < -32 || break_animation_complete?(rock)
    end
  end

  def collidable?(rock)
    !rock.break_started_tick
  end
end