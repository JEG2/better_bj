# encoding: UTF-8

require "test_helper"

require "better_bj/code_executor"

class TestCodeExecutor < Test::Unit::TestCase
  def teardown
    cleanup_result_file
  end
  
  def test_code_is_executed
    assert_result_file_doesnt_exist
    run_code('open(%p, "w") { }' % RESULT_PATH)
    assert_result_file_exists
  end

  def test_code_is_executed_in_a_separate_process
    assert_result_file_doesnt_exist
    run_code('open(%p, "w") { |f| f.puts Process.pid }' % RESULT_PATH)
    assert_not_equal(Process.pid, File.read(RESULT_PATH).to_i)
  end
  
  def test_code_can_be_started_and_waited_on
    prepare_code('sleep 1')
    assert_nil(@code.pid)
    @code.start
    assert_not_nil(@code.pid)
    assert_pid_running(@code.pid)
    @code.wait
    assert_pid_not_running(@code.pid)
  end
  
  def test_exit_status_of_the_code_process_is_captured
    # normal exit
    prepare_code('# do nothing')
    assert_nil(@code.exit_status)
    @code.run
    assert_equal(0, @code.exit_status)

    # exit with code
    run_code('exit 42')
    assert_equal(42, @code.exit_status)

    # process killed
    prepare_code('sleep 60')
    @code.start
    Process.kill("KILL", @code.pid)
    @code.wait
    assert_nil(@code.exit_status)
  end
  
  def test_the_returned_result_of_the_code_is_captured_when_possible
    assert_equal(42, run_code('42'))
    assert_equal(42, @code.result)
  end
  
  def test_errors_from_the_code_are_captured_when_possible
    run_code('raise StandardError, "My error message"')
    assert_not_nil(@code.error)
    assert_instance_of(StandardError, @code.error)
    assert_match(/My error message/, @code.error.message)
  end
  
  def test_successful_tracks_finished_exit_status_and_error
    # success
    prepare_code('sleep 1  # and exit normally')
    assert(!@code.successful?, "Code was successful before it ran")
    @code.start
    assert(!@code.successful?, "Code was successful before it finished")
    @code.wait
    assert(@code.successful?, "Code wasn't successful with a normal exit")
    
    # fail with an error
    run_code('fail "Oops!"')
    assert(!@code.successful?, "Code was successful with an error")
    
    # fail with an abnormal exit status
    run_code('exit 7')
    assert(!@code.successful?, "Code was successful with an abnormal exit")
  end
  
  def test_run_error_shows_process_failure_reason
    # success
    run_code('# exit normally')
    assert_nil(@code.run_error)
    
    # fail with an error
    run_code('fail "Oops!"')
    assert_match(/\ARuntimeError:\s+/,                        @code.run_error)
    assert_match(/\s+#{Regexp.escape(@code.error.message)}$/, @code.run_error)
    @code.error.backtrace.each do |line|
      assert_match(/^\s*#{Regexp.escape(line)}$/,             @code.run_error)
    end
    
    # fail with an abnormal exit status
    run_code('exit 7')
    assert_match(/\AExit status:\s+7\z/, @code.run_error)
    
    # fail by being KILLed
    prepare_code('sleep 60')
    @code.start
    Process.kill("KILL", @code.pid)
    @code.wait
    assert_match(/Job terminated unexpectedly/, @code.run_error)
  end
  
  private
  
  def prepare_code(*args)
    @code = BetterBJ::CodeExecutor.new(*args)
  end
  
  def run_code(*args)
    prepare_code(*args).run
  end
end
