class SpawnScheduler

  def initialize(delay:)
    @delay = delay
    @last_spawn_at = Kernel.tick_count
    @next_delay = @delay.call
  end

  def ready?
    Kernel.tick_count - @last_spawn_at >= @next_delay
  end

  def reset!
    @last_spawn_at = Kernel.tick_count
    @next_delay = @delay.call
  end

end