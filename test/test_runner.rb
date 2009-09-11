# encoding: UTF-8

require "test_helper"

require "better_bj/runner"

class TestRunner < Test::Unit::TestCase
  def setup
    prepare_test_db
  end
  
  def teardown
    cleanup_test_db
  end
  
  ##############
  ### Schema ###
  ##############
  
  def test_hostname_is_required
    assert_required_field(BetterBJ::Runner, :hostname, "my.host")
  end
  
  def test_hostname_defaults_to_socket_gethostname
    assert_equal(Socket.gethostname, BetterBJ::Runner.new.hostname)
    assert_equal( "my.host",
                  BetterBJ::Runner.new(:hostname => "my.host").hostname )
  end
  
  def test_environment_detection
    # environment defaults to "development"
    assert(!defined?(RAILS_ENV), "Tests were run within a Rails environment")
    assert_equal("development", BetterBJ::Runner.environment)
    assert_equal("development", BetterBJ::Runner.new.environment)
    
    # otherwise the environment matches the Rails environment
    %w[development test production].each do |env|
      reader, writer = IO.pipe
      pid            = fork do
        reader.close
        Object.const_set(:RAILS_ENV, env)
        writer.puts BetterBJ::Runner.environment
        writer.puts BetterBJ::Runner.new.environment
      end
      writer.close
      Process.wait(pid)
      assert_equal(env, reader.gets.strip)
      assert_equal(env, reader.gets.strip)
      reader.close
    end
  end
  
  def test_uid_is_required
    assert_required_field(BetterBJ::Runner, :uid, 1)
  end
  
  def test_uid_defaults_to_1
    assert_equal(1,  BetterBJ::Runner.new.uid)
    assert_equal(42, BetterBJ::Runner.new(:uid => 42).uid)
  end
  
  def test_uid_be_an_integer
    assert_invalid_field(BetterBJ::Runner, :uid, "junk")
    assert_invalid_field(BetterBJ::Runner, :uid, "3.14")
  end
  
  def test_pid_is_required
    assert_required_field(BetterBJ::Runner, :uid, 1)
  end
  
  def test_pid_be_an_integer
    assert_invalid_field(BetterBJ::Runner, :pid, "junk")
    assert_invalid_field(BetterBJ::Runner, :pid, "3.14")
  end
  
  #################
  ### Tethering ###
  #################
  
  def test_a_tethered_runner_exits_when_the_launching_process_exits
    launch_runner( :tethered           => true,
                   :sleep_seconds      => 1,
                   :sleep_after_launch => 4 )  # some runtime for us to check
    
    3.times do
      assert_pid_running(@launching_pid)
      assert_pid_running(@runner_pid)
      sleep 1
    end
    
    wait_on_launcher
    assert_pid_not_running(@runner_pid)
  end
  
  def test_a_tethered_runner_exits_when_the_launching_process_is_killed
    launch_runner(:tethered => true, :sleep_seconds => 1)
    
    assert_pid_running(@launching_pid)
    assert_pid_running(@runner_pid)
    
    Process.kill("KILL", @launching_pid)  # forcfully kill the launching process 
    sleep 2                               # give the processes time to notice
    Process.wait(@launching_pid, Process::WNOHANG)  # reap the launcher
    assert_pid_not_running(@launching_pid)
    assert_pid_not_running(@runner_pid)
  end
  
  def test_a_runner_notices_the_launchers_exit_when_sleeping
    launch_runner( :tethered      => true,
                   :sleep_seconds => 42 )  # a long sleep for the runner
    
    wait_on_launcher
    assert_pid_not_running(@runner_pid)
  end
  
  #################
  ### Launching ###
  #################
  
  def test_can_only_launch_one_copy_of_each_uid_per_host_and_environment
    # can launch the first copy of a UID (default)
    pids = try_to_launch_runner
    assert_not_nil(pids)
    assert_pids_running(pids)
    
    # cannot launch another of the same UID (default)
    assert_nil(try_to_launch_runner)
    assert_pids_running(pids)
    
    # can launch a different UID
    other_pids = try_to_launch_runner(:uid => 2)
    assert_not_nil(other_pids)
    assert_pids_running_then_stop(other_pids)
    
    # NOT TESTED:  can launch the same UID (default) on a different host
    
    # can launch the same UID (default) in a different environment
    other_pids = try_to_launch_runner(:environment => "test")
    assert_not_nil(other_pids)
    assert_pids_running_then_stop(other_pids)
    
    # stop original runner
    assert_pids_running_then_stop(pids)
  end
  
  ######################
  ### Auto-launching ###
  ######################
  
  def test_autolaunch_tethers_development_test_and_missing_environments
    [nil, "development", "test"].each do |env|
      autolaunch_runner(:rails_env => env)

      wait_on_launcher
      assert_pid_not_running(@runner_pid)
    end
  end
  
  def test_autolaunch_does_not_tether_a_production_environment
    autolaunch_runner(:rails_env => "production")

    wait_on_launcher
    assert_pid_running(@runner_pid)
    
    Process.kill("TERM", @runner_pid)
  end
  
  def test_passing_true_makes_autolaunch_tether_a_production_environment
    autolaunch_runner(:always_tether => true, :rails_env => "production")

    wait_on_launcher
    assert_pid_not_running(@runner_pid)
  end
  
  ####################
  ### Running Jobs ###
  ####################
  
  def test_runners_execute_pending_jobs_when_they_are_launched
    BetterBJ::Job.submit(':successfully_run')
    pids = try_to_launch_runner
    assert_not_nil(pids)
    sleep 1  # give the job time to run
    job = BetterBJ::ExecutedJob.first
    assert_not_nil(job)
    assert_equal(:successfully_run, job.result)
    assert_pids_running_then_stop(pids)
  end
  
  def test_runners_will_notice_pending_jobs_between_sleep_cycles
    pids = try_to_launch_runner(:sleep_seconds => 1)
    assert_not_nil(pids)
    sleep 1  # give time to get the runner going
    BetterBJ::Job.submit(':run_asap')
    sleep 2  # give time to end sleep and run the job
    job = BetterBJ::ExecutedJob.first
    assert_not_nil(job)
    assert_equal(:run_asap, job.result)
    assert_pids_running_then_stop(pids)
  end
  
  def test_notifying_a_runner_of_pending_jobs
    pids = try_to_launch_runner
    assert_not_nil(pids)
    sleep 1  # give time to get the runner going
    BetterBJ::Job.submit(':see_me')
    sleep 1  # the job will not run due to the long sleep
    assert_nil(BetterBJ::ExecutedJob.first)
    runner = BetterBJ::Runner.find_by_pid(pids.last)
    assert_not_nil(runner)
    runner.notice_jobs
    sleep 1  # give the job time to run
    job = BetterBJ::ExecutedJob.first
    assert_not_nil(job)
    assert_equal(:see_me, job.result)
    assert_pids_running_then_stop(pids)
  end
  
  def test_shutting_a_runner_down
    pids = try_to_launch_runner(:tethered => false)  # don't exit with launcher
    assert_not_nil(pids)
    runner = BetterBJ::Runner.find_by_pid(pids.last)
    Process.kill("TERM", pids.first)  # kill launcher
    Process.wait(pids.first)          # wait for it
    sleep 1                           # make sure the runner has time to notice
    assert_pid_running(runner.pid)    # but stays up
    assert_not_nil(runner)
    runner.shutdown  # send the signal
    sleep 1          # give the runner time to close down
    assert_pid_not_running(runner.pid)
  end
  
  #######
  private
  #######
  
  def launch_runner(options)
    sleep_after_launch = options.delete(:sleep_after_launch) || 1
    reader, writer     = IO.pipe
    @launching_pid     = BetterBJ::Util.db_safe_fork do
      reader.close
      runner           = BetterBJ::Runner.new(options)
      runner.run
      writer.puts runner.pid
      sleep sleep_after_launch
    end
    writer.close
    @runner_pid = Integer(reader.gets)
    reader.close
    @runner_pid
  end
  
  def try_to_launch_runner(options = { })
    reader, writer = IO.pipe
    launching_pid  = BetterBJ::Util.db_safe_fork do
      reader.close
      if runner    = BetterBJ::Runner.launch(options)
        writer.puts runner.pid
        loop do
          sleep 42
        end
      end
    end
    writer.close
    if runner_pid = reader.gets
      [launching_pid, Integer(runner_pid)]
    else
      Process.wait(launching_pid)
      nil
    end
  end
  
  def autolaunch_runner(options)
    rails_env          = options.delete(:rails_env)
    always_tether      = options.delete(:always_tether) || false
    reader, writer     = IO.pipe
    @launching_pid     = BetterBJ::Util.db_safe_fork do
      reader.close
      Object.const_set(:RAILS_ENV, rails_env) if rails_env
      runner           = BetterBJ::Runner.autolaunch(always_tether)
      writer.puts runner.pid
    end
    writer.close
    @runner_pid = Integer(reader.gets)
    reader.close
    @runner_pid
  end
  
  def wait_on_launcher(extra_seconds = 1)
    Process.wait(@launching_pid)  # wait for launching process to exit
    sleep extra_seconds           # give the child time to notice it
    assert_pid_not_running(@launching_pid)
  end
  
  def assert_pids_running_then_stop(pids)
    assert_pids_running(pids)
    Process.kill("TERM", pids.first)
    Process.wait(pids.first)
    sleep 1  # give the runner time to notice it
    assert_pids_not_running(pids)
  end
end
