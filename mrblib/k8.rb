module K8
	module Preprocessor

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

		# Move any unknown attributes on services to annotations
		class ServiceAnnotations
			def process data
				(data['_services'] || {}).each do |k, v|
					annotate = v.clone
					new_v = {}
					['port', 'labels', 'selector', 'annotations'].each do |key|
						annotate.delete key
						new_v[key] = v[key] if v[key]
					end

					data['_services'][k] = v.deep_merge({
						'annotations' => annotate
					})
				end

				data
			end
		end
	end
end

module K8
	module Manifest
		module Parser
			def self.get target
				if target =~ /(\.yml|\.yaml)$/
					return Yaml.new target
				else
					raise "Unsupported manifest format"
				end
			end

			class Yaml
				def initialize data
					@data = data
					@vars = {}
				end

				def parse
					YAML::load(@data)
				end

				def vars
					return @vars if @vars.length > 0
					begin
						final = @data % @vars
					rescue KeyError => e
						key = e.message.gsub(/.*{(.*)}.*/, '\1')
						@vars[key.to_sym] = "%{#{key}}"
						retry
					end
					@vars
				end
			end
		end

		module Loader
			def self.get target
				if target =~ /^https?:/
					return HttpFile.new target
				else
					return File.new target
				end
			end

			class File
				def initialize file
					@file = file
				end

				def load
					File.read @file
				end
			end

			class HttpFile
				def initialize url
					@url = url
				end

				def load
					r = Http.get(@url)

					if r.code != 200
						ui.debug "Unable to fetch #{f}: #{r.code} #{r.body}"
						return nil
					end

					r.body
				end
			end
		end
	end
end

class K8Cfg
	attr_accessor :file, :raw, :parsed, :missing_vars, :preprocessors, :var_map

	def initialize file
		self.file = file
		self.var_map = {}
		# TODO move out of here; process / preprocess is orthogonal to reading / fetching
		self.raw = load_file(file)
		self.parsed, self.missing_vars = populate_vars(raw, spec_vars(raw))
		self.preprocessors = [
			::K8::Preprocessor::ReverseProxyRoutes.new,
			::K8::Preprocessor::ShorthandServices.new,
			::K8::Preprocessor::ServiceAnnotations.new,
			::K8::Preprocessor::NameLabels.new
		]
		ui.debug "Variable map: #{self.var_map}", 2
	end

	def preprocess
		preprocessors.each do |p|
			self.parsed = p.process(self.parsed)
		end
	end

	def process
		services = []
		pods = []
		rcs = []

		# Explicit services
		parsed['_services'].each do |k, v|
			services << ::K8::Service.new(
				v['labels']['name'], # id
				v['port'],           # port
				v['selector'],       # selector
				v['labels'],         # labels
				v['annotations']     # annotations
			)
		end if parsed['_services']

		parsed.each do |k, v|
			next if k[0] == '_'

			containers = if v['containers']
				v['containers'].map do |ck, cv|
					::K8::Container.new(
						cv['labels']['name'], # name
						cv['image'],          # image
						cv['ports'],          # ports
						cv['env'],            # env
						cv['mounts']          # mounts
					)
				end
			end || []

			volumes = if v['volumes']
				v['volumes'].map do |vk, vv|
					::K8::Volume.new(
						vk, # name
						vv  # params
					)
				end
			end || []

			pod = ::K8::Pod.new(
				v['labels']['name'], # id        
				v['labels'],         # labels
				containers,          # containers
				volumes              # volumes
			)

			if v['replicas']
				rcs << ::K8::ReplicationController.new(
					v['labels']['name'], # id
					v['replicas'],       # replicas,
					v['labels'],         # selector,
					v['labels'],         # labels,
					pod                  # pod
				)
			else
				pods << pod
			end
		end

		{
			:pods => pods,
			:replicationControllers => rcs,
			:services => services
		}
	end

	private

	def load_file file
		raw = File.read file
		parsed = YAML::load(raw)

		_, defined_vars = populate_vars(parsed, {})
		defined_vars.each do |v|
			self.var_map[v] ||= []
			self.var_map[v] << file
		end

		if parsed['_inherit']
			inherited = load_file(File.expand_path(File.dirname(file) + "/#{parsed['_inherit']}.yml"))
			parsed = inherited.deep_merge(parsed)
		end

		if parsed['_catalog']
			parsed['_catalog'].each do |service|
				type = parsed[service] && parsed[service]['type'] ? parsed[service]['type'] : service

				repository = parsed['_repository'] || "https://s3-eu-west-1.amazonaws.com/inviqa-hobo/k8"

				manifest_file = find_or_fetch_catalog_type(File.dirname(file), repository, type)
				raise "Missing catalog file: #{type}" if manifest_file.nil?
				ui.debug "Using #{manifest_file} for #{type}"

				catalog_def = load_file(manifest_file)
				parsed[service] = catalog_def.deep_merge(parsed[service] || {})
			end
		end

		parsed
	end

	def find_or_fetch_catalog_type local_dir, repository, type
		opts = [
			File.expand_path("#{local_dir}/catalog/#{type}.yml"),
			File.expand_path("~/.k8/catalog/#{type}.yml"),
			"#{repository.gsub(/\/+$/, '')}/#{type}.yml"
		]

		opts.each do |f|
			if f =~ /^https?:/
				ui.debug("Attempting to fetch #{f} for #{type}")
				r = Http.get(f)

				if r.code != 200
					ui.debug "Unable to fetch #{f}: #{r.code} #{r.body}"
					next
				end

				dir = File.expand_path("~/.k8/catalog")
				file = "#{dir}/#{type}.yml"
				FileUtils.mkdir_p(dir)
				File.write(file, r.body)
				return file
			end

			return f if File.exist? f
		end

		return nil
	end

	def populate_vars parsed, vars
		missing = []
		final = YAML::dump(parsed)
		
		begin
			final = final % vars
		rescue KeyError => e
			key = e.message.gsub(/.*{(.*)}.*/, '\1')
			missing << key
			ui.warn "Missing a variable definition for #{key}"
			vars[key.to_sym] = "%{#{key}}"
			retry
		end

		[ YAML::load(final), missing ]
	end

	def spec_vars yaml
		out = {}
		ENV.keys.each do |k|
			out[k.to_sym] = ENV[k]
		end

		return out unless yaml['_vars']

		yaml.each do |k,v|
			next unless k[0] == '_'
			next if v.is_a? Hash or v.is_a? Array
			out[k.gsub(/^_/, '').to_sym] = v
		end

		yaml['_vars'].each do |k,v|
			out[k.to_sym] = v
		end

		return out
	end
end

class Event
	def self.trigger handle, *args
		((@listeners || {})[handle] || []).each do |l|
			l.send handle, *args
		end
	end

	def self.register handle, listener
		@listeners ||= {}
		@listeners[handle] ||= []
		@listeners[handle] << listener
		@listeners[handle].uniq!
	end
end

class String
	def highlight
		Rainbow(self).green
	end
end

class BasicUi
	attr_accessor :level
	def initialize level = 0
		@level = level
	end

	def service_list services
		return unless services.length > 0
		mapped_services = services.map do |service|
			service.is_a?(Hash) ? service['id'] : service.id
		end
		Event.trigger('output', "Services:".highlight + " #{mapped_services}")
	end

	def rc_list rcs
		return unless rcs.length > 0
		mapped_rcs = rcs.map do |rc|
			rc.is_a?(Hash) ? rc['id'] : rc.id
		end
		Event.trigger('output', "RCs:".highlight + " #{mapped_rcs}")
	end

	def pod_list pods
		return unless pods.length > 0
		mapped_pods = pods.map do |pod|
			pod.is_a?(Hash) ? pod['id'] : pod.id
		end
		Event.trigger('output', "Pods:".highlight + " #{mapped_pods}")
	end

	def output message
		puts "#{message}"
	end

	def error message
		STDERR.puts "#{Rainbow(message).red}"
	end

	def debug message, level = 1
		return unless @level >= level
		STDERR.puts "debug: #{message.strip.gsub(/\n/, "\ndebug: ")}"
	end
end

class EventProxy
	def method_missing method, *args, &block
		Event.trigger method.to_s, *args
	end
end

def ui
	EventProxy.new
end

def exec purpose, cmd
	ui.debug purpose
	ui.debug cmd, 2
	output = `#{cmd}`
	ui.debug "  " + output.strip.gsub(/\n/, "\n  "), 3
	return output
end

def main
	basic_ui = BasicUi.new

	Event.register 'service_list', basic_ui
	Event.register 'pod_list', basic_ui
	Event.register 'rc_list', basic_ui
	Event.register 'output', basic_ui
	Event.register 'error', basic_ui
	Event.register 'debug', basic_ui

	Slop.parse do
		on :v, :version, "Display version" do
			ui.output "k8 v0.0.1"
			exit 0
		end

		command "start" do
			on :'dry-run'
			on :'file='
			on :debug= do |v|
				basic_ui.level = v.to_i
			end

			run do |opts, args|
				ui.debug("Running apply task")
				ui.debug("Opts: #{opts.to_hash}")
				ui.debug("Args: #{args}")

				file = opts[:file] || 'k8.yml'
				resolved_file = File.expand_path(file)

				unless File.exists? resolved_file and File.stat(resolved_file).readable?
					ui.error "Invalid or unreadable k8 manifest file: #{resolved_file}"
					exit 1
				end

				cfg = K8Cfg.new(file)

				cfg.preprocess

				ui.debug YAML::dump(cfg.parsed), 3

				data = cfg.process

				if cfg.missing_vars.length > 0
					ui.error ""
					ui.error "There are missing (required) variables:"
					cfg.missing_vars.each do |v|
						ui.error "  #{v} is required by #{cfg.var_map[v].join(', ')}"
					end
					ui.error "Please define them in the _vars key in #{file} before continuing"
					exit 1
				end

				ui.service_list data[:services]
				ui.pod_list data[:pods]
				ui.rc_list data[:replicationControllers]

				list = data[:pods].map(&:to_kube) + data[:services].map(&:to_kube) + data[:replicationControllers].map(&:to_kube)

				ui.output "Applying..."
				list.each do |l|
					content = JSON::stringify(l).gsub(/\\\//, '/')
					ui.debug "Pushing to kubectl: #{content}", 3

					unless opts[:'dry-run']
						File.write("/tmp/k8", content)
						exec(
							"Pushing config to kubernetes",
							"cat /tmp/k8 | kubectl -n#{cfg.parsed['_project']} create -f -"
						)
					end
				end
			end
		end

		command "stop" do
			on :labels=
			
			run do |opts, args|
				cfg = K8Cfg.new(args.first)
				namespace = "-ns '#{cfg.parsed['_project']}'"
				label = "-l '#{opts[:labels]}'" if opts[:labels]

				rcs_json = exec(
					"Retrieving list of ReplicationControllers",
					"kubecfg #{namespace} -json #{label} list replicationControllers"
				)
				rcs = JSON::parse(rcs_json)['items'] || []

				ui.rc_list rcs
				rcs.each do |r|
					ui.output "Stopping #{r['id']}"
					exec(
						"Stopping replication controller '#{r['id']}'",
						"kubecfg #{namespace} stop #{r['id']}"
					)
					exec(
						"Removing replication controller '#{r['id']}'",
						"kubecfg #{namespace} rm #{r['id']}"
					)
				end

				exec "Stalling for replication controller shutdown", "sleep 2"

				services_json = exec(
					"Retrieving list of Services",
					"kubecfg #{namespace} -json #{label} list services"
				)
				services = JSON::parse(services_json)['items'] || []

				pods_json = exec(
					"Retrieving list of Pods",
					"kubecfg #{namespace} -json #{label} list pods"
				)
				pods = JSON::parse(pods_json)['items'] || []

				services.reject! do |s|
					s['id'] =~ /kubernetes/
				end

				ui.pod_list pods
				ui.service_list services

				services.each do |s|
					ui.output "Stopping #{s['id']}"
					exec(
						"Stopping service #{s['id']}",
						"kubecfg #{namespace} delete services/#{s['id']}"
					)
				end

				pods.each do |p|
					ui.output "Stopping #{p['id']}"
					exec(
						"Stopping pod #{p['id']}",
						"kubecfg #{namespace} delete pods/#{p['id']}"
					)
				end
			end
		end
	end
end
#$logger = Logger.new STDERR
#$logger.level = Logger::INFO
#$logger.formatter = lambda { |l1, l2, l3, l4| "#{l1} => #{l4}\n"}
#k8 = K8MiniCfgApp.new ARGV[1]
#k8.run ARGV[0]


# $ k8 apply
# => Services: inviqa.com, mysql
# => ReplicationControllers: inviqa.com (silverstripe), mysql
# => Applying

# $ k8 kill
# => Services: inviqa.com, mysql
# => ReplicationControllers: inviqa.com (silverstripe), mysql
# => Killing...

# $ k8 update --services=mysql
# => Service: mysql
# => 
