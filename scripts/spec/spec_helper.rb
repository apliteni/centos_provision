require 'pathname'

ROOT_PATH=File.expand_path('../../', __FILE__)
ENV['BUNDLE_GEMFILE'] ||= "#{ROOT_PATH}/Gemfile"

require 'rubygems'
require 'bundler/setup'

require 'byebug'

require 'inventory'
require 'script'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  Dir["#{ROOT_PATH}/spec/scripts/shared_examples/**/*.rb"].each {|f| require f}
  Dir["#{ROOT_PATH}/spec/scripts/shared_contexts/**/*.rb"].each {|f| require f}
end
