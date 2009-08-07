# encoding: UTF-8

require "test_helper"

require "better_bj/code_executor"

class TestCodeExecutor < Test::Unit::TestCase
  def setup
    @result_path = File.join(File.dirname(__FILE__), "code_run.txt")
  end
  
  def teardown
    File.unlink(@result_path) if File.exist? @result_path
  end
  
  def test_code_is_executed
    flunk("Run file already existed") if File.exist? @result_path
    run_code('open(%p, "w") { }' % @result_path)
    assert(File.exist?(@result_path), "Run file was not created")
  end

  def test_code_is_executed_in_a_separate_process
    flunk("Run file already existed") if File.exist? @result_path
    run_code('open(%p, "w") { |f| f.puts Process.pid }' % @result_path)
    assert_not_equal(Process.pid, File.read(@result_path).to_i)
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
  
  private
  
  def prepare_code(*args)
    @code = BetterBJ::CodeExecutor.new(*args)
  end
  
  def run_code(*args)
    prepare_code(*args).run
  end
end
