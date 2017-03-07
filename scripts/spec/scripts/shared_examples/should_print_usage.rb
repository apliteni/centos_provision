RSpec.shared_examples_for 'should print usage when invoked with' do |args:|
  it_behaves_like 'should exit with error', 'Usage:' do
    let(:args) { args }
  end
end
