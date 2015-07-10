module Tochtli
  module SimpleValidation
    attr_reader :errors

    def add_error(message)
      @errors << message
    end

    def valid?
      @errors = []
      validate
      !@errors || @errors.empty?
    end

    def invalid?
      !valid?
    end

    # abstract method
    def validate
    end
  end
end