require 'sinatra'
require 'sinatra/reloader' if development?
require_relative 'lib/task_api_client'

# Webhook履歴をメモリ内に保存するクラス変数
class WebhookHistory
  @@logs = []

  def self.add(log)
    @@logs.unshift(log)
    @@logs = @@logs.first(10) # 最新10件まで保持
  end

  def self.all
    @@logs
  end

  def self.clear
    @@logs = []
  end
end

# セッションを有効化（フラッシュメッセージ用）
if ENV['RACK_ENV'] == 'production'
  # 本番環境では暗号化セッション
  enable :sessions
else
  # 開発・テスト環境ではCookieセッション（暗号化なし）
  use Rack::Session::Cookie, secret: 'development_secret_key_change_in_production'
end

# フラッシュメッセージヘルパー
helpers do
  def flash
    session[:flash] ||= {}
  end
end

# リクエスト前にフラッシュメッセージを読み込み
before do
  @flash = flash.dup
  session[:flash] = {}
end

# トップページ（タスク一覧表示）
get '/' do
  # API クライアントを初期化
  client = TaskApiClient.new

  # タスク一覧を取得
  result = client.fetch_tasks

  # 取得結果に応じて変数を設定
  if result[:success]
    @tasks = result[:tasks]
    @error = nil
  else
    @tasks = []
    @error = result[:error]
  end

  # ビューをレンダリング
  erb :index
end

# タスク作成
post '/tasks/create' do
  # API クライアントを初期化
  client = TaskApiClient.new

  # リクエストパラメータを作成
  params_hash = {
    task: {
      title: params[:title],
      due_date: params[:due_date],
      priority: params[:priority]
    }
  }

  # プロジェクトIDがある場合は追加
  params_hash[:task][:project_id] = params[:project_id] if params[:project_id] && !params[:project_id].empty?

  # API呼び出し
  result = client.create_task(params_hash)

  # 結果に応じてフラッシュメッセージを設定
  if result[:success]
    flash[:success] = "✅ タスクを作成しました！（ID: #{result[:task]['id']}）"
  elsif result[:errors]
    flash[:error] = "❌ #{result[:errors].join(', ')}"
  else
    flash[:error] = "❌ #{result[:error]}"
  end

  redirect '/'
end

# タスク更新
post '/tasks/update/:id' do
  # API クライアントを初期化
  client = TaskApiClient.new

  # リクエストパラメータを作成
  params_hash = {
    task: {}
  }

  # 各パラメータが空でなければ追加
  params_hash[:task][:title] = params[:title] if params[:title] && !params[:title].empty?
  params_hash[:task][:due_date] = params[:due_date] if params[:due_date] && !params[:due_date].empty?
  params_hash[:task][:priority] = params[:priority] if params[:priority] && !params[:priority].empty?
  params_hash[:task][:project_id] = params[:project_id] if params[:project_id] && !params[:project_id].empty?

  # API呼び出し
  result = client.update_task(params[:id], params_hash)

  # 結果に応じてフラッシュメッセージを設定
  if result[:success]
    flash[:success] = "✅ タスクを更新しました！（ID: #{params[:id]}）"
  elsif result[:errors]
    flash[:error] = "❌ #{result[:errors].join(', ')}"
  else
    flash[:error] = "❌ #{result[:error]}"
  end

  redirect '/'
end

# タスク削除
post '/tasks/delete/:id' do
  # API クライアントを初期化
  client = TaskApiClient.new

  # API呼び出し
  result = client.delete_task(params[:id])

  # 結果に応じてフラッシュメッセージを設定
  if result[:success]
    flash[:success] = "✅ #{result[:message]}（ID: #{params[:id]}）"
  else
    flash[:error] = "❌ #{result[:error]}"
  end

  redirect '/'
end

# Webhook受信エンドポイント
post '/webhook' do
  # リクエストボディを読み取り
  request.body.rewind
  payload = JSON.parse(request.body.read)

  # ログに記録
  puts "=" * 50
  puts "🔔 Webhook受信！"
  puts "イベント: #{payload['event']}"
  puts "タスクID: #{payload['task']['id']}"
  puts "タスク名: #{payload['task']['title']}"
  puts "発生時刻: #{payload['timestamp']}"
  puts "=" * 50

  # Webhook履歴をメモリ内に保存（最新10件まで）
  WebhookHistory.add({
    event: payload['event'],
    task: payload['task'],
    timestamp: payload['timestamp']
  })

  # 成功レスポンスを返す
  status 200
  content_type :json
  { success: true, message: "Webhook received" }.to_json
rescue JSON::ParserError => e
  # JSONパースエラー
  status 400
  content_type :json
  { success: false, error: "Invalid JSON: #{e.message}" }.to_json
rescue => e
  # その他のエラー
  status 500
  content_type :json
  { success: false, error: "Server error: #{e.message}" }.to_json
end

# Webhook履歴表示ページ
get '/webhooks' do
  @webhook_logs = WebhookHistory.all
  erb :webhooks
end

# Webhook履歴取得API（リアルタイム更新用）
get '/api/webhook_logs' do
  # メモリからWebhook履歴を取得
  webhook_logs = WebhookHistory.all

  # JSON形式で返す
  content_type :json
  { webhook_logs: webhook_logs }.to_json
end
