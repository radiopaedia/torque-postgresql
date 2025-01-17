# frozen_string_literal: true

module Torque
  module PostgreSQL
    module Adapter
      module SchemaDumper
        def dump(stream) # :nodoc:
          @connection.dump_mode!
          super

          @connection.dump_mode!
          stream
        end

        # Translate +:enum_set+ into +:enum+
        def schema_type(column)
          column.type == :enum_set ? :enum : super
        end

        private

          def tables(stream) # :nodoc:
            around_tables(stream) { dump_tables(stream) }
          end

          def around_tables(stream)
            functions(stream) if fx_functions_position == :beginning

            yield

            functions(stream) if fx_functions_position == :end
            triggers(stream) if defined?(::Fx::SchemaDumper::Trigger)
          end

          def dump_tables(stream)
            inherited_tables = @connection.inherited_tables
            sorted_tables = @connection.tables.sort - @connection.views

            stream.puts "  # These are the common tables"
            (sorted_tables - inherited_tables.keys).each do |table_name|
              table(table_name, stream) unless ignored?(table_name)
            end

            if inherited_tables.present?
              stream.puts "  # These are tables that have inheritance"
              inherited_tables.each do |table_name, inherits|
                next if ignored?(table_name)

                sub_stream = StringIO.new
                table(table_name, sub_stream)

                # Add the inherits setting
                sub_stream.rewind
                inherits.map!(&:to_sym)
                inherits = inherits.first if inherits.size === 1
                inherits = ", inherits: #{inherits.inspect} do |t|"
                table_dump = sub_stream.read.gsub(/ do \|t\|$/, inherits)

                # Ensure bodyless definitions
                table_dump.gsub!(/do \|t\|\n  end/, '')
                stream.print table_dump
              end
            end

            # Dump foreign keys at the end to make sure all dependent tables exist.
            if @connection.supports_foreign_keys?
              sorted_tables.each do |tbl|
                foreign_keys(tbl, stream) unless ignored?(tbl)
              end
            end
          end

          def fx_functions_position
            return unless defined?(::Fx::SchemaDumper::Function)
            Fx.configuration.dump_functions_at_beginning_of_schema ? :beginning : :end
          end
      end

      ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend SchemaDumper
    end
  end
end
