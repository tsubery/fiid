class PodchaserGuestFeed < Feed
  store_accessor :config, :podchaser_guest_name, :podchaser_guest_pcid

  validates :podchaser_guest_name, presence: true
  before_validation :fill_missing_details

  SearchQuery = Podchaser::Client.parse <<~GRAPHQL
    query($searchTerm: String!) {
      creators(searchTerm: $searchTerm, first: 1) {
        data { pcid, name, imageUrl }
      }
    }
  GRAPHQL

  EpisodeCreditsQuery = Podchaser::Client.parse <<~GRAPHQL
    query($pcid: String!, $first: Int!) {
      creator(identifier: { type: PCID, id: $pcid }) {
        pcid
        name
        imageUrl
        episodeCredits(
          first: $first,
          filters: { role: ["guest"] },
          sort: { sortBy: DATE, direction: DESCENDING }
        ) {
          paginatorInfo { count, hasMorePages }
          data {
            episode {
              id
              title
              airDate
              url
              audioUrl
              length
              imageUrl
              podcast { title, imageUrl }
            }
          }
        }
      }
    }
  GRAPHQL

  def normalized_url
    return url unless podchaser_guest_name.present?
    "podchaser://#{podchaser_guest_name.parameterize}"
  end

  def fill_missing_details
    return unless podchaser_guest_name.present?
    self.title = "PodChaser - #{podchaser_guest_name}"
    return if podchaser_guest_pcid.present?

    result = Podchaser::Client.query(SearchQuery, variables: { searchTerm: podchaser_guest_name })
    guest = result.data&.creators&.data&.first

    unless guest
      self.fetch_error_message = "Guest '#{podchaser_guest_name}' not found on Podchaser"
      update_column(:fetch_error_message, fetch_error_message) if persisted?
      return
    end

    self.podchaser_guest_pcid = guest.pcid
    self.thumbnail_url = guest.image_url if thumbnail_url.blank?
  end

  def recent_media_items(*)
    return "PodchaserGuestFeed##{id}: no guest ID resolved" unless podchaser_guest_pcid.present?

    result = Podchaser::Client.query(
      EpisodeCreditsQuery,
      variables: { pcid: podchaser_guest_pcid, first: 25 }
    )

    guest = result.data&.creator
    return "Error fetching feed ##{id}: guest not found" unless guest

    credits = guest.episode_credits&.data || []

    credits.filter_map do |credit|
      ep = credit.episode
      next unless ep

      guid = "podchaser:#{ep.id}"

      media_items.find_by(guid: guid) ||
        media_items.new(
          guid: guid,
          url: ep.audio_url || ep.url,
          title: [title, "#{ep.podcast&.title} - #{ep.title}"].compact.join(": "),
          author: ep.podcast&.title || title,
          description: '',
          mime_type: ep.audio_url.present? ? MediaItem::VIDEO_MIME_TYPE : MediaItem::HTML_MIME_TYPE,
          published_at: ep.air_date,
          duration_seconds: ep.length,
          thumbnail_url: ep.image_url || ep.podcast&.image_url || ''
        )
    end
  rescue => e
    "Error fetching feed ##{id}: #{e.inspect}"
  end
end
