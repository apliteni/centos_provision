require 'shell'

RSpec.shared_context 'build subject', build_subject: :yes do
  let(:env) { {LANG: 'C'} }
  let(:options) { '' }
  let(:args) { options }
  let(:docker_image) { nil }
  let(:command_stubs) { {} }
  let(:all_command_stubs) {}
  let(:commands) { [] }
  let(:save_files) { [] }
  let(:prompts_with_values) { make_prompts_with_values(:en) }
  let(:prompts) { {en: {}, ru: {}} }
  let(:user_values) { {} }

  def make_prompts_with_values(lang)
    user_values.map { |k, v| [prompts[lang][k], v] }.to_h
  end

  subject do
    Script.new script_name,
               env: env,
               args: args,
               prompts_with_values: prompts_with_values,
               docker_image: docker_image,
               command_stubs: command_stubs,
               commands: commands,
               save_files: save_files
  end
end
