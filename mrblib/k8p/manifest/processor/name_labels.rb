module K8P
  module Manifest
    module Processor
      # Set name=KEY labels on everything by default
      class NameLabels
        def process data
          (data['units'] || {}).each do |k, v|
            v = {} if v.empty?
            data['units'][k] = apply_name_label(k, v)

            if v['containers']
              v['containers'].each do |ck, cv|
                data['units'][k]['containers'][ck] = apply_name_label(ck, cv)
              end
            end
          end

          (data['services'] || {}).each do |k, v|
            next if k[0] == '_'
            data['services'][k] = apply_name_label(k, v)
          end

          data
        end

        def apply_name_label k, v
          v['labels'] ||= {}
          return v if v['labels']['name']
          v['labels']['name'] = k.gsub(/\./, '-')
          v
        end
      end
    end
  end
end
