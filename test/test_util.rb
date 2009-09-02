# encoding: UTF-8

require "test_helper"

require "better_bj/util"
require "better_bj/job"  # load some models

class TestUtil < Test::Unit::TestCase
  def teardown
    @reader.close if defined?(@reader) and not @reader.closed?
  end
  
  def test_stop_process_returns_exit_status_if_available
    child_pid = fork_and_wait_for_setup do
      trap("TERM") do
        exit 1
      end
    end
    assert_equal(1, BetterBJ::Util.stop_process(child_pid))
  end
  
  def test_stop_process_just_returns_exit_status_if_the_process_is_already_gone
    child_pid = fork_and_wait_for_setup(0) do
      # do nothing:  exit normally
    end
    assert_equal(0, BetterBJ::Util.stop_process(child_pid))
  end
  
  def test_stop_process_tries_a_term_and_wait_approach_first
    child_pid = fork_and_wait_for_setup do
      trap("TERM") do
        @writer.puts "TERM received."
        exit 13
      end
    end
    assert_equal(13,               BetterBJ::Util.stop_process(child_pid))
    assert_equal("TERM received.", @reader.read.strip)
  end
  
  def test_stop_process_will_use_kill_if_term_is_ignored
    child_pid = fork_and_wait_for_setup do
      trap("TERM", "IGNORE")
    end
    assert_nil(BetterBJ::Util.stop_process(child_pid, 1))
  end
  
  def test_db_safe_fork_returns_child_process_pid
    reader, writer = IO.pipe
    fork_pid       = BetterBJ::Util.db_safe_fork do
      reader.close
      writer.puts Process.pid
    end
    writer.close
    pipe_pid = reader.gets.to_i
    reader.close
    assert_equal(pipe_pid, fork_pid)
    Process.wait(fork_pid)
  end
  
  def test_can_use_the_database_on_both_sides_of_db_safe_fork
    prepare_test_db
    job = BetterBJ::ActiveCodeJob.create!(
      :code          => 'puts "Hello world!"',
      :run_at        => Time.now,
      :submitter_pid => Process.pid
    )
    pid = BetterBJ::Util.db_safe_fork do
      assert_equal(job, BetterBJ::ActiveJob.first)
    end
    assert_equal(job, BetterBJ::ActiveJob.first)
    Process.wait(pid)
  ensure
    cleanup_test_db
  end
  
  private
  
  def fork_and_wait_for_setup(sleep_seconds = 60)
    @reader, @writer = IO.pipe
    child_pid        = fork do
      @reader.close
      yield
      @writer.puts "Ready"
      sleep sleep_seconds
    end
    @writer.close
    assert_equal("Ready", @reader.gets.strip)
    child_pid
  end
end
