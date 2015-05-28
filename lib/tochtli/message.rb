require 'active_model'

module Tochtli
  class Message
    include ActiveModel::Naming
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    include ActiveModel::Serializers::JSON

    class_attribute :routing_key, :instance_writer => false
    class_attribute :attribute_names, :instance_writer => false
    class_attribute :excess_attributes_policy, :instance_writer => false

    attr_reader :id, :properties

    self.include_root_in_json = false

    validate :validate_excess_attributes

    def self.inherited(subclass)
      subclass.attribute_names = Set.new
    end

    def self.bind_topic(routing_key)
      Tochtli::MessageMap.instance.bind(self, routing_key)
      self.routing_key = routing_key
    end

    def self.attributes(*attributes)
      options  = attributes.extract_options!
      validate = options.fetch(:validate, true)

      attribute_names.merge(attributes)

      attr_accessor *attributes
      validates_presence_of *attributes if validate
    end

    def self.required_attributes(*attributes)
      options = attributes.extract_options!
      self.attributes *attributes, options.merge(validate: true)
    end

    def self.optional_attributes(*attributes)
      options = attributes.extract_options!
      self.attributes *attributes, options.merge(validate: false)
    end

    def self.ignore_excess_attributes
      self.excess_attributes_policy = :ignore
    end

    def initialize(attributes={}, properties=nil)
      @excess_attributes = {}
      self.attributes    = attributes if attributes
      @properties        = properties
      @id                = if properties && properties.message_id
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
        setter = "#{name}="
        if respond_to?(setter)
          send setter, value
        else
          @excess_attributes[name] = value
        end
      end
    end

    def validate_excess_attributes
      if !@excess_attributes.empty? && self.class.excess_attributes_policy != :ignore
        @excess_attributes.each_key do |name|
          self.errors.add :base, "Undefined attribute :#{name}"
        end
      end
    end

    def self.generate_id
      SecureRandom.uuid
    end
  end

  class ErrorMessage < Message
    attributes :error, :message
  end
end