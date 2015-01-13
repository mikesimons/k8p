module K8
	module Manifest
		module Processor
			class LoadManifest
				def initialize file, var_catalog
					@file = file
					@var_catalog = var_catalog
				end

				def process data
					loaded = load File.basename(@file), [@file]
					(data || {}).deep_merge(loaded)
				end

				def load type, candidates
					loader = loader_for(type, candidates)

					loaded = loader.load
					parser = ::K8::Manifest::Parser.get(loader.target)
					manifest = parser.parse loaded

					@var_catalog.add(loader.target, parser.vars(loaded))

					if manifest['_inherit']
						# FIXME: Hardcoded local path assumption. Does this need to be more flexible?
						# FIXME: What does this do with a remote manifest that inherits?
						inherited = load(manifest['_inherit'], File.expand_path(File.dirname(@file) + "/#{manifest['_inherit']}.yml"))
						manifest = inherited.deep_merge(manifest)
					end

					manifest
				end

				def loader_for type, candidates
					candidates.each do |f|
						loader = ::K8::Manifest::Loader.get(f)
						if loader.loadable?
							ui.debug "Using #{loader.target} for #{type}"
							return loader
						end
					end

					raise ::K8::Exception::MissingManifest.new(type, candidates)
				end
			end
		end
	end
end