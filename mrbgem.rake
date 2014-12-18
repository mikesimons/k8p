MRuby::Gem::Specification.new('k8') do |spec|
  spec.license = 'LICENSE'
  spec.authors = [ 'AUTHOR' ]
  spec.rbfiles = Dir.glob("#{dir}/mrblib/**/*.rb")
end