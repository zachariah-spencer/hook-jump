class RockManager
attr_dr

def initialize
  @rocks = []
  @rock_spawned_at = 0
  @next_rock_spawn_delay = Numeric.rand(difficulty.min_rock_spawn_delay..difficulty.max_rock_spawn_delay)
  @next_rock_spawn_x = Numeric.rand(MIN_ROCK_SPAWN_X..MAX_ROCK_SPAWN_X)
  @next_rock_dy = Numeric.rand(difficulty.min_rock_fall_speed..difficulty.max_rock_fall_speed)
  @next_special_rock_spawn_countdown = Numeric.rand(difficulty.min_special_rock_spawn_countdown..difficulty.max_special_rock_spawn_countdown)
  @next_down_rock_spawn_countdown = Numeric.rand(difficulty.min_down_rock_spawn_countdown..difficulty.max_down_rock_spawn_countdown)
  @next_shop_rock_spawn_countdown = Numeric.rand(HARD_MIN_SHOP_ROCK_SPAWN_COUNTDOWN..HARD_MAX_SHOP_ROCK_SPAWN_COUNTDOWN)
  @only_spawn_up_rocks = false
end

def tick

end

def calc

end

def primitives

end
end