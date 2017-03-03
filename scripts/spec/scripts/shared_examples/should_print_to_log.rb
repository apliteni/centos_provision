RSpec.shared_examples_for 'should print to log' do |expected_texts|
  it "prints to log #{expected_texts.inspect}" do
    run_script
    [*expected_texts].each do |expected_text|
      expect(subject.log).to match(expected_text)
    end
  end
end
