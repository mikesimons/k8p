module K8P
  module Manifest
    module Parser
      class Yaml
        def parse data
          ::YAML::load(data)
        end

        def vars data
          v = {}
          begin
            final = data % v
          rescue KeyError => e
            key = e.message.gsub(/.*{(.*)}.*/, '\1')
            v[key.to_sym] = "%{#{key}}"
            retry
          end
          v
        end
      end
    end
  end
end
