RSpec.shared_examples_for 'should not print to' do |destination, expected_texts|
  it "does not print to #{destination} #{expected_texts.inspect}" do
    run_script
    [*expected_texts].each do |expected_text|
      expect(subject.send(destination)).not_to match(expected_text)
    end
  end
end
