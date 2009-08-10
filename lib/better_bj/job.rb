# encoding: UTF-8

require "better_bj/table"

module BetterBJ
  class Job < Table
    ##############
    ### Schema ###
    ##############
    
    self.abstract_class = true
    
    field :code,           :text,                               :null => false
    field :type,           :string,                             :null => false
    field :priority,       :integer,  :default => 0,            :null => false

    field :retries,        :integer,  :default => 0,            :null => false
    field :attempts,       :integer,  :default => 0,            :null => false
    field :timeout,        :integer,  :default => 10 * 60,      :null => false
    field :last_run_error, :text

    field :submitter,      :text
    field :submitter_pid,  :integer,                            :null => false
    field :runner_pid,     :integer
    field :job_pid,        :integer
    
    field :run_at,         :datetime, :default => "NOW()",      :null => false
    field :started_at,     :datetime
    field :finished_at,    :datetime
    
    field :exit_status,    :integer
    field :result,         :text
    field :error,          :text
    field :env,            :text
    field :stdin,          :text
    field :stdout,         :text
    field :stderr,         :text
    
    ###################
    ### Validations ###
    ###################
    
    validates_presence_of     :code, :priority, :retries, :attempts, :timeout,
                              :submitter_pid, :run_at
    validates_numericality_of :priority, :retries, :attempts, :timeout,
                              :submitter_pid,
                              :only_integer => true
    
    ########################
    ### Instance Methods ###
    ########################
    
    def submitted_at
      created_at
    end
  end
  
  class ActiveJob < Job
    #################
    ### Constants ###
    #################
    
    STATES = %w[Pending Starting Running]
    
    ##############
    ### Schema ###
    ##############
    
    set_table_name "better_bj_active_jobs"

    field :state,          :string,   :default => STATES.first, :null => false
    
    ###################
    ### Validations ###
    ###################
    
    validates_presence_of  :state
    validates_inclusion_of :state, :in => STATES
  end
  
  class ActiveCodeJob < ActiveJob
    
  end
  
  class ActiveRubyScriptJob < ActiveJob
    
  end
  
  class ActiveRakeTaskJob < ActiveJob
    
  end
  
  class ActiveShellCommandJob < ActiveJob
    
  end
  
  class ExecutedJob < Job
    ##############
    ### Schema ###
    ##############
    
    set_table_name "better_bj_executed_jobs"
    
    ########################
    ### Instance Methods ###
    ########################
    
    def state
      "Executed"
    end
  end
end
