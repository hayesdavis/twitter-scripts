require 'rubygems'
require 'uri'
require 'yajl'
require 'yajl/http_stream'
require 'yajl/json_gem'
require 'ruby-growl'

class ChirpHaxStream
  
  def initialize(screen_name, password)
    @screen_name = screen_name
    @password = password
    @users_by_id={}
  end
  
  def run
    g = Growl.new "localhost", "ruby-growl", ["ruby-growl Notification"]    
    uri = URI.parse("http://#{@screen_name}:#{@password}@chirpstream.twitter.com/2b/user.json")
    puts "Listening for user stream events for #{@screen_name}"    
    Yajl::HttpStream.get(uri, :symbolize_keys => true) do |hash|
      if hash[:event]
        puts hash.inspect        
        msg = case hash[:event]
          when 'favorite'   then favorite_message(hash)
          when 'unfavorite' then unfavorite_message(hash)
          when 'follow'     then follow_message(hash)
          when 'retweet'    then retweet_message(hash)
          else "#{hash[:event]} #{hash[:target].inspect}"
        end
        if msg
          g.notify "ruby-growl Notification", "ChirpHax Growler", msg
        end
      end
    end
  end
  
  private
    def follow_message(event)
      results = users(event[:source][:id],event[:target][:id])
      source = results.find{|r| r[:id] == event[:source][:id]}
      target = results.find{|r| r[:id] == event[:target][:id]}
      "#{source[:screen_name]} followed #{target[:screen_name]}"
    end
 
    def retweet_message(event)
      source = user(event[:source][:id])
      rt = tweet(event[:target_object][:id])
      "#{source[:screen_name]} retweeted #{rt[:user][:screen_name]}: \"#{rt[:text]}\""
    end
  
    def favorite_message(event)
      source = user(event[:source][:id])
      fav = tweet(event[:target_object][:id])
      "#{source[:screen_name]} favorited: #{fav[:user][:screen_name]}: \"#{fav[:text]}\""
    end
  
    def unfavorite_message(event)
      source = user(event[:source][:id])
      fav = tweet(event[:target_object][:id])
      "#{source[:screen_name]} un-favorited: #{fav[:user][:screen_name]}: \"#{fav[:text]}\""
    end
     
    def user(id)
      some_user = @users_by_id[id]
      unless some_user
        some_user = rest_get("users/show.json?id=#{id}")
        @users_by_id[id] = some_user
      end
      some_user
    end
    
    def users(*ids)
      results = []
      ids_to_request = []
      ids.each do |id|
        user = @users_by_id[id]
        if user
          results << user
        else
          ids_to_request << id
        end
      end
      unless ids_to_request.empty?
        lookups = Yajl::HttpStream.get(URI.parse("http://#{@screen_name}:#{@password}@api.twitter.com/1/users/lookup.json?user_id=#{ids_to_request.join(',')}"),:symbolize_keys=>true)
        puts lookups
        lookups.each do |user|
          @users_by_id[user[:id]] = user
          results << user
        end
      end
      results
    end
    
    def tweet(id)
      rest_get("statuses/show/#{id}.json")
    end
    
    def rest_get(path)
      Yajl::HttpStream.get(URI.parse("http://#{@screen_name}:#{@password}@api.twitter.com/1/#{path}"),:symbolize_keys=>true)
    end
  
end

ChirpHaxStream.new(ARGV[0],ARGV[1]).run