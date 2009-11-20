require 'grackle'
require 'yaml'

module Utils
  
  class << self
    
    def with_cursor(res_proc)
      cursor = -1
      until cursor == 0 do
        res = res_proc.call(cursor)
        if res
          yield(res)
          cursor = res.next_cursor
        else
          cursor = 0
        end
      end
    end    
    
    def with_retry(default=nil,attempts=3)
      yield if attempts > 0
    rescue => e
      puts "Received error #{e}"
      if should_retry?(e)
        puts "Will attempt #{attempts-1} more time(s)."
        attempts -= 1
        retry
      else
        raise e
      end
    end
    
    def should_retry?(err)
      if err.kind_of?(Grackle::TwitterError)
        #Satus of nil means it was an unexpected error generally
        #500 errors are probably transient
        err.status.nil? || err.status.to_i >= 500
      else
        false
      end
    end
    
    def twitter_client
      opts = {}
      home_config = File.expand_path('~/.twitter_client')
      if File.exists?('./.twitter_client')
        opts = YAML.load(IO.read('./.twitter_client'))
      elsif home_config
        opts = YAML.load(IO.read(home_config))
      end
      Grackle::Client.new(symbolize(opts))
    end
    
    private
      def symbolize(hash)
        hash.inject({}) do |h, (key,value)|
          if value && value.kind_of?(Hash)
            h[key.to_sym] = symbolize(value)
          else
            h[key.to_sym] = value
          end
          h
        end
      end
  end
  
end