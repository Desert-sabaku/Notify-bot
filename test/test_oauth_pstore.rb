require_relative "test_helper"

class FakePStoreError < StandardError
  # purposely name the class like PStore::Error for detection
  def self.name
    "PStore::Error"
  end
end

class TestOauthPStoreHandling < Minitest::Test
  include TestHelper

  def setup
    setup_env_vars
    # ensure token path used by config is a temp file in the project dir
    @token_path = Syodosima::TOKEN_PATH
    # ensure no token file exists before test
    File.delete(@token_path) if File.exist?(@token_path)
  end

  def teardown
    cleanup_env_vars
    File.delete(@token_path) if File.exist?(@token_path)
    # also cleanup any backups
    Dir.glob("#{@token_path}.*.bak").each { |f| File.delete(f) }
  end

  def test_corrupted_token_file_is_backed_up_and_deleted_non_ci
    # Create a dummy token file to simulate a corrupted store
    File.write(@token_path, "corrupted")

    # Mock authorizer to raise a PStore-like error on first get_credentials call
    mock_authorizer = Object.new
    def mock_authorizer.get_credentials(_user_id)
      raise FakePStoreError, "PStore file seems to be corrupted."
    end

    Google::Auth::ClientId.stub :from_file, Object.new do
      Google::Auth::Stores::FileTokenStore.stub :new, Object.new do
        Google::Auth::UserAuthorizer.stub :new, mock_authorizer do
          # capture backup attempts via File.rename or FileUtils.cp
          backups = []
          File.stub :rename, ->(_src, dest) { backups << dest } do
            require "fileutils"
            FileUtils.stub :cp, ->(_src, dest) { backups << dest } do
              # Run authorize; it will attempt to backup/delete and then raise because we don't implement full retry
              begin
                Syodosima.authorize
              rescue StandardError
                # ignore subsequent errors from flow; we just want to assert backup occurred
              end
              # Expect that a backup file was created
              assert_operator backups.size, :>, 0
              assert_match(/#{Regexp.escape(@token_path)}\.[0-9]{14}\.bak\z/, backups.first)
            end
          end
        end
      end
    end
  end

  def test_corrupted_token_file_in_ci_raises_no_delete
    # simulate CI environment
    ENV["CI"] = "true"

    File.write(@token_path, "corrupted")

    mock_authorizer = Object.new
    def mock_authorizer.get_credentials(_user_id)
      raise FakePStoreError, "PStore file seems to be corrupted."
    end

    Google::Auth::ClientId.stub :from_file, Object.new do
      Google::Auth::Stores::FileTokenStore.stub :new, Object.new do
        Google::Auth::UserAuthorizer.stub :new, mock_authorizer do
          deleted = []
          File.stub :delete, ->(path) { deleted << path } do
            err = assert_raises(StandardError) { Syodosima.authorize }
            assert_match(/CI 上では対話認証ができません/, err.message)
            assert_equal [], deleted
          end
        end
      end
    end
  ensure
    ENV.delete("CI")
  end
end
