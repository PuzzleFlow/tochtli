require_relative 'test_helper'
require 'benchmark'

class MessageTest < Minitest::Test
	KeyPattern = Tochtli::BaseController::KeyPattern

	def test_simple_pattern
		pattern = KeyPattern.new('a.b.c')

		assert_matches pattern, 'a.b.c'
		refute_matches pattern, 'a.b.c.d'
		refute_matches pattern, 'b.c.d'
	end

	def test_asterix_at_start
		pattern = KeyPattern.new('*.b.c')

		assert_matches pattern, 'a.b.c'
		assert_matches pattern, 'b.b.c'
		refute_matches pattern, 'a.b.c.d'
	end

	def test_asterix_in_the_middle
		pattern = KeyPattern.new('a.*.b.c')

		assert_matches pattern, 'a.a.b.c'
		assert_matches pattern, 'a.d.b.c'
		refute_matches pattern, 'a.b.c.d'
	end

	def test_asterix_at_the_end
		pattern = KeyPattern.new('a.b.c.*')

		assert_matches pattern, 'a.b.c.d'
		assert_matches pattern, 'a.b.c.a'
		refute_matches pattern, 'a.b.c'
		refute_matches pattern, 'a.b.c.d.e'
	end

	def test_hash
		pattern = KeyPattern.new('#')

		assert_matches pattern, ''
		assert_matches pattern, 'a.b.c'
		assert_matches pattern, 'a.b.b.c'
	end

	def test_hash_at_start
		pattern = KeyPattern.new('#.b.c')

		assert_matches pattern, 'b.c'
		assert_matches pattern, 'a.b.c'
		assert_matches pattern, 'a.b.b.c'
		refute_matches pattern, 'a.b.c.d'
	end

	def test_hash_in_the_middle
		pattern = KeyPattern.new('a.#.c')

		assert_matches pattern, 'a.a.b.c'
		assert_matches pattern, 'a.d.b.c'
		refute_matches pattern, 'a.b.c.d'
	end

	def test_hash_at_the_end
		pattern = KeyPattern.new('a.b.#')

		assert_matches pattern, 'a.b.c.d'
		assert_matches pattern, 'a.b.c'
		assert_matches pattern, 'a.b.c.d.e'
	end

	def test_complex
		pattern = KeyPattern.new('*.*.a.b.#.c.#')

		assert_matches pattern, '1.2.a.b.c.d'
		assert_matches pattern, '1.2.a.b.3.4.c.d'
		assert_matches pattern, '1.2.a.b.c'
		refute_matches pattern, 'a.b.c.d.e'
	end

	def test_performance
		pattern = KeyPattern.new('*.*.a.b.#.c.#')

		n = 10_000
		time = Benchmark.realtime { n.times { pattern =~ '1.2.a.b.3.4.c.d' } }

		assert time < 0.1
	end

	protected

	def assert_matches(pattern, key)
		assert pattern =~ key, "#{key} SHOULD match #{pattern}"
	end

	def refute_matches(pattern, key)
		assert pattern !~ key, "#{key} MUST NOT match #{pattern}"
	end
end