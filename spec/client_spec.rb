# frozen_string_literal: true

require 'rspec'
require_relative '../lib/client'

RSpec.describe 'Client' do
  let(:base_url) { 'http://localhost:9080' }
  let(:username) { 'admin' }
  let(:fake_username) { 'fake' }
  let(:password) { 'district' }

  describe '#ok' do
    it 'returns 200 if client is successfully connected' do
      client = Client.new(base_url, username, password)
      response = client.ok
      expect(response&.code.to_i).to eq(200)
    end

    it 'raises an SocketError when the server is not available' do
      client = Client.new('http://notlocalhost:8080', username, password)
      expect { client.ok }.to raise_error(SocketError)
    end

    it 'raises an error when the server connection fails' do
      client = Client.new(base_url, fake_username, password)
      expect { client.ok }.to raise_error(Errno::ECONNREFUSED)

    end
  end
end
