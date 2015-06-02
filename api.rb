module GrapeDemo do 
	class API < Grape::API
	  version 'v1', using: :header, vendor: 'twitter'
      format :json


       resource :students do
	      desc "Return all students."
	      get :index do
	        Student.limit(20)
	      end
	   end   

	end	
	
end