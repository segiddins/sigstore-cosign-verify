module Sigstore
  module Internal
    class Key
      def self.read(key_type, schema, key_bytes, key_id: nil)
        case key_type
        when "ecdsa", "ecdsa-sha2-nistp256"
          key = OpenSSL::PKey.read(key_bytes)
          EDCSA.new(key_type, schema, key, key_id: key_id)
        when "rsa"
          key = OpenSSL::PKey.read(key_bytes)
          RSA.new(key_type, schema, key, key_id: key_id)
        else
          raise ArgumentError, "Unsupported key type #{key_type}"
        end.tap do |key|
          if RUBY_ENGINE == "jruby" && key.to_pem != key_data && key.to_der != key_data
            raise "Key mismatch: #{key.to_pem.inspect} != #{key_data.inspect}"
          end
        end
      end

      attr_reader :key_type, :schema, :key_id

      def initialize(key_type, schema, key, key_id: nil)
        @key_type = key_type
        @key = key
        @schema = schema
        @key_id = key_id
      end

      def to_pem
        @key.to_pem
      end

      def to_der
        @key.to_der
      end

      def verify(algo, signature, data)
        @key.verify(algo, signature, data)
      end

      class EDCSA < Key
        def initialize(...)
          super
          unless @key_type == "ecdsa" || @key_type == "ecdsa-sha2-nistp256"
            raise ArgumentError,
                  "key_type must be edcsa, given #{@key_type}"
          end
          raise ArgumentError, "key must be an OpenSSL::PKey::EC" unless @key.is_a?(OpenSSL::PKey::EC)
          raise ArgumentError, "schema must be #{schema}" unless @schema == schema

          case @schema
          when "ecdsa-sha2-nistp256"
            unless @key.group.curve_name == "prime256v1"
              raise ArgumentError, "Expected prime256v1 curve, got #{key.group.curve_name}"
            end
          else
            raise ArgumentError, "Unsupported schema #{schema}"
          end
        end
      end

      class RSA < Key
        def initialize(...)
          super
          raise ArgumentError, "key_type must be rsa, given #{@key_type}" unless @key_type == "rsa"
          raise ArgumentError, "key must be an OpenSSL::PKey::RSA" unless @key.is_a?(OpenSSL::PKey::RSA)

          case @schema
          when "rsassa-pss-sha256"
          else
            raise ArgumentError, "Unsupported schema #{schema}"
          end
        end

        def verify(_algo, signature, data)
          case @schema
          when "rsassa-pss-sha256"
            @key.verify_pss("sha256", signature, data, salt_length: :auto, mgf1_hash: "SHA256")
          end
        end
      end
    end
  end
end
