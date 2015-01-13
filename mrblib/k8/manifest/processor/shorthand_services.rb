module K8
	module Manifest
		module Processor
			# Convert shorthand services in to long form
			class ShorthandServices
				def process data
					data.each do |k, v|
						next if k[0] == '_'
						next unless v['service']

						data.deep_merge({
							k => {
								'labels' => {
									'service' => "#{k}-service-#{v['service']}"
								}
							},
							'_services' => {
								"#{k}-service" => {
									'port' => v['service'],
									'selector' => { 'service' => "#{k}-service-#{v['service']}" }
								}
							}
						})
					end

					data
				end
			end
		end
	end
end