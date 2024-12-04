# frozen_string_literal: true

module Torque
  module PostgreSQL
    module AutosaveAssociation
      module ClassMethods
        # Since belongs to many is a collection, the callback would normally go
        # to +after_create+. However, since it is a +belongs_to+ kind of
        # association, it neds to be executed +before_save+
        def add_autosave_association_callbacks(reflection)
          return super unless reflection.macro.eql?(:belongs_to_many)

          save_method = :"autosave_associated_records_for_#{reflection.name}"
          define_non_cyclic_method(save_method) do
            save_belongs_to_many_association(reflection)
          end

          before_save(save_method)

          define_autosave_validation_callbacks(reflection)
        end
      end

      def save_has_one_association(reflection)
        return super unless reflection.connected_through_array?
        return super if reflection.through_reflection

        assn = association(reflection.name)
        autosave = reflection.options[:autosave]
        primary_key = Array(compute_primary_key(reflection, self)).map(&:to_s)
        primary_key_value = primary_key.map { |key| _read_attribute(key) }

        record = assn.load_target
        if record && (
          (autosave && record.changed_for_autosave?) ||
          _record_changed?(reflection, record, primary_key_value)
        )
          foreign_key = Array(reflection.foreign_key)
          primary_key_foreign_key_pairs = primary_key.zip(foreign_key)

          primary_key_foreign_key_pairs.each do |primary_key, foreign_key|
            association_id = _read_attribute(primary_key)
            (record[foreign_key] ||= []).push(association_id) unless record[foreign_key]&.include?(association_id)
          end
          assn.set_inverse_instance(record)

          raise ActiveRecord::Rollback unless record.save(validate: false)
          return true
        end
        super
      end

      # Ensure the right way to execute +save_collection_association+ and also
      # keep it as a single change using +build_changes+
      def save_belongs_to_many_association(reflection)
        previously_new_record_before_save = (@new_record_before_save ||= false)
        @new_record_before_save = new_record?

        association = association_instance_get(reflection.name)
        association&.build_changes { save_collection_association(reflection) }
      rescue ::ActiveRecord::RecordInvalid
        throw(:abort)
      ensure
        @new_record_before_save = previously_new_record_before_save
      end
    end

    ::ActiveRecord::Base.singleton_class.prepend(AutosaveAssociation::ClassMethods)
    ::ActiveRecord::Base.include(AutosaveAssociation)
  end
end
