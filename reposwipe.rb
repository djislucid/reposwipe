#!/usr/bin/env ruby
# Created by djislucid

require 'net/http'
require 'optparse'
require 'colorize'
require 'json'
require 'git'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: swiperepo -n [name] [options]"

  opts.on("-n", "--name [NAME]", "Specify the name of the user or organizing who's repos you want to clone") do |name|
    options[:name] = name
  end

  opts.on("-o", "--org", "Clone all repos belonging to an organization") { options[:type] = "orgs" }
  opts.on("-u", "--user", "Clone all repos belonging to a user") { options[:type] = "users" }
  opts.on("-h", "--help", "Print this help text") do 
    puts opts
    exit 0
  end
end.parse!

# Make sure the -n option was specified
unless options[:name]
  puts "You must specify the name of a user or organization! See -h for more info".red
  exit 1
end

begin
  uri = URI("https://api.github.com/#{options[:type]}/#{options[:name]}/repos\?per_page\=100\&page\=1")
  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "token #{ENV['GITHUB_TOKEN']}"

  # Request the repos from Github
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(req)
  end

  # loop. Then clone all the repos in as multi-threaded a fashion as you can in ruby into options[:dir]
  # Then use Jobert's regex on all the files.
  JSON.parse(res.body).each do |object|
    begin
      # clone each of these into a directory
      repo = object['clone_url'].gsub(/"/, '')
      location = repo.split('/', -1)[4]
    rescue TypeError
      puts "You must specify whether #{options[:name]} is a user or organization (-o/-u). See -h for more info.".red
      exit
    end

    # Clone all the repos the a directory with the name you specified
    begin
      Git.clone(repo, location, :path => options[:name])
      puts "Cloned #{location} into #{Dir.pwd}/#{options[:name]}/#{location}".green
    rescue Git::GitExecuteError
      # if something went wrong move on. Likely the directory already exists
      puts "Failed to clone #{location}".red
      next
    end
  end

rescue Interrupt
  puts "Terminated by user".red
  exit
end