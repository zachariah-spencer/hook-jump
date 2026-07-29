module WorldSpawnBounds
  HORIZONTAL_PADDING = 32

  def self.min_x
    HORIZONTAL_PADDING
  end

  def self.max_x
    Grid.w - HORIZONTAL_PADDING
  end

  def self.random_x
    Numeric.rand(min_x..max_x)
  end
end