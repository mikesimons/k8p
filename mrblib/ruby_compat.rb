RUBY_PLATFORM = "mruby"

def require name
  # NOP
end

class Object
	def freeze
		self
	end
end

class RbConfig
	CONFIG = {
		'host_os' => ''
	}
end

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

class Http
	def self.get url
		parsed = Uri::parse url
		SimpleHttp.new(parsed['scheme'], parsed['host'], parsed['port']).request("GET", parsed['path'], {})
	end
end

class Uri
	def self.parse url
		m = url.match(/((?<scheme>[^:]+):\/\/)?(?<host>[^:\/]+)(?<port>:([0-9]+))?(?<path>[^\?#]+)?(\?(?<query>[^#]+))?(?<fragment>#.*)?/)
		Hash[m.names.zip(m.captures)]
	end
end