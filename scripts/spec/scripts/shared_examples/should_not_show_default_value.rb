RSpec.shared_examples_for 'should not show default value' do |field|
  it 'stdout does not contain prompt with default value' do
    run_script
    expect(subject.stdout).to include("#{prompts[:en][field]} >")
  end
end

