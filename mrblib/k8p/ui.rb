module K8P
  class BasicUi
    attr_accessor :level
    def initialize level = 0
      @level = level
    end

    def output message
      puts "#{message}"
    end

    def error message
      STDERR.puts "#{Rainbow(message).red}"
    end

    def debug message, level = 1
      return unless @level >= level
      STDERR.puts "debug: #{message.strip.gsub(/\n/, "\ndebug: ")}"
    end
  end
end
