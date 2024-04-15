# frozen_string_literal: true

require 'rspec'
require_relative '../lib/client'
require_relative '../lib/event_trigger'

RSpec.describe 'EventTrigger' do
  before do
    # fetch all events of the tei - 'mAEqUcmcils'
    event_data = client.get('events/', {paging: false, trackedEntity: 'mAEqUcmcils', fields: 'event'})
    # delete all the events
    event_data['events']&.map { |event|
      client.delete("events/#{event.values[0]}/")
      puts("Deleted event - #{event["event"]}")
    }
  end

  after do
    # Do nothing
  end

  describe '#update_overdue_htn_visit_event_after_first_call' do
    let(:client) { Client.new('http://localhost:8080/api/', 'admin', 'district') }
    let(:program_id) { 'pMIglSEqPGS' }
    let(:org_unit_id) { 'SDXi1tscdL7' }
    let(:tracked_entity_instance_id) { 'mAEqUcmcils' }
    let(:bp_diastole_id) { 'yNhtHKtKkO1' }
    let(:bp_systole_id) { 'IxEwYiq1FTq' }
    let(:htn_visit_program_stage_id) { 'anb2cjLx3WM' }
    let(:calling_report_program_stage_id) { 'W7BCOaSquMd' }
    let(:result_of_call_id) { 'q362A7evMYt' }
    let(:remove_reason_id) { 'MZkqsWH2KSe' }
    let(:first_call_date_id) { 'Y6WYj6bbgeV' }

    it 'succeeds' do
      htn_visit = {
        program: program_id,
        eventDate: '2024-03-10',
        dueDate: '2024-03-10',
        programStage: htn_visit_program_stage_id,
        trackedEntityInstance: tracked_entity_instance_id,
        orgUnit: org_unit_id,
        status: 'COMPLETED',
        dataValues: [
          {
            dataElement: bp_systole_id,
            value: 143
          },
          {
            dataElement: bp_diastole_id,
            value: 92
          }
        ]
      }
      overdue_htn_visit = {
        program: program_id,
        dueDate: '2024-04-10',
        programStage: htn_visit_program_stage_id,
        status: 'SCHEDULE',
        trackedEntityInstance: tracked_entity_instance_id,
        orgUnit: org_unit_id
      }
      calling_report = {
        status: 'COMPLETED',
        program: program_id,
        programStage: calling_report_program_stage_id,
        trackedEntityInstance: tracked_entity_instance_id,
        orgUnit: org_unit_id,
        eventDate: '2024-04-11',
        dueDate: '2024-04-11',
        dataValues: [
          {
            dataElement: result_of_call_id,
            value: 'AGREE_TO_VISIT'
          }
        ]
      }
      _htn_visit_event = client.post('events/', htn_visit)
      overdue_htn_visit_event = client.post('events/', overdue_htn_visit)
      overdue_htn_visit_event_id = overdue_htn_visit_event['response']['importSummaries'][0]['reference']

      expect(data_element_in_event?(first_call_date_id, overdue_htn_visit_event_id)).to eq(false)

      _calling_report_event = client.post('events/', calling_report)
      expect(data_element_in_event?(first_call_date_id, overdue_htn_visit_event_id)).to eq(true)
    end
  end

  private

  def data_element_in_event?(data_element, event_id)
    event = client.get("events/#{event_id}", {paging: false, trackedEntity: 'mAEqUcmcils'})
    data_values = event['dataValues']&.map { |dv| dv['dataElement'] }
    puts data_values
    data_values.include?(data_element)
  end
end
