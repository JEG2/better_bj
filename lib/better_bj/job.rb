# encoding: UTF-8

require "better_bj/table"
require "better_bj/code_executor"

module BetterBJ
  class Job < Table
    ##############
    ### Schema ###
    ##############
    
    self.abstract_class = true
    
    field :code,           :text,                               :null => false
    field :priority,       :integer,  :default => 0,            :null => false

    field :retries,        :integer,  :default => 0,            :null => false
    field :attempts,       :integer,  :default => 0,            :null => false
    field :timeout,        :integer,  :default => 10 * 60,      :null => false
    field :last_run_error, :text

    field :submitter,      :text
    field :submitter_pid,  :integer,                            :null => false
    field :runner_pid,     :integer
    field :job_pid,        :integer
    
    field :run_at,         :datetime,                           :null => false
    field :started_at,     :datetime
    field :finished_at,    :datetime
    
    field :exit_status,    :integer
    field :result,         :text
    field :error,          :text
    field :env,            :text
    field :stdin,          :text
    field :stdout,         :text
    field :stderr,         :text
    
    serialize :result
    serialize :error
    
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

    field :type,           :string,                             :null => false
    field :state,          :string,   :default => STATES.first, :null => false
    field :lock_version,   :integer,  :default => 0,            :null => false
    
    ###################
    ### Validations ###
    ###################
    
    validates_presence_of  :state
    validates_inclusion_of :state, :in => STATES

    ########################
    ### Instance Methods ###
    ########################
    
    def run
      executor = prepare_executor
      job_pid  = executor.start

      update_attributes(:state => "Running", :job_pid => job_pid)
      
      executor.wait
      if executor.successful? or attempts >= retries
        completed_job = attributes.dup
        %w[id type state lock_version].each do |attribute|
          completed_job.delete(attribute)
        end
        transaction do
          ExecutedJob.create!( completed_job.merge(
            :job_type       => self.class.name[/\bActive(\w+)Job\z/, 1].
                                          underscore,
            :attempts       => attempts + 1,
            :exit_status    => executor.exit_status,
            :result         => executor.result,
            :error          => executor.error,
            :last_run_error => executor.run_error || last_run_error,
            :successful     => executor.successful?,
            :finished_at    => Time.now
          ) )
          destroy or fail "Could not destroy executed job"
        end
      else
        update_attributes( :attempts       => attempts + 1,
                           :last_run_error => executor.run_error,
                           :finished_at    => Time.now )
      end
    end
  end
  
  class ActiveCodeJob < ActiveJob
    ########################
    ### Instance Methods ###
    ########################
    
    def prepare_executor
      CodeExecutor.new(code, :timeout => timeout)
    end
  end
  
  class ActiveRubyScriptJob < ActiveJob
    
  end
  
  class ActiveRakeTaskJob < ActiveJob
    
  end
  
  class ActiveShellCommandJob < ActiveJob
    
  end
  
  class ExecutedJob < Job
    #################
    ### Constants ###
    #################
    
    JOB_TYPES = %w[code ruby_script rake_task shell_command]
    
    ##############
    ### Schema ###
    ##############
    
    set_table_name "better_bj_executed_jobs"

    field :job_type,       :string,                             :null => false
    field :successful,     :boolean,                            :null => false
    
    ###################
    ### Validations ###
    ###################
    
    validates_presence_of  :job_type
    validates_inclusion_of :job_type, :in => JOB_TYPES
    
    ########################
    ### Instance Methods ###
    ########################
    
    def state
      "Executed"
    end
  end
end
