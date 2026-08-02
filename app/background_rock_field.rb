class BackgroundRockField

  PATHS = [
    "sprites/background/rock_1.png",
    "sprites/background/rock_2.png",
  ]

  COLOR = {
    r: 55,
    g: 35,
    b: 75,
    a: 180
  }

  ROCKS_PER_SECTION = 12
  SECTION_HEIGHT = 720

  def initialize
    @sections = {}


  end

  def tick(view:)
    first_section = (view.y / SECTION_HEIGHT).floor
    last_section = ((view.y + view.h) / SECTION_HEIGHT).floor

    (first_section - 1).upto(last_section + 1) do |section_index|
      ensure_section(section_index)
    end
  end

  def primitives(view:)
    first_section = (view.y / SECTION_HEIGHT).floor
    last_section = ((view.y + view.h) / SECTION_HEIGHT).floor

    (first_section..last_section).flat_map do |section_index|
      @sections[section_index] || []
    end
  end

  def ensure_section(section_index)
    return if @sections.key?(section_index)

    section_bottom = section_index * SECTION_HEIGHT

    @sections[section_index] = ROCKS_PER_SECTION.map do
      size = Numeric.rand(48..128)

      {
        x: Numeric.rand((size / 2)..(Grid.w - (size / 2))),
        y: section_bottom + Numeric.rand(0..SECTION_HEIGHT),
        w: size,
        h: size,
        path: PATHS.sample,
        angle: Numeric.rand(0..359),
        anchor_x: 0.5,
        anchor_y: 0.5,
        **COLOR
      }

    end
  end

  def reset!
    @sections.clear
  end
end