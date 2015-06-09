require 'test_helper'

class TeacherTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "validates" do
  	teacher = Teacher.new
  	assert_not teacher.save
  end	

  test "full name " do 
  	teacher = Teacher.first
	assert_not_nil teacher.full_name	
  end	

  test "full name = " do
	teacher = Teacher.first
	assert_not_nil teacher.first_name
	assert_not_nil teacher.last_name  	
  end	
end
