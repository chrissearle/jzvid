#!/usr/bin/env ruby

require 'vimeo'
require 'json'
require 'open-uri'
require 'yaml'

def clean_title(title)
  title.strip.upcase.gsub(/[^A-Z\s]/, '').gsub(/\n/, " ").gsub(/  */, " ")
end

class Configuration
  def initialize
    @config = YAML.load_file("config.yaml")
  end

  def vimeo?
    @options[:vimeo]
  end

  def vimeo
    {
        :key          => @config["vimeo"]["key"],
        :secret       => @config["vimeo"]["secret"],
        :token        => @config["vimeo"]["token"],
        :token_secret => @config["vimeo"]["token_secret"],
        :album        => @config["vimeo"]["album"]
    }
  end
  
  def ems
    {
      :url => @config["ems"]["url"]
    }
  end
end

class Videos
  def initialize(config)
    @album = Vimeo::Advanced::Album.new(config.vimeo[:key],
                                        config.vimeo[:secret],
                                        :token => config.vimeo[:token],
                                        :secret => config.vimeo[:token_secret])
    @album_id = config.vimeo[:album]
  end

  def retrieve
    page = 1
    seen = 0
    total = 10000000

    result = {}
    
    until (seen >= total)
      videos = @album.get_videos(@album_id, :page => page, :per_page => 50, :full_response => 1)

      total = videos['videos']['total'].to_i

      page = page + 1

      seen = seen + videos['videos']['on_this_page'].to_i

      videos['videos']['video'].map do |video|
        item = {
          :vtitle      => video['title'],
          :vurl        => video['urls']['url'].first['_content'],
          :vcleantitle => clean_title(video['title'])
        }
        result[item[:vcleantitle]] = item
      end
    end
    
    result
  end
end

class EMS
  def initialize(config)
    @url = config.ems[:url]
  end
  
  def retrieve
    json_response = nil

    open(@url, "Accept" => "application/json") { |f|
      json_response = f.gets(nil)
    }

    doc = JSON.parse json_response

    result = {}

    doc["collection"]["items"].each do |session|
      item = {
        :etitle      => session['data'].find{|i| i["name"] == "title"}["value"],
        :eurl        => session['href'],
        :ecleantitle => clean_title(session['data'].find{|i| i["name"] == "title"}["value"])
      }
      result[item[:ecleantitle]] = item
    end
    
    result
  end
end

config = Configuration.new

videos = Videos.new(config)
ems = EMS.new(config)

items = ems.retrieve.merge(videos.retrieve){|key, oldval, newval| newval.merge(oldval)}.values

items.find_all{|i| i.has_key?(:vurl) && i.has_key?(:eurl)}.map {|item| puts "#{item[:eurl].gsub(/.*\//, "")}\t#{item[:vurl]}"}

items.find_all{|i| i.has_key?(:vurl) && !i.has_key?(:eurl)}.map {|item| $stderr.puts "#{item[:vtitle]} only on Vimeo #{item[:vurl]}"}

items.find_all{|i| !i.has_key?(:vurl) && i.has_key?(:eurl)}.map {|item| $stderr.puts "#{item[:etitle]} only on EMS #{item[:eurl]}"}
