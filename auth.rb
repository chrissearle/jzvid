require 'vimeo'
require 'yaml'

config = YAML.load_file("config.yaml")

base = Vimeo::Advanced::Base.new(@config["vimeo"]["key"], @config["vimeo"]["secret"])

#request_token = base.get_request_token

#puts request_token.secret
#puts base.authorize_url
#http://vimeo.com/oauth/authorize?permission=delete&oauth_token=<oauth token>
#<oauth secret>

#access_token = base.get_access_token("<oauth token>", "<oauth secret>", "<oauth verifier>")

#puts access_token.token
#puts access_token.secret
