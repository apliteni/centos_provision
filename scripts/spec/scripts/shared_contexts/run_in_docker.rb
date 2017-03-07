require 'shell'

RSpec.shared_context 'run in docker', run_in_docker: :yes do
  before(:all) { `docker rm keitaro_scripts_test &>/dev/null` }

  let(:docker_image) { 'centos' }
end
