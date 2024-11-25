# frozen_string_literal: true

module Torque
  module PostgreSQL
    module Associations
      module Builder
        module HasOne
          def valid_options(options)
            super + [:array]
          end
        end

        ::ActiveRecord::Associations::Builder::HasOne.extend(HasOne)
      end
    end
  end
end
