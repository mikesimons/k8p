class Hash
	def compact
		n = {}
		self.each do |k,v|
			next if v.nil? or (v.respond_to? :empty and v.empty?) or (v.respond_to? :length and v.length == 0)
			n[k] = v.is_a?(Hash) ? v.compact : v
		end
		n
	end
end

class File
	def self.write file, contents
		File.open file, "w+" do |f|
			f.write contents
		end
	end
end