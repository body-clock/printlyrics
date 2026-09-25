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
      puts "  song: #{feedback.query}" if feedback.query.present?
      feedback.message.to_s.each_line { |line| puts "  note: #{line.chomp}" } if feedback.message.present?
      puts "  reply: #{feedback.contact_email}" if feedback.contact_email.present?
      puts
    end
  end
end
