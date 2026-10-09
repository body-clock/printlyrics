namespace :feedback do
  desc "Print the feedback visitors sent, newest first"
  task list: :environment do
    records = Feedback.recent.limit(Integer(ENV.fetch("LIMIT", 50)))

    if records.empty?
      puts "No feedback yet."
      next
    end

    records.each do |feedback|
      puts "#{feedback.created_at.to_fs(:db)}  #{feedback.surface}  " \
        "#{feedback.verified ? 'verified' : 'UNVERIFIED'}"
      puts "  reason: #{feedback.reason}" if feedback.reason.present?
      puts "  song: #{feedback.query}" if feedback.query.present?
      feedback.message.to_s.each_line { |line| puts "  note: #{line.chomp}" } if feedback.message.present?
      puts "  reply: #{feedback.contact_email}" if feedback.contact_email.present?
      puts "  sheets already made this visit: #{feedback.visit_sheet_count}" unless feedback.visit_sheet_count.nil?
      puts
    end
  end

  desc "Rank the songs visitors asked for, most requested first"
  task demand: :environment do
    limit = Integer(ENV.fetch("LIMIT", 500))
    records = Feedback.recent.where.not(query: [ nil, "" ]).limit(limit)

    if records.empty?
      puts "No songs have been asked for yet."
      next
    end

    # The same song typed twice is one request, so the ranking reads the words
    # rather than the row: the case and the spacing are the visitor's, not the
    # song's.
    groups = records.group_by { |feedback| feedback.query.to_s.strip.downcase.gsub(/\s+/, " ") }
    ranked = groups.sort_by { |_song, rows| [ -rows.size, -rows.first.created_at.to_i ] }

    counted = ->(values) do
      values.tally.sort_by { |value, count| [ -count, value.to_s ] }
        .map { |value, count| "#{value} #{count}" }.join(" · ")
    end

    puts "#{records.size} song requests in the newest #{limit} submissions, most requested first:"
    puts

    ranked.each do |_song, rows|
      latest = rows.first
      surfaces = rows.map(&:surface).uniq.sort.join("/")
      notes = rows.count { |row| row.message.present? }

      puts "#{rows.size.to_s.rjust(3)}×  #{latest.query.to_s.truncate(40).ljust(40)} " \
        "#{surfaces.ljust(24)} notes #{notes}  last #{latest.created_at.to_date}"
    end

    puts
    puts "Surfaces  #{counted.call(records.map(&:surface))}"
    puts "Reasons   #{counted.call(records.map { |row| row.reason || 'unlabelled' })}"
    puts "Notes     #{records.count { |row| row.message.present? }} — read them with bin/rails feedback:list"
  end
end
