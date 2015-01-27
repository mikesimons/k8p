module K8P
	class Config
		def self.default file
			default_repository ||= 'https://s3-eu-west-1.amazonaws.com/inviqa-hobo/k8/'
			var_catalog = ::K8P::Manifest::VarCatalog.new

			processors = Proc.new do |cfg|
				[
					::K8P::Manifest::Processor::LoadManifest.new(cfg.file, cfg.var_catalog),
					::K8P::Manifest::Processor::UnitMerge.new(File.dirname(cfg.file), cfg.default_repository, cfg.var_catalog),
					::K8P::Manifest::Processor::DebugState.new("Merged data", 3),
					::K8P::Manifest::Processor::PopulateVars.new,
					::K8P::Manifest::Processor::ReverseProxyRoutes.new,
					::K8P::Manifest::Processor::ShorthandServices.new,
					::K8P::Manifest::Processor::ServiceAnnotations.new,
					::K8P::Manifest::Processor::NameLabels.new,
					::K8P::Manifest::Processor::DebugState.new("Final data", 4)
				]
			end

			self.new File.expand_path(file), default_repository, var_catalog, processors
		end

		attr_accessor :file, :default_repository, :var_catalog, :processors

		def initialize file, default_repository, var_catalog, processors
			@file = file
			@var_catalog = var_catalog
			@processors = processors
			@default_repository = default_repository
		end

		def processors
			@processors.call(self)
		end
	end
end