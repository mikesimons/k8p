module K8
	module Manifest
		module Processor
			# FIXME a manifest loader should be has_a not an is_a
			class CatalogMerge < LoadManifest
				def initialize local_dir, default_repository, var_catalog
					@dir = local_dir
					@repository = default_repository.gsub(/\/+$/, '')
					@var_catalog = var_catalog
				end

				def process data
					if data['_catalog']
						data['_catalog'].each do |service|
							type = ::NilHash.wrap(data)[service]['type'].unwrap
							type ||= service

							candidates = [
								File.expand_path("#{@dir}/catalog/#{type}.yml"),
								"#{data['_repository'] || @repository}/#{type}.yml"
							]

							catalog_def = load(type, candidates)
							
							data[service] = catalog_def.deep_merge(data[service] || {})
						end
					end
					data
				end
			end
		end
	end
end