class RockManager

  EASY_TO_MEDIUM_DIFFICULTY_DURATION = 35.seconds
  MEDIUM_TO_HARD_DIFFICULTY_DURATION = 70.seconds

  EASY_MIN_ROCK_SPAWN_DELAY = 0.16.seconds
  EASY_MAX_ROCK_SPAWN_DELAY = 0.26.seconds
  EASY_MIN_DOWN_ROCK_SPAWN_COUNTDOWN = 12
  EASY_MAX_DOWN_ROCK_SPAWN_COUNTDOWN = 16
  EASY_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN = 8
  EASY_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN = 12
  EASY_MIN_ROCK_FALL_SPEED = 5.175
  EASY_MAX_ROCK_FALL_SPEED = 6.9

  MEDIUM_MIN_ROCK_SPAWN_DELAY = 0.13.seconds
  MEDIUM_MAX_ROCK_SPAWN_DELAY = 0.24.seconds
  MEDIUM_MIN_DOWN_ROCK_SPAWN_COUNTDOWN = 7
  MEDIUM_MAX_DOWN_ROCK_SPAWN_COUNTDOWN = 10
  MEDIUM_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN = 7
  MEDIUM_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN = 10
  MEDIUM_MIN_ROCK_FALL_SPEED = 5.52
  MEDIUM_MAX_ROCK_FALL_SPEED = 7.935

  HARD_MIN_ROCK_SPAWN_DELAY = 0.10.seconds
  HARD_MAX_ROCK_SPAWN_DELAY = 0.18.seconds
  HARD_MIN_DOWN_ROCK_SPAWN_COUNTDOWN = 4
  HARD_MAX_DOWN_ROCK_SPAWN_COUNTDOWN = 7
  HARD_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN = 6
  HARD_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN = 9
  HARD_MIN_ROCK_FALL_SPEED = 8.165
  HARD_MAX_ROCK_FALL_SPEED = 9.775

  MIN_SHOP_ROCK_SPAWN_COUNTDOWN = 20
  MAX_SHOP_ROCK_SPAWN_COUNTDOWN = 40
  ROCK_BREAK_FRAME_COUNT = 5
  ROCK_BREAK_FRAME_HOLD = 3
  SPECIAL_ROCK_TYPES = [:up, :bomb, :gold]

  MIN_REPEAT_DISTANCE = 96
  ROCK_SIZE = 64
  VISUAL_GAP = 16
  SPAWN_SAFETY_HEIGHT = 128
  SPAWN_CANDIDATE_COUNT = 10
  SPAWN_HISTORY_LIMIT = 5

  MIN_RECENT_SPAWN_DISTANCE = 96
  PREFERRED_STEP_MIN = 128
  PREFERRED_STEP_MAX = 224
  MAX_FLOW_STEP = 256

  SPAWN_SAFETY_HEIGHT = 160
  HORIZONTAL_SAFETY_DISTANCE = 80
  MIN_VERTICAL_SPAWN_GAP = 80
  MAX_VERTICAL_SPAWN_GAP = 128
  TWO_ROCK_LAYER_CHANCE = 0.40
  MIN_BRANCH_HORIZONTAL_GAP = 224
  MAX_BRANCH_HORIZONTAL_GAP = 480

  FLOW_RANDOMNESS = 8.0
  TOP_CANDIDATE_COUNT = 3

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
    @spawn_history = []
    @flow_direction = nil
    @direction_streak = 0
    @rocks = []
    @next_special_rock_spawn_countdown = Numeric.rand(@difficulty.min_special_rock_spawn_countdown..@difficulty.max_special_rock_spawn_countdown)
    @next_down_rock_spawn_countdown = Numeric.rand(@difficulty.min_down_rock_spawn_countdown..@difficulty.max_down_rock_spawn_countdown)
    @next_shop_rock_spawn_countdown = Numeric.rand(MIN_SHOP_ROCK_SPAWN_COUNTDOWN..MAX_SHOP_ROCK_SPAWN_COUNTDOWN)
    @only_spawn_up_rocks = false
    @spawn_frontier_y = nil
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

  def convert_normal_and_down_to_up!
    @rocks.each do |rock|
      next unless collidable?(rock)
      next unless [:basic, :down].include?(rock.type)

      rock.type = :up
      rock.path = "sprites/rocks/up_rock.png"
    end
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

  def within_vertical_range(min_y:, max_y:, excluding: nil)
    @rocks.select do |rock|
      rock != excluding &&
        collidable?(rock) &&
        rock.y + rock.h >= min_y &&
        rock.y <= max_y
    end
  end

  def reset!
    @rocks.clear
    @spawn_history.clear
    @spawn_frontier_y = nil
    reset_spawn_variables
  end

  private

  def reset_spawn_variables
    visible_spawn_y = @spawn_y.call
    @spawn_frontier_y =
      if @spawn_frontier_y
        [
          @spawn_frontier_y + Numeric.rand(MIN_VERTICAL_SPAWN_GAP..MAX_VERTICAL_SPAWN_GAP),
          visible_spawn_y
        ].max
      else
        visible_spawn_y
      end
    @next_rock_spawn_y = @spawn_frontier_y

    @next_rock_dy = Numeric.rand(@difficulty.min_rock_fall_speed..@difficulty.max_rock_fall_speed)

    @next_rock_spawn_x = select_next_spawn_x(
      spawn_y: @next_rock_spawn_y,
      fall_speed: @next_rock_dy
    )
  end

  def select_next_spawn_x(spawn_y:, fall_speed:)
    candidates = SPAWN_CANDIDATE_COUNT.times.map { @spawn_x.call }

    safe_candidates = candidates.reject do |x|
      unsafe_near_spawn?(x, spawn_y, fall_speed)
    end

    safe_and_spaced_candidates = safe_candidates.reject do |x|
      near_recent_spawn?(x)
    end

    pool =
      if safe_and_spaced_candidates.any?
        safe_and_spaced_candidates
      elsif safe_candidates.any?
        safe_candidates
      else
        candidates
      end

    select_from_best_candidates(pool)
  end

  def select_from_best_candidates(candidates)
    scored_candidates = candidates.map do |x|
      random_variation = Numeric.rand(0.0..FLOW_RANDOMNESS)

      {
        x: x,
        score: flow_score(x) + random_variation
      }
    end

    best_candidates = scored_candidates.sort_by { |candidate| -candidate.score }.first(TOP_CANDIDATE_COUNT)

    best_candidates.sample.x
  end

  def flow_score(candidate)
    return 0 if @spawn_history.empty?


    step_distance_score(candidate) +
      direction_score(candidate) +
      lane_freshness_score(candidate) +
      edge_score(candidate)
  end

  def step_distance_score(candidate)
    last_x = @spawn_history.last.x
    distance = (candidate - last_x).abs

    case distance
    when 0...MIN_RECENT_SPAWN_DISTANCE
      -50
    when MIN_RECENT_SPAWN_DISTANCE...PREFERRED_STEP_MIN
      10
    when PREFERRED_STEP_MIN..PREFERRED_STEP_MAX
      30
    when PREFERRED_STEP_MAX..MAX_FLOW_STEP
      10
    else
      -20
    end
  end

  def direction_between(from_x, to_x)
    to_x <=> from_x
  end

  def direction_score(candidate)
    return 0 if @spawn_history.length < 2

    previous = @spawn_history[-2]
    last = @spawn_history[-1]

    previous_direction = direction_between(previous.x, last.x)
    candidate_direction = direction_between(last.x, candidate)

    return -10 if candidate_direction == 0

    if candidate_direction == previous_direction
      15
    else
      8
    end
  end

  def lane_freshness_score(candidate)
    recency_penalties = [20, 12, 6, 3]

    score = 0

    @spawn_history.reverse.each_with_index do |spawn, index|
      penalty = recency_penalties[index] || 0
      distance = (candidate - spawn.x).abs

      score -= penalty if distance < MIN_RECENT_SPAWN_DISTANCE
    end

    score
  end

  def edge_score(candidate)
    edge_region_width = 128
    last_spawn = @spawn_history.last

    near_left_edge = candidate < WorldSpawnBounds.min_x + edge_region_width
    near_right_edge = candidate > WorldSpawnBounds.max_x - edge_region_width

    return 0 unless near_left_edge || near_right_edge
    return 0 unless last_spawn

    direction = direction_between(last_spawn.x, candidate)
    moving_outward = (near_left_edge && direction < 0) || (near_right_edge && direction > 0)

    moving_outward ? -15 : 5
  end

  def near_recent_spawn?(x)
    last_spawn = @spawn_history.last
    return false unless last_spawn

    (x - last_spawn.x).abs < MIN_REPEAT_DISTANCE
  end

  def unsafe_near_spawn?(x, spawn_y, fall_speed)
    @rocks.any? do |rock|
      next false unless collidable?(rock)

      vertical_distance = (spawn_y - rock.y).abs
      horizontal_distance = (x - rock.x).abs

      vertical_distance < SPAWN_SAFETY_HEIGHT && horizontal_distance < HORIZONTAL_SAFETY_DISTANCE
    end
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

    refresh_spawn_position_if_stale
    return unless vertical_spawn_clear?(@next_rock_spawn_y)

    selected_rock_type = select_type
    primary_rock = Rocks.build(
      type: selected_rock_type,
      spawn_x: @next_rock_spawn_x,
      spawn_y: @next_rock_spawn_y,
      fall_speed: @next_rock_dy
    )
    new_rocks = [primary_rock]

    if Numeric.rand(0.0..1.0) < TWO_ROCK_LAYER_CHANCE
      companion_x = select_companion_spawn_x(primary_rock.x)
      if companion_x
        companion_type = @only_spawn_up_rocks ? :up : :basic
        new_rocks << Rocks.build(
          type: companion_type,
          spawn_x: companion_x,
          spawn_y: @next_rock_spawn_y,
          fall_speed: @next_rock_dy
        )
      end
    end

    @rocks.concat(new_rocks)

    # Keep the primary rock last so the established flow path remains the
    # anchor for the next layer; companions are alternate choices off it.
    new_rocks.reverse_each do |rock|
      @spawn_history << {
        x: rock.x,
        y: rock.y,
        dy: rock.dy
      }
    end
    @spawn_history.shift while @spawn_history.length > SPAWN_HISTORY_LIMIT

    @spawn_scheduler.reset!
    reset_spawn_variables
  end

  def select_companion_spawn_x(primary_x)
    previous_layer_x = @spawn_history.last ? @spawn_history.last.x : nil
    candidates = SPAWN_CANDIDATE_COUNT.times.map { @spawn_x.call }

    candidates.select! do |candidate_x|
      branch_gap = (candidate_x - primary_x).abs
      reachable_from_previous =
        !previous_layer_x || (candidate_x - previous_layer_x).abs <= MAX_FLOW_STEP

      branch_gap.between?(MIN_BRANCH_HORIZONTAL_GAP, MAX_BRANCH_HORIZONTAL_GAP) &&
        reachable_from_previous &&
        !unsafe_near_spawn?(candidate_x, @next_rock_spawn_y, @next_rock_dy)
    end

    candidates.sample
  end

  def refresh_spawn_position_if_stale
    minimum_spawn_y = @spawn_y.call
    return if @next_rock_spawn_y >= minimum_spawn_y

    @spawn_frontier_y = minimum_spawn_y
    @next_rock_spawn_y = minimum_spawn_y
    @next_rock_spawn_x = select_next_spawn_x(
      spawn_y: @next_rock_spawn_y,
      fall_speed: @next_rock_dy
    )
  end

  def vertical_spawn_clear?(spawn_y)
    @rocks.none? do |rock|
      collidable?(rock) && (spawn_y - rock.y).abs < MIN_VERTICAL_SPAWN_GAP
    end
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
