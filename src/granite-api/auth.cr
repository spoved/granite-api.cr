module Granite::Api
  class Auth
    getter pub_key : String

    def initialize(@pub_key : String); end

    class Unauthorized < Exception; end

    class Unauthenticated < Exception; end

    module ClassMethods
      def authorized?(env)
        token = env.get?("token")
        if token.is_a?(BearerToken)
          raise Unauthorized.new(token.error || "unauthorized") unless token.valid?
        else
          raise Unauthenticated.new
        end
      end

      def unauthenticated_resp(env)
        env.response.status_code = 401
        env.response.close
      end

      def unauthorized_resp(env, msg)
        env.response.status_code = 403
        env.response.print ({code: 403, message: msg}.to_json)
        env.response.close
      end
    end

    extend ClassMethods
  end
end
