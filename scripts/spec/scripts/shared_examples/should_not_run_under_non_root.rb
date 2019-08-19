RSpec.shared_examples_for 'should not run under non-root' do
  it_behaves_like 'should exit with error', 'You should run this program as root'
end
