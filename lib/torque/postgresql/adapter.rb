# frozen_string_literal: true

require_relative 'adapter/database_statements'
require_relative 'adapter/oid'
require_relative 'adapter/quoting'
require_relative 'adapter/schema_creation'
require_relative 'adapter/schema_definitions'
require_relative 'adapter/schema_dumper'
require_relative 'adapter/schema_statements'

module Torque
  module PostgreSQL
    module Adapter
      include Quoting
      include DatabaseStatements
      include SchemaStatements

      # :nodoc:
      class DeduplicatableArray < ::Array
        def deduplicate
          map { |value| -value }
        end

        alias :-@ :deduplicate
      end

      # Get the current PostgreSQL version as a Gem Version.
      def version
        @version ||= Gem::Version.new(
          select_value('SELECT version()').match(/#{Adapter::ADAPTER_NAME} ([\d\.]+)/)[1]
        )
      end

      # Add `inherits` to the list of extracted table options
      def extract_table_options!(options)
        super.merge(options.extract!(:inherits))
      end

      # Allow filtered bulk insert by adding the where clause. This method is
      # only used by +InsertAll+, so it somewhat safe to override it
      def build_insert_sql(insert)
        super.tap do |sql|
          if insert.update_duplicates? && insert.where_condition?
            if insert.returning
              sql.sub!(' RETURNING ', " WHERE #{insert.where} RETURNING ")
            else
              sql << " WHERE #{insert.where}"
            end
          end
        end
      end
    end

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend Adapter
  end
end
