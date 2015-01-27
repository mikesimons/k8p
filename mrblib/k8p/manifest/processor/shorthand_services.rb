module K8P
	module Manifest
		module Processor
			# Convert shorthand services in to long form
			class ShorthandServices
				def process data
					(data['units'] || {}).each do |k, v|
						next unless v['service']

						data.deep_merge({
							'units' => {
								k => {
									'labels' => {
										'service' => "#{k}-service-#{v['service']}"
									}
								},
							},
							'services' => {
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