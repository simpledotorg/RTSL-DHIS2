# frozen_string_literal: true

require_relative '../../config/db_connection'

class AddTriggerOnProgramStageInstance < ActiveRecord::Migration[7.0]

  def up
    execute(File.read('db/scripts/update_htn_visit_after_first_call_trigger.sql'))
  end

  def down
    execute <<-SQL
      DROP TRIGGER after_insert_calling_report_programstageinstance ON programstageinstance;
      DROP FUNCTION update_htn_visit_after_first_call_trigger();
      DROP FUNCTION update_patient_status(program_instance_id BIGINT, remove_reason TEXT);
    SQL
  end
end
