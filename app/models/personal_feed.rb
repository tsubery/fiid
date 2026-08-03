class PersonalFeed < Feed
  def self.poll?
    # PersonalFeed items are added manually
    false
  end

  def refresh_later
    # No-op: PersonalFeed items are added manually
  end

  def self.first
    super ||  create!(title: "Personal", url: 'personal://feed')
  end
end
