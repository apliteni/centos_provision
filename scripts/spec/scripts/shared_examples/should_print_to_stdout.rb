RSpec.shared_examples_for 'should print to stdout' do |expected_text|
  it "prints to stdout #{expected_text.inspect}" do
    run_script
    expect(subject.stdout).to match(expected_text)
  end
end
