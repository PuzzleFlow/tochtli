require_relative 'test_helper'

class ConfigurationStoreTest < ServiceBase::Test::Client
	def setup
		@store = ServiceBase::Configuration::ActiveRecordStore.new
	end

	test "load no data" do
		assert_nil @store.read('not.existing')
	end

	test "write and load" do
		value = {a: 'A', b: 'B'}
		@store.write 'a.b.c', value
		assert_equal value, @store.read('a.b.c')
	end

	test "test fetch with default" do
		assert_nil @store.fetch('not.existing')
		av = {:a => 'A'}
		bv = {:b => 'B'}
		assert_equal av, @store.fetch('not.existing.1', av)
		assert_equal av, @store.fetch('not.existing.1') { bv }
		assert_equal bv, @store.fetch('not.existing.2') { bv }
		assert_equal bv, @store.fetch('not.existing.2', av)
	end
end
