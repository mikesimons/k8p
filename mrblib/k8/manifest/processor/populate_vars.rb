module K8
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

					raise ::K8::Exception::MissingVariables.new(missing) if missing.length > 0

					YAML::load(data_as_string)
				end

				def spec_vars data
					out = {}

					## TODO pass this in to init and merge as generic source
					ENV.keys.each do |k|
						next unless k =~ /^K8_/
						out[k.gsub(/^K8_/, '').to_sym] = ENV[k]
					end

					return out unless data['_vars']

					data.each do |k,v|
						next unless k[0] == '_'
						next if v.is_a? Hash or v.is_a? Array
						out[k.gsub(/^_/, '').to_sym] = v
					end

					(data['_vars'] || {}).each do |k,v|
						out[k.to_sym] = v
					end

					return out
				end
			end
		end
	end
end