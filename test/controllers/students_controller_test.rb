require 'test_helper'

class StudentsControllerTest < ActionController::TestCase
  # test "the truth" do
  #   assert true
  # end
  setup :initialize_student

  def teardown
    @student = nil
  end

  test "should get index" do
  	get :index
  	assert_response :success
  	assert_not_nil assigns(:students)
  end	

  test "should get show" do
  	get :show, id: @student.id
  	assert_response :success
  	assert_not_nil assigns(:student)
  end

  test "should get new" do
  	get :new
  	assert_response :success
  	assert_template  partial: "_form"
  	assert_not_nil assigns(:student)
  end	

  test "should create student" do
  	assert_difference('Student.count') do
  		post :create, student: { age: @student.age, name: @student.name, gender: @student.gender,  mobile: @student.mobile }
  	end	
  end	

  test "should destroy student" do
  	assert_difference('Student.count', -1) do
  		delete :destroy, id: @student
  	end	
  	assert_redirected_to students_path
  end	

  test "should get edit" do
  	get :edit, id: @student
  	assert_not_nil assigns(:student)
  	assert_template  partial: "_form"
  	assert_response :success
  end	

  test "should put update student" do
  	put :update, id: @student, student:{age: @student.age, name: @student.name, gender: @student.gender,  mobile: @student.mobile}
  	assert_not_nil assigns(:student)
  	assert_redirected_to students_path
  end	

  private

  def initialize_student
  	@student = students(:one)
  end	
end
