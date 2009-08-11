# encoding: UTF-8

require "test_helper"

require "better_bj/util"
require "better_bj/job"  # load some models

class TestUtil < Test::Unit::TestCase
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
end
