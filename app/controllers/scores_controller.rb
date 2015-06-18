class ScoresController < ApplicationController
	before_action :set_score, only: [:show, :edit]

	def index
		@scores = Score.all
	end	

	def new
		@score = Score.new
	end	

	def edit; end

	private 

	def set_score
		@score = Score.find_by(id: params[:id])
	end	
end
