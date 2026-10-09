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

  test "list prints the answer and what the visit had already made" do
    Feedback.create!(surface: "sheet", message: "The second verse is cut off.",
      reason: "print_problem", visit_sheet_count: 2)

    output, = capture_io { list_task.invoke }

    assert_includes output, "reason: print_problem"
    assert_includes output, "sheets already made this visit: 2"
  end

  test "list says so when nothing has been sent" do
    output, = capture_io { list_task.invoke }

    assert_includes output, "No feedback yet."
  end

  test "demand ranks the requests by how often they were made" do
    Feedback.create!(surface: "search_miss", query: "Mahal Magmahl")
    Feedback.create!(surface: "search_miss", query: "mahal  magmahl")
    Feedback.create!(surface: "search_miss", query: "Dynamite taio cruise")

    output, = capture_io { demand_task.invoke }

    assert_includes output, "3 song requests"
    assert_match(/2×\s+mahal\s+magmahl/, output.downcase)
    assert_operator output.downcase.index("2×"), :<, output.downcase.index("dynamite")
  end

  test "demand counts the surfaces and the answers" do
    Feedback.create!(surface: "sheet", message: "Cut off.", query: "A Song", reason: "print_problem")
    Feedback.create!(surface: "search_miss", query: "Another Song")

    output, = capture_io { demand_task.invoke }

    assert_includes output, "Surfaces  search_miss 1 · sheet 1"
    assert_includes output, "Reasons   print_problem 1 · unlabelled 1"
    assert_includes output, "Notes     1"
  end

  test "demand says so when no song has been asked for" do
    Feedback.create!(surface: "feedback_page", message: "Three columns, please.")

    output, = capture_io { demand_task.invoke }

    assert_includes output, "No songs have been asked for yet."
  end

  private

  def list_task = rake_task("feedback:list")
  def demand_task = rake_task("feedback:demand")

  def rake_task(name)
    Rails.application.load_tasks unless Rake::Task.task_defined?(name)
    Rake::Task[name].tap(&:reenable)
  end
end
