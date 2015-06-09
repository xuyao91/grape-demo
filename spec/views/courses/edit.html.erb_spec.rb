require 'rails_helper'

RSpec.describe "courses/edit", type: :view do
  before(:each) do
    @course = assign(:course, Course.create!(
      :sku => "MyString",
      :name => "MyString"
    ))
  end

  it "renders the edit course form" do
    render

    assert_select "form[action=?][method=?]", course_path(@course), "post" do

      assert_select "input#course_sku[name=?]", "course[sku]"

      assert_select "input#course_name[name=?]", "course[name]"
    end
  end
end
