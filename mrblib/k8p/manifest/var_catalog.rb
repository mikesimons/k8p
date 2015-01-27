module K8P
	module Manifest
		class VarCatalog
			attr_reader :vars

			def initialize vars = {}
				@vars = vars
			end

			def add file, vars
				vars.keys.each do |v|
					@vars[v.to_s] ||= []
					@vars[v.to_s] << file
				end
			end
		end
	end
end

