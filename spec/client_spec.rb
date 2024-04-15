# frozen_string_literal: true

require 'rspec'
require_relative '../lib/client'

RSpec.describe 'Client' do
  let(:base_url) { 'http://localhost:8080' }
  let(:username) { 'admin' }
  let(:fake_username) { 'fake' }
  let(:password) { 'district' }

  describe '#ok' do
    it 'returns 200 if client is successfully connected' do
      client = Client.new(base_url, username, password)
      response = client.ok
      expect(response.code).to eq(200.to_s)
    end

    it 'raises an SocketError when the server connection fails' do
      client = Client.new('http://notlocalhost:8080', username, password)
      expect { client.ok }.to raise_error(SocketError)
    end
  end
end
