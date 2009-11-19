#!/usr/bin/env ruby

require 'rubygems'
require 'grackle'
require 'redis'
require 'lib/utils'

# Shows the list of users that a Twitter account follows and that also follow 
# that Twitter account.
#
# Inspired by http://friendorfollow.com from the always awesome 
# @DustyReagan[http://twitter.com/DustyReagan]. Buy his 
# book[http://www.amazon.com/Twitter-Application-Development-Dummies-Reagan/dp/0470568623]!
#
# Usage: 
#   ./friend_or_follow.rb screen_name [reset]
# 
# Arguments
#   screen_name:
#     the Twitter user to test. Assumes the user isn't protected.
#   reset: 
#     re-fetch the data from Twitter the screen name. If this is not set, the 
#     friend and follower data stored in Redis from any previous executions of 
#     this script for the same name will be used.
#  
# Requirements/Limitations
#   * You'll need Grackle and the redis Ruby gem.
#   * Assumes you have Redis running on the default port
#   * Assumes neither Twitter account is protected 

$stdout.sync = true

class FriendOrFollow
  
  attr_accessor :client, :redis, :screen_name, :reset
  
  def initialize(client,redis,screen_name,reset=false)
    self.client = client
    self.redis = redis
    self.screen_name = screen_name
    self.reset = reset
  end

  def get_followers
    Proc.new do |cursor|
      Utils.with_retry do 
        client.statuses.followers? :screen_name=>screen_name, :cursor=>cursor
      end
    end
  end
  
  def get_friends
    Proc.new do |cursor|
      Utils.with_retry do 
        client.statuses.friends? :screen_name=>screen_name, :cursor=>cursor
      end
    end  
  end
  
  def store_screen_names(key,getter)
    key = "#{screen_name}/#{key}"
    redis.delete(key) if reset?
    if redis.keys(key).empty?
      print "Getting #{key} for #{screen_name} ["
      Utils.with_cursor(getter) do |res|
        print '.'
        res.users.each do |user|
          redis.set_add key, user.screen_name   
        end
      end
      puts ']'
    else
      puts "Followers for #{screen_name} already stored"
    end
    key  
  end  

  def store_followers
    store_screen_names('followers',get_followers)
  end
  
  def store_friends
    store_screen_names('friends',get_friends)
  end
  
  def reset?
    reset == true
  end
  
  def execute
    friends_key = store_friends
    followers_key = store_followers
    mutual_key = "#{screen_name}/mutual"
    redis.set_intersect_store(mutual_key,friends_key,followers_key)
    {
      :following=>(redis.set_diff(friends_key,mutual_key)||[]).sort,
      :fans=>(redis.set_diff(followers_key,mutual_key)||[]).sort,
      :friends=>(redis.set_members(mutual_key)||[]).sort
    }
  end
  
end



screen_name = ARGV[0]
reset = ARGV[1] == 'reset'

client = Grackle::Client.new
redis = Redis.new

fof = FriendOrFollow.new(client,redis,screen_name,reset)
results = fof.execute

friends = results[:friends]
puts "\n#{friends.size} Friends"
puts friends.join(",")

following = results[:following]
puts "\n#{following.size} Following"
puts following.join(",")

fans = results[:fans]
puts "\n#{fans.size} Fans"
puts fans.join(",")