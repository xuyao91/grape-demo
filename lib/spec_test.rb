require 'byebug'
$count = 0
RSpec.describe "let" do
  let(:count) { $count += 1 }

  it "memoizes the value" do
    expect(count).to eq(1)
    expect(count).to eq(1)
  end

  it "is not cached across examples" do
    expect(count).to eq(2)
  end
end

RSpec.describe "an example" do
  def help
    :available
  end

  describe "in a nested group" do
    it "has access to methods defined in its parent group" do
      expect(help).to be(:available)
    end
  end
end

RSpec.describe String do
  it "is available as described_class" do
    expect(described_class).to eq(String)
  end
end


RSpec.describe "example as block arg to it, before, and after" do
  before do |example|
    expect(example.description).to eq("is the example object")
  end

  after do |example|
    expect(example.description).to eq("is the example object")
  end

  it "is the example object" do |example|
    expect(example.description).to eq("is the example object")
  end
end

RSpec.describe "example as block arg to let" do
  let(:the_description) do |example|
    example.description
  end

  it "is the example object" do |example|
    expect(the_description).to eq("is the example object")
  end
end

RSpec.describe "example as block arg to subject" do
  subject do |example|
    example.description
  end

  it "is the example object" do |example|
    expect(subject).to eq("is the example object")
  end
end

RSpec.describe "example as block arg to subject with a name" do
  subject(:the_subject) do |example|
    example.description
  end

  it "is the example object" do |example|
    expect(the_subject).to eq("is the example object")
    expect(subject).to eq("is the example object")
  end
end