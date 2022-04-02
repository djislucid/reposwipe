#!/usr/bin/env ruby

require 'net/http'
require 'optparse'
require 'json'
require 'git'


options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: giturls -n [name] [options]"

  opts.on("-n", "--name [NAME]", "Specify the name of the user or organizing who's repos you want to clone") do |name|
    options[:name] = name
  end

  opts.on("-o", "--org", "Clone all repos belonging to an organization") { options[:type] = "orgs" }
  opts.on("-u", "--user", "Clone all repos belonging to a user") { options[:type] = "users" }
  opts.on("-h", "--help", "Print this help text") { puts opts }
end.parse!

# Request all the repos
uri = URI("https://api.github.com/#{options[:type]}/#{options[:name]}/repos\?per_page\=100\&page\=1")
req = Net::HTTP::Get.new(uri)
req["Authorization"] = "token #{ENV['GITHUB_TOKEN']}"

res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
  http.request(req)
end

# loop. Then clone all the repos in as multi-threaded a fashion as you can in ruby into options[:dir]
# Then use Jobert's regex on all the files.
parsed = JSON.parse(res.body)

parsed.each do |object|
  # clone each of these into a directory
  repo = object['clone_url'].gsub(/"/, '')
  location = repo.split('/', -1)[4]

  Git.clone(repo, location, :path => options[:name])
end

