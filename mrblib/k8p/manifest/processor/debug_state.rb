module K8P
	module Manifest
		module Processor
			class DebugState
				def initialize label, level
					@label = label
					@level = level
				end

				def process data
					# We need to duplicate the ui.level check here as YAML::dump is really expensive
					ui.debug "\n#{@label}\n#{YAML::dump(data)}\n", @level if @level > ui.level
					data
				end
			end
		end
	end
end