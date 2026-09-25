require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "a note is enough on its own" do
    assert Feedback.new(surface: "feedback_page", message: "Three columns, please.").valid?
  end

  test "a song title is enough on its own" do
    assert Feedback.new(surface: "search_miss", query: "A song nobody has").valid?
  end

  test "a blank message and a blank title leave nothing to read" do
    feedback = Feedback.new(surface: "search_miss", message: "   ", query: "")

    assert_not feedback.valid?
    assert_includes feedback.errors.full_messages, I18n.t("feedbacks.errors.blank")
  end

  test "rejects a surface this application never renders" do
    assert_not Feedback.new(surface: "newsletter", message: "hi").valid?
  end

  test "keeps a note inside its bound" do
    feedback = Feedback.new(surface: "feedback_page", message: "x" * (Feedback::MAX_MESSAGE_LENGTH + 1))

    assert_not feedback.valid?
  end

  test "leaves the reply address optional" do
    assert Feedback.new(surface: "feedback_page", message: "hi", contact_email: "").valid?
  end

  test "rejects something that is not a reply address" do
    assert_not Feedback.new(surface: "feedback_page", message: "hi", contact_email: "not an address").valid?
  end

  test "recent lists the newest submission first" do
    older = Feedback.create!(surface: "feedback_page", message: "older")
    older.update_column(:created_at, 1.hour.ago)
    newer = Feedback.create!(surface: "feedback_page", message: "newer")

    assert_equal [ newer, older ], Feedback.recent.to_a
  end
end
