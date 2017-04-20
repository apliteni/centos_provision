RSpec.shared_examples_for 'should print to' do |destination, expected_texts|
  it "prints to #{destination} #{expected_texts.inspect}" do
    run_script
    [*expected_texts].each do |expected_text|
      expect(subject.send(destination)).to match(expected_text)
    end
  end
end
