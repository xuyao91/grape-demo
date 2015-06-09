require 'rails_helper'

RSpec.describe "courses/index", type: :view do
  before(:each) do
    assign(:courses, [
      Course.create!(
        :sku => "Sku",
        :name => "Name"
      ),
      Course.create!(
        :sku => "Sku",
        :name => "Name"
      )
    ])
  end

  it "renders a list of courses" do
    render
    assert_select "tr>td", :text => "Sku".to_s, :count => 2
    assert_select "tr>td", :text => "Name".to_s, :count => 2
  end
end
