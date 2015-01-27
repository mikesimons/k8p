module K8P
  module Manifest
    module Processor
      # Move any unknown attributes on services to annotations
      class ServiceAnnotations
        def process data
          (data['services'] || {}).each do |k, v|
            annotate = v.clone
            new_v = {}
            ['port', 'labels', 'selector', 'annotations'].each do |key|
              annotate.delete key
              new_v[key] = v[key] if v[key]
            end

            data['services'][k] = v.deep_merge({
              'annotations' => annotate
            })
          end

          data
        end
      end
    end
  end
end
