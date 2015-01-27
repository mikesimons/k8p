class Hash
  def compact
    n = {}
    self.each do |k,v|
      next if v.nil? or (v.respond_to? :empty and v.empty?) or (v.respond_to? :length and v.length == 0)
      n[k] = v.is_a?(Hash) ? v.compact : v
    end
    n
  end

  def to_dotted_hash(recursive_key = "")
    self.each_with_object({}) do |v, ret|
      k = v[0]
      v = v[1]
      key = recursive_key + k.to_s
      if v.is_a? Hash
        ret.merge! v.to_dotted_hash(key + ".")
      else
        ret[key.to_sym] = v
      end
    end
  end
end

class File
  def self.write file, contents
    File.open file, "w+" do |f|
      f.write contents
    end
  end
end
