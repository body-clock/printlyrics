require "test_helper"
require "rake"

class LyricsRakeTest < ActiveSupport::TestCase
  test "purge expired deletes only expired pages and reports the count" do
    keep = Lyric.create!(lyrics: "Still here")
    expired = 2.times.map { Lyric.create!(lyrics: "Gone", expires_at: 1.minute.ago) }

    output, = capture_io { purge_task.invoke }

    assert_includes output, "Deleted 2 expired lyric pages and 0 expired songbooks."
    assert Lyric.exists?(keep.id)
    expired.each { |lyric| assert_not Lyric.exists?(lyric.id) }
  end

  test "purge expired also deletes expired songbooks" do
    keep = Songbook.start_with(Lyric.create!(lyrics: "Still here"))
    expired = Songbook.create!(expires_at: 1.minute.ago)

    output, = capture_io { purge_task.invoke }

    assert_includes output, "Deleted 0 expired lyric pages and 1 expired songbook."
    assert Songbook.exists?(keep.id)
    assert_not Songbook.exists?(expired.id)
  end

  private

  def purge_task
    Rails.application.load_tasks unless Rake::Task.task_defined?("lyrics:purge_expired")
    Rake::Task["lyrics:purge_expired"].tap(&:reenable)
  end
end
