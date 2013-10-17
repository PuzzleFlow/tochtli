require 'pg_hstore'

module ServiceBase
	module Configuration
		class AbstractStore
			def write(key, value)
				raise NotImplemented
			end

			def read(key)
				raise NotImplemented
			end

			def fetch(key, default=nil)
				value = read(key)
				if !value && block_given?
					default = yield
				end

				if !value && default
					value = default
					write key, value
				end

				value
			end
		end

		class ActiveRecordStore < AbstractStore
			def write(key, value)
				sql_name = ActiveRecord::Base.connection.quote(key)
				sql_value = PgHstore.dump(value, false)
				ActiveRecord::Base.connection.execute "SELECT upset_configuration_store(#{sql_name}, #{sql_value})"
			end

			def read(key)
				sql_name = ActiveRecord::Base.connection.quote(key)
				result = ActiveRecord::Base.connection.query("SELECT value FROM configuration_store WHERE name = #{sql_name}")
				unless result.empty?
					PgHstore.load(result[0][0], true)
				end
			end
		end
	end
end