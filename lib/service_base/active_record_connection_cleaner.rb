module ServiceBase
	class ActiveRecordConnectionCleaner < Middleware
		def call(env)
			@app.call(env)
		ensure
			ActiveRecord::Base.clear_active_connections!
		end
	end
end
