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

  describe 'GET /api/webhook_logs' do
    context 'Webhook履歴がセッションに保存されている場合' do
      before do
        # セッションにWebhook履歴を設定
        env 'rack.session', {
          webhook_logs: [
            {
              event: 'created',
              task: {
                'id' => 1,
                'title' => 'テストタスク1',
                'priority' => 'high',
                'due_date' => '2025-12-21'
              },
              timestamp: '2025-12-14T12:00:00Z'
            },
            {
              event: 'updated',
              task: {
                'id' => 2,
                'title' => 'テストタスク2',
                'priority' => 'medium',
                'due_date' => '2025-12-22'
              },
              timestamp: '2025-12-14T13:00:00Z'
            }
          ]
        }
      end

      it '200 OKを返す' do
        get '/api/webhook_logs'

        expect(last_response.status).to eq(200)
      end

      it 'Content-Typeがapplication/jsonである' do
        get '/api/webhook_logs'

        expect(last_response.content_type).to include('application/json')
      end

      it 'Webhook履歴をJSON形式で返す' do
        get '/api/webhook_logs'

        response_body = JSON.parse(last_response.body)
        expect(response_body['webhook_logs']).to be_an(Array)
        expect(response_body['webhook_logs'].length).to eq(2)
        expect(response_body['webhook_logs'][0]['event']).to eq('created')
        expect(response_body['webhook_logs'][0]['task']['title']).to eq('テストタスク1')
      end
    end

    context 'Webhook履歴が空の場合' do
      before do
        # セッションを空に設定
        env 'rack.session', { webhook_logs: [] }
      end

      it '200 OKを返す' do
        get '/api/webhook_logs'

        expect(last_response.status).to eq(200)
      end

      it '空の配列を返す' do
        get '/api/webhook_logs'

        response_body = JSON.parse(last_response.body)
        expect(response_body['webhook_logs']).to eq([])
      end
    end
  end

  describe 'GET /' do
    context 'Webhook履歴がセッションに保存されている場合' do
      before do
        # TaskApiClientをモック化
        allow_any_instance_of(TaskApiClient).to receive(:fetch_tasks).and_return({
          success: true,
          tasks: []
        })

        # セッションにWebhook履歴を設定
        env 'rack.session', {
          webhook_logs: [
            {
              event: 'created',
              task: {
                'id' => 1,
                'title' => 'テストタスク',
                'priority' => 'high',
                'due_date' => '2025-12-21'
              },
              timestamp: '2025-12-14T12:00:00Z'
            }
          ]
        }
      end

      it 'Webhook履歴セクションが表示される' do
        get '/'

        expect(last_response.body).to include('Webhook受信履歴')
        expect(last_response.body).to include('webhook-logs-table')
      end
    end
  end
end
