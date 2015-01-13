module K8
	module Manifest
		module Processor
			# Convert 'routes' entry in to a service w/ reverse-proxy-hosts annotations
			class ReverseProxyRoutes
				def process data
					data.each do |k, v|
						next if k[0] == '_'
						next unless v['routes']
						data.deep_merge({
							k => {
								'labels' => {
									'route' => "#{k}-route-80"
								}
							},
							'_services' => {
								"#{k}-service" => {
									'port' => 80,
									'selector' => { 'route' => "#{k}-route-80" },
									'annotations' => {
										'reverse-proxy-hosts' => v['routes'],
										'reverse-proxy-ports' => 80
									}
								}
							}
						})
						v.delete 'routes'
					end

					data
				end
			end
		end
	end
end