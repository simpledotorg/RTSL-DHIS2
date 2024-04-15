# frozen_string_literal: true

require 'rspec'
require_relative '../lib/client'
require_relative '../lib/event'

RSpec.describe 'Event' do
  let(:program_id) { 'pMIglSEqPGS' }
  let(:org_unit_id) { 'SDXi1tscdL7' }
  let(:data_element_id) { 'data_element_id' }
  let(:value) { '10' }

  describe '#create_event' do
    before do
      # clears events in DB
    end


    let(:event_data) do
      {
        program: program_id,
        eventDate: '2024-04-10',
        orgUnit: org_unit_id,
        dataValues: [
          { dataElement: data_element_id, value: value }
        ]
      }
    end

    describe "#index" do
      it 'should list all events' do
        client = Client.new("http://localhost:8080/","admin" , "district")
        events = Event.new(client).index
        puts(events)

      end
    end

    context 'when event creation is successful' do

      it 'creates an event' do

      end
    end

    context 'when event creation fails' do

    end
  end
end
