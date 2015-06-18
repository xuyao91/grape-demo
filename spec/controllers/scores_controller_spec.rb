require 'rails_helper'

RSpec.describe ScoresController, type: :controller do

	let(:score_params) {{student_id: 1, coures_id: 2, grade:2}}

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
			expect(response).to render_template("new")
		end	
	end

	describe "GET#edit" do
		it "should requested edit as @score" do
			score = FactoryGirl.create(:score)
			get :edit, id: score.id
			expect(assigns(:score)).to eq(score)
			expect(response).to be_success
		end	
	end	

	context "POST#create" do
		it "create the score" do
			 expect {
          post :create, {score: score_params}
        }.to change(Score, :count).by(1)
		end	
	end	
end
