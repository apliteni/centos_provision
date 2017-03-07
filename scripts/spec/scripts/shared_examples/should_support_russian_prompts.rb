RSpec.shared_examples_for 'should support russian prompts' do
  let(:options) { '-s -p -l ru' }
  let(:prompts_with_values) { make_prompts_with_values(:ru) }

  it 'stdout contains prompt with default value' do
    run_script
    prompts[:ru].values.each do |value|
      expect(subject.stdout).to include(value)
    end
  end
end