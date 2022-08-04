module Granite::Api
  class Auth
    getter scheme_name : String = "bearerAuth"
    getter security_scheme : Open::Api::Security::Scheme = Open::Api::Security::Scheme::HTTPAuth::Bearer.jwt
    getter pub_key : String? = nil

    def initialize(@security_scheme : Open::Api::Security::Scheme = Open::Api::Security::Scheme::HTTPAuth::Bearer.jwt,
                   @scheme_name : String = "bearerAuth",
                   @pub_key : String? = nil); end

    class Unauthorized < Exception; end

    class Unauthenticated < Exception; end

    module ClassMethods
      def authorized?(env, security : Array(Open::Api::Security::Requirement)? = nil)
        return true if ENV["KEMAL_ENV"]? == "test" || ENV["KEMAL_ENV"]? == "development"

        env.response.headers.delete("Cache-Control")

        token = env.get?("token")
        if token.is_a?(BearerToken)
          raise Unauthorized.new(token.error || "unauthorized") unless token.valid?
        else
          raise Unauthenticated.new("unauthenticated")
        end
      end

      def unauthenticated_resp(env)
        env.response.status_code = 401
        env.response.close
      end

      def unauthorized_resp(env, msg)
        env.response.status_code = 403
        env.response.print({code: 403, message: msg}.to_json)
        env.response.close
      end
    end

    extend ClassMethods
  end
end
