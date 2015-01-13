module K8
	module Exception
		class MissingVariables < ::Exception
			attr_accessor :vars
			def initialize vars
				@vars = vars
				super("Some variables required have not been defined")
			end

			def message_with_catalog var_catalog
				"#{self.message}:\n" + @vars.map do |v|
					"  #{v} - #{var_catalog.vars[v].join(', ')}"
				end.join("\n")
			end
		end

		class MissingManifest < ::Exception
			attr_reader :type, :candidates
			def initialize type, candidates
				@type = type
				@candidates = candidates
				
				super(
					"The '#{type}' manifest could not be found among:\n" +
					(@candidates.map { |c| "  #{c}"}.join(', '))
				)
			end
		end

		class UnsupportedManifestFormat < ::Exception
			attr_reader :target
			def initialize target
				@target = target
				super("K8 does not know how to parse '#{target}'")
			end
		end
	end
end