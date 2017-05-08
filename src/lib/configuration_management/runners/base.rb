require "yast"
require "pathname"
require "cheetah"

Yast.import "Installation"

module Yast
  module ConfigurationManagement
    module Runners
      # A runner is a class which takes care of using a provisioner (Salt, Puppet, etc.)
      # to configure the system.
      class Base
        include Yast::Logger

        # @return [Configurations::Salt] Configuration object
        attr_reader :config

        class << self
          # Return the runner for a given CM system and a configuration
          def for(config)
            class_for(config.type).new(config)
          end

          # Return the configurator class to handle a given CM system
          #
          # It tries to find the definition.
          #
          # @param type [String] CM type ("salt", "puppet", etc.)
          # @return [Class] Runner class
          def class_for(type)
            require "configuration_management/runners/#{type}"
            Yast::ConfigurationManagement::Runners.const_get type.capitalize
          rescue NameError, LoadError
            raise "Runner for '#{type}' not found"
          end
        end

        # Constructor
        #
        # @param config [Hash] config
        # @option config [Integer] :mode          Operation's mode
        # @option config [Integer] :auth_attempts Number of authentication attempts
        # @option config [Integer] :auth_time_out Authentication time out for each attempt
        def initialize(config)
          log.info "Initializing runner #{self.class.name}"
          @config = config
        end

        # Run the configurator applying the configuration to the system
        #
        # Work is delegated to methods called after the mode: #run_masterless_mode
        # and #run_client_mode.
        #
        # @param stdout [IO] Standard output channel used by the configurator
        # @param stderr [IO] Standard error channel used by the configurator
        #
        # @see run_masterless_mode
        # @see run_client_mode
        def run(stdout = nil, stderr = nil)
          stdout ||= $stdout
          stderr ||= $stderr
          without_zypp_lock do
            send("run_#{config.mode}_mode", stdout, stderr)
          end
        end

      protected

        # Apply the configuration using the CM system
        #
        # To be redefined by inheriting classes.
        #
        # @param stdout [IO] Standard output channel used by the configurator
        # @param stderr [IO] Standard error channel used by the configurator
        #
        # @return [Boolean] true if the configuration was applied; false otherwise.
        def run_client_mode(_stdout, _stderr)
          raise NotImplementedError
        end

        # Apply the configuration using the CM system
        #
        # Configuration is available at #config_tmpdir
        #
        # @param stdout [IO] Standard output channel used by the configurator
        # @param stderr [IO] Standard error channel used by the configurator
        #
        # @return [Boolean] true if the configuration was applied; false otherwise.
        #
        # @see config_tmpdir
        def run_masterless_mode(_stdout, _stderr)
          raise NotImplementedError
        end

      private

        def with_retries(attempts = 1, time_out = nil)
          attempts.times do |i|
            log.info "Running provisioner (try #{i + 1}/#{attempts})"
            return true if yield(i)
            sleep time_out if time_out && i < attempts - 1 # Sleep unless it's the last attempt
          end
          false
        end

        # Run a provisioner command a return a boolean value (success, failure)
        #
        # @return [Boolean] true if command ran successfully; false otherwise.
        def run_cmd(*args)
          args.last[:chroot] = Yast::Installation.destdir
          Cheetah.run(*args)
          true
        rescue Cheetah::ExecutionFailed
          false
        end

        # zypp lock file
        ZYPP_PID = Pathname("/mnt/var/run/zypp.pid")
        # zypp lock backup file
        ZYPP_PID_BACKUP = ZYPP_PID.sub_ext(".save")

        # Run a block without the zypp lock
        #
        # @param [Proc] Block to run
        def without_zypp_lock(&block)
          ::FileUtils.mv(ZYPP_PID, ZYPP_PID_BACKUP) if ZYPP_PID.exist?
          block.call
        ensure
          ::FileUtils.mv(ZYPP_PID_BACKUP, ZYPP_PID) if ZYPP_PID_BACKUP.exist?
        end
      end
    end
  end
end
