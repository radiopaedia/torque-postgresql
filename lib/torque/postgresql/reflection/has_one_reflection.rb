# frozen_string_literal: true

module Torque
  module PostgreSQL
    module Reflection
      module HasOneReflection
        def connected_through_array?
          options[:array]
        end
      end

      ::ActiveRecord::Reflection::HasOneReflection.include(HasOneReflection)
    end
  end
end
