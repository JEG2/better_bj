# encoding: UTF-8

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
