module K8P
  module Manifest
    module Loader
      class HttpFile
        def initialize url, cache_dir = '~/.k8/catalog'
          @url = url
          @cache_dir = ::File.expand_path(cache_dir)
          @cache_file = "#{@cache_dir}/#{::File.basename url}"
        end

        def load
          ::File.read(@cache_file)
        end

        def loadable?
          def format t
            data = Hash[
              [:weekday, :month, :day, :time, :zone, :year].zip(t.to_s.split(" "))
            ]
            "%{weekday}, %{day} %{month} %{year} %{time} %{zone}" % data
          end

          stat = ::File.stat(@cache_file) if ::File.exists? @cache_file

          mtime = format(stat.mtime.getgm) if stat

          ui.debug("Fetching #{@url}#{" if modified since #{mtime}" if mtime}")
          r = Http.get(@url, { 'If-Modified-Since' => mtime }.compact)
          case r.code
          when 200
            ui.debug("#{@url} 200 - cache updated")
            FileUtils.mkdir_p @cache_dir
            ::File.write(@cache_file, r.body)
            return true
          when 304
            ui.debug("#{@url} 304 - cache ok")
            return true
          else
            ui.debug("#{@url} #{r.code} - #{r.body}")
            return false
          end
        end

        def target
          @url
        end
      end
    end
  end
end
