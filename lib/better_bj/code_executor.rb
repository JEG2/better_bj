# encoding: UTF-8

require "thread"

module BetterBJ
  class CodeExecutor
    def initialize(code)
      @code             = code
      @execution_thread = nil
      @pid              = nil
      @exit_status      = nil
      @result           = nil
      @error            = nil
    end
    
    attr_reader :pid, :exit_status, :result, :error
    
    def start
      q                 = Queue.new
      @execution_thread = Thread.new do
        reader, writer  = IO.pipe
        pid             = fork do
          reader.close
          __code_executor_result__ = { }
          at_exit do
            begin
              writer.write(Marshal.dump(__code_executor_result__))
            rescue Exception
              # do nothing:  we can't pass the results up
            end
          end
          begin
            __code_executor_result__[:result] = eval(@code, TOPLEVEL_BINDING)
          rescue Exception => error
            raise if error.is_a? SystemExit
            __code_executor_result__[:error] = error
          end
        end
        writer.close
        q << pid
        @exit_status = Process.wait2(pid).last.exitstatus
        begin
          result = Marshal.load(reader.read)
          if result.is_a? Hash
            @result = result[:result]
            @error  = result[:error]
          end
        rescue Exception
          # do nothing:  we couldn't retrieve the results
        end
      end
      @pid = q.pop
    end
    
    def wait
      @execution_thread.join if @execution_thread
      result
    end
    
    def run
      start
      wait
    end
  end
end
