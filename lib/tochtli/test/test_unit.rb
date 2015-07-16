module Tochtli
  module Test
    module UnitTestSupport
      module BaseBeforeSetup
        def before_setup
        end
      end

      def append_features(base)
        base.send :include, BaseBeforeSetup
        super
      end

      def included(base)
        if base < ::Test::Unit::TestCase
          base.setup :before_setup # Run before_setup for Test::Unit (Minitest uses it as an only callback)
        end
        super
      end
    end
  end
end
