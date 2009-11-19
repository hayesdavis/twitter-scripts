#!/usr/bin/env ruby

require 'rubygems'
require 'grackle'
require 'redis'
require 'lib/utils'

# Tells you how the followers list for a Twitter user has changed since the 
# last execution. As the name implies it's meant to be run once per day but you 
# can run it as often as you want. Provides counts and lists for followers 
# gained and lost during the period since the last execution. The first run, 
# obviously, won't provide any results. Consider setting up a cron job and 
# writing the results to a file for perusal.
#
# Usage: 
#   ./daily_diff.rb screen_name
# 
# Arguments
#   screen_name:
#     the Twitter user to test. Assumes the user isn't protected.
#  
# Requirements/Limitations
#   * You'll need Grackle and the redis Ruby gem.
#   * Assumes you have Redis running on the default port
#   * Assumes the Twitter account is not protected 

$stdout.sync = true

class DailyDiff
  
  attr_accessor :client, :redis, :screen_name
  
  def initialize(client,redis,screen_name)
    self.client = client
    self.redis = redis
    self.screen_name = screen_name
  end

  def get_followers
    Proc.new do |cursor|
      Utils.with_retry do 
        client.statuses.followers? :screen_name=>screen_name, :cursor=>cursor
      end
    end
  end
  
  def store_screen_names(key,getter)
    key = "#{screen_name}/#{key}"
    redis.delete(key)
    if redis.keys(key).empty?
      print "Getting #{key} ["
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
  
  def execute
    followers_key = store_followers
    prev_results_key = "#{screen_name}/dd/previous_results"
    prev_exec_key = "#{screen_name}/dd/previous_exec"
    unless redis.keys(prev_results_key).empty?
      results = {
        :previous_execution=>redis[prev_exec_key],
        :lost => redis.set_diff(prev_results_key,followers_key),
        :gained => redis.set_diff(followers_key,prev_results_key)
      }
    else
      results = nil
    end
    redis.rename(followers_key,prev_results_key)
    redis[prev_exec_key] = Time.now.to_s
    results
  end
  
end

screen_name = ARGV[0]

client = Grackle::Client.new
redis = Redis.new

dd = DailyDiff.new(client,redis,screen_name)
results = dd.execute

if results.nil?
  puts "Can't run the diff because there are no previous results."
  puts "Your results have been stored and the next run will perform a diff."
else
  puts "Diff with results from #{results[:previous_execution]}"
  
  gained = results[:gained]
  puts "\nGained #{gained.size} followers:"
  puts gained.join(",")
  
  lost = results[:lost]
  puts "\nLost #{lost.size} followers:"
  puts lost.join(",")
  
  puts "\nNet Gained/Lost: #{gained.size-lost.size}"
  
end