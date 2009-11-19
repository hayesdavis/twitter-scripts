module Utils
  
  class << self
    
    def with_cursor(res_proc)
      cursor = -1
      values = []
      until cursor == 0 do
        res = res_proc.call(cursor)
        if res
          values += yield(res)
          cursor = res.next_cursor
        else
          cursor = 0
        end
      end
      values
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
    
  end
  
  
end