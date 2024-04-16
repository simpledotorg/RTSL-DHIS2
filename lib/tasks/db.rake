# frozen_string_literal: true

require_relative '../../db/data/20240416_add_trigger_on_program_stage_instance'

namespace :db do
  desc 'Runs the "up" for a given migration'
  task :migrate do
    AddTriggerOnProgramStageInstance.new.up
    puts 'migrated!'
  end

  desc 'Runs the "down" for a given migration'
  task :rollback do
    AddTriggerOnProgramStageInstance.new.down
    puts 'rollback!'
  end
end
