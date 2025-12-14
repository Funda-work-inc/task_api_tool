require 'sinatra'
require 'sinatra/reloader' if development?
require_relative 'lib/task_api_client'

# セッションを有効化（フラッシュメッセージ用）
enable :sessions

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
