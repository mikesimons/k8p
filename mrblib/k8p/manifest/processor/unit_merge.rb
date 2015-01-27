module K8P
	module Manifest
		module Processor
			# FIXME a manifest loader should be has_a not an is_a
			class UnitMerge < LoadManifest
				def initialize local_dir, default_repository, var_catalog
					@dir = local_dir
					@repository = default_repository.gsub(/\/+$/, '')
					@var_catalog = var_catalog
				end

				def process data
					if data['units']
						data['units'].each do |unit_name, unit|
							type = unit['type'] || unit_name

							candidates = [
								File.expand_path("#{@dir}/units/#{type}.yml"),
								"#{data['_repository'] || @repository}/#{type}.yml"
							]

							unit_definition = load(type, candidates)
							
							data['units'][unit_name] = unit_definition.deep_merge(unit || {})
						end
					end
					data
				end
			end
		end
	end
end