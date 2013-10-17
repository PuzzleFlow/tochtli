class CreateConfigurationStore < ActiveRecord::Migration
	def self.up
		execute "CREATE EXTENSION IF NOT EXISTS hstore"

		execute <<-SQL
			CREATE TABLE configuration_store
			(
			  name character varying(2048),
			  value hstore,
			  CONSTRAINT configuration_store_pkey PRIMARY KEY (name)
			)
		SQL

		execute <<-SQL
			CREATE UNIQUE INDEX idx_configuration_store_key ON configuration_store
	 									USING btree (name text_pattern_ops);
		SQL

		execute <<-SQL
			CREATE OR REPLACE FUNCTION upset_configuration_store( up_name character varying(2048), up_value hstore ) RETURNS void as $$
			BEGIN
				UPDATE configuration_store set value = up_value WHERE name = up_name;
					IF FOUND THEN
						RETURN;
					END IF;
					BEGIN
						INSERT INTO configuration_store (name, value) VALUES (up_name, up_value);
					EXCEPTION WHEN unique_violation THEN
						UPDATE configuration_store set value = up_value WHERE name = up_name;
					END;
					RETURN;
			END;
			$$ language plpgsql;
		SQL
	end

	def self.down
		execute 'DROP TABLE configuration_store'
		execute 'DROP FUNCTION upset_configuration_store( character varying(2048), hstore )'
	end
end
