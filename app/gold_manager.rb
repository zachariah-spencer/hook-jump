class GoldManager
  MIN_SPAWN_DELAY = 0.75.seconds
  MAX_SPAWN_DELAY = 1.5.seconds

  ATTRACTION_RADIUS = 350
  ATTRACTION_STRENGTH = 10.0

  MIN_FALL_SPEED = 3.8
  MAX_FALL_SPEED = 5.3

  def initialize(spawn_x:, spawn_y:, expired:)
    @spawn_x = spawn_x
    @spawn_y = spawn_y
    @expired = expired
    @gold = []
    @spawn_scheduler = SpawnScheduler.new(
      delay: lambda {
        Numeric.rand(MIN_SPAWN_DELAY..MAX_SPAWN_DELAY)
      }
    )
    reset_spawn_variables
  end

  def tick(attraction_target:, attraction_active:)
    spawn_if_ready
    move_gold
    attract_gold_to(attraction_target) if attraction_active
    remove_expired_gold
  end

  def primitives
    @gold
  end

  def collect_intersecting(rect)
    collected, remaining = @gold.partition do |gold|
      Geometry.intersect_rect?(rect, gold)
    end

    @gold = remaining
    collected
  end

  private

  def spawn_if_ready
    return unless @spawn_scheduler.ready?

    @gold << Gold.build(
      spawn_x: @next_spawn_x,
      spawn_y: @next_spawn_y,
      fall_speed: @next_fall_speed
    )

    @spawn_scheduler.reset!
    reset_spawn_variables
  end

  def move_gold
    @gold.each do |gold|
      gold.y -= gold.dy
    end
  end

  def attract_gold_to(target)
    @gold.each do |gold|
      target_x = target.x + (target.w / 2)
      target_y = target.y + (target.h / 2)
      gold_x = gold.x + (gold.w / 2)
      gold_y = gold.y + (gold.h / 2)

      offset_x = target_x - gold_x
      offset_y = target_y - gold_y
      distance = Math.sqrt((offset_x**2) + (offset_y**2))

      next if distance.zero?
      next if distance >= ATTRACTION_RADIUS

      proximity = 1.0 - (distance / ATTRACTION_RADIUS)
      pull = ATTRACTION_STRENGTH * (proximity**2)

      gold.x += offset_x / distance * pull
      gold.y += offset_y / distance * pull
    end
  end

  def remove_expired_gold
    @gold.reject! { |gold| @expired.call(gold) }
  end

  def reset_spawn_variables
    @next_spawn_x = @spawn_x.call
    @next_spawn_y = @spawn_y.call
    @next_fall_speed = Numeric.rand(MIN_FALL_SPEED..MAX_FALL_SPEED)
  end


end