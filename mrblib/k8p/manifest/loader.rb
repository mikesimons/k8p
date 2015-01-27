module K8P
  module Manifest
    module Loader
      def self.get target
        if target =~ /^https?:/
          return HttpFile.new(target)
        else
          return File.new(target)
        end
      end
    end
  end
end
