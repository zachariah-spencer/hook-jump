require_relative "powerups"
require_relative "hook"
require_relative "player"
require_relative "rocks"
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
