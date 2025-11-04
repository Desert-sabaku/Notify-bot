require "googleauth/stores/file_token_store"

module Syodosima
  # In-memory token store that reads from environment variables
  # This replaces FileTokenStore to avoid managing token.yaml files
  class MemoryTokenStore
    # Initialize the memory token store
    #
    # @param [Hash] _options initialization options (unused, for compatibility)
    def initialize(_options = {})
      @tokens = {}
      load_from_env
    end

    # Load a token from the store
    #
    # @param [String] id token identifier
    # @return [String, nil] the stored token or nil
    def load(id)
      @tokens[id]
    end

    # Store a token
    #
    # @param [String] id token identifier
    # @param [String] token the token data to store
    # @return [void]
    def store(id, token)
      @tokens[id] = token
    end

    # Delete a token from the store
    #
    # @param [String] id token identifier
    # @return [void]
    def delete(id)
      @tokens.delete(id)
    end

    private

    # Load token from environment variable if available
    #
    # @return [void]
    def load_from_env
      # Try base64 encoded version first
      if ENV["GOOGLE_TOKEN_YAML_BASE64"] && !ENV["GOOGLE_TOKEN_YAML_BASE64"].empty?
        load_base64_token
      elsif ENV["GOOGLE_TOKEN_YAML"] && !ENV["GOOGLE_TOKEN_YAML"].empty?
        load_plain_token
      end
    end

    # Load and decode base64 encoded token
    #
    # @return [void]
    def load_base64_token
      require "base64"
      require "yaml"
      decoded = Base64.strict_decode64(ENV["GOOGLE_TOKEN_YAML_BASE64"])
      data = YAML.safe_load(decoded, permitted_classes: [Symbol])
      @tokens.merge!(data) if data.is_a?(Hash)
    rescue StandardError => e
      warn "Warning: Failed to load token from GOOGLE_TOKEN_YAML_BASE64: #{e.message}"
    end

    # Load plain YAML token
    #
    # @return [void]
    def load_plain_token
      require "yaml"
      data = YAML.safe_load(ENV["GOOGLE_TOKEN_YAML"], permitted_classes: [Symbol])
      @tokens.merge!(data) if data.is_a?(Hash)
    rescue StandardError => e
      warn "Warning: Failed to load token from GOOGLE_TOKEN_YAML: #{e.message}"
    end
  end
end
