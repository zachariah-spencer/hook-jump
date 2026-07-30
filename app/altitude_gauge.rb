class AltitudeGauge

  TICK_INTERVAL_METERS = 10.0

  def initialize(x:, y:, w:, h:, displayed_gap_meters:)
    @x = x
    @y = y
    @w = w
    @h = h
    @displayed_gap_meters = displayed_gap_meters
  end

  def primitives(height_meters:, current_height_meters:, lava_gap_meters:)

    gap_progress = lava_gap_meters.fdiv(@displayed_gap_meters).clamp(0.0, 1.0)

    player_marker_y = @y + (@h * gap_progress)

    result = [
      background,
      *tick_marks,
      lava_marker,
      distance_bar(player_marker_y, gap_progress),
      player_marker(player_marker_y),
      height_label(height_meters),
      current_height_label(current_height_meters, player_marker_y),
      gap_label(lava_gap_meters),
      warning_label(lava_gap_meters)
    ]

    result.compact
  end

  private

  def background
    {
      x: @x,
      y: @y,
      w: @w,
      h: @h,
      r: 20,
      g: 20,
      b: 28,
      a: 210,
      primitive_marker: :solid
    }
  end

  def lava_marker
    {
      x: @x,
      y: @y,
      w: @w,
      h: 8,
      r: 255,
      g: 70,
      b: 15,
      a: 255,
      primitive_marker: :solid
    }
  end

  def distance_bar(player_marker_y, gap_progress)
    color = danger_color(gap_progress)

    {
      x: @x + (@w / 2) - 2,
      y: @y + 8,
      w: 4,
      h: [player_marker_y - (@y + 8), 0].max,
      **color,
      primitive_marker: :solid
    }
  end

  def player_marker(player_marker_y)
    {
      x: @x + (@w / 2) - 6,
      y: player_marker_y - 6,
      w: 12,
      h: 12,
      r: 80,
      g: 220,
      b: 255,
      a: 255,
      primitive_marker: :solid
    }
  end

  def height_label(height_meters)
    {
      x: @x + (@w / 2),
      y: @y + @h + 28,
      text: "Top #{height_meters.floor} m",
      anchor_x: 0.5,
      size_px: 24,
      r: 255,
      g: 255,
      b: 255,
      primitive_marker: :label
    }
  end

  def current_height_label(current_height_meters, player_marker_y)
    {
      x: @x + (@w / 2) + 40,
      y: player_marker_y + 12,
      text: "#{current_height_meters.floor} m",
      anchor_x: 0.5,
      size_px: 24,
      r: 255,
      g: 255,
      b: 255,
      primitive_marker: :label
    }
  end

  def gap_label(lava_gap_meters)
    {
      x: @x + (@w / 2),
      y: @y - 10,
      text: "Lava #{lava_gap_meters.round(1)} m",
      anchor_x: 0.5,
      alignment_enum: 0,
      anchor_y: 1.0,
      size_px: 18,
      r: 255,
      g: 150,
      b: 60,
      primitive_marker: :label
    }
  end

  def tick_marks
    marks = []
    meters = 0.0

    while meters <= @displayed_gap_meters
      progress = meters.fdiv(@displayed_gap_meters)
      marker_y = @y + (@h * progress)

      marks << {
        x: @x - 5,
        y: marker_y,
        w: @w + 10,
        h: 2,
        r: 120,
        g: 120,
        b: 130,
        a: 180,
        primitive_marker: :solid
      }

      meters += TICK_INTERVAL_METERS
    end

    marks
  end

  def warning_label(lava_gap_meters)
    return nil if lava_gap_meters > 10.0

    {
      x: @x + (@w / 2),
      y: @y + @h + 58,
      text: "LAVA!",
      anchor_x: 0.5,
      size_px: 24,
      r: 255,
      g: 45,
      b: 25,
      a: warning_alpha,
      primitive_marker: :label
    }
  end

  def warning_alpha
    140 + ((Kernel.tick_count / 10.0).sin * 115).abs
  end

  def danger_color(progress)
    if progress <= 0.2
      { r: 255, g: 40, b: 30, a: 255 }
    elsif progress <= 0.5
      { r: 255, g: 155, b: 30, a: 255 }
    else
      { r: 80, g: 220, b: 120, a: 255 }
    end
  end

end