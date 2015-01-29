module K8P
  module Manifest
    module Processor
      class PopulateVars
        def process data
          vars = spec_vars(data)
          missing = []
          data_as_string = YAML::dump(data)

          begin
            data_as_string = data_as_string % vars
          rescue KeyError => e
            key = e.message.gsub(/.*{(.*)}.*/, '\1')
            missing << key
            vars[key.to_sym] = "%{#{key}}"
            retry
          end

          raise ::K8P::Exception::MissingVariables.new(missing) if missing.length > 0

          YAML::load(data_as_string)
        end

        def spec_vars data
          out = {}

          ## TODO pass this in to init and merge as generic source
          ENV.keys.each do |k|
            next unless k =~ /^K8P_/
            out[k.gsub(/^K8P_/, '').downcase.to_sym] = ENV[k]
          end

          return out unless data['metadata']
          return data['metadata'].to_dotted_hash.deep_merge(out)
        end
      end
    end
  end
end
