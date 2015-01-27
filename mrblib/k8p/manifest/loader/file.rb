module K8P
  module Manifest
    module Loader
      class File
        def initialize file
          @file = file
        end

        def load
          ::File.read @file
        end

        def loadable?
          ::File.exists?(@file) && ::File.stat(@file).readable?
        end

        def target
          @file
        end
      end
    end
  end
end
