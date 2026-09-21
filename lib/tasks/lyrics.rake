namespace :lyrics do
  desc "Delete lyric pages and songbooks whose retention window has elapsed"
  task purge_expired: :environment do
    lyrics = Lyric.purge_expired!
    songbooks = Songbook.purge_expired!

    puts "Deleted #{lyrics} expired lyric #{'page'.pluralize(lyrics)} " \
      "and #{songbooks} expired #{'songbook'.pluralize(songbooks)}."
  end
end
