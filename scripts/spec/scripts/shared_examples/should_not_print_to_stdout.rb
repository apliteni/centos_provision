shared_examples_for 'should not print to stdout' do |expected_text|
  it "does not print to stdout #{expected_text.inspect}" do
    subject.call
    expect(subject.stdout).not_to match(expected_text)
  end
end


