############################
# Start of your build_config

MRuby::Build.new do |conf|
  toolchain :gcc

  enable_debug

  conf.bins = ["mrbc"]

  # mruby's Core GEMs
  conf.gem 'mrbgems/mruby-bin-mirb'
  conf.gem 'mrbgems/mruby-bin-mruby'
  conf.gem 'mrbgems/mruby-array-ext'
  conf.gem 'mrbgems/mruby-enum-ext'
  conf.gem 'mrbgems/mruby-eval'
  conf.gem 'mrbgems/mruby-exit'
  conf.gem 'mrbgems/mruby-enumerator'
  conf.gem 'mrbgems/mruby-fiber'
  conf.gem 'mrbgems/mruby-hash-ext'
  conf.gem 'mrbgems/mruby-math'
  conf.gem 'mrbgems/mruby-numeric-ext'
  conf.gem 'mrbgems/mruby-object-ext'
  conf.gem 'mrbgems/mruby-objectspace'
  conf.gem 'mrbgems/mruby-print'
  conf.gem 'mrbgems/mruby-proc-ext'
  conf.gem 'mrbgems/mruby-random'
  conf.gem 'mrbgems/mruby-range-ext'
  conf.gem 'mrbgems/mruby-sprintf'
  conf.gem 'mrbgems/mruby-string-ext'
  conf.gem 'mrbgems/mruby-string-utf8'
  conf.gem 'mrbgems/mruby-struct'
  conf.gem 'mrbgems/mruby-symbol-ext'
  conf.gem 'mrbgems/mruby-time'
  conf.gem 'mrbgems/mruby-toplevel-ext'

  # user-defined GEMs
  
  #conf.gem :git => 'https://github.com/pbosetti/mruby-merb.git'
  #conf.gem :git => 'https://github.com/iij/mruby-tempfile.git'
  #conf.gem :git => 'https://github.com/mattn/mruby-thread.git'

  # Regexp
  conf.gem :git => 'https://github.com/iij/mruby-regexp-pcre.git'
  
  # IO, File & Dir
  conf.gem :git => 'https://github.com/mikesimons/mruby-io.git'
  conf.gem :git => 'https://github.com/iij/mruby-dir.git'
  conf.gem :git => 'https://github.com/ksss/mruby-file-stat'
  
  # JSON & YAML
  conf.gem :git => 'https://github.com/mattn/mruby-json.git'
  conf.gem :git => 'https://github.com/AndrewBelt/mruby-yaml.git'

  # HTTP support
  conf.gem :git => 'https://github.com/iij/mruby-pack.git'
  conf.gem :git => 'https://github.com/iij/mruby-socket.git'
  conf.gem :git => 'https://github.com/matsumoto-r/mruby-simplehttp.git'
  conf.gem :git => 'https://github.com/luisbebop/mruby-polarssl'

  # ENV vars
  conf.gem :git => 'https://github.com/iij/mruby-env.git'

  # GRRR (PolarSSL)
  conf.cc.include_paths << "#{File.dirname(__FILE__)}/build/mrbgems/mruby-io/include"
  conf.gem :git => "https://github.com/iij/mruby-mtest"

  # CLI opt parse / commands
  conf.gem :git => "https://github.com/mikesimons/mruby-slop"

  %{self}
  %{rubygems}

  #conf.gem :git => 'https://github.com/mattn/mruby-require.git'
end

# End of your build_config
############################

