require "yaml"
require "pathname"
require "tmpdir"
require "uri"

Yast.import "Installation"
Yast.import "Directory"

module Yast
  module ConfigurationManagement
    module Configurations
      # This class inteprets the module configuration
      class Base
        # Default location of the module configuration
        DEFAULT_PATH = Pathname.new("/var/adm/autoinstall/configuration_management.yml")
        # Default value for auth_attempts
        DEFAULT_AUTH_ATTEMPTS = 3
        # Defaull value for auth_time_out
        DEFAULT_AUTH_TIME_OUT = 15

        # @return [String] Provisioner type ("salt" and "puppet" are supported)
        attr_reader :type
        # @return [:client, :masterless] Operation mode
        attr_reader :mode
        # @return [String,nil] Master server hostname
        attr_reader :master
        # @return [Integer] Number of authentication attempts
        attr_reader :auth_attempts
        # @return [Integer] Authentication time out for each authentication attempt
        attr_reader :auth_time_out
        # @return [URI,nil] Keys URL
        attr_reader :keys_url
        # @return [Boolean] CM Services will be enabled on the target system
        attr_reader :enable_services

        class << self
          # @return [Base] Current configuration
          attr_accessor :current

          # Import settings from an AutoYaST profile
          #
          # @param profile [Hash] Configuration management settings from profile
          def import(profile)
            self.current = self.for(profile)
          end

          # Load configuration from a file
          #
          # If not specified, the DEFAULT_PATH is used.
          #
          # @return [Pathname] File path
          # @return [Config] Configuration
          #
          # @see DEFAULT_PATH
          def load(path = DEFAULT_PATH)
            return false unless path.exist?
            content = YAML.load_file(path)
            class_for(content[:type]).new(content)
          end

          def for(config)
            class_for(config["type"]).new(config)
          end

          def class_for(type)
            require "configuration_management/configurations/#{type}"
            Yast::ConfigurationManagement::Configurations.const_get type.capitalize
          rescue NameError, LoadError
            raise "Configuration handler for '#{type}' not found"
          end
        end

        def initialize(options)
          symbolized_opts = Hash[options.map { |k, v| [k.to_sym, v] }]
          @master           = symbolized_opts[:master]
          @mode             = @master ? :client : :masterless
          @keys_url         = URI(symbolized_opts[:keys_url]) if symbolized_opts[:keys_url]
          @auth_attempts    = symbolized_opts[:auth_attempts] || DEFAULT_AUTH_ATTEMPTS
          @auth_time_out    = symbolized_opts[:auth_time_out] || DEFAULT_AUTH_TIME_OUT
          @enable_services  = symbolized_opts[:enable_services] || true
          post_initialize(symbolized_opts)
        end

        def post_initialize(_options)
          nil
        end

        # Return an array of exportable attributes
        #
        # @return [Array<Symbol>] Attribute names
        def attributes
          @attributes ||= %i(type mode master auth_attempts auth_time_out keys_url work_dir
                             enable_services)
        end

        # Save configuration to the given file
        #
        # @param path [Pathname] Path to file
        def save(path = DEFAULT_PATH)
          # The information will be written to inst-sys only. So we do not
          # have to take care about secure data.
          File.open(path, "w+") { |f| f.puts to_hash.to_yaml }
        end

        # Save configuration to target system. Filter out all
        # sensible data.
        # @param path [Pathname] Path to file
        def secure_save(path = DEFAULT_PATH)
          File.open(::File.join(Yast::Installation.destdir, path), "w+") do |f|
            f.puts to_secure_hash.to_yaml
          end
        end

        # Return configuration values in a hash
        #
        # @return [Hash] Configuration values
        def to_hash
          attributes.each_with_object({}) do |key, memo|
            value = send(key)
            memo[key] = value unless value.nil?
          end
        end

        # Return configuration values in a hash but filtering sensible information
        #
        # @return [Hash] Configuration values filtering sensible information.
        def to_secure_hash
          to_hash.reject { |k| k.to_s.end_with?("_url") }
        end

        # Return a path to a temporal directory to extract states/pillars
        #
        # @param  [Symbol] Path relative to inst-sys (:local) or the target system (:target)
        # @return [String] Path name to the temporal directory
        def work_dir(scope = :local)
          @work_dir ||= build_work_dir_name
          prefix = (scope == :target) ? "/" : Installation.destdir
          Pathname.new(prefix).join(@work_dir)
        end

      private

        # Build a path to be used as work_dir
        #
        # @return [Pathname] Relative work_dir path
        def build_work_dir_name
          path = Pathname.new(Directory.vardir).join("cm-#{Time.now.strftime("%Y%m%d%H%M")}")
          path.relative_path_from(Pathname.new("/"))
        end
      end
    end
  end
end
