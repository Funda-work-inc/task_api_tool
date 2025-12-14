require 'net/http'
require 'json'
require 'uri'

# task_learning_app の REST API クライアント
# Rails API（http://localhost:3000/api/v1）と通信してタスク操作を行う
class TaskApiClient
  # Rails API のベースURL
  BASE_URL = 'http://localhost:3000/api/v1'

  # タスク一覧を取得する
  # @return [Hash] { success: true, tasks: [...] } または { success: false, error: "..." }
  def fetch_tasks
    uri = URI("#{BASE_URL}/tasks")

    # HTTP GET リクエストを送信
    response = Net::HTTP.get_response(uri)

    # レスポンスを解析
    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      { success: true, tasks: data['tasks'] }
    else
      { success: false, error: "HTTPエラー: #{response.code} #{response.message}" }
    end
  rescue Errno::ECONNREFUSED
    # Rails API が起動していない場合
    { success: false, error: "APIサーバーに接続できません。task_learning_appが起動しているか確認してください。" }
  rescue JSON::ParserError => e
    # JSON パースエラー
    { success: false, error: "JSONの解析に失敗しました: #{e.message}" }
  rescue => e
    # その他のエラー
    { success: false, error: "エラーが発生しました: #{e.message}" }
  end

  # タスクを作成する
  # @param params [Hash] タスクのパラメータ { task: { title: "...", due_date: "...", priority: "..." } }
  # @return [Hash] { success: true, task: {...} } または { success: false, errors: [...] / error: "..." }
  def create_task(params)
    uri = URI("#{BASE_URL}/tasks")
    http = Net::HTTP.new(uri.host, uri.port)

    # POST リクエストを作成
    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request.body = params.to_json

    # リクエストを送信
    response = http.request(request)

    # レスポンスを解析
    parse_response(response)
  rescue Errno::ECONNREFUSED
    { success: false, error: "APIサーバーに接続できません" }
  rescue => e
    { success: false, error: "エラーが発生しました: #{e.message}" }
  end

  # タスクを更新する
  # @param id [Integer] タスクID
  # @param params [Hash] タスクのパラメータ
  # @return [Hash] { success: true, task: {...} } または { success: false, errors: [...] / error: "..." }
  def update_task(id, params)
    uri = URI("#{BASE_URL}/tasks/#{id}")
    http = Net::HTTP.new(uri.host, uri.port)

    # PATCH リクエストを作成
    request = Net::HTTP::Patch.new(uri.path, 'Content-Type' => 'application/json')
    request.body = params.to_json

    # リクエストを送信
    response = http.request(request)

    # レスポンスを解析
    parse_response(response)
  rescue Errno::ECONNREFUSED
    { success: false, error: "APIサーバーに接続できません" }
  rescue => e
    { success: false, error: "エラーが発生しました: #{e.message}" }
  end

  # タスクを削除する
  # @param id [Integer] タスクID
  # @return [Hash] { success: true, message: "..." } または { success: false, error: "..." }
  def delete_task(id)
    uri = URI("#{BASE_URL}/tasks/#{id}")
    http = Net::HTTP.new(uri.host, uri.port)

    # DELETE リクエストを作成
    request = Net::HTTP::Delete.new(uri.path)

    # リクエストを送信
    response = http.request(request)

    # レスポンスを解析（削除は特別処理）
    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      { success: true, message: data['message'] }
    elsif response.code.to_i == 404
      data = JSON.parse(response.body)
      { success: false, error: data['error'] }
    else
      { success: false, error: "HTTPエラー: #{response.code} #{response.message}" }
    end
  rescue Errno::ECONNREFUSED
    { success: false, error: "APIサーバーに接続できません" }
  rescue => e
    { success: false, error: "エラーが発生しました: #{e.message}" }
  end

  private

  # レスポンスを解析する
  # @param response [Net::HTTPResponse] HTTPレスポンス
  # @return [Hash] パース結果
  def parse_response(response)
    if response.is_a?(Net::HTTPSuccess)
      # 成功時（200 OK, 201 Created）
      data = JSON.parse(response.body)
      { success: true, task: data['task'] }
    elsif response.code.to_i == 422
      # バリデーションエラー（422 Unprocessable Entity）
      data = JSON.parse(response.body)
      { success: false, errors: data['errors'] }
    elsif response.code.to_i == 404
      # Not Found（404）
      data = JSON.parse(response.body)
      { success: false, error: data['error'] }
    else
      # その他のエラー
      { success: false, error: "HTTPエラー: #{response.code} #{response.message}" }
    end
  rescue JSON::ParserError => e
    { success: false, error: "JSONの解析に失敗しました: #{e.message}" }
  end
end
