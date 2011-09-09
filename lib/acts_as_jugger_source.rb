require 'juggernaut'

module ::Acts #:nodoc:
  module JuggerSource #:nodoc:
    module ClassMethods #:nodoc:
      def acts_as_jugger_source(options = {}, &block)
        return if self.respond_to? :jugger_channel
        cattr_accessor :jugger_channel, :jugger_block, :jugger_callbacks

        self.jugger_channel = options[:channel] || name
        self.jugger_block = block_given? ? block : nil
        self.jugger_callbacks = [:create, :save, :destroy].select{|x| (x if options[:operations].include? x rescue x)}

        log_with self, :debug, "GESPRO, #{self} acting as a juggernaut source in channel #{self.jugger_channel}, operations: #{self.jugger_callbacks.inspect}"

        # Register the callbacks :nodoc:
        class_eval do
          after_create :acts_as_jugger_after_create if self.jugger_callbacks.include? :create
          after_update :acts_as_jugger_after_save if self.jugger_callbacks.include? :save
          after_destroy :acts_as_jugger_after_destroy if self.jugger_callbacks.include? :destroy
        end

        # Generate the callback instance methods.
        klazz = self
        [:save, :create, :destroy].each do |which|
          class_eval <<-EOF
            def acts_as_jugger_after_#{which}(*args)
              instance = args[0] || self
              begin
                #{klazz}.send :jugger_send_notification, :#{which}, instance
              rescue Exception => e
                ::Logger.new(STDOUT).error "JUGGER ERROR: "+e.message+"\n\t"+(e.backtrace.join('\n\t') rescue '')
              end
              true # To make sure the rest of callbacks are called!
            end
          EOF
        end
      end

      def build_jugger_event(operation, model, instance)
        {:operation => operation, :model => model, :instance => instance}
      end

      private

      def jugpublish(channels, data)
        Juggernaut.publish(channels, data)
      end

      def log_with instance, severity, *args
        ::Logger.new(STDOUT).debug *args
        jugpublish("acts_as_jugger_source.#{severity}", args[0]) if [:warning, :error].include? severity rescue nil

        if instance.respond_to? :logger and instance.logger.respond_to? severity
          instance.logger.send severity, *args
        else
          ::Logger.new(STDOUT).send severity, *args rescue nil
        end
      end

      def jugger_send_notification operation, instance
        channel = self.jugger_channel
        operation = :create if instance.new_record?
        payload = {}
        specs = self.instance_exec(operation, instance.class, instance, &self.jugger_block) if self.jugger_block
        specs ||= build_jugger_event(operation, instance.class, instance)
        if specs.is_a? Hash
          specs = [specs]
        end
        specs.each do |spec|
          begin
            payload[:operation] = (spec[:operation] rescue nil) || operation
            payload[:model] = (spec[:model].name rescue nil) || self.name
            payload[:instance] = (spec[:instance] rescue nil) || instance
            jugpublish(channel, payload)
          rescue Exception => e
            # Try to isolate several notifications
            log_with instance, :error, "JUGGER ERROR: #{e.message}. #{e.backtrace.inspect}"
          end
        end
      rescue Exception => e
        # Avoid nilly-willy exceptions but log them
        log_with instance, :error, "JUGGER ERROR: #{e.message}. #{e.backtrace.inspect}"
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end

  end
end
