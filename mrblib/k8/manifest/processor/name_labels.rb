module K8
	module Manifest
		module Processor
			# Set name=KEY labels on everything by default
			class NameLabels
				def process data
					data.each do |k, v|
						next if k[0] == '_'
						data[k] = apply_name_label(k, v)

						if v['containers']
							v['containers'].each do |ck, cv|
								data[k]['containers'][ck] = apply_name_label(ck, cv)
							end
						end
					end

					(data['_services'] || {}).each do |k, v|
						next if k[0] == '_'
						data['_services'][k] = apply_name_label(k, v)
					end

					data
				end

				def apply_name_label k, v
					v['labels'] ||= {}
					return v if v['labels']['name']
					v['labels']['name'] = k.gsub(/\./, '-')
					v
				end
			end
		end
	end
end