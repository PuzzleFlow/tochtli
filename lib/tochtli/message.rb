require 'securerandom'

module Tochtli
  class Message
    extend Uber::InheritableAttr
    include Lotus::Validations

    inheritable_attr :routing_key
    inheritable_attr :extra_attributes_policy

    attr_reader :id, :properties

    def self.route_to(routing_key=nil, &block)
      self.routing_key = routing_key || block
    end

    # Compatibility with version 0.3
    def self.attributes(*attributes)
      options  = attributes.extract_options!
      required = options.fetch(:validate, true)

      attributes.each do |name|
        attribute name, type: String, presence: required
      end
    end

    def self.required_attributes(*attributes)
      options = attributes.extract_options!
      self.attributes *attributes, options.merge(validate: true)
    end

    def self.optional_attributes(*attributes)
      options = attributes.extract_options!
      self.attributes *attributes, options.merge(validate: false)
    end

    def self.ignore_extra_attributes
      self.extra_attributes_policy = :ignore
    end

    def initialize(attributes={}, properties=nil)
      super attributes || {}

      @properties = properties
      @id         = properties.message_id if properties
      @id         ||= self.class.generate_id

      store_extra_attributes(attributes)
    end

    def attributes=(attributes)
      attributes.each do |key,val|
        self.send("#{key}=", val)
      end

      store_extra_attributes(attributes)
    end

    # public api method for private #read_attributes from Lotus::Validations
    def attributes
      read_attributes
    end

    def store_extra_attributes(attributes)
      @extra_attributes ||= {}
      if attributes
        attributes.each do |name, value|
          unless self.class.defined_attributes.include?(name.to_s)
            @extra_attributes[name] = value
          end
        end
      end
    end

    def validate_extra_attributes
      if self.class.extra_attributes_policy != :ignore && !@extra_attributes.empty?
        @extra_attributes.each do |extra|
          errors.add(:extra, 'Extra attributes are not allowed')
        end
      end
    end

    def validate
      super
      validate_extra_attributes
    end

    def self.generate_id
      SecureRandom.uuid
    end

    def routing_key
			if self.class.routing_key.is_a?(Proc)
				self.instance_eval(&self.class.routing_key)
			else
        self.class.routing_key
			end
    end

    def to_hash
      read_attributes.inject({}) do |hash, (name, value)|
          value = value.map(&:to_hash) if value.is_a?(Array)
          hash[name] = value
          hash
      end
    end

    def to_json
      JSON.dump(to_hash)
    end
  end

  class ErrorMessage < Message
    attributes :error, :message
  end
end
