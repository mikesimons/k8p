module K8
	module Command
		class PrepareManifest
		end

		class Start
		end

		class Stop
		end

		class Status
		end
	end
end

class K8Cfg
	attr_accessor :file, :data, :processors, :var_catalog

	def initialize file
		@file = File.expand_path(file)
		@default_repository = 'https://s3-eu-west-1.amazonaws.com/inviqa-hobo/k8/'
		@var_catalog = ::K8::Manifest::VarCatalog.new

		@processors = [
			::K8::Manifest::Processor::LoadManifest.new(@file, @var_catalog),
			::K8::Manifest::Processor::CatalogMerge.new(File.dirname(file), @default_repository, @var_catalog),
			::K8::Manifest::Processor::DebugState.new("Merged data", 3),
			::K8::Manifest::Processor::PopulateVars.new,
			::K8::Manifest::Processor::ReverseProxyRoutes.new,
			::K8::Manifest::Processor::ShorthandServices.new,
			::K8::Manifest::Processor::ServiceAnnotations.new,
			::K8::Manifest::Processor::NameLabels.new,
			::K8::Manifest::Processor::DebugState.new("Final data", 4)
		]
	end

	def preprocess
		processors.each do |p|
			self.data = p.process(self.data)
		end
	end

	def process
		services = []
		pods = []
		rcs = []

		# Explicit services
		self.data['_services'].each do |k, v|
			services << ::K8::Service.new(
				v['labels']['name'], # id
				v['port'],           # port
				v['selector'],       # selector
				v['labels'],         # labels
				v['annotations']     # annotations
			)
		end if self.data['_services']

		self.data.each do |k, v|
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

				begin
					cfg.preprocess
				rescue ::K8::Exception::MissingVariables => e
					ui.error e.message_with_catalog(cfg.var_catalog)
					exit 1
				end

				data = cfg.process

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