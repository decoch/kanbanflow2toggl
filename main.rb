# coding: utf-8
require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'date'
require 'time'

kanban_flow_api_token = ENV['KANBAN_FLOW_API_TOKEN']
toggl_api_token = ENV['TOGGL_API_TOKEN']
toggl_default_project_id = ENV['TOGGL_DEFAULT_PROJECT_ID']
color_project_mappings = JSON.parse(ENV['COLOR_PROJECT_MAPPINGS'] || '{}')

# Get kanban flow tasks
uri = URI.parse("https://kanbanflow.com/api/v1/tasks?apiToken=#{kanban_flow_api_token}")
response = Net::HTTP.get_response(uri)
columns = JSON.parse(response.body)
tasks = columns
  .map { |column| column['tasks'] }
  .flatten
  .map{ |task| [task['_id'], task] }.to_h

# Get kanban flow tiem entries
from = (Date.today-1).strftime('%Q').to_i
to = (Date.today).strftime('%Q').to_i
uri = URI.parse("https://kanbanflow.com/api/v1/time-entries?apiToken=#{kanban_flow_api_token}&from=#{from}&to=#{to}")
response = Net::HTTP.get_response(uri)
time_entries = JSON.parse(response.body)

# Merge & format to toggl
toggl_entries = time_entries.map do |entry|
  task = tasks[entry['taskId']]
  {
    time_entry: {
      description: task['name'],
      duration: Time.parse(entry['endTimestamp']) - Time.parse(entry['startTimestamp']),
      start: entry['startTimestamp'],
      pid: color_project_mappings[task['color']] || toggl_default_project_id,
      created_with: 'KanbanFlow2Toggl'
    }
  }
end

# Post to toggl
toggl_entries.each do |entry|
  body = entry.to_json

  uri = URI('https://www.toggl.com/api/v8/time_entries')
  request = Net::HTTP::Post.new(uri.request_uri)
  request.basic_auth toggl_api_token, 'api_token'
  request['Content-Type'] = 'application/json'
  request.body = body

  Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
end