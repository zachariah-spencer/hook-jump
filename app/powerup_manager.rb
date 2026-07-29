class PowerupManager
  MIN_SPAWN_DELAY = 20.seconds
  MAX_SPAWN_DELAY = 35.seconds
  FALL_SPEED = 4.5

  def initialize(spawn_x:, spawn_y:, expired:)
    @spawn_x = spawn_x
    @spawn_y = spawn_y
    @expired = expired
    @powerups = []

    @spawn_scheduler = SpawnScheduler.new(
      delay: lambda {
        Numeric.rand(MIN_SPAWN_DELAY..MAX_SPAWN_DELAY)
      }
    )
    reset_spawn_variables
  end

  def tick
    spawn_if_ready
    move_powerups
    remove_expired_powerups
  end

  def primitives
    @powerups
  end

  def collect_intersecting(rect)
    collected, remaining = @powerups.partition do |powerup|
      Geometry.intersect_rect?(rect, powerup)
    end

    @powerups = remaining
    collected
  end

  private

  def spawn_if_ready
    return unless @spawn_scheduler.ready?

    powerup_type = Powerups::TYPES.sample

    @powerups << Powerups.build(
      type: powerup_type,
      spawn_x: @next_spawn_x,
      spawn_y: @next_spawn_y
    )

    @spawn_scheduler.reset!
    reset_spawn_variables
  end

  def move_powerups
    @powerups.each do |powerup|
      powerup.y -= FALL_SPEED
    end
  end

  def reset_spawn_variables
    @next_spawn_x = @spawn_x.call
    @next_spawn_y = @spawn_y.call
  end

  def remove_expired_powerups
    @powerups.reject! do |powerup|
      @expired.call(powerup)
    end
  end

end