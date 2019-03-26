RSpec.shared_examples_for 'should show default value' do |field, showed_value:, inventory_values: {}|
  it 'stdout contains prompt with default value' do
    run_script(inventory_values: inventory_values)
    expect(subject.stdout).to match(/#{Regexp.escape(prompts[:en][field])} \[#{showed_value}\] >/)
  end
end

