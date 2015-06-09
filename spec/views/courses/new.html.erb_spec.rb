require 'rails_helper'

RSpec.describe "courses/new", type: :view do
  before(:each) do
    assign(:course, Course.new(
      :sku => "MyString",
      :name => "MyString"
    ))
  end

  it "renders new course form" do
    render

    assert_select "form[action=?][method=?]", courses_path, "post" do

      assert_select "input#course_sku[name=?]", "course[sku]"

      assert_select "input#course_name[name=?]", "course[name]"
    end
  end
end
