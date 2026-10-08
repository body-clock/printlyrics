class AddReasonAndVisitSheetsToFeedbacks < ActiveRecord::Migration[8.1]
  def change
    # Which of the answers this application offers the visitor picked, from
    # Feedback::REASONS. Blank is the common case: the question is optional
    # everywhere it is asked, and the miss prompt's own answer is implied by its
    # surface.
    add_column :feedbacks, :reason, :string

    # How many sheets the visit had made when it submitted. A miss with none is a
    # visitor who left empty-handed; a miss after three is someone who found the
    # rest of what they came for. Nil on rows written before this column existed,
    # which is not the same fact as zero.
    add_column :feedbacks, :visit_sheet_count, :integer
  end
end
