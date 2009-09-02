# encoding: UTF-8

require "timeout"

module BetterBJ
  module Util
    class DatabaseForkManager
      def initialize
        @database_active = defined?(ActiveRecord) &&
                           ActiveRecord::Base.connected?
        @db_config       = nil
      end
      
      def prepare_database_for_fork
        @db_config = ActiveRecord::Base.remove_connection if @database_active
      end
      
      def restore_child_database_after_fork
        ActiveRecord::Base.establish_connection(@db_config) if @database_active
      end
      alias_method :restore_parent_database_after_fork,
                   :restore_child_database_after_fork
    end
    
    module_function
    
    def stop_process(child_pid, pause_between_signals = 10)
      %w[TERM KILL].each { |signal|
        begin
          Process.kill(signal, child_pid)    # attempt to stop process
        rescue Exception                     # no such process
          break                              # the process is stopped
        end
        break if signal == "KILL"                            # don't wait
        begin
          Timeout.timeout(pause_between_signals) {           # wait for response
            return Process.wait2(child_pid).last.exitstatus  # response
          }
        rescue Timeout::Error  # the process didn't exit in time
          # do nothing:  try again with KILL
        rescue Exception       # no such child
          return nil           # we have already caught the child
        end
      }
      begin
        Process.wait2(child_pid).last.exitstatus
      rescue Exception  # no such child
        nil             # we have already caught the child
      end
    end
    
    def db_safe_fork(&child)
      dbfm = DatabaseForkManager.new
      dbfm.prepare_database_for_fork
      child_pid = fork do
        dbfm.restore_child_database_after_fork
        yield
      end
      dbfm.restore_parent_database_after_fork
      child_pid
    end
  end
end
