module K8P
  module Manifest
    class Manifest
      def self.load config
        ui.debug "Loading manifest data"
        data = {}
        config.processors.each do |p|
          ui.debug "Running #{p.class} preprocessor"
          data = p.process(data)
        end

        from_data data
      end

      def self.from_data data
        services = []
        pods = []
        rcs = []

        # Explicit services
        data['services'].each do |k, v|
          services << ::K8P::Service.new(
            v['labels']['name'], # id
            v['port'],           # port
            v['selector'],       # selector
            v['labels'],         # labels
            v['annotations']     # annotations
          )
        end if data['services']

        (data['units'] || {}).each do |k, v|
          containers = if v['containers']
            v['containers'].map do |ck, cv|
              ::K8P::Container.new(
                cv['labels']['name'], # name
                cv['image'],          # image
                cv['ports'],          # ports
                cv['env'],            # env
                cv['mounts']          # mounts
              )
            end
          end || []

          volumes = if v['volumes']
            v['volumes'].map do |vk, vv|
              ::K8P::Volume.new(
                vk, # name
                vv  # params
              )
            end
          end || []

          pod = ::K8P::Pod.new(
            v['labels']['name'], # id
            v['labels'],         # labels
            containers,          # containers
            volumes              # volumes
          )

          if v['replicas']
            rcs << ::K8P::ReplicationController.new(
              v['labels']['name'], # id
              v['replicas'],       # replicas,
              v['labels'],         # selector,
              v['labels'],         # labels,
              pod                  # pod
            )
          else
            pods << pod
          end
        end

        self.new pods, rcs, services
      end

      attr_reader :pods, :replication_controllers, :services

      def initialize pods, rcs, services
        @pods = pods
        @replication_controllers = rcs
        @services = services
      end

      def to_kube
        @services.map(&:to_kube) + @pods.map(&:to_kube) + @replication_controllers.map(&:to_kube)
      end
    end
  end
end
