#module GrapeDemo 
	class API < Grape::API
	  version 'v1', using: :header, vendor: 'twitter'
      format :json


       resource :students do
	      desc "Return all students."
	      get :index do
	        Student.limit(20)
	      end

	      desc "Return a student."
	      params do
	        requires :id, type: Integer, desc: "student id."
	      end
	      route_param :id do
	        get do
	          Student.find(params[:id])
	        end
	      end

	      desc "create a student "
	      params do
	      	requires :student , type: Hash do
	      		requires :name, type: String
	      		requires :age, type: Integer
	      		requires :gender, type: Integer
	      		requires :mobile, type: String
	      	end	
	      end
	      	post do
	      		Student.create!(params[:student])
	      	end	

	   end   

	end	
	
#end