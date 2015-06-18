require 'rails_helper'

RSpec.describe ScoresController, type: :controller do

	let(:score_params) {{student_id: 1, course_id: 2, grade:2}}
	let(:invalid_score_params) {{student_id: 1, course_id: 2, grade: nil}}

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

  describe "POST#create" do
		context "with valid score_params" do
			it "create the score" do
				 expect {
	          post :create, {score: score_params}
	        }.to change(Score, :count).by(1)
	    end

	    it "new a score" do
	      post :create, {score: score_params}
	      expect(assigns(:score)).to be_a(Score)
	      expect(assigns(:score)).to be_persisted
	    end

	    it "redirect to create score" do
	      post :create, {score:score_params}
	      expect(response).to redirect_to(assigns(:score))
	      # expect(response).to redirect_to(assigns(:score))
	    end
	  end
	  
	  context "with invalid score_params" do
	  	it "create thoe score with invalid" do
        post :create, {score: invalid_score_params}
        expect(assigns(:score)).to be_a_new(Score)
	  	end

	  	it "render the new template" do
	  		post :create, {score: invalid_score_params}
	  		expect(response).to render_template("new")
	  	end	
	  end
	end	

	describe "DELETE#destroy" do
		it "find the score" do
			score = FactoryGirl.create(:score)
			# expect(assigns(:score)).to eq(score)
		end		

		it "delete the score" do
			score = FactoryGirl.create(:score)
			expect{
				delete :destroy, {id: score.id}
			}.to change(Score, :count).by(-1)
		end	
	end	

end
