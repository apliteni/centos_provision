RSpec.shared_context 'make prompts with values' do
  def make_prompts_with_values(lang)
    user_values.map { |k, v| [prompts[lang][k], v] }.to_h
  end
end
