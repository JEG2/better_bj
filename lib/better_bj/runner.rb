# encoding: UTF-8

require "socket"

require "better_bj/table"
require "better_bj/job"
require "better_bj/util"

module BetterBJ
  class Runner < Table
    #####################
    ### Class Methods ###
    #####################
    
    def self.environment
      defined?(RAILS_ENV) ? RAILS_ENV : "development"
    end
    
    def self.launch(options = { })
      new(options).run
    end
    
    def self.autolaunch(always_tether = false)
      options = if always_tether or environment != "production"
                  {:tethered => true}
                else
                  {:tethered => false}
                end
      launch(options)
    end
    
    ##############
    ### Schema ###
    ##############
    
    set_table_name "better_bj_job_runners"

    field :hostname,    :string,  :default => Socket.gethostname, :null => false
    field :environment, :string,                                  :null => false
    field :uid,         :integer, :default => 1,                  :null => false
    field :pid,         :integer,                                 :null => false
    field :status,      :string
    
    ###################
    ### Validations ###
    ###################
    
    validates_presence_of     :hostname, :environment, :uid, :pid
    validates_uniqueness_of   :uid, :scope => %w[hostname environment]
    validates_numericality_of :uid, :pid, :only_integer => true

    ########################
    ### Instance Methods ###
    ########################
    
    attr_writer :tethered, :sleep_seconds
    
    def tethered?
      return @tethered if defined? @tethered
      @tethered = true
    end
    
    def sleep_seconds
      @sleep_seconds ||= 42
    end
    
    def environment
      e = read_attribute(:environment)
      e.blank? ? self.class.environment : e
    end
    
    def run
      prepare_tether if tethered?
      prepare_status_pipe
      self.pid = Util.db_safe_fork do
        prepare_runner_process
        tether_to_launching_process if tethered?
        report_status
        do_event_loop
      end
      tether_to_running_process if tethered?
      read_status? ? self : nil
    end
    
    def notice_jobs
      return if pid.blank?
      if hostname == Socket.gethostname and pid == Process.pid
        if defined? @event_loop_thread
          @event_loop_thread.run
          true
        else
          false
        end
      else
        begin
          Process.kill("ALRM", pid)
          true
        rescue Exception
          false
        end
      end
    end
    
    def shutdown
      return if pid.blank?
      if hostname == Socket.gethostname and pid == Process.pid
        if defined?(@running) and defined? @event_loop_thread
          @running = false
          @event_loop_thread.run
          true
        else
          false
        end
      else
        begin
          Process.kill("TERM", pid)
          true
        rescue Exception
          false
        end
      end
    end
    
    #######
    private
    #######
    
    ######################
    ### Runner Process ###
    ######################
    
    def prepare_runner_process
      trap("ALRM") do
        notice_jobs
      end
      %w[TERM INT].each do |signal|
        trap(signal) do
          shutdown
        end
      end
    end
    
    def tether_to_launching_process
      @tether_writer.close
      @tether_thread                      = Thread.new do
        Thread.current.abort_on_exception = true
        begin
          @tether_reader.read
        rescue Exception
          # do nothing:  we lost our tether
        end
        shutdown
      end
    end
    
    def report_status
      @status_reader.close
      self.environment = environment
      self.pid         = Process.pid
      self.status      = "Loading"
      if launched      = save
        at_exit { destroy }
      end
      @status_writer.puts(launched ? "Launched" : "UID already running")
      @status_writer.close
      exit unless launched
    end
    
    def do_event_loop
      @running                            = true
      @event_loop_thread                  = Thread.new do
        Thread.current.abort_on_exception = true
        while @running
          run_jobs
          sleep sleep_seconds
        end
      end
      @event_loop_thread.join
    end
    
    def run_jobs
      while job = ActiveJob.find_ready_to_run
        job.lock? or next
        job.run
      end
    end
    
    #########################
    ### Launching Process ###
    #########################
    
    def prepare_tether
      @tether_reader, @tether_writer = IO.pipe
    end

    def prepare_status_pipe
      @status_reader, @status_writer = IO.pipe
    end
    
    def tether_to_running_process
      @tether_reader.close
    end
    
    def read_status?
      @status_writer.close
      status = @status_reader.gets.to_s.strip
      @status_reader.close
      status == "Launched"
    end
  end
end
