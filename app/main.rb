require_relative "camera"
require_relative "world_spawn_bounds"
require_relative "spawn_scheduler"
require_relative "gold"
require_relative "gold_manager"
require_relative "powerups"
require_relative "powerup_manager"
require_relative "hook"
require_relative "player"
require_relative "rocks"
require_relative "rock_manager"
require_relative "game"

module Main

  def start(args)
    $game = Game.new args
    $game.args = args
    $game.start
  end

  def tick(args)
    $game.args = args
    $game.tick
  end

  def shutdown
    $game.shutdown
  end
end
