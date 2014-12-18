module K8
	class Service < Struct.new(:id, :port, :selector, :labels, :annotations)
		def to_kube
			{
				:id => id,
				:kind => "Service",
				:apiVersion => "v1beta1",
				:port => port,
				:selector => selector,
				:annotations => annotations
			}.compact
		end
	end

	class Pod < Struct.new(:id, :labels, :containers, :volumes)
		def to_kube
			{
				:id => id,
				:kind => 'Pod',
				:apiVersion => 'v1beta1',
				:desiredState => {
					:manifest => {
						:version => 'v1beta1',
						:id => id,
						:containers => containers.map(&:to_kube),
						:volumes => volumes.map(&:to_kube)
					}
				},
				:labels => labels
			}.compact
		end
	end

	class ReplicationController < Struct.new(:id, :replicas, :selector, :labels, :pod)
		def to_kube
			pod_template = pod.to_kube
			[:id, :kind, :apiVersion].each { |k| pod_template.delete k }
			{
				:id => id,
				:kind => 'ReplicationController',
				:apiVersion => 'v1beta1',
				:desiredState => {
					:replicas => replicas,
					:replicaSelector => selector,
					:podTemplate => pod_template
				},
				:labels => labels
			}.compact
		end
	end

	class Container < Struct.new(:name, :image, :ports, :env, :mounts)
		def to_kube
			{
				:name => name,
				:image => image,
				:ports => ports,
				:env => env.map { |k,v| { :name => k, :value => v } },
				:volumeMounts => mounts
			}.compact
		end
	end

	class Volume < Struct.new(:name, :type, :params)
		def source params
			if params.nil? or (params.is_a? String and params.empty?)
				{ :emptyDir => {} }
			elsif params.is_a? String
				params =~ /git:\/\// ? :git : { :hostDir => { :path => params } }
			else
				raise "Unknown volume type!"
			end
		end

		def to_kube
			{
				:name => name,
				:source => source(params)
			}
		end
	end
end