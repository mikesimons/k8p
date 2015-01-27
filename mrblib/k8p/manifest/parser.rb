module K8P
  module Manifest
    module Parser
      def self.get target
        if target =~ /(\.yml|\.yaml)$/
          return Yaml.new
        else
          raise ::K8P::Exception::UnsupportedManifestFormat.new(target)
        end
      end
    end
  end
end
