#!/usr/bin/env ruby

require 'optparse'
require 'uri'
require 'mongo'
require 'vimeo'
require 'json'
require 'open-uri'
require 'yaml'

class Configuration
  def initialize
    @config = YAML.load_file("config.yaml")
    @options = options
  end

  def tag
    @config["tag"]
  end

  def vimeo?
    @options[:vimeo]
  end

  def vimeo
    {
        :key          => @config["vimeo"]["key"],
        :secret       => @config["vimeo"]["secret"],
        :token        => @config["vimeo"]["token"],
        :token_secret => @config["vimeo"]["token_secret"]
    }
  end

  def incogito?
    @options[:incogito]
  end

  def incogito_url
    @config["incogito"]["url"]
  end

  def match?
    @options[:match]
  end

  def set_output
    if @options[:file]
      $stdout.reopen(@options[:file], "w")
    end
  end

  def db
    @db ||= connect
  end

  private

  def connect
    conn = Mongo::Connection.from_uri(@config["mongo"]["uri"])
    conn.db(@config["mongo"]["db"])
  end

  def options
    options = {}

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: javazone.rb [options]"

      options[:vimeo] = false
      opts.on('-v', '--vimeo', 'Retrieve videos from vimeo') do
        options[:vimeo] = true
      end

      options[:incogito] = false
      opts.on('-i', '--incogito', 'Retrieve sessions from incogito') do
        options[:incogito] = true
      end

      options[:match] = false
      opts.on('-m', '--match', 'Match sessions and generate plist') do
        options[:match] = true
      end

      options[:file] = nil
      opts.on('-f', '--file PLIST', 'When passing -i write plist to PLIST instead of STDOUT') do |file|
        options[:file] = file
      end

      opts.on('-h', '--help', 'Display this screen') do
        puts opts
        exit
      end
    end

    optparse.parse!

    options
  end

end

class Videos
  def initialize(config)
    @db = config.db

    @video = Vimeo::Advanced::Video.new(config.vimeo[:key], config.vimeo[:secret],
                                        :token => config.vimeo[:token], :secret => config.vimeo[:token_secret])
  end

  def retrieve
    coll = @db['videos']
    coll.drop

    page = 1
    seen = 0
    total = 10000000

    until (seen >= total)
      videos = @video.get_all("javazone", :page => page, :per_page => 50, :full_response => 1)

      total = videos['videos']['total'].to_i

      page = page + 1

      seen = seen + videos['videos']['on_this_page'].to_i

      videos['videos']['video'].map do |video|
        item = Item.new(coll)
        item.item= video
        item.store
      end
    end

    puts "#{seen} videos seen on vimeo."
  end
end

class Incogito
  def initialize(config)
    @db = config.db
    @url = config.incogito_url
  end

  def retrieve
    coll = @db['sessions']
    coll.drop

    json_response = nil

    open(@url, "Accept" => "application/json") { |f|
      json_response = f.gets(nil)
    }

    doc = JSON.parse json_response

    doc["sessions"].each do |session|
      item = Item.new(coll)
      item.item= session
      item.store
    end

    puts "#{doc["sessions"].size} sessions seen on incogito."
  end
end

class Item
  def initialize(coll)
    @coll = coll
  end


  def item= (item)
    @item = item
  end

  def store
    cleantitle

    save
  end

  def all
    @coll.find.map do |i|
      item = Item.new(@coll)
      item.item= i

      item
    end
  end

  def find_by_compare_key(key_val)
    @coll.find({cleantitle: key_val}).map do |i|
      item = Item.new(@coll)
      item.item= i

      item
    end
  end

  def is_published
    @item['privacy'] && (@item['privacy'] == "anybody")
  end

  def compare_key
    @item['cleantitle']
  end

  def has_tag(tag)
    @item['tags'] && @item['tags']['tag'].map { |m| m['normalized'] }.include?(tag.downcase.gsub(/ */, ""))
  end

  def title
    @item['title']
  end

  def id
    @item['id']
  end

  def url
    @item['urls']['url'].first['_content']
  end

  def settings_url
    "#{url}/settings"
  end

  private

  def cleantitle
    @item['cleantitle'] = @item['title'].strip.upcase.gsub(/  */, " ")
  end

  def save
    @coll.insert(@item)
  end
end

config = Configuration.new

if config.vimeo?
  videos = Videos.new(config)
  videos.retrieve
end

if config.incogito?
  incogito = Incogito.new(config)
  incogito.retrieve
end

if config.match?
  db = config.db

  sessions = Item.new(db['sessions'])
  videos = Item.new(db['videos'])

  mapping = Hash.new
  titles = Hash.new

  errors = Hash.new
  errors[:session] = Array.new
  errors[:duplicates] = Hash.new
  errors[:tag] = Array.new
  errors[:video] = Array.new

  videos.all.each do |video|
    next unless video.is_published

    seen = false

    if titles.has_key? video.compare_key
      titles[video.compare_key] << video.settings_url
      errors[:duplicates][video.title] = titles[video.compare_key]
    else
      titles[video.compare_key] = Array.new
      titles[video.compare_key] << video.settings_url
    end

    sessions.find_by_compare_key(video.compare_key).each do |session|
      seen = true

      mapping[session.id] = video.id

      errors[:tag] << {:title => video.title, :url => video.settings_url} unless video.has_tag(config.tag)
    end

    unless seen
      errors[:video] << {:title => video.title, :url => video.settings_url} if video.has_tag(config.tag)
    end
  end

  sessions.all.each do |session|
    errors[:session] << session.title unless mapping.has_key? session.id
  end

  puts "Found a matching video from vimeo with title but missing tag '#{config.tag}':" if errors[:tag].size > 0
  errors[:tag].each do |error|
    puts "    #{error[:title]}"
    puts "        #{error[:url]}"
  end

  puts "Saw a duplicate video from vimeo with title:" if errors[:duplicates].size > 0
  errors[:duplicates].sort.each do |title, links|
    puts "    #{title}"
    links.each do |link|
      puts "        #{link}"
    end
  end

  puts "Session seen but didn't find a video:" if errors[:session].size > 0
  errors[:session].sort.each do |error|
    puts "    #{error}"
  end

  puts "Video on vimeo had no matching session - perhaps the title is incorrect:" if errors[:video].size > 0
  errors[:video].each do |error|
    puts "    #{error[:title]}"
    puts "        #{error[:url]}"
  end

  puts "Matched: #{mapping.size}"
  
  config.set_output

  puts <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
EOF

  mapping.each do |session, video|
    puts <<EOF
  	<key>#{session}</key>
  	<string>http://player.vimeo.com/video/#{video}</string>
EOF
  end

  puts <<EOF
  </dict>
</plist>
EOF
end