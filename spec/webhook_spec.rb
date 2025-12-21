require 'spec_helper'
require 'json'

RSpec.describe 'Webhook endpoint' do
  describe 'POST /webhook' do
    let(:valid_payload) do
      {
        event: 'created',
        task: {
          id: 1,
          title: 'テストタスク',
          priority: 'high',
          due_date: '2025-12-21',
          completed_at: nil,
          created_at: '2025-12-14T12:00:00Z',
          updated_at: '2025-12-14T12:00:00Z'
        },
        timestamp: '2025-12-14T12:00:00Z'
      }
    end

    context '正常なWebhookペイロードの場合' do
      it '200 OKを返す' do
        post '/webhook', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(200)
      end

      it '成功レスポンスを返す' do
        post '/webhook', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.body).to include_json(
          success: true,
          message: 'Webhook received'
        )
      end

      it 'Content-Typeがapplication/jsonである' do
        post '/webhook', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.content_type).to include('application/json')
      end
    end

    context '不正なJSONの場合' do
      it '400 Bad Requestを返す' do
        post '/webhook', 'invalid json', { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
      end

      it 'エラーメッセージを含む' do
        post '/webhook', 'invalid json', { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.body).to include_json(
          success: false
        )
        expect(JSON.parse(last_response.body)['error']).to include('Invalid JSON')
      end
    end

    context '各イベントタイプのWebhookの場合' do
      ['created', 'updated', 'destroyed'].each do |event_type|
        it "#{event_type}イベントを正常に受信する" do
          payload = valid_payload.merge(event: event_type)
          post '/webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }

          expect(last_response.status).to eq(200)
          expect(last_response.body).to include_json(success: true)
        end
      end
    end
  end

  describe 'GET /webhooks' do
    it '200 OKを返す' do
      get '/webhooks'

      expect(last_response.status).to eq(200)
    end
  end
end
