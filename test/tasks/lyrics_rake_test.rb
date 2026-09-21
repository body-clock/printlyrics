require "test_helper"
require "rake"

class LyricsRakeTest < ActiveSupport::TestCase
  test "purge expired deletes only expired pages and reports the count" do
    keep = Lyric.create!(lyrics: "Still here")
    expired = 2.times.map { Lyric.create!(lyrics: "Gone", expires_at: 1.minute.ago) }

    output, = capture_io { purge_task.invoke }

    assert_includes output, "Deleted 2 expired lyric pages."
    assert Lyric.exists?(keep.id)
    expired.each { |lyric| assert_not Lyric.exists?(lyric.id) }
  end

  private

  def purge_task
    Rails.application.load_tasks unless Rake::Task.task_defined?("lyrics:purge_expired")
    Rake::Task["lyrics:purge_expired"].tap(&:reenable)
  end
end
