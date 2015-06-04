class Teacher < ActiveRecord::Base

  validates :full_name, :age, :gender, :mobile, presence: true

  def full_name
  	[first_name, last_name].join(' ')
  end	

  def full_name= (full_name)
  	split = full_name.split(' ', 2)
  	self.first_name = split[0]
  	self.last_name = split[1]
  end	
end
