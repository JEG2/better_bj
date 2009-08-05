# encoding: UTF-8

require "test/unit"

require "better_bj/runner"

class TestRunner < Test::Unit::TestCase
  def test_a_tethered_runner_exits_when_the_launching_process_exits
    launch_runner( :tethered      => true,
                   :sleep_seconds => 1,
                   :event_loop    => lambda {  } )
    
    3.times do
      assert_pid_running(@launching_pid)
      assert_pid_running(@runner_pid)
      sleep 1
    end
    
    Process.wait(@launching_pid)  # wait for launching process to exit
    sleep 2                       # give the child time to notice it
    assert_pid_not_running(@launching_pid)
    assert_pid_not_running(@runner_pid)
  end
  
  def test_a_tethered_runner_exits_when_the_launching_process_is_killed
    launch_runner( :tethered      => true,
                   :sleep_seconds => 1,
                   :event_loop    => lambda {  } )
    
    assert_pid_running(@launching_pid)
    assert_pid_running(@runner_pid)
    
    Process.kill("KILL", @launching_pid)  # forcfully kill the launching process 
    sleep 2                               # give the processes time to notice
    Process.wait(@launching_pid, Process::WNOHANG)  # reap the launcher
    assert_pid_not_running(@launching_pid)
    assert_pid_not_running(@runner_pid)
  end
  
  def test_a_runner_notices_the_launchers_exit_when_sleeping
    launch_runner( :tethered           => true,
                   :sleep_seconds      => 42,
                   :event_loop         => lambda {  },
                   :sleep_after_launch => 1 )  # time for the runner to sleep
    
    Process.wait(@launching_pid)  # wait for launching process to exit
    sleep 2                       # give the child time to notice it
    assert_pid_not_running(@launching_pid)
    assert_pid_not_running(@runner_pid)
  end
  
  private
  
  def launch_runner(options)
    sleep_after_launch = options.delete(:sleep_after_launch) || 4
    @reader, writer    = IO.pipe
    @launching_pid     = fork do
      runner = BetterBJ::Runner.new(options)
      runner.run
      writer.puts runner.pid
      writer.puts "active"
      sleep sleep_after_launch
    end
    @runner_pid = Integer(@reader.gets)
    @reader.gets  # wait for "active"
  end
  
  def pid_running?(pid)
    Process.kill(0, pid)
    true
  rescue Exception
    false
  end
  
  def assert_pid_running(pid)
    assert(pid_running?(pid), "PID #{pid} could not be found")
  end
  
  def assert_pid_not_running(pid)
    assert(!pid_running?(pid), "PID #{pid} was found")
  end
end
