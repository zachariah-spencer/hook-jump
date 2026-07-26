module Rocks

  def self.build(type:, spawn_x:, fall_speed:)
    case type
    when :basic
      basic(spawn_x: spawn_x, fall_speed: fall_speed)
    when :bomb
      bomb(spawn_x: spawn_x, fall_speed: fall_speed)
    when :down
      down(spawn_x: spawn_x, fall_speed: fall_speed)
    when :up
      up(spawn_x: spawn_x, fall_speed: fall_speed)
    when :gold
      gold(spawn_x: spawn_x, fall_speed: fall_speed)
    when :shop
      shop(spawn_x: spawn_x, fall_speed: fall_speed)
    else
      raise ArgumentError, "Unknown rock type: #{type.inspect}"
    end
  end

  def self.basic(spawn_x:, fall_speed:)
    {
      x: spawn_x,
      y: 800,
      anchor_x: 0.5,
      anchor_y: 0.5,
      w: 64,
      h: 64,
      r: 255,
      g: 255,
      b: 255,
      angle: Numeric.rand(-360..360),
      dang: Numeric.rand(-1.2..1.2),
      dy: fall_speed,

      type: :basic,
      path: "sprites/rocks/basic_rock.png",
    }
  end

  def self.bomb(spawn_x:, fall_speed:)
    {
      x: spawn_x,
      y: 720,
      w: 64,
      h: 64,
      r: 255,
      g: 255,
      b: 255,
      dy: fall_speed,
      type: :bomb,
      path: "sprites/rocks/bomb_rock.png",
    }
  end

  def self.down(spawn_x:, fall_speed:)
    {
      x: spawn_x,
      y: 720,
      w: 64,
      h: 64,
      r: 255,
      g: 255,
      b: 255,
      dy: fall_speed,
      type: :down,
      path: "sprites/rocks/down_rock.png",
    }
  end

  def self.up(spawn_x:, fall_speed:)
    {
      x: spawn_x,
      y: 720,
      w: 64,
      h: 64,
      r: 255,
      g: 255,
      b: 255,
      dy: fall_speed,
      type: :up,
      path: "sprites/rocks/up_rock.png",
    }
  end

  def self.gold(spawn_x:, fall_speed:)
    {
      x: spawn_x,
      y: 720,
      w: 64,
      h: 64,
      r: 255,
      g: 255,
      b: 255,
      dy: fall_speed,
      type: :gold,
      path: "sprites/rocks/gold_rock.png",
    }
  end

  def self.shop(spawn_x:, fall_speed:)
    {
      x: spawn_x,
      y: 720,
      w: 64,
      h: 64,
      r: 255,
      g: 255,
      b: 255,
      dy: fall_speed,
      type: :shop,
      path: "sprites/rocks/gold_ore.png",
    }
  end
end