# encoding: UTF-8

require "better_bj/table"

module BetterBJ
  class Job < Table
    self.abstract_class = true
  end
  
  class ActiveJob < Job
    set_table_name "better_bj_active_jobs"
  end
  
  class ExecutedJob < Job
    set_table_name "better_bj_executed_jobs"
  end
end
