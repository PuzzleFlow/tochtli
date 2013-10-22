require 'singleton'

module ServiceBase
	class MessageMap
		include Singleton

		def initialize
			@topic_map = {}
		end

		def bind(message_class, routing_key)
			if (existing_message_class = @topic_map[routing_key])
				raise "Unable to bind topic to message #{message_class.name}. Already bound to #{existing_message_class.name}."
			end
			@topic_map[routing_key] = message_class
		end

		def for(routing_key)
			@topic_map[routing_key]
		end

	end
end