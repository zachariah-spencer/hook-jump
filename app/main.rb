require_relative "game"
require_relative "powerups"
require_relative "player"
require_relative "rocks"
require_relative "hook"

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
