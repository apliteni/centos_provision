RSpec.shared_examples_for 'should try to detect bash pipe mode' do
  let(:options) { '-s -p' }

  it_behaves_like 'should print to', :log, "Can't detect pipe bash mode. Stdin hack disabled"
end

