# frozen_string_literal: true

module Torque
  module PostgreSQL
    module Associations
      module Preloader
        module Association

          delegate :connected_through_array?, to: :@reflection

          # For reflections connected through an array, make sure to properly
          # decuple the list of ids and set them as associated with the owner
          def run
            return self if run?
            return super unless connected_through_array?

            @run = true
            send("run_array_for_#{@reflection.macro}")
            self
          end

          # Correctly correlate records when they are connected theough an array
          def set_inverse(record)
            return super unless connected_through_array?
            return super unless @reflection.macro == :has_many || @reflection.macro == :has_one

            # Only the first owner is associated following the same instruction
            # on the original implementation
            convert_key(record[association_key_name])&.each do |key|
              if owners = owners_by_key[key]
                association = owners.first.association(reflection.name)
                association.set_inverse_instance(record)
              end
            end
          end

          # Requires a slight change when running on has many since the value
          # of the foreign key being an array
          def load_records(raw_records = nil)
            return super unless connected_through_array?
            return super unless @reflection.macro == :has_many || @reflection.macro == :has_one

            @records_by_owner = {}.compare_by_identity
            raw_records ||= loader_query.records_for([self])

            @preloaded_records = raw_records.select do |record|
              assignments = false

              keys = convert_key(record[association_key_name]) || []
              owners_by_key.values_at(*keys).each do |owner|
                entries = (@records_by_owner[owner] ||= [])

                if reflection.collection? || entries.empty?
                  entries << record
                  assignments = true
                end
              end

              assignments
            end
          end

          # Make sure to change the process when connected through an array
          def owners_by_key
            return super unless connected_through_array?
            @owners_by_key ||= owners.each_with_object({}) do |owner, result|
              Array.wrap(convert_key(owner[owner_key_name])).each do |key|
                (result[key] ||= []) << owner
              end
            end
          end

          private

            # Specific run for belongs_many association
            def run_array_for_belongs_to_many
              # Add reverse to has_many
              records = groupped_records
              owners.each do |owner|
                items = records.values_at(*Array.wrap(owner[owner_key_name]))
                associate_records_to_owner(owner, items.flatten)
              end
            end

            # Specific run for belongs_many association
            def run_array_for_has_one
              # Add reverse to has_many
              records = groupped_records
              owners.each do |owner|
                items = records.values_at(*records.keys.select {|k| k.include?(owner[owner_key_name])})
                associate_records_to_owner(owner, items.flatten)
              end
            end

            # Specific run for has_many association
            def run_array_for_has_many
              # Add reverse to belongs_to_many
              records = Hash.new { |h, k| h[k] = [] }
              groupped_records.each do |ids, record|
                ids.each { |id| records[id].concat(Array.wrap(record)) }
              end

              records.default_proc = nil
              owners.each do |owner|
                associate_records_to_owner(owner, records[owner[owner_key_name]] || [])
              end
            end

            # Build correctly the constraint condition in order to get the
            # associated ids
            def records_for(ids, &block)
              return super unless connected_through_array?
              condition = scope.arel_table[association_key_name]
              condition = reflection.build_id_constraint(condition, ids.flatten.uniq)
              scope.where(condition).load(&block)
            end

            def associate_records_to_owner(owner, records)
              return super unless connected_through_array?
              return super if records.empty?
              association = owner.association(reflection.name)
              association.loaded!
              if @reflection.macro == :has_one
                association.target = records.sole
              else
                association.target.concat(records)
              end
            end

            def groupped_records
              preloaded_records.group_by do |record|
                convert_key(record[association_key_name])
              end
            end
        end

        ::ActiveRecord::Associations::Preloader::Association.prepend(Association)
      end
    end
  end
end
