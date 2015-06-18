class ScoresController < ApplicationController
	before_action :set_score, only: [:show, :edit]

	def index
		@scores = Score.all
	end	

	def new
		@score = Score.new
	end	

	def edit; end

	def create
		@score = Score.new(score_params)
		if @score.save
			redirect_to @score
		else
			render action: :new
		end		
	end	

	private 

	def set_score
		@score = Score.find_by(id: params[:id])
	end

	def score_params
		params.require(:score).permit(:student_id, :course_id,:grade)
	end	
end
