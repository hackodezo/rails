# frozen_string_literal: true

require "abstract_unit"
require "active_support/encrypted_configuration"

class EncryptedConfigurationTest < ActiveSupport::TestCase
  setup do
    @credentials_config_path = File.join(Dir.tmpdir, "credentials.yml.enc")
    
    @credentials_key_path = File.join(Dir.tmpdir, "credentials.yml.key")
    File.write(@credentials_key_path, ActiveSupport::EncryptedConfiguration.generate_key)

    @credentials = ActiveSupport::EncryptedConfiguration.new \
      config_path: @credentials_config_path, key_path: @credentials_key_path, env_key: 'RAILS_CREDENTIALS_KEY'
  end

  teardown do
    FileUtils.rm_rf @credentials_config_path
    FileUtils.rm_rf @credentials_key_path
  end

  test "reading configuration by env key" do
    FileUtils.rm_rf @credentials_key_path

    begin
      ENV["RAILS_CREDENTIALS_KEY"] = ActiveSupport::EncryptedConfiguration.generate_key
      @credentials.write({ something: { good: true, bad: false }}.to_yaml)

      assert @credentials[:something][:good]
      assert_not @credentials.dig(:something, :bad)
      assert_nil @credentials.fetch(:nothing, nil)
    ensure 
      ENV["RAILS_CREDENTIALS_KEY"] = nil
    end
  end

  test "reading configuration by key file" do
    @credentials.write({ something: { good: true }}.to_yaml)

    assert @credentials[:something][:good]
  end

  test "change configuration by key file" do
    @credentials.write({ something: { good: true }}.to_yaml)
    @credentials.change do |config_file|
      config = YAML.load(config_file.read)
      config_file.write config.merge(new: "things").to_yaml
    end

    assert @credentials[:something][:good]
    assert_equal "things", @credentials[:new]
  end

  test "change configuration and save it by key file" do
    @credentials[:something] = "neat"
    @credentials.save
    
    reloaded_config = new_credentials_configuration

    assert_equal "neat", reloaded_config[:something]
  end

  test "change JSON configuration" do
    json_config = new_credentials_configuration serializer: :json

    json_config[:something] = "nice"
    json_config.save

    reloaded_json_configuration = new_credentials_configuration serializer: :json

    assert_equal "nice", json_config[:something]
  end

  private
    def new_credentials_configuration(serializer: :yaml)
      ActiveSupport::EncryptedConfiguration.new \
        config_path: @credentials_config_path,
        key_path: @credentials_key_path,
        env_key: 'RAILS_CREDENTIALS_KEY',
        serializer: serializer
    end
end