#!/usr/bin/env ruby
# Created by djislucid
# Add multithreading
# For now this works by: reposwipe -n att -r --org| extract_urls
# I'll add it in later

require 'net/http'
require 'optparse'
require 'colorize'
require 'json'
require 'git'
require 'find'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: reposwipe -n [name] [options]"

  opts.on("-n", "--name [NAME]", "Specify the name of the user or organizing who's repos you want to clone") do |name|
    options[:name] = name
  end

  opts.on("-o", "--org", "Clone all repos belonging to an organization") { options[:type] = "orgs" }
  opts.on("-u", "--user", "Clone all repos belonging to a user") { options[:type] = "users" }
  opts.on("-r", "--relative-urls", "Cat the file contents and search for relative URLS") do |regex|
    options[:regex] = true
  end
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

# List all files in the repos
def list_recursively(dir)
  Find.find(dir) do |path|
    first_dir = path.split(/#{dir}/, -1)[1].split('/', -1)[1]

    # don't need to read files in the .git directory of the repo
    if first_dir != ".git"
      content = File.read(path) unless FileTest.directory?(path)

      # this is where we would eventually use Jobert's regex
      # since it involves relative URLs you can't exactly check for att.com in the URL for example
      # But we could always add that as an optional flag
      puts content
    end
  end
end

begin
  uri = URI("https://api.github.com/#{options[:type]}/#{options[:name]}/repos\?per_page\=100\&page\=1")
  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "token #{ENV['GITHUB_TOKEN']}"

  # Request the repos from Github
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(req)
  end

  # Parse the JSON response for the clone URLs
  JSON.parse(res.body).each do |object|
    begin
      repo = object['clone_url'].gsub(/"/, '')
      location = repo.split('/', -1)[4]
    rescue TypeError
      puts "You must specify whether #{options[:name]} is a user or organization (-o/-u). See -h for more info.".red
      exit
    end

    # Clone all the repos the a directory with the name you specified
    begin
      Git.clone(repo, location, :path => options[:name])

      path = "#{Dir.pwd}/#{options[:name]}/#{location}"
      puts "Cloned #{location.green} into #{path.green}"

      # list the files in the directory we just clone
      list_recursively(path) if options[:regex]
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
