module K8P
	module Manifest
		module Processor
			# Convert 'routes' entry in to a service w/ reverse-proxy-hosts annotations
			class ReverseProxyRoutes
				def process data
					(data['units'] || {}).each do |k, v|
						next unless v['routes'] || v['secure_routes']

						annotations = {}
						annotations['routes'] = v['routes']if v['routes']
						annotations['secure_routes'] = v['secure_routes'] if v['secure_routes']

						data.deep_merge({
							'units' => {
								k => {
									'labels' => {
										'route' => "#{k}-route"
									}
								},
							},
							'services' => {
								"#{k}-service" => {
									'port' => 80,
									'selector' => { 'route' => "#{k}-route" },
									'annotations' => annotations
								}
							}
						})
						v.delete 'routes'
						v.delete 'secure_routes'
					end

					data
				end
			end
		end
	end
end