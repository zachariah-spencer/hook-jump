module Powerups

  TYPES = [:up_rock, :wide_hook, :gold_rush, :eagle]

  def self.build(type:, spawn_x: 0, spawn_y: 0)
    case type
    when :wide_hook
      wide_hook(spawn_x: spawn_x, spawn_y: spawn_y)
    when :up_rock
      up_rock(spawn_x: spawn_x, spawn_y: spawn_y)
    when :gold_rush
      gold_rush(spawn_x: spawn_x, spawn_y: spawn_y)
    when :eagle
      eagle(spawn_x: spawn_x, spawn_y: spawn_y)
    else
      raise ArgumentError, "Unknown powerup type: #{type.inspect}"
    end
  end

  def self.wide_hook(spawn_x:, spawn_y:)
    {
      x: spawn_x,
      y: spawn_y,
      w: 64,
      h: 64,
      path: "sprites/powerups/wide_hook_powerup.png",
      r: 255,
      g: 255,
      b: 255,
      name: "Wide Hook",
      start_tick: Kernel.tick_count,
      type: :wide_hook,
      duration: 10.0.seconds,
      active: false,
    }
  end

  def self.up_rock(spawn_x:, spawn_y:)
    {
      x: spawn_x,
      y: spawn_y,
      w: 64,
      h: 64,
      path: "sprites/powerups/up_rock_powerup.png",
      r: 255,
      g: 255,
      b: 255,
      name: "Boost Rock Avalanche",
      start_tick: Kernel.tick_count,
      type: :up_rock,
      duration: 10.0.seconds,
      active: false,
    }
  end

  def self.gold_rush(spawn_x:, spawn_y:)
    {
      x: spawn_x,
      y: spawn_y,
      w: 64,
      h: 64,
      path: "sprites/powerups/gold_rush_powerup.png",
      r: 255,
      g: 255,
      b: 255,
      name: "Gold Rush!(2x $)",
      start_tick: Kernel.tick_count,
      type: :gold_rush,
      duration: 15.seconds,
      active: false,
    }
  end

  def self.eagle(spawn_x:, spawn_y:)
    {
      x: spawn_x,
      y: spawn_y,
      w: 64,
      h: 64,
      path: "sprites/powerups/eagle_powerup.png",
      r: 255,
      g: 255,
      b: 255,
      name: "Eagle",
      start_tick: Kernel.tick_count,
      type: :eagle,
      duration: 10.seconds,
      active: false,
    }
  end
end