class Game
  include WorldSpawnBounds
  attr_dr

  FONT = "fonts/carterone.ttf"

  DIFFICULTY_RAMP_DURATION = 105.seconds
  EASY_TO_MEDIUM_DIFFICULTY_DURATION = 35.seconds
  MEDIUM_TO_HARD_DIFFICULTY_DURATION = 70.seconds

  EASY_MIN_ROCK_SPAWN_DELAY = 0.22.seconds
  EASY_MAX_ROCK_SPAWN_DELAY = 0.42.seconds
  EASY_MIN_DOWN_ROCK_SPAWN_COUNTDOWN = 12
  EASY_MAX_DOWN_ROCK_SPAWN_COUNTDOWN = 16
  EASY_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN = 8
  EASY_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN = 12
  EASY_MIN_SHOP_ROCK_SPAWN_COUNTDOWN = 14
  EASY_MAX_SHOP_ROCK_SPAWN_COUNTDOWN = 18
  EASY_MIN_ROCK_FALL_SPEED = 3.8
  EASY_MAX_ROCK_FALL_SPEED = 5.3

  MEDIUM_MIN_ROCK_SPAWN_DELAY = 0.18.seconds
  MEDIUM_MAX_ROCK_SPAWN_DELAY = 0.34.seconds
  MEDIUM_MIN_DOWN_ROCK_SPAWN_COUNTDOWN = 7
  MEDIUM_MAX_DOWN_ROCK_SPAWN_COUNTDOWN = 10
  MEDIUM_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN = 7
  MEDIUM_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN = 10
  MEDIUM_MIN_SHOP_ROCK_SPAWN_COUNTDOWN = 18
  MEDIUM_MAX_SHOP_ROCK_SPAWN_COUNTDOWN = 20
  MEDIUM_MIN_ROCK_FALL_SPEED = 4.6
  MEDIUM_MAX_ROCK_FALL_SPEED = 6.2

  HARD_MIN_ROCK_SPAWN_DELAY = 0.14.seconds
  HARD_MAX_ROCK_SPAWN_DELAY = 0.26.seconds
  HARD_MIN_DOWN_ROCK_SPAWN_COUNTDOWN = 4
  HARD_MAX_DOWN_ROCK_SPAWN_COUNTDOWN = 7
  HARD_MIN_SPECIAL_ROCK_SPAWN_COUNTDOWN = 6
  HARD_MAX_SPECIAL_ROCK_SPAWN_COUNTDOWN = 9
  HARD_MIN_SHOP_ROCK_SPAWN_COUNTDOWN = 20
  HARD_MAX_SHOP_ROCK_SPAWN_COUNTDOWN = 40
  HARD_MIN_ROCK_FALL_SPEED = 5.2
  HARD_MAX_ROCK_FALL_SPEED = 7.2

  COMBO_RESET_DURATION = 2.0.seconds
  COMBO_PARTICLE_DURATION = 1.0.seconds
  COMBO_PARTICLE_FLOAT_DISTANCE = 64
  BOMB_ROCK_EXPLOSION_RADIUS = 1280.0

  def initialize(args)
  end

  def start
    state.input_active = true
    state.run_started_tick = nil
    state.run_ended_tick = nil
    state.longest_run_time = DR.read_file("data/save.txt").to_f || 0.0
    state.paused_tick = nil
    state.total_time_paused = 0.0
    state.shop_open_tick = nil
    state.shop_close_tick = nil
    state.shop_alpha = 0
    @player = Player.new
    @player.args = args
    state.gold_modifier = 1.0
    state.shop_leave_button_color = {
      r: 20,
      g: 20,
      b: 20,
    }

    @camera = Camera.new(
      x: 640.0,
      y: 360.0,
      screen_x: 640,
      screen_y: 360,
    )

    # difficulty = calc_current_difficulty_levers
    @rock_manager = RockManager.new(difficulty: calc_current_difficulty_levers, spawn_x: -> { WorldSpawnBounds.random_x })

    @powerup_manager = PowerupManager.new(
      spawn_x: -> { WorldSpawnBounds.random_x },
      spawn_y: -> { Grid.h },
      expired: -> (powerup) { powerup.y <= -powerup.h }
    )

    @gold_manager = GoldManager.new(
      spawn_x: -> { WorldSpawnBounds.random_x },
      spawn_y: -> { Grid.h },
      expired: -> (gold) { gold.y < -16 }
    )

    state.shop_items = []
    state.combo_manager = {
      grapple_count: 0,
      last_grapple_active_tick: nil,
      particles: [],
    }
  end

  def tick
    input
    calc
    render
  end

  def input
    return unless state.input_active

    state.move_direction_x = 0
    state.move_direction_y = 0

    state.move_direction_x -= 1 if inputs.keyboard.left
    state.move_direction_x += 1 if inputs.keyboard.right
    state.move_direction_y -= 1 if inputs.keyboard.down
    state.move_direction_y += 1 if inputs.keyboard.up && @player.carried_by_eagle
    state.hook_input_pressed = inputs.keyboard.key_down.space
    state.hook_input_released = inputs.keyboard.key_up.space

    return if state.run_started_tick
    state.run_started_tick = Kernel.tick_count if state.move_direction_x != 0 || state.move_direction_y != 0 || state.hook_input_pressed
  end

  def calc
    unless state.paused_tick
      calc_longest_run_time if state.run_started_tick
      if state.run_started_tick
        grappled_rock = @player.tick

        if @player.dead?
          calc_end_game
        elsif grappled_rock
          handle_rock_effect(grappled_rock)
          enable_input
        end
      end
      @powerup_manager.tick
      @rock_manager.tick(difficulty: calc_current_difficulty_levers)
      @gold_manager.tick(
        attraction_target: @player,
        attraction_active: !!state.run_started_tick
      )
      calc_active_powerup_effects
      calc_combo
      @camera.tick
      calc_collisions if state.run_started_tick
    else
      outputs.watch "PAUSED"
      state.total_time_paused = state.paused_tick.elapsed_time
      calc_shop if state.shop_open_tick
    end
  end

  def render
    outputs.background_color = [0, 0, 0]
    render_world
    render_ui
  end

  def render_world
    @player.primitives.each do |primitive|
      outputs.sprites << @camera.transform_rect(primitive)
    end
    @rock_manager.primitives.each do |primitive|
      outputs.sprites << @camera.transform_rect(primitive)
    end

    @gold_manager.primitives.each do |primitive|
      outputs.sprites << @camera.transform_rect(primitive)
    end

    @powerup_manager.primitives.each do |primitive|
      outputs.sprites << @camera.transform_rect(primitive)
    end

    render_combo_particles
  end

  def render_ui
    outputs.labels << start_instructions_label unless state.run_started_tick
    outputs.labels << [run_timer_label, longest_run_time_label, gold_label]
    render_combo_ui
    render_powerup_ui
    render_shop if state.shop_open_tick && state.shop_alpha > 0
  end

  def render_combo_particles
    state.combo_manager.particles.each do |p|
      outputs.labels << camera_transform_combo_particle(p)
    end
  end

  def render_combo_ui
    return unless combo_timer_active?

    outputs.solids << combo_timer_backdrop_rect
    outputs.solids << combo_timer_fill_rect
    outputs.labels << combo_count_label if combo_active?
  end

  def render_powerup_ui
    finite_powerups = @player.finite_powerups
    return if finite_powerups.empty?

    finite_powerups.each_with_index do |p, i|
      time_left_ticks = remaining_powerup_time(p)
      start_y = Grid.h - 96
      spacing = 32
      outputs.labels << powerup_timer_label(time_left: time_left_ticks, y: start_y - (spacing * i), display_name: p.name)
    end



  end

  def remaining_powerup_time(p)
    p.duration - p.start_tick.elapsed_time
  end



  def enable_input
    state.input_active = true
  end

  def disable_input
    state.input_active = false
    state.move_direction_x = 0
    state.move_direction_y = 0
  end

  def camera_transform_combo_particle(particle)
    elapsed = active_tick_count - particle.started_active_tick
    progress = elapsed.fdiv(COMBO_PARTICLE_DURATION).clamp(0, 1)
    screen_position = @camera.world_to_screen(
      x: particle.x,
      y: particle.y + COMBO_PARTICLE_FLOAT_DISTANCE
    )

    {
      x: screen_position.x,
      y: screen_position.y,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 64,
      font: FONT,
      text: particle.text,
      r: 255,
      g: 245,
      b: 120,
      a: 255.lerp(0, progress),
    }
  end

  def calc_combo
    if combo_timer_active? && combo_elapsed_since_last_grapple > COMBO_RESET_DURATION
      state.combo_manager.grapple_count = 0
      state.combo_manager.last_grapple_active_tick = nil
    end

    state.combo_manager.particles.reject! do |p|
      active_tick_count - p.started_active_tick >= COMBO_PARTICLE_DURATION
    end
  end

  def combo_active?
    state.combo_manager.grapple_count >= 2 && state.combo_manager.last_grapple_active_tick
  end

  def combo_timer_active?
    state.combo_manager.grapple_count > 0 && state.combo_manager.last_grapple_active_tick
  end

  def register_combo_grapple
    if combo_timer_active? && combo_elapsed_since_last_grapple <= COMBO_RESET_DURATION
      state.combo_manager.grapple_count += 1
    else
      state.combo_manager.grapple_count = 1
    end

    state.combo_manager.last_grapple_active_tick = active_tick_count
    state.combo_manager.particles << combo_particle(number: state.combo_manager.grapple_count) if combo_active?
  end

  def combo_particle(number:)
    {
      x: @player.x + (@player.w / 2),
      y: @player.y + @player.h + 12,
      text: "#{number}x",
      started_active_tick: active_tick_count,
    }
  end

  def active_tick_count
    Kernel.tick_count - state.total_time_paused
  end

  def combo_elapsed_since_last_grapple
    active_tick_count - state.combo_manager.last_grapple_active_tick
  end

  def calc_shop
    if !state.shop_close_tick && state.shop_alpha < 255
      ease_percentage = Easing.smooth_stop(start_at: state.shop_open_tick,
                                duration: 0.5.seconds,
                                tick_count: Kernel.tick_count,
                                power: 1)
      state.shop_alpha = state.shop_alpha.lerp(255, ease_percentage)
    elsif state.shop_close_tick && state.shop_close_tick.elapsed_time < 0.5.seconds
      ease_percentage = Easing.smooth_stop(start_at: state.shop_close_tick,
                                duration: 0.5.seconds,
                                tick_count: Kernel.tick_count,
                                power: 1)
      state.shop_alpha = state.shop_alpha.lerp(0, ease_percentage)
    elsif state.shop_close_tick && state.shop_close_tick.elapsed_time >= 0.5.seconds
      state.shop_open_tick = nil
      state.shop_close_tick = nil
      state.paused_tick = nil
    end

    return if state.shop_close_tick
    state.shop_items.each do |b|
      if inputs.mouse.intersect_rect?(b)
        b.g = 200
        b.b = 200

        if inputs.mouse.click && @player.gold >= b.price
          @player.gold -= b.price
          @player.add_powerup(powerup_type: b.item_id)
          state.shop_close_tick = Kernel.tick_count
        end

      else
        b.g = 20
        b.b = 20
      end
    end

    if inputs.mouse.intersect_rect?(shop_leave_button_rect)
      state.shop_leave_button_color.g = 200
      state.shop_leave_button_color.b = 200

      if inputs.mouse.click
        state.shop_close_tick = Kernel.tick_count
      end

    else
      state.shop_leave_button_color.g = 20
      state.shop_leave_button_color.b = 20
    end
  end

  def render_shop
    outputs.labels << {
      x: Grid.w / 2,
      y: Grid.h - 128,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 64,
      font: FONT,
      text: "The Rock Shoppe",
      r: 220,
      g: 220,
      b: 220,
      a: state.shop_alpha
    }

    state.shop_items.each do |si|
      outputs.solids << {
        x: si.x,
        y: si.y,
        w: si.w,
        h: si.h,
        r: si.r,
        g: si.g,
        b: si.b,
        a: [state.shop_alpha, 190].min,
      }
      outputs.labels << {
        x: si.x + (si.w / 2),
        y: si.y + (si.w / 2) + 32,
        anchor_x: 0.5,
        anchor_y: 0.5,
        size_px: 32,
        font: FONT,
        r: 220,
        g: 220,
        b: 220,
        a: state.shop_alpha,
        text: "#{si.display_name}"
      }
      outputs.labels << {
        x: si.x + (si.w / 2),
        y: si.y + (si.w / 2) - 32,
        anchor_x: 0.5,
        anchor_y: 0.5,
        size_px: 32,
        font: FONT,
        r: 220,
        g: 220,
        b: 220,
        a: state.shop_alpha,
        text: "#{si.price}"
      }
    end

    outputs.solids << shop_leave_button_rect
    outputs.labels << {
      x: (Grid.w / 2) - 28,
      y: (Grid.h / 2) - 196 - 16,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 24,
      font: FONT,
      r: 220,
      g: 220,
      b: 220,
      a: state.shop_alpha,
      text: "Exit the Shoppe"
    }
  end

  def shop_leave_button_rect
    {
        x: (Grid.w / 2) - 128 - 28,
        y: (Grid.h / 2) - 256,
        w: 256,
        h: 96,
        r: state.shop_leave_button_color.r,
        g: state.shop_leave_button_color.g,
        b: state.shop_leave_button_color.b,
        a: [state.shop_alpha, 190].min,
    }
  end

  def shop_item(item_id:, price:, display_name:, x:, y:)
    {
      x: x,
      y: y,
      w: 256,
      h: 256,
      r: 20,
      g: 20,
      b: 20,
      item_id: item_id,
      display_name: display_name,
      price: price,
    }
  end

  def calc_longest_run_time
    ticks_factoring_pause_elapsed = state.run_started_tick.elapsed_time - state.total_time_paused
    return if (ticks_factoring_pause_elapsed / 60).round(1) <= state.longest_run_time
    elapsed_seconds = ticks_factoring_pause_elapsed / 60
    state.longest_run_time = elapsed_seconds.round(1)
  end

  def calc_collisions
    @player.x = 0 if @player.x <= 0
    @player.x = Grid.w - @player.w if @player.x >= Grid.w - @player.w
    @player.y = Grid.h if @player.y <= (0 - @player.h)

    collected_gold = @gold_manager.collect_intersecting(@player)
    @player.gold += collected_gold.count * state.gold_modifier

    collected_powerups = @powerup_manager.collect_intersecting(@player)
    collected_powerups.each do |powerup|
      @player.add_powerup(powerup_type: powerup.type)
    end

    if @player.carried_by_eagle
      @rock_manager.intersecting_rocks(@player).each { |rock| handle_rock_effect(rock) }
    end

    # everything below this handles hook collisions if the hitbox for it is active
    return unless @player.hook.active?

    rocks_hit = @rock_manager.intersecting_rocks(@player.hook)

    previous_tick_hit_target = @player.hook.hit_target
    hit_target = find_first_rock_hit(rocks_hit, direction: @player.hook.direction, origin: @player)

    if hit_target && !previous_tick_hit_target
      disable_input
      @player.start_grapple(hit_target)

      @camera.zoom_to(
        target: 1.05,
        zoom_in_duration: @player.grapple_duration,
        zoom_out_duration: 20
        )
    end
  end

  def calc_active_powerup_effects
    expired_powerups = []

    @player.powerups.each do |p|
      unless p.active
        p.active = true

        case p.type
        when :wide_hook
          @player.hook.widen!
        when :up_rock
          @rock_manager.only_spawn_up_rocks!
        when :gold_rush
          state.gold_modifier = 2.0
        when :eagle
          @player.carried_by_eagle = true
        end

        next
      end

      next unless remaining_powerup_time(p) <= 0

      case p.type
      when :wide_hook
        @player.hook.reset_size!
      when :up_rock
        @rock_manager.restore_normal_spawning!
      when :gold_rush
        state.gold_modifier = 1.0
      when :eagle
        @player.carried_by_eagle = false
      end

      expired_powerups << p
    end

    @player.powerups.reject! do |powerup|
      expired_powerups.include?(powerup)
    end
  end

  def handle_rock_effect(target_rock)
    return if target_rock.break_started_tick

    case target_rock.type
    when :basic
      @player.jump!
      @camera.shake(strength: 12, duration: 30)
    when :bomb
      @player.jump!
      @camera.shake(strength: 30, duration: 120)

      nearby_rocks = @rock_manager.within_radius(
        target_rock: target_rock,
        radius: BOMB_ROCK_EXPLOSION_RADIUS
      )

      nearby_rocks.each { |rock| @rock_manager.break(rock) }
    when :down
      @player.knock_down!
      @camera.shake(strength: 50, duration: 20)
    when :up
      @player.boosted_jump!
      @camera.shake(strength: 50, duration: 20)
    when :shop
      open_shop
      @player.jump!
      @camera.shake(strength: 12, duration: 30)
    when :gold
      @player.jump!
      @camera.shake(strength: 12, duration: 30)
      @player.gold += 5 * state.gold_modifier
    when :default
      @player.jump!
      @camera.shake(strength: 12, duration: 30)
    end
    @player.start_jump_animation
    register_combo_grapple
    @rock_manager.break(target_rock)
  end

  def find_first_rock_hit(rocks, direction:, origin:)
    return nil if rocks.empty?

    if direction > 0
      origin_edge_x = origin.x + origin.w
      rocks.min_by { |rock| rock.x - origin_edge_x }
    elsif direction < 0
      origin_edge_x = origin.x
      rocks.min_by { |rock| origin_edge_x - (rock.x + rock.w)}
    end
  end

  def open_shop
    state.paused_tick = Kernel.tick_count
    state.shop_open_tick = Kernel.tick_count
    state.shop_items.clear
    padding = 64
    item_option_width = 256
    start_x = (Grid.w / 2) - (item_option_width) - padding
    2.times.each do |i|
      powerup_type = Powerups::TYPES.sample
      new_item_option = Powerups.build(type: powerup_type)
      state.shop_items << shop_item(item_id: new_item_option.type, price: Numeric.rand(25..100), display_name: new_item_option.name, x: start_x + ((item_option_width + padding) * i), y: (Grid.h / 2) - (256 / 2))
    end
  end

  def calc_current_difficulty_levers
    if state.run_started_tick
      elapsed = state.run_started_tick.elapsed_time
    else
      elapsed = 0.0
    end

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

  def calc_end_game
    enable_input
    state.run_started_tick = nil
    state.total_time_paused = 0
    state.run_ended_tick = Kernel.tick_count
    @player = Player.new
    @player.args = args
    state.gold_modifier = 1.0
    @rock_manager.restore_normal_spawning!
    reset_combo
  end

  def reset_combo
    state.combo_manager.grapple_count = 0
    state.combo_manager.last_grapple_active_tick = nil
    state.combo_manager.particles.clear
  end

  def shutdown
    DR.write_file "data/save.txt", "#{state.longest_run_time}" if state.longest_run_time
  end

  def start_instructions_label
    {
      x: Grid.w / 2,
      y: Grid.h / 2,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 96,
      font: FONT,
      text: "Press A or D to Play",
      r: 95,
      g: 15,
      b: 185,
    }
  end

  def run_timer_label
    ticks_factoring_pause_elapsed = (state.run_started_tick ? state.run_started_tick.elapsed_time : 0) - state.total_time_paused
    ticks_elapsed = ticks_factoring_pause_elapsed
    timer_value_seconds = ticks_elapsed / 60

    {
      x: Grid.w / 2,
      y: Grid.h - 32,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 64,
      font: FONT,
      text: "Time: #{timer_value_seconds.round(1)}",
      r: 95,
      g: 15,
      b: 185,
    }
  end

  def longest_run_time_label
      {
      x: 96,
      y: Grid.h - 32,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 32,
      font: FONT,
      text: "Best Time: #{state.longest_run_time}",
      r: 95,
      g: 15,
      b: 185,
    }
  end

  def gold_label
      {
      x: Grid.w - 32 - 32,
      y: Grid.h - 32,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 32,
      font: FONT,
      text: "Gold: #{@player.gold.round(0)}",
      r: 95,
      g: 15,
      b: 185,
    }
  end

  def powerup_timer_label(time_left:, y:, display_name:)
    {
      x: Grid.w / 2,
      y: y,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 32,
      font: FONT,
      text: "#{display_name} - #{(time_left / 60).round(1)}",
      r: 140,
      g: 255,
      b: 250,
    }
  end

  def combo_reset_time_remaining
    return 0 unless combo_timer_active?

    (COMBO_RESET_DURATION - combo_elapsed_since_last_grapple).clamp(0, COMBO_RESET_DURATION)
  end

  def combo_reset_progress
    combo_reset_time_remaining.fdiv(COMBO_RESET_DURATION).clamp(0, 1)
  end

  def combo_timer_backdrop_rect
    {
      x: (Grid.w / 2) - 80,
      y: Grid.h - 78,
      w: 160,
      h: 10,
      r: 95,
      g: 15,
      b: 185,
      a: 100,
    }
  end

  def combo_timer_fill_rect
    combo_timer_backdrop_rect.merge(
      w: 160 * combo_reset_progress,
      r: 95,
      g: 15,
      b: 185,
      a: 220,
    )
  end

  def combo_count_label
    {
      x: Grid.w / 2,
      y: Grid.h - 96,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 24,
      font: FONT,
      text: "Combo #{state.combo_manager.grapple_count}",
      r: 95,
      g: 15,
      b: 185,
      a: 255,
    }
  end

end