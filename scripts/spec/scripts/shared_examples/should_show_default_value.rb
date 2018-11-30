RSpec.shared_examples_for 'should show default value' do |field, showed_value:|
  it 'stdout contains prompt with default value' do
    run_script(inventory_values: stored_values)
    expect(subject.stdout).to match(/#{Regexp.escape(prompts[:en][field])} \[#{showed_value}\] >/)
  end
end

