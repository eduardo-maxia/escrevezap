module Inter
  class TokenManager
    include Loggable

    TOKEN_CACHE_DIR = Rails.root.join("tmp", "inter_tokens")

    class << self
      # List all cached tokens with their status
      def list_cached_tokens
        ensure_cache_directory

        tokens = []

        Dir.glob(TOKEN_CACHE_DIR.join("*_token.json")).each do |file_path|
          begin
            token_data = JSON.parse(File.read(file_path))
            scope = token_data["scope"]
            expires_at = Time.parse(token_data["expires_at"])
            is_expired = expires_at <= Time.current

            tokens << {
              scope: scope,
              file: File.basename(file_path),
              expires_at: expires_at,
              expired: is_expired,
              created_at: Time.parse(token_data["created_at"])
            }
          rescue => e
            Rails.logger.warn "Failed to parse token file #{file_path}: #{e.message}"
          end
        end

        tokens.sort_by { |t| t[:scope] }
      end

      # Clear all cached tokens
      def clear_all_tokens
        ensure_cache_directory

        count = 0
        Dir.glob(TOKEN_CACHE_DIR.join("*_token.json")).each do |file_path|
          File.delete(file_path)
          count += 1
        end

        Rails.logger.info "Cleared #{count} cached tokens"
        count
      end

      # Clear expired tokens only
      def clear_expired_tokens
        ensure_cache_directory

        count = 0
        Dir.glob(TOKEN_CACHE_DIR.join("*_token.json")).each do |file_path|
          begin
            token_data = JSON.parse(File.read(file_path))
            expires_at = Time.parse(token_data["expires_at"])

            if expires_at <= Time.current
              File.delete(file_path)
              count += 1
              Rails.logger.info "Deleted expired token for scope: #{token_data['scope']}"
            end
          rescue => e
            Rails.logger.warn "Failed to process token file #{file_path}: #{e.message}"
            # Delete corrupted files
            File.delete(file_path)
            count += 1
          end
        end

        Rails.logger.info "Cleared #{count} expired/corrupted tokens"
        count
      end

      # Clear token for specific scope
      def clear_scope_token(scope)
        ensure_cache_directory

        file_name = "#{scope.gsub('.', '_')}_token.json"
        file_path = TOKEN_CACHE_DIR.join(file_name)

        if File.exist?(file_path)
          File.delete(file_path)
          Rails.logger.info "Cleared token for scope: #{scope}"
          true
        else
          Rails.logger.warn "No token found for scope: #{scope}"
          false
        end
      end

      # Get token info for specific scope
      def token_info(scope)
        ensure_cache_directory

        file_name = "#{scope.gsub('.', '_')}_token.json"
        file_path = TOKEN_CACHE_DIR.join(file_name)

        return nil unless File.exist?(file_path)

        begin
          token_data = JSON.parse(File.read(file_path))
          expires_at = Time.parse(token_data["expires_at"])

          {
            scope: scope,
            expires_at: expires_at,
            expired: expires_at <= Time.current,
            created_at: Time.parse(token_data["created_at"]),
            time_until_expiry: expires_at - Time.current
          }
        rescue => e
          Rails.logger.error "Failed to read token info for scope #{scope}: #{e.message}"
          nil
        end
      end

      # Check if we have valid tokens for all scopes
      def check_all_scopes_status
        scopes = [ "webhook.read", "webhook.write", "pix.read", "cob.write", "extrato.read", "rec.read", "rec.write", "payloadlocationrec.write" ]

        scopes.map do |scope|
          info = token_info(scope)
          {
            scope: scope,
            has_token: !info.nil?,
            valid: info && !info[:expired]
          }
        end
      end

      private

      def ensure_cache_directory
        FileUtils.mkdir_p(TOKEN_CACHE_DIR) unless Dir.exist?(TOKEN_CACHE_DIR)
      end
    end
  end
end
