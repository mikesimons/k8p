module K8
	module Manifest
		module Processor
			class DebugState
				def initialize label, level
					@label = label
					@level = level
				end

				def process data
					ui.debug "\n#{@label.highlight}\n#{YAML::dump(data)}\n", @level
					data
				end
			end
		end
	end
end