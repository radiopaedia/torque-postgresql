# frozen_string_literal: true

module Torque
  module PostgreSQL
    # = Torque PostgreSQL Railtie
    class Railtie < Rails::Railtie # :nodoc:

      # Get information from the running rails app
      initializer 'torque-postgresql' do |app|
        torque_config = Torque::PostgreSQL.config
        torque_config.eager_load = app.config.eager_load

        # Setup belongs_to_many association
        ActiveRecord::Base.belongs_to_many_required_by_default = torque_config.associations
          .belongs_to_many_required_by_default
      end
    end
  end
end
