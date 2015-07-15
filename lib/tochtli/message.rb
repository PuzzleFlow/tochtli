module Tochtli
  class Message
    extend Uber::InheritableAttr
    include Virtus.model
    include Tochtli::SimpleValidation

    inheritable_attr :routing_key
    inheritable_attr :extra_attributes_policy

    attr_reader :id, :properties

    def self.route_to(routing_key=nil)
      self.routing_key = routing_key
    end

    # Compatibility with version 0.3
    def self.attributes(*attributes)
      options  = attributes.extract_options!
      required = options.fetch(:validate, true)

      attributes.each do |name|
        attribute name, String, required: required
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
      super
      store_extra_attributes(attributes)
    end

    def store_extra_attributes(attributes)
      @extra_attributes ||= {}
      if attributes
        attributes.each do |name, value|
          unless allowed_writer_methods.include?("#{name}=")
            @extra_attributes[name] = value
          end
        end
      end
    end

    def validate_extra_attributes
      if self.class.extra_attributes_policy != :ignore && !@extra_attributes.empty?
        add_error "Unexpected attributes: #{@extra_attributes.keys.map(&:to_s).join(', ')}"
      end
    end

    def validate_attributes_presence
      nil_attributes = attribute_set.select { |a| a.required? && self[a.name].nil? }.map(&:name)
      unless nil_attributes.empty?
        add_error "Required attributes: #{nil_attributes.map(&:to_s).join(', ')} not specified"
      end
    end

    def validate
      validate_extra_attributes
      validate_attributes_presence
    end

    def self.generate_id
      SecureRandom.uuid
    end

    def routing_key
      self.class.routing_key
    end

    def to_hash
      attributes.inject({}) do |hash, (name, value)|
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