require "jwt"

module Granite::Api
  class BearerToken
    getter pub_key : String
    getter token : String
    getter payload : JSON::Any? = nil
    getter header : Hash(String, JSON::Any)? = nil
    getter valid : Bool = false
    getter error : String? = nil

    def initialize(@token : String, @pub_key : String)
      validate unless @token == "null"
    end

    private def validate
      @payload, @header = JWT.decode(@token, @pub_key, JWT::Algorithm::RS256, verify: false, validate: true)
      @valid = true
    rescue ex
      Log.trace { "BearerToken: #{ex}" }
      Log.trace { @token.inspect }
      @error = ex.message
      @valid = false
    end

    def valid?
      @valid
    end

    def uid : String?
      self.payload.nil? ? nil : self.payload.not_nil!["uid"].as_s
    end
  end

  class TokenHandler < Kemal::Handler
    exclude ["/healthz", "/api/v1/swagger.json"]
    getter auth_config : Granite::Api::Auth

    def initialize(@auth_config : Granite::Api::Auth); end

    def call(env)
      return call_next(env) if exclude_match?(env)
      return call_next(env) unless auth_config.security_scheme.is_a?(Open::Api::Security::Scheme::HTTPAuth::Bearer)

      if env.request.headers["Authorization"]? && env.request.headers["Authorization"] =~ /Bearer (.*)/
        token = $1.not_nil!

        env.set "token", BearerToken.new(token, auth_config.pub_key.not_nil!)
      else
        env.set "token", nil
      end

      call_next env
    end
  end
end

add_context_storage_type(Granite::Api::BearerToken)
