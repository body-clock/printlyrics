namespace :songs do
  desc "Recheck promoted songs and remove unavailable pages from public discovery"
  task verify_catalog: :environment do
    limit = Integer(ENV.fetch("LIMIT", 100), exception: false)
    abort "LIMIT must be a positive integer" unless limit&.positive?

    result = SongCatalogVerifier
      .new(client: LrcLibClient.new)
      .verify(limit: limit)

    puts result.map { |name, count| "#{name}=#{count}" }.join(" ")
  end
end
