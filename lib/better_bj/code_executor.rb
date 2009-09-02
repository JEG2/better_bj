# encoding: UTF-8

require "thread"
require "timeout"

require "better_bj/util"

module BetterBJ
  class CodeExecutor
    def initialize(code, options = { })
      @code             = code
      @timeout          = options.fetch(:timeout, 10 * 60)
      @exceeded_timeout = false
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
        pid             = Util.db_safe_fork do
          reader.close
          result = { }
          at_exit do
            begin
              writer.write(Marshal.dump(result))
            rescue Exception
              # do nothing:  we can't pass the results up
            end
          end
          begin
            result[:result] = eval(@code, TOPLEVEL_BINDING)
          rescue Exception => error
            fail if error.is_a? SystemExit
            result[:error] = error
          end
        end
        writer.close
        q << pid
        begin
          Timeout.timeout(@timeout) do
            @exit_status = Process.wait2(pid).last.exitstatus
          end
        rescue Timeout::Error
          @exceeded_timeout = true
          @exit_status      = Util.stop_process(pid)
        end
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
    
    def successful?
      @execution_thread            and
      not @execution_thread.alive? and
      @exit_status == 0            and
      @error.nil?
    end
    
    def exceeded_timeout?
      @exceeded_timeout
    end
    
    def run_error
      if successful?
        nil
      elsif exceeded_timeout?
        "Job exceeded timeout"
      elsif not error.nil?
        "#{error.class}: #{error.message}\n#{error.backtrace.join("\n")}\n"
      elsif not exit_status.nil? and exit_status.nonzero?
        "Exit status:  #{exit_status}"
      else
        "Job terminated unexpectedly"
      end
    end
  end
end
