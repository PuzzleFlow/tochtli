module ServiceBase
	class Message
		include ActiveModel::Naming
		include ActiveModel::Validations
		include ActiveModel::Serializers::JSON

		class_attribute :routing_key, :instance_writer => false
		class_attribute :attribute_names, :instance_writer => false

		attr_reader :id, :properties

		def self.inherited(subclass)
			subclass.attribute_names = Set.new
		end

		def self.bind_topic(routing_key)
			ServiceBase::MessageMap.instance.bind(self, routing_key)
			self.routing_key = routing_key
		end

		def self.attributes(*attributes)
			options = attributes.extract_options!
			validate = options.fetch(:validate, true)

			attribute_names.merge(attributes)

			attr_accessor *attributes
			validates_presence_of *attributes if validate
		end

		def initialize(attributes={}, properties=nil)
			self.attributes = attributes if attributes
			@properties = properties
			@id = if properties && properties.message_id
							properties.message_id
						else
							self.class.generate_id
						end
		end

		def attributes
			self.class.attribute_names.inject({}) do |hash, name|
				hash[name] = send(name)
				hash
			end
		end

		def attributes=(attributes)
			attributes.each do |name, value|
				send "#{name}=", value
			end
		end

		def self.generate_id
			SecureRandom.uuid
		end
	end

	class ErrorMessage < Message
		attributes :message
	end
end