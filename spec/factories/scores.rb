FactoryGirl.define do
  factory :score do
    student_id 11
    sequence(:course_id, 100) { |n| n }
		sequence(:grade, 100) { |n| n }
  end

end
