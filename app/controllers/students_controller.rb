class StudentsController < ApplicationController
	before_action :set_student, only: [:show, :destroy, :edit, :update]

	def index
		@students = Student.all
	end	

	def new
		@student = Student.new
	end	

	def create
		@student = Student.new(student_params)
		redirect_to @student if @student.save
	end	

	def destroy
		redirect_to students_path if @student.destroy
	end	

	def update
		redirect_to students_path if @student.update(student_params)
	end	

	private

	def student_params
		params.require(:student).permit(:name, :age, :gender, :mobile)
	end	

	def set_student
		@student = Student.find_by(id: params[:id])
	end	
end
