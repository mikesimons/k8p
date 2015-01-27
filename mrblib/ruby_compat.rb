# Required by Rainbow gem
RUBY_PLATFORM = "mruby"

# All files loaded by default; stub
def require name
  # NOP
end

# Ruby API parity; MEH
class Object
	def freeze
		self
	end
end

# Basic RbConfig stub for Rainbow
class RbConfig
	CONFIG = {
		'host_os' => ''
	}
end

class File
	def self.basename f, p = nil
		f.split('/').last
	end
end

# Minimal FileUtils support for mkdir_p
module FileUtils
	def self.mkdir_p dir
		path = ""
		success = dir.split('/').reject(&:empty?).map do |d|
			path += "/#{d}"
			Dir.mkdir path unless File.exist? path
		end

		success.reject do |v|
			v == 0 || v == nil
		end.length == 0
	end
end

# Ease-of-use wrapper for mruby-simplehttp
class Http
	def self.get url, headers = {}
		parsed = Uri::parse url
		SimpleHttp.new(parsed['scheme'], parsed['host'], parsed['port']).request("GET", parsed['path'], headers)
	end
end

# Primitive URI alternative for parsing URIs
class Uri
	def self.parse url
		m = url.match(/((?<scheme>[^:]+):\/\/)?(?<host>[^:\/]+)(?<port>:([0-9]+))?(?<path>[^\?#]+)?(\?(?<query>[^#]+))?(?<fragment>#.*)?/)
		Hash[m.names.zip(m.captures)]
	end
end

# Simple "maybe" implementation for hash access
class NilHash
	def self.wrap v
		NilHash.new v
	end

	def initialize v
		@v = v
	end

	def [] k
		NilHash.new(@v != nil && @v.include?(k) ? @v[k] : nil)
	end

	def method_missing method, *vars, &block
		@v.call(method, *vars, &block)
	end

	def unwrap
		@v
	end
end