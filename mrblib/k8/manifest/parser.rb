module K8
	module Manifest
		module Parser
			def self.get target
				if target =~ /(\.yml|\.yaml)$/
					return Yaml.new
				else
					raise ::K8::Exception::UnsupportedManifestFormat.new(target)
				end
			end
		end
	end
end