RSpec.shared_examples_for 'should not print to' do |destination, expected_texts|
  it "does not print to #{destination} #{expected_texts.inspect}" do
    run_script
    [*expected_texts].each do |expected_text|
      if expected_text.is_a?(Regexp)
        expect(subject.send(destination)).not_to match(expected_text)
      else
        expect(subject.send(destination)).not_to include(expected_text)
      end
    end
  end
end
