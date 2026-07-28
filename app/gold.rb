module Gold
  def self.build(spawn_x:, spawn_y:, fall_speed:)
    {
      x: spawn_x,
      y: spawn_y,
      w: 16,
      h: 16,
      dy: fall_speed * 1.5,
      type: :gold,
      path: "sprites/rocks/gold_ore.png"
    }
  end
end