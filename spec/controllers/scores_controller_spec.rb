require 'rails_helper'

RSpec.describe ScoresController, type: :controller do

	describe 'GET#index' do
		it "assigns all scores as @scores" do
			score = FactoryGirl.create(:score)
			get :index
			# expect(assigns(:scores)).to match_array([score])
			expect(response).to be_success
		end	
	end	

	describe "GET#show" do
		it "assigns the requested score as @score" do
			score = FactoryGirl.create(:score)
			get :show, {:id => score.to_param}
			expect(assigns(:score)).to eq(score)
			expect(response).to be_success
		end	
	end	

	describe "GET#new" do
		it "new the requested score as @score" do
			get :new
			expect(assigns(:score)).to  be_a_new(Score)
		end	

		it "render template form" do
			get :new
			expect(view).to render_template(:partial => "_form")
		end	
	end	
end
