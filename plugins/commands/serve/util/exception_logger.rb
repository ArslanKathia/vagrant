module VagrantPlugins
  module CommandServe
    module Util
      # Adds exception logging to all public instance methods
      module ExceptionLogger
        prepend Util::HasMapper

        def self.included(klass)
          # Get all the public instance methods. Need to search ancestors as well
          # for modules like the Guest service which includes the CapabilityPlatform
          # module
          klass_public_instance_methods = klass.public_instance_methods
          # Remove all generic instance methods from the list of ones to modify
          logged_methods = klass_public_instance_methods - Object.public_instance_methods
          logged_methods.each do |m_name|
            klass.define_method(m_name) do |*args, **opts, &block|
              begin
                super(*args, **opts, &block)
              rescue => err
                proto = Google::Rpc::Status.new(
                  code: GRPC::Core::StatusCodes::UNKNOWN, 
                  message: "#{err.message}\n#{err.backtrace.join("\n")}",
                  details: [mapper.map(err.message, to: Google::Protobuf::Any)]
                )
                encoded_proto = Google::Rpc::Status.encode(proto)
                grpc_status_details_bin_trailer = 'grpc-status-details-bin'
                grpc_error = GRPC::BadStatus.new(
                  GRPC::Core::StatusCodes::UNKNOWN,
                  err.message,
                  {grpc_status_details_bin_trailer => encoded_proto},
                )

                if self.respond_to?(:logger)
                  # logger.error(err.message)
                  # logger.debug("#{err.class}: #{err}\n#{err.backtrace.join("\n")}")
                  logger.debug("status: #{grpc_error.to_status}")
                  logger.debug("rpc status: #{grpc_error.to_rpc_status}")
                end

                raise grpc_error
              end
            end
          end
        end
      end
    end
  end
end
