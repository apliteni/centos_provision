RSpec.shared_examples_for 'should exit with error' do |error_texts|
  it "exits with error #{error_texts.inspect}" do
    run_script
    expect(subject.ret_value).not_to be_success
    [*error_texts].each do |error_text|
      expect(subject.stderr).to match(error_text)
    end
  end
end
