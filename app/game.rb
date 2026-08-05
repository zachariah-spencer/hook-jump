class Game
  include WorldSpawnBounds
  attr_dr



  COMBO_RESET_DURATION = 2.0.seconds
  COMBO_PARTICLE_DURATION = 1.0.seconds
  COMBO_PARTICLE_FLOAT_DISTANCE = 64
  BOMB_ROCK_CLEARANCE_ABOVE_SCREEN = 256
  SCREEN_BORDER_SPAWN_PADDING = 128
  PIXELS_PER_METER = 32.0
  LAVA_INTRO_DURATION = 2.0.seconds
  CAMERA_INTRO_DURATION = 1.25.seconds
  PLAYER_LAVA_START_BUFFER = 1250
  DEATH_SEQUENCE_DURATION = 1.75.seconds


  def initialize(args)
  end

  def start
    state.input_active = true
    state.run_phase = :pre_game
    state.run_intro_started_tick = nil
    state.run_started_tick = nil
    state.death_sequence_ended_tick = nil
    state.run_ended_tick = nil
    state.longest_run_time = DR.read_file("data/save.txt").to_f || 0.0
    state.paused_tick = nil
    state.total_time_paused = 0.0
    state.shop_open_tick = nil
    state.shop_close_tick = nil
    state.shop_alpha = 0
    state.gold_modifier = 1.0
    state.shop_leave_button_hovered = false
    state.shop_leave_button_clicked = false

    @background_rock_field = BackgroundRockField.new

    @player = Player.new
    @player.args = args

    @run_start_y = @player.y
    player_center_y = @player.y + (@player.h / 2.0)
    @highest_player_y = player_center_y

    @camera = Camera.new(
      x: 640.0,
      y: 360.0,
      screen_x: 640,
      screen_y: 360,
      viewport_w: Grid.w,
      viewport_h: Grid.h
    )

    @lava = Lava.new(
      surface_y: 200,
      start_speed: 0.9,
      max_speed: 3.45,
      ramp_duration: 200
    )

    @altitude_gauge = AltitudeGauge.new(
      x: 60,
      y: 100,
      w: 24,
      h: 400,
      displayed_gap_meters: 500.0
    )


    @rock_manager = RockManager.new(
        spawn_x: -> { WorldSpawnBounds.random_x },
        spawn_y: -> {
          visible = @camera.visible_world_rect
          visible.y + visible.h + 160
        },
        expired: -> (rock) {
          visible = @camera.visible_world_rect
          rock.y + rock.h < visible.y - SCREEN_BORDER_SPAWN_PADDING
        }
      )

    @powerup_manager = PowerupManager.new(
      spawn_x: -> { WorldSpawnBounds.random_x },
      spawn_y: -> {
        visible = @camera.visible_world_rect
        visible.y + visible.h + 64
      },
      expired: -> (powerup) {
        visible = @camera.visible_world_rect
        powerup.y + powerup.h < visible.y - SCREEN_BORDER_SPAWN_PADDING
      }
    )

    @gold_manager = GoldManager.new(
      spawn_x: -> { WorldSpawnBounds.random_x },
      spawn_y: -> {
        visible = @camera.visible_world_rect
        visible.y + visible.h + 64
      },
      expired: -> (gold) {
        visible = @camera.visible_world_rect
        gold.y + gold.h < visible.y - SCREEN_BORDER_SPAWN_PADDING
       }
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
    state.start_pressed = state.move_direction_x != 0 || state.move_direction_y != 0 || state.hook_input_pressed
  end

  def calc

    @background_rock_field.tick(view: @camera.visible_world_rect)
    calc_lava_audio

    case state.run_phase
    when :pre_game
      calc_pre_game
    when :lava_intro
      calc_lava_intro
    when :camera_intro
      calc_camera_intro
    when :active
      calc_active_run
    when :death_sequence
      calc_death_sequence
    end
  end

  def calc_pre_game
    audio.delete(:run_music) if audio.include?(:run_music)
    audio[:pre_game_music] ||= { input: Sounds::PRE_GAME_MUSIC, looping: true, gain: 0.1 }
    audio[:wind] ||= {
      input: Sounds::WIND_AMBIENCE,
      looping: true,
      gain: 0.35
    }

    if state.start_pressed
      state.run_phase = :lava_intro
      state.run_intro_started_tick = Kernel.tick_count
      audio[:lava_rise] = { input: Sounds::LAVA_RISE, gain: 0.5 }
    end
  end

  def calc_lava_intro
    audio.delete(:pre_game_music)
    audio[:run_music] ||= { input: Sounds::RUN_MUSIC, looping: true, gain: 0.08 }
    @camera.tick
    elapsed = state.run_intro_started_tick.elapsed_time

    @camera.shake(strength: 15.0, duration: LAVA_INTRO_DURATION)
    @lava.tick(elapsed: elapsed)

    return if elapsed < LAVA_INTRO_DURATION

    prepare_camera_intro
  end

  def prepare_camera_intro
    player_danger_offset = @player.h * 0.4

    @player.y = @lava.surface_y + PLAYER_LAVA_START_BUFFER - player_danger_offset
    @player.dx = 0
    @player.dy = 0

    @run_start_y = @player.y
    @highest_player_y = @player.y + (@player.h / 2.0)

    target_camera_y = @player.y + (@player.h / 2.0)
    @camera.move_vertical_to(y: target_camera_y, duration: CAMERA_INTRO_DURATION)

    state.run_phase = :camera_intro
  end

  def calc_camera_intro
    @camera.tick
    @rock_manager.tick(elapsed: 0)

    start_active_run unless @camera.moving?
  end

  def start_active_run
    state.run_phase = :active
    state.run_started_tick = Kernel.tick_count

    state.move_direction_x = 0
    state.move_direction_y = 0
    state.hook_input_pressed = false
    state.hook_input_released = false
  end

  def calc_active_run
    unless state.paused_tick
      elapsed_run_time =
        if state.run_started_tick
          state.run_started_tick.elapsed_time - state.total_time_paused
        else
          0
        end

      calc_longest_run_time if state.run_started_tick
      if state.run_started_tick
        grappled_rock = @player.tick
        @lava.tick(elapsed: elapsed_run_time)

        player_center_y = @player.y + (@player.h / 2.0)
        @highest_player_y = [@highest_player_y, player_center_y].max

        if @player.dead? || @lava.intersect_rect?(@player)
          prepare_death_sequence
        elsif grappled_rock
          audio[:rock_break] = {
              input: Sounds::ROCK_BREAK,
              gain: 0.85,
            }
          handle_rock_effect(grappled_rock)
          enable_input
        end
      end
      @powerup_manager.tick



      @rock_manager.tick(elapsed: elapsed_run_time)
      @gold_manager.tick(
        attraction_target: @player,
        attraction_active: !!state.run_started_tick
      )
      calc_active_powerup_effects
      calc_combo
      @camera.follow_vertical(target: @player, lower_threshold: 0.18, upper_threshold: 0.6, min_y: Grid.h / 2) if state.run_started_tick
      @camera.tick
      calc_collisions if state.run_started_tick
    else
      outputs.watch "PAUSED"
      state.total_time_paused = state.paused_tick.elapsed_time
      calc_shop if state.shop_open_tick
    end
  end

  def prepare_death_sequence
    audio[:game_over] = {
      input: Sounds::GAME_OVER,
      gain: 0.6,
      pitch: 1.25
    }

    disable_input
    @player.carried_by_eagle = false
    state.run_ended_tick = Kernel.tick_count
    state.run_phase = :death_sequence
  end

  def calc_death_sequence
    if state.run_ended_tick.elapsed_time <= DEATH_SEQUENCE_DURATION
      @player.play_death_animation
      @player.tick
    else
      calc_end_game
    end
  end

  def render
    outputs.background_color = [0, 0, 0]
    render_world
    render_ui
  end

  def calc_lava_audio
    view = @camera.visible_world_rect
    lava_surface_visible = @lava.surface_y >= view.y && @lava.surface_y <= view.y + view.h

    if lava_surface_visible
      audio[:lava_bubbling] ||= {
        input: Sounds::LAVA_BUBBLING_AMBIENCE,
        looping: true,
        gain: 0.4
      }
    else
      audio.delete(:lava_bubbling)
    end
  end

  def render_world

    @background_rock_field.primitives(view: @camera.visible_world_rect).each do |primitive|
      outputs.sprites << @camera.transform_rect(primitive)
    end

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

    @lava.primitives(view: @camera.visible_world_rect).each do |primitive|
      outputs.primitives << @camera.transform_rect(primitive).merge({primitive_marker: :solid})
    end

    render_combo_particles
  end

  def render_ui
    outputs.labels << start_instructions_label if state.run_phase == :pre_game
    render_combo_ui
    render_powerup_ui

    if state.run_phase == :active
      outputs.labels << [run_timer_label, longest_run_time_label, gold_label]

      outputs.primitives << @altitude_gauge.primitives(
        height_meters: altitude_measurements.height_meters,
        current_height_meters: altitude_measurements.current_height_meters,
        lava_gap_meters: altitude_measurements.lava_gap_meters
      )
    elsif state.run_phase == :death_sequence
      game_over_fade_time = state.run_ended_tick.elapsed_time
      game_over_progress = (game_over_fade_time / 0.25.seconds).clamp(0, 1)
      game_over_alpha = (255 * game_over_progress).round
      outputs.labels << game_over_label(a: game_over_alpha)
    end

    render_shop if state.shop_open_tick && state.shop_alpha > 0
  end

  def render_combo_particles
    state.combo_manager.particles.each do |p|
      outputs.labels << camera_transform_combo_particle(p)
    end
  end

  def render_combo_ui
    return unless combo_timer_active?

    outputs.primitives << combo_timer_backdrop_rect
    outputs.primitives << combo_timer_fill_rect
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
      y: particle.y + (COMBO_PARTICLE_FLOAT_DISTANCE * progress)
    )

    {
      x: screen_position.x,
      y: screen_position.y,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 64,
      font: Styles::FONT,
      text: particle.text,
      r: 230,
      g: 171,
      b: 255,
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
      font: Styles::FONT,
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

    state.shop_items.each { |item| item.clicked = false }
    state.shop_leave_button_clicked = false
    return if state.shop_close_tick

    state.shop_items.each do |b|
      was_hovered = b.hovered
      b.hovered = inputs.mouse.intersect_rect?(b)
      play_shop_rollover_sound if b.hovered != was_hovered
      b.clicked = b.hovered && !!inputs.mouse.click
      if b.hovered

        if b.clicked && @player.gold >= b.price
          play_shop_press_sound
          @player.gold -= b.price
          @player.add_powerup(powerup_type: b.item_id)
          state.shop_close_tick = Kernel.tick_count
        elsif b.clicked
          play_shop_press_sound
        end
      end
    end

    leave_button_was_hovered = state.shop_leave_button_hovered
    state.shop_leave_button_hovered = inputs.mouse.intersect_rect?(shop_leave_button_rect)
    play_shop_rollover_sound if state.shop_leave_button_hovered != leave_button_was_hovered
    state.shop_leave_button_clicked = state.shop_leave_button_hovered && !!inputs.mouse.click
    if state.shop_leave_button_hovered
      if state.shop_leave_button_clicked
        play_shop_press_sound
        state.shop_close_tick = Kernel.tick_count
      end
    end
  end

  def play_shop_rollover_sound
    audio[:shop_ui_rollover] = {
      input: Sounds::UI_ROLLOVER,
      gain: 0.7
    }
  end

  def play_shop_press_sound
    audio[:shop_ui_press] = {
      input: Sounds::UI_PRESS,
      gain: 1.0
    }
  end

  def render_shop
    outputs.labels << {
      x: Grid.w / 2,
      y: Grid.h - 128,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 64,
      font: Styles::FONT,
      text: "The Rock Shoppe",
      r: 220,
      g: 220,
      b: 220,
      a: state.shop_alpha
    }

    state.shop_items.each do |si|
      outputs.sprites << {
        x: si.x,
        y: si.y,
        w: si.w,
        h: si.h,
        path: si.clicked ? "sprites/ui/button_square_line.png" : "sprites/ui/button_square_depth_line.png",
        r: si.hovered ? 220 : 255,
        g: si.hovered ? 220 : 255,
        b: si.hovered ? 220 : 255,
        a: state.shop_alpha
      }
      outputs.labels << {
        x: si.x + (si.w / 2),
        y: si.y + (si.w / 2) + 32,
        anchor_x: 0.5,
        anchor_y: 0.5,
        size_px: 32,
        font: Styles::FONT,
        r: 55,
        g: 55,
        b: 65,
        a: state.shop_alpha,
        text: "#{si.display_name}"
      }
      outputs.labels << {
        x: si.x + (si.w / 2),
        y: si.y + (si.w / 2) - 32,
        anchor_x: 0.5,
        anchor_y: 0.5,
        size_px: 32,
        font: Styles::FONT,
        r: 130,
        g: 95,
        b: 20,
        a: state.shop_alpha,
        text: "#{si.price}"
      }
    end

    outputs.sprites << shop_leave_button_sprite
    outputs.labels << {
      x: Grid.w / 2,
      y: shop_leave_button_rect.y + (shop_leave_button_rect.h / 2),
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 24,
      font: Styles::FONT,
      r: 55,
      g: 55,
      b: 65,
      a: state.shop_alpha,
      text: "Exit the Shoppe"
    }
  end

  def shop_leave_button_rect
    {
      x: (Grid.w / 2) - 192,
      y: 64,
      w: 384,
      h: 128
    }
  end

  def shop_leave_button_sprite
    shop_leave_button_rect.merge(
      path: state.shop_leave_button_clicked ? "sprites/ui/button_rectangle_line.png" : "sprites/ui/button_rectangle_depth_line.png",
      r: state.shop_leave_button_hovered ? 220 : 255,
      g: state.shop_leave_button_hovered ? 220 : 255,
      b: state.shop_leave_button_hovered ? 220 : 255,
      a: state.shop_alpha
    )
  end

  def shop_item(item_id:, price:, display_name:, x:, y:)
    {
      x: x,
      y: y,
      w: 256,
      h: 256,
      hovered: false,
      clicked: false,
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
    audio[:gold] = {
      input: Sounds::PICKUP_GOLD,
      gain: 0.25
    } unless collected_gold.empty?
    @player.gold += collected_gold.count * state.gold_modifier

    collected_powerups = @powerup_manager.collect_intersecting(@player)
    audio[:pickup_powerup] = {
      input: Sounds::PICKUP_POWERUP,
      gain: 0.35
    } unless collected_powerups.empty?
    collected_powerups.each do |powerup|
      @player.add_powerup(powerup_type: powerup.type)
    end

    player_rock_collisions = @rock_manager.intersecting_rocks(@player)
    if @player.carried_by_eagle
      player_rock_collisions.each { |rock| handle_rock_effect(rock) }
    elsif !player_rock_collisions.empty? && @player.can_be_hit_by_rock?
      @player.hit_by_rock!
      @rock_manager.break(player_rock_collisions.first)
      audio[:rock_break] = {
        input: Sounds::ROCK_BREAK,
        gain: 0.85,
      }
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
        target: 0.9,
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
          @rock_manager.convert_normal_and_down_to_up!
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
      audio[:rock_explodes] = {
        input: Sounds::ROCK_EXPLODES,
        gain: 0.75
      }
      @player.jump!
      @camera.shake(strength: 30, duration: 120)

      visible = @camera.visible_world_rect
      nearby_rocks = @rock_manager.within_vertical_range(
        min_y: visible.y,
        max_y: visible.y + visible.h + BOMB_ROCK_CLEARANCE_ABOVE_SCREEN,
        excluding: target_rock
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
      #TODO: Add gold rush sfx
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
    state.shop_leave_button_hovered = false
    state.shop_leave_button_clicked = false
    padding = 64
    item_option_width = 256
    start_x = (Grid.w / 2) - (item_option_width) - padding
    2.times.each do |i|
      powerup_type = Powerups::TYPES.sample
      new_item_option = Powerups.build(type: powerup_type)
      state.shop_items << shop_item(item_id: new_item_option.type, price: Numeric.rand(15..50), display_name: new_item_option.name, x: start_x + ((item_option_width + padding) * i), y: (Grid.h / 2) - (256 / 2))
    end
  end

  def calc_end_game
    enable_input

    @camera.move_to(
      x: Grid.w / 2,
      y: Grid.h / 2
    )

    state.run_phase = :pre_game
    state.run_intro_started_tick = nil
    state.run_started_tick = nil
    state.total_time_paused = 0
    state.run_ended_tick = Kernel.tick_count
    state.last_run_height_meters = (@highest_player_y - @run_start_y)
      .fdiv(PIXELS_PER_METER)
      .clamp(0.0, Float::INFINITY)
    state.highest_height_meters = [state.highest_height_meters || 0.0, state.last_run_height_meters].max

    @player = Player.new
    @player.args = args

    @run_start_y = @player.y
    player_center_y = @player.y + (@player.h / 2.0)
    @highest_player_y = player_center_y

    state.gold_modifier = 1.0

    @rock_manager.restore_normal_spawning!
    @rock_manager.reset!
    @gold_manager.reset!
    @powerup_manager.reset!
    @lava.reset!
    @background_rock_field.reset!
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

  def altitude_measurements
    player_danger_y =
      @player.y + (@player.h * 0.4)

    {
      height_meters: [(@highest_player_y - @run_start_y).fdiv(PIXELS_PER_METER), 0.0].max,

      current_height_meters: (@player.y - @run_start_y).fdiv(PIXELS_PER_METER),

      lava_gap_meters: [(player_danger_y - @lava.surface_y).fdiv(PIXELS_PER_METER), 0.0].max
    }
  end

  def start_instructions_label
    [
      {
        x: Grid.w / 2,
        y: (Grid.h / 2) + 32,
        anchor_x: 0.5,
        anchor_y: 0.5,
        size_px: 96,
        font: Styles::FONT,
        text: "Press A or D to Move",
        r: 176,
        g: 32,
        b: 247,
        a: start_instructions_alpha
      },
      {
        x: Grid.w / 2,
        y: (Grid.h / 2) - 32,
        anchor_x: 0.5,
        anchor_y: 0.5,
        size_px: 96,
        font: Styles::FONT,
        text: "Press SPACE to Grapple",
        r: 176,
        g: 32,
        b: 247,
        a: start_instructions_alpha
      }
    ]
  end

  def game_over_label(a: 255)
    {
      x: Grid.w / 2,
      y: Grid.h / 2,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 96,
      font: Styles::FONT,
      text: "Game Over",
      r: 176,
      g: 32,
      b: 247,
      a: a
    }
  end

  def run_timer_label
    ticks_factoring_pause_elapsed = (state.run_started_tick ? state.run_started_tick.elapsed_time : 0) - state.total_time_paused
    timer_value_seconds = ticks_factoring_pause_elapsed / 60.0

    {
      x: 96,
      y: Grid.h - 32,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 32,
      font: Styles::FONT,
      text: "Time: #{ '%.1f' % timer_value_seconds.round(1) }",
      r: 176,
      g: 32,
      b: 247,
    }
  end

  def longest_run_time_label
      {
      x: Grid.w - 32 - 96,
      y: Grid.h - 32,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 32,
      font: Styles::FONT,
      text: "Best Time: #{ '%.1f' % state.longest_run_time }",
      r: 95,
      g: 15,
      b: 185,
    }
  end

  def gold_label
      {
      x: 96,
      y: Grid.h - 32 - 32,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 32,
      font: Styles::FONT,
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
      font: Styles::FONT,
      text: "#{display_name} - #{'%.1f' % (time_left / 60)}",
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
      primitive_marker: :solid
    }
  end

  def combo_timer_fill_rect
    combo_timer_backdrop_rect.merge(
      w: 160 * combo_reset_progress,
      r: 95,
      g: 15,
      b: 185,
      a: 220,
      primitive_marker: :solid
    )
  end

  def combo_count_label
    {
      x: Grid.w / 2,
      y: Grid.h - 96,
      anchor_x: 0.5,
      anchor_y: 0.5,
      size_px: 24,
      font: Styles::FONT,
      text: "Combo #{state.combo_manager.grapple_count}",
      r: 95,
      g: 15,
      b: 185,
      a: 255,
    }
  end

  def start_instructions_alpha
    110 + ((Kernel.tick_count * 2.5).sin * 115).abs
  end

end
