$0 = "k8p"
def main
	Slop.parse do
		on :v, :version, "Display version" do
			ui.output "k8p v0.0.1"
			exit 0
		end

		on :debug do |v|
			ui.level = 5
		end

		on :repository=, "Unit repository path / URL"

		on :help do
			puts self
			exit 0
		end

		run do |opts, args|
			ui.debug("Running process task")
			ui.debug("Opts: #{opts.to_hash}")
			ui.debug("Args: #{args}")

			file = args[0] || 'k8.yml'
			resolved_file = File.expand_path(file)

			unless File.exists? resolved_file and File.stat(resolved_file).readable?
				ui.error "Invalid or unreadable k8 manifest file: #{resolved_file}"
				exit 1
			end

			cfg = K8P::Config.default(file)
			cfg.default_repository = opts[:repository] if opts[:repository]

			begin
				manifest = K8P::Manifest::Manifest.load cfg
			rescue ::K8P::Exception::MissingVariables => e
				ui.error e.message_with_catalog(cfg.var_catalog)
				exit 1
			end

			ui.output JSON::stringify(manifest.to_kube).gsub(/\\\//, '/')
		end
	end
end
