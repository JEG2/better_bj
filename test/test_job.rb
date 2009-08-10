# encoding: UTF-8

require "test_helper"

require "better_bj/job"

class TestJob < Test::Unit::TestCase
  def setup
    prepare_test_db
  end
  
  def teardown
    cleanup_test_db
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
end
