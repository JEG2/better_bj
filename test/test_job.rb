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
  
  # ActiveRecord doesn't support run_at's default time

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
  
  def test_run_updates_attempts_last_run_error_and_finished_at_for_a_failed_job
    create_code_job('exit -1', :retries => 1)
    assert_equal(0, @job.attempts)
    assert_nil(@job.last_run_error)
    assert_nil(@job.finished_at)
    @job.run
    assert_equal(1, @job.attempts)
    assert_match(/\AExit status/, @job.last_run_error)
    assert_not_nil(@job.finished_at)
  end
  
  def test_run_moves_a_job_to_executed_jobs_when_retries_are_exhausted
    test_run_updates_attempts_last_run_error_and_finished_at_for_a_failed_job
    assert_equal(@job.retries, @job.attempts)  # the next run exhausts retries
    assert_equal(1, BetterBJ::ActiveJob.count)
    assert_equal(0, BetterBJ::ExecutedJob.count)
    @job.run
    assert_equal(0, BetterBJ::ActiveJob.count)
    assert_equal(1, BetterBJ::ExecutedJob.count)
    executed = BetterBJ::ExecutedJob.first
    assert_equal(executed.retries + 1, executed.attempts)
    assert_match(/\AExit status/, @job.last_run_error)
    assert(!executed.successful?, "Exhausting retries wasn't unsuccessful")
  end
  
  private
  
  def create_code_job(code, options = { })
    @job = BetterBJ::ActiveCodeJob.create!( { :code          => code,
                                              :submitter_pid => Process.pid,
                                              :run_at        => Time.now }.
                                            merge(options) )
  end
end
