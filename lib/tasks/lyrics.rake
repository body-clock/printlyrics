namespace :lyrics do
  desc "Delete lyric pages whose retention window has elapsed"
  task purge_expired: :environment do
    deleted = Lyric.purge_expired!
    puts "Deleted #{deleted} expired lyric #{'page'.pluralize(deleted)}."
  end
end
