# frozen_string_literal: true

require 'rspec'
require_relative '../lib/client'
require_relative '../lib/event_trigger'
require 'active_support/all'
require 'dotenv'
Dotenv.load('.env')

RSpec.describe 'EventTrigger' do
  before do
    # 1. Ensure the trigger function in present in the DHIS2 database. If not present, run `rake db:migrate`.
    # 2. Delete all the events(if any) of the 'test' tracked entity instance - 'mAEqUcmcils'
    [tracked_entity_instance_1_id, tracked_entity_instance_2_id].map do |tei|
      event_data = client.get('events/', { paging: false, trackedEntity: tei, fields: 'event' })
      event_data['events']&.map do |event|
        client.delete("events/#{event.values[0]}/")
      end
    end
  end

  describe '#update_overdue_htn_visit_event_after_first_call' do
    let(:client) { Client.new("#{ENV['DHIS2_URL']}api/", ENV['DHIS2_USERNAME'], ENV['DHIS2_PASSWORD']) }
    let(:program_id) { 'pMIglSEqPGS' }
    let(:org_unit_id) { 'SDXi1tscdL7' }
    let(:tracked_entity_instance_1_id) { 'mAEqUcmcils' }
    let(:tracked_entity_instance_2_id) { 'hq1rJeuaFjX' }
    let(:bp_diastole_id) { 'yNhtHKtKkO1' }
    let(:bp_systole_id) { 'IxEwYiq1FTq' }
    let(:htn_visit_program_stage_id) { 'anb2cjLx3WM' }
    let(:calling_report_program_stage_id) { 'W7BCOaSquMd' }
    let(:result_of_call_id) { 'q362A7evMYt' }
    let(:remove_reason_id) { 'MZkqsWH2KSe' }
    let(:first_call_date_id) { 'Y6WYj6bbgeV' }

    it 'updates the htn & diabetes visit event which is overdue with details of calling report event' do
      overdue_htn_visit_event_ids = [tracked_entity_instance_1_id, tracked_entity_instance_2_id].map do |tei|
        htn_visit = {
          program: program_id,
          eventDate: '2024-03-10',
          dueDate: '2024-03-10',
          programStage: htn_visit_program_stage_id,
          trackedEntityInstance: tei,
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
          trackedEntityInstance: tei,
          orgUnit: org_unit_id
        }
        _htn_visit_event = client.post('events/', htn_visit)
        overdue_htn_visit_event = client.post('events/', overdue_htn_visit)
        overdue_htn_visit_event['response']['importSummaries'][0]['reference']
      end

      overdue_htn_visit_event_ids.map do |event_id|
        expect(has_data_element?(first_call_date_id, event_id)).to eq(false)
      end

      calling_report1 = {
        status: 'COMPLETED',
        program: program_id,
        programStage: calling_report_program_stage_id,
        trackedEntityInstance: tracked_entity_instance_1_id,
        orgUnit: org_unit_id,
        eventDate: '2024-04-11',
        dueDate: '2024-04-11',
        dataValues: [
          {
            dataElement: result_of_call_id,
            value: 'REMOVE_FROM_OVERDUE'
          },
          {
            dataElement: remove_reason_id,
            value: 'MOVED'
          }
        ]
      }
      calling_report2 = {
        status: 'COMPLETED',
        program: program_id,
        programStage: calling_report_program_stage_id,
        trackedEntityInstance: tracked_entity_instance_2_id,
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
      _calling_report_event = client.post('events/', calling_report1)
      _calling_report_event = client.post('events/', calling_report2)

      expect(has_data_element?(first_call_date_id, overdue_htn_visit_event_ids[0])).to eq(true)
      expect(get_value(first_call_date_id, overdue_htn_visit_event_ids[0]).to_date).to eq('2024-04-11'.to_date)
      expect(get_value(result_of_call_id, overdue_htn_visit_event_ids[0])).to eq('REMOVE_FROM_OVERDUE')
      expect(get_value(remove_reason_id, overdue_htn_visit_event_ids[0])).to eq('MOVED')
      expect(has_data_element?(first_call_date_id, overdue_htn_visit_event_ids[1])).to eq(true)
      expect(get_value(first_call_date_id, overdue_htn_visit_event_ids[1]).to_date).to eq('2024-04-11'.to_date)
      expect(get_value(result_of_call_id, overdue_htn_visit_event_ids[1])).to eq('AGREE_TO_VISIT')
    end

    it 'updates the htn & diabetes visit event whose status is SCHEDULE' do
      htn_visit = {
        program: program_id,
        eventDate: '2024-03-10',
        dueDate: '2024-03-10',
        programStage: htn_visit_program_stage_id,
        trackedEntityInstance: tracked_entity_instance_1_id,
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
        trackedEntityInstance: tracked_entity_instance_1_id,
        orgUnit: org_unit_id
      }
      calling_report = {
        status: 'COMPLETED',
        program: program_id,
        programStage: calling_report_program_stage_id,
        trackedEntityInstance: tracked_entity_instance_1_id,
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
      htn_visit_event = client.post('events/', htn_visit)
      htn_visit_event_id = htn_visit_event['response']['importSummaries'][0]['reference']
      overdue_htn_visit_event = client.post('events/', overdue_htn_visit)
      overdue_htn_visit_event_id = overdue_htn_visit_event['response']['importSummaries'][0]['reference']
      _calling_report_event = client.post('events/', calling_report)

      expect(has_data_element?(first_call_date_id, overdue_htn_visit_event_id)).to eq(true)
      expect(get_event_data(overdue_htn_visit_event_id)['status']).to eq('SCHEDULE')
      expect(has_data_element?(first_call_date_id, htn_visit_event_id)).to eq(false)
      expect(get_event_data(htn_visit_event_id)['status']).to eq('COMPLETED')
    end

    it 'updates the htn & diabetes visit event with the details of the first call' do
      htn_visit = {
        program: program_id,
        eventDate: '2024-03-10',
        dueDate: '2024-03-10',
        programStage: htn_visit_program_stage_id,
        trackedEntityInstance: tracked_entity_instance_1_id,
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
        trackedEntityInstance: tracked_entity_instance_1_id,
        orgUnit: org_unit_id
      }
      calling_report_1 = {
        status: 'COMPLETED',
        program: program_id,
        programStage: calling_report_program_stage_id,
        trackedEntityInstance: tracked_entity_instance_1_id,
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
      calling_report_2 = {
        status: 'COMPLETED',
        program: program_id,
        programStage: calling_report_program_stage_id,
        trackedEntityInstance: tracked_entity_instance_1_id,
        orgUnit: org_unit_id,
        eventDate: '2024-04-11',
        dueDate: '2024-04-11',
        dataValues: [
          {
            dataElement: result_of_call_id,
            value: 'REMIND_TO_CALL'
          }
        ]
      }
      _htn_visit_event = client.post('events/', htn_visit)
      overdue_htn_visit_event = client.post('events/', overdue_htn_visit)
      overdue_htn_visit_event_id = overdue_htn_visit_event['response']['importSummaries'][0]['reference']
      _calling_report_event_1 = client.post('events/', calling_report_1)
      _calling_report_event_2 = client.post('events/', calling_report_2)
      overdue_event_data = get_event_data(overdue_htn_visit_event_id)

      expect(overdue_event_data['status']).to eq('SCHEDULE')
      expect(has_data_element?(first_call_date_id, overdue_htn_visit_event_id)).to eq(true)
      expect(overdue_event_data['dataValues'][0]['value']).to eq('AGREE_TO_VISIT')
    end
  end

  private

  def get_event_data(event_id)
    client.get("events/#{event_id}", { paging: false, trackedEntity: tracked_entity_instance_1_id })
  end

  def get_data_values(event_id)
    get_event_data(event_id)['dataValues']
  end

  def has_data_element?(data_element, event_id)
    data_values = get_data_values(event_id)
    return false if data_values&.empty?

    data_elements = data_values.map { |dv| dv['dataElement'] }
    data_elements.include?(data_element)
  end

  def get_value(data_element_id, event_id)
    data_values = get_data_values(event_id)
    return if data_values&.empty?

    data_values.map do |dv|
      return dv['value'] if dv['dataElement'] == data_element_id
    end
  end
end
