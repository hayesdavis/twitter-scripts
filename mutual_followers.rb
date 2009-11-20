#!/usr/bin/env ruby

require 'rubygems'
require 'grackle'
require 'redis'
require 'lib/utils'

# Shows the list of mutual followers between two Twitter users using Redis
# sets and set intersections.
#
# Usage: 
#   ./mutual_followers.rb screen_name1 screen_name2 [reset]
# 
# Arguments
#   screen_name1, screen_name2:
#     the Twitter users to compare. Assumes both users are not protected.
#   reset: 
#     re-fetch the followers for both names. If this is not set, the list of 
#     followers stored in Redis from any previous executions of this script
#     will be used.
#  
# Requirements/Limitations
#   * You'll need Grackle and the redis Ruby gem.
#   * Assumes you have Redis running on the default port
#   * Assumes neither Twitter account is protected 

# To set up redis to play around, do the following
#  $ curl -O http://redis.googlecode.com/files/redis-1.02.tar.gz
#  $ tar xzf redis-1.02.tar.gz
#  $ cd redis-1.02
#  $ make
#  $ ./redis-server

# To shut it down
# telnet 127.0.0.1 6379
# type 'SHUTDOWN' and hit return

$stdout.sync = true

def get_followers(client,screen_name)
  Proc.new do |cursor|
    Utils.with_retry do 
      client.statuses.followers? :screen_name=>screen_name, :cursor=>cursor
    end
  end
end

def store_followers(client,redis,screen_name,reset=false)
  key = "#{screen_name}/followers"
  redis.delete(key) if reset
  if redis.keys(key).empty?
    print "Getting followers for #{screen_name} ["
    Utils.with_cursor(get_followers(client,screen_name)) do |res|
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

user1 = ARGV[0]
user2 = ARGV[1]
reset = ARGV[2] == 'reset'

client = Utils.twitter_client
redis = Redis.new
user1_key = store_followers(client,redis,user1,reset)
user2_key = store_followers(client,redis,user2,reset)

mutual_followers = redis.set_intersect(user1_key,user2_key).sort
puts "#{mutual_followers.size} Mutual Followers:\n#{mutual_followers.join(", ")}"
