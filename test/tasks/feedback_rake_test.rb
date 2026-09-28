require "test_helper"
require "rake"

class FeedbackRakeTest < ActiveSupport::TestCase
  test "list prints each submission with its surface, note, and reply address" do
    older = Feedback.create!(surface: "search_miss", query: "A song nobody has", verified: true)
    older.update_column(:created_at, 2.days.ago)
    Feedback.create!(surface: "feedback_page", message: "Three columns, please.", contact_email: "singer@example.com")

    output, = capture_io { list_task.invoke }

    assert_includes output, "search_miss"
    assert_includes output, "song: A song nobody has"
    assert_includes output, "note: Three columns, please."
    assert_includes output, "reply: singer@example.com"
    assert_includes output, "verified"
    assert_includes output, "UNVERIFIED"
    assert_operator output.index("Three columns, please."), :<, output.index("A song nobody has")
  end

  test "list says so when nothing has been sent" do
    output, = capture_io { list_task.invoke }

    assert_includes output, "No feedback yet."
  end

  private

  def list_task
    Rails.application.load_tasks unless Rake::Task.task_defined?("feedback:list")
    Rake::Task["feedback:list"].tap(&:reenable)
  end
end
