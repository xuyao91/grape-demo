class Score < ActiveRecord::Base
  belongs_to :student
  belongs_to :course
  validates :student_id, :course_id, :grade, presence: true
end
