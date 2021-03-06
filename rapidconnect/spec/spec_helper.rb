# frozen_string_literal: true

require 'simplecov'

ENV['RACK_ENV'] = 'test'

require 'bundler'
Bundler.require :default, :test

require 'rack/test'
require 'shoulda/matchers'

Mail.defaults do
  delivery_method :test
end

Sinatra::Base.set :app_root,
                  File.expand_path(File.join(File.dirname(__FILE__), '..'))

Sinatra::Base.set :app_logfile,
                  File.join(settings.app_root, 'logs', 'app-test.log')

Sinatra::Base.set :audit_logfile,
                  File.join(settings.app_root, 'logs', 'audit-test.log')

Sinatra::Base.set :issuer, 'https://rapid.example.org'
Sinatra::Base.set :hostname, 'rapid.example.org'
Sinatra::Base.set :organisations, '/tmp/rspec_organisations.json'
Sinatra::Base.set :federation, 'production'
Sinatra::Base.set :mail, from: 'noreply@example.org', to: 'support@example.org'

Sinatra::Base.set :export, enabled: true
Sinatra::Base.set :export, secret: 'test_secret'

Shoulda::Matchers::ActiveModel::AllowValueMatcher.class_eval do
  alias_method :failure_message_for_should_not, :failure_message_when_negated
end

# Supply common framework actions to tests
module AppHelper
  def app
    RapidConnect
  end

  def session
    last_request.env['rack.session']
  end

  def last_email
    Mail::TestMailer.deliveries[0]
  end

  def flush_stores
    @redis.flushall
    Mail::TestMailer.deliveries.clear
  end

  def flash
    last_request.env['x-rack.flash']
  end
end

FactoryBot.find_definitions

Timecop.safe_mode = true

RSpec.configure do |config|
  config.before { Redis::Connection::Memory.reset_all_databases }

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.order = :random
  Kernel.srand config.seed

  config.include Rack::Test::Methods
  config.include Mail::Matchers
  config.include AppHelper
  config.include FactoryBot::Syntax::Methods
  config.include(Shoulda::Matchers::ActiveModel, type: :model)

  RSpec::Matchers.define_negated_matcher :not_change, :change
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :active_model
  end
end
