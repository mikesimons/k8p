#!/usr/bin/ruby

require 'fileutils'

MRUBY_VERSION = "1.1.0"
TARGET_BIN = "k8"
GEMS = {
  "deep_merge-1.0.1" => [],
  "rainbow-2.0.0" => [
    lambda { sh "rm -rf mrblib/rainbow/legacy.rb mrblib/rainbow/ext/string.rb" }
  ]
}

gems = []
GEMS.each do |g, extra|
  name = g.gsub(/-[^\-]+$/, '')
  gems << "build/gems/#{name}"
  file "build/gems/#{name}" do
    FileUtils.mkdir_p "build/gems/#{name}/mrblib"
    FileUtils.mkdir_p "build/gems/#{name}/tmp"

    Dir.chdir "build/gems/#{name}/tmp" do
      sh "wget http://rubygems.org/downloads/#{g}.gem"
      sh "tar -xf #{g}.gem"
      sh "tar -xf data.tar.gz"
      sh "mv lib/* ../mrblib/"
    end

    Dir.chdir "build/gems/#{name}" do
      sh "rm -rf tmp"
      File.write(
        "mrbgem.rake",
        "
MRuby::Gem::Specification.new('#{name}') do |spec|
  spec.license = 'LICENSE'
  spec.authors = [ 'AUTHOR' ]
  spec.rbfiles = Dir.glob(\"\#{dir}/mrblib/**/*.rb\")
  File.write(\"/tmp/debug\", \"DEBUG HEAD: (\#{dir}): \" + Dir.glob(\"\#{dir}/mrblib/**/*.rb\").join(', '))
end
        "
      )
      extra.each(&:call)
      #sh "git init . && git add * && git commit -m 'init'"
    end
  end
end

file "build/mruby" do
  FileUtils.mkdir_p "build/mruby"
  Dir.chdir "build/mruby" do
    sh "wget https://github.com/mruby/mruby/archive/#{MRUBY_VERSION}.tar.gz"
    sh "tar -xf #{MRUBY_VERSION}.tar.gz"
    sh "mv mruby-#{MRUBY_VERSION}/* ."
    sh "rm -rf mruby-#{MRUBY_VERSION} #{MRUBY_VERSION}.tar.gz"
  end
end

file "build/mruby/build_config.rb" => gems do
  f = File.read("build_config.rb")
  dir = File.dirname(__FILE__)
  gems = gems.map do |g|
    "conf.gem '#{dir}/#{g}'"
  end
  f = f % { :rubygems => gems.join("\n"), :self => "conf.gem '#{dir}'" }

  File.write("build/mruby/build_config.rb", f) unless File.exists? "build/mruby/build_config.rb" && File.read("build/mruby/build_config.rb") != f
end

file "build/mruby/build/host/lib/libmruby.a" => [ "build/mruby", "build/mruby/build_config.rb" ] do
  Dir.chdir "build/mruby" do
    sh "make"
  end
end

file "build/#{TARGET_BIN}" => [ "build/mruby/build/host/lib/libmruby.a" ] do
  sh "gcc -O2 -Ibuild/mruby/include driver.c build/mruby/build/host/lib/libmruby.a -lm -ldl -l:/usr/lib/x86_64-linux-gnu/libyaml.a -o build/#{TARGET_BIN}"
end

task :default => [ "build/#{TARGET_BIN}" ]

task :clean do
  sh "rm -rf build/#{TARGET_BIN}"
  #sh "rm -rf build/mruby/build_config.rb"
  sh "rm -rf build/mruby/build/mrbgems/k8"
  sh "rm -rf build/mruby/build/host/lib/libmruby.a"
end

task :clean_all do
  sh "rm -rf build"
end
