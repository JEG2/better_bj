# encoding: UTF-8

require "test_helper"

require "better_bj/job"

class TestJob < Test::Unit::TestCase
  def setup
    prepare_test_db
  end
  
  def teardown
    cleanup_test_db
    cleanup_result_file
  end
  
  ##############
  ### Schema ###
  ##############
  
  def test_parent_classes_are_abstract_while_child_classes_are_not
    [BetterBJ::Table, BetterBJ::Job].each do |parent|
      assert(parent.abstract_class?, "#{parent.name} class was not abstract")
    end
    [BetterBJ::ActiveJob, BetterBJ::ExecutedJob].each do |child|
      assert(!child.abstract_class?, "#{child.name} class was abstract")
    end
  end
  
  def test_code_is_required
    assert_required_field(BetterBJ::ActiveCodeJob, :code, 'puts "Hello world!"')
  end
  
  def test_priority_is_required
    assert_required_field(BetterBJ::ActiveCodeJob, :priority, 42)
  end
  
  def test_priority_must_be_an_integer
    assert_invalid_field(BetterBJ::ActiveCodeJob, :priority, "junk")
    assert_invalid_field(BetterBJ::ActiveCodeJob, :priority, "3.14")
  end
  
  def test_priority_defaults_to_0
    assert_equal(0, BetterBJ::ActiveCodeJob.new.priority)
  end
  
  def test_retries_is_required
    assert_required_field(BetterBJ::ActiveCodeJob, :retries, 42)
  end
  
  def test_retries_must_be_an_integer
    assert_invalid_field(BetterBJ::ActiveCodeJob, :retries, "junk")
    assert_invalid_field(BetterBJ::ActiveCodeJob, :retries, "3.14")
  end
  
  def test_retries_defaults_to_0
    assert_equal(0, BetterBJ::ActiveCodeJob.new.retries)
  end
  
  def test_attempts_is_required
    assert_required_field(BetterBJ::ActiveCodeJob, :attempts, 42)
  end
  
  def test_attempts_must_be_an_integer
    assert_invalid_field(BetterBJ::ActiveCodeJob, :attempts, "junk")
    assert_invalid_field(BetterBJ::ActiveCodeJob, :attempts, "3.14")
  end
  
  def test_attempts_defaults_to_0
    assert_equal(0, BetterBJ::ActiveCodeJob.new.attempts)
  end
  
  def test_timeout_is_required
    assert_required_field(BetterBJ::ActiveCodeJob, :timeout, 42)
  end
  
  def test_timeout_must_be_an_integer
    assert_invalid_field(BetterBJ::ActiveCodeJob, :timeout, "junk")
    assert_invalid_field(BetterBJ::ActiveCodeJob, :timeout, "3.14")
  end
  
  def test_timeout_defaults_to_10_minutes
    assert_equal(10 * 60, BetterBJ::ActiveCodeJob.new.timeout)
  end
  
  def test_submitter_pid_is_required
    assert_required_field(BetterBJ::ActiveCodeJob, :submitter_pid, 42)
  end
  
  def test_submitter_pid_must_be_an_integer
    assert_invalid_field(BetterBJ::ActiveCodeJob, :submitter_pid, "junk")
    assert_invalid_field(BetterBJ::ActiveCodeJob, :submitter_pid, "3.14")
  end
  
  def test_run_at_is_required
    assert_required_field(BetterBJ::ActiveCodeJob, :run_at, Time.now)
  end
  
  def test_state_is_required
    assert_required_field(BetterBJ::ActiveCodeJob, :state, "Pending")
  end
  
  def test_state_must_match_allowed_states
    BetterBJ::ActiveCodeJob::STATES.each do |state|
      assert_valid_field(BetterBJ::ActiveCodeJob, :state, state)
    end
    assert_invalid_field(BetterBJ::ActiveCodeJob, :state, "junk")
  end
  
  def test_state_defaults_to_pending
    assert_equal("Pending", BetterBJ::ActiveCodeJob.new.state)
  end

  def test_job_type_is_required
    assert_required_field(BetterBJ::ExecutedJob, :job_type, "code")
  end
  
  def test_job_type_must_match_allowed_job_types
    BetterBJ::ExecutedJob::JOB_TYPES.each do |type|
      assert_valid_field(BetterBJ::ExecutedJob, :job_type, type)
    end
    assert_invalid_field(BetterBJ::ExecutedJob, :job_type, "junk")
  end
  
  def test_result_and_error_are_serialized
    create_code_job('never_run', :result => [ ], :error => Exception.new)
    @job.reload
    assert_instance_of(Array,     @job.result)
    assert_instance_of(Exception, @job.error)
  end
  
  ##################
  ### Submitting ###
  ##################
  
  def test_sumbit_creates_an_active_job
    assert_nil(BetterBJ::ActiveJob.first)
    code = '# some work here'
    BetterBJ::Job.submit(code)
    job = BetterBJ::ActiveJob.first
    assert_not_nil(job)
    assert_equal(code, job.code)
  end
  
  def test_sumbit_sets_a_default_submitter_pid_for_the_current_process
    assert_nil(BetterBJ::ActiveJob.first)
    BetterBJ::Job.submit('# some work here')
    assert_equal(Process.pid, BetterBJ::ActiveJob.first.submitter_pid)
    BetterBJ::ActiveJob.delete_all
    pid = 123
    BetterBJ::Job.submit('# some work here', :submitter_pid => pid)
    assert_equal(pid, BetterBJ::ActiveJob.first.submitter_pid)
  end
  
  def test_sumbit_sets_a_default_run_at_of_now
    assert_nil(BetterBJ::ActiveJob.first)
    BetterBJ::Job.submit('# some work here')
    assert_in_delta(Time.now.to_f, BetterBJ::ActiveJob.first.run_at.to_f, 1)
    BetterBJ::ActiveJob.delete_all
    time = Time.now + 1 * 60 * 60 * 24
    BetterBJ::Job.submit('# some work here', :run_at => time)
    assert_in_delta(time.to_f, BetterBJ::ActiveJob.first.run_at.to_f, 1)
  end
  
  def test_sumbit_raises_an_error_if_the_job_cannot_be_created
    assert_raise(ActiveRecord::RecordInvalid) do
      BetterBJ::Job.submit('# some work here', :run_at => nil)
    end
  end
  
  ###########################
  ### Finding and Locking ###
  ###########################
  
  def test_finding_ready_to_run_jobs
    assert_nil(BetterBJ::ActiveJob.find_ready_to_run)  # no jobs in the database
    create_code_job('# some work here', :run_at => Time.now + 1)
    assert_nil(BetterBJ::ActiveJob.find_ready_to_run)  # it's not time yet
    sleep 1                                            # wait for the set time
    assert_equal(@job, BetterBJ::ActiveJob.find_ready_to_run)
  end
  
  def test_locking_a_job_sets_state_started_at_and_runner_pid
    create_code_job('# some work here')
    assert_equal("Pending", @job.state)
    assert_nil(@job.started_at)
    assert_nil(@job.runner_pid)
    assert(@job.lock?, "We could not lock the job")
    assert_equal("Starting", @job.state)
    assert_not_nil(@job.started_at)
    assert_equal(Process.pid, @job.runner_pid)
  end
  
  def test_cannot_lock_a_job_that_has_been_touched_by_another_process
    create_code_job('# some work here')
    job_in_another_process = BetterBJ::ActiveJob.find(@job.id)
    job_in_another_process.touch  # incrementing the lock_version
    assert(!@job.lock?, "We locked a job that was externally manipulated")
  end
  
  #################
  ### Execution ###
  #################
  
  def test_run_sets_running_state_while_in_progress
    create_code_job('sleep 1')
    assert_not_equal("Running", @job.state)
    # sample state halfway through run
    state_while_running = Thread.new do
      sleep 0.5
      @job.state
    end
    @job.run
    assert_equal("Running", state_while_running.value)
  end
  
  def test_run_executes_job_code_in_a_job_process
    assert_result_file_doesnt_exist
    create_code_job('open(%p, "w") { |f| f.puts Process.pid }' % RESULT_PATH)
    assert_nil(@job.job_pid)
    @job.run
    job_pid = File.read(RESULT_PATH).to_i
    assert_not_equal(Process.pid, job_pid)
    assert_equal(job_pid, @job.job_pid)
  end
  
  def test_run_moves_a_successful_job_into_the_executed_jobs
    create_code_job('# exit normally')
    assert_equal(1, BetterBJ::ActiveJob.count)
    assert_equal(0, BetterBJ::ExecutedJob.count)
    @job.run
    assert_equal(0, BetterBJ::ActiveJob.count)
    assert_equal(1, BetterBJ::ExecutedJob.count)
  end
  
  def test_run_edits_the_job_as_it_is_moved_to_executed_jobs
    create_code_job(<<-END_RUBY)
    sleep 1
    :some_value  # return a value
    # and exit normally
    END_RUBY
    submitted_at = @job.submitted_at
    assert_nil(@job.finished_at)
    @job.run
    executed = BetterBJ::ExecutedJob.first
    assert_equal(submitted_at.to_a, executed.submitted_at.to_a)  # no change
    assert_equal(1,                 executed.attempts)
    assert_equal(0,                 executed.exit_status)
    assert_equal(:some_value,       executed.result)
    assert_equal("Executed",        executed.state)  # static for ExecutedJob
    assert_not_nil(executed.finished_at)
    assert(executed.successful?, "Job wasn't successful with a normal exit")
  end
  
  def test_run_updates_state_attempts_error_and_finished_at_for_a_failed_job
    create_code_job('exit -1  # fail', :retries => 1)
    assert_equal(0, @job.attempts)
    assert_nil(@job.last_run_error)
    assert_nil(@job.finished_at)
    @job.run
    assert_equal("Pending", @job.state)
    assert_equal(1, @job.attempts)
    assert_match(/\AExit status/, @job.last_run_error)
    assert_not_nil(@job.finished_at)
  end
  
  def test_job_retry_delays_increase_until_the_maximum_delay_repeats
    delays = BetterBJ::ActiveJob::RETRY_DELAYS
    create_code_job('exit -1  # fail', :retries => delays.size + 2)
    (delays + [delays.max] * 2).each do |delay|
      old_run_time = @job.run_at
      @job.run
      assert_equal(old_run_time + delay, @job.run_at)
    end
  end
  
  def test_run_keeps_the_latest_run_error_if_not_replaced
    path = File.join(File.dirname(__FILE__), "one_error_only.txt")
    create_code_job(<<-END_RUBY % [path, path], :retries => 1)
    if File.exist? %p
      # exit cleanly
    else
      open(%p, "w") { }  # just touch the file
      exit -1            # and exit with an error
    end
    END_RUBY
    assert_nil(@job.last_run_error)
    @job.run
    assert_match(/\AExit status/, @job.last_run_error)
    @job.run
    assert_equal(0, BetterBJ::ActiveJob.count)
    assert_equal(1, BetterBJ::ExecutedJob.count)
    executed = BetterBJ::ExecutedJob.first
    assert_match(/\AExit status/, executed.last_run_error)
    assert(executed.successful?, "The second job execution wasn't successful")
  ensure
    File.unlink(path) if File.exist? path
  end
  
  def test_run_moves_a_job_to_executed_jobs_when_retries_are_exhausted
    test_run_updates_state_attempts_error_and_finished_at_for_a_failed_job
    assert_equal(@job.retries, @job.attempts)  # the next run exhausts retries
    assert_equal(1, BetterBJ::ActiveJob.count)
    assert_equal(0, BetterBJ::ExecutedJob.count)
    @job.run
    assert_equal(0, BetterBJ::ActiveJob.count)
    assert_equal(1, BetterBJ::ExecutedJob.count)
    executed = BetterBJ::ExecutedJob.first
    assert_equal(executed.retries + 1, executed.attempts)
    assert_match(/\AExit status/, executed.last_run_error)
    assert(!executed.successful?, "Exhausting retries wasn't unsuccessful")
  end
  
  def test_run_marks_jobs_with_a_timeout_error
    create_code_job('sleep 60', :timeout => 1, :retries => 1)
    assert_nil(@job.last_run_error)
    @job.run
    assert_match(/Job exceeded timeout/, @job.last_run_error)
  end
  
  #######
  private
  #######
  
  def create_code_job(code, options = { })
    @job = BetterBJ::ActiveCodeJob.create!( { :code          => code,
                                              :submitter_pid => Process.pid,
                                              :run_at        => Time.now }.
                                            merge(options) )
  end
end
