# encoding: UTF-8

require "test/unit"

module TestHelper
  private
  
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

Test::Unit::TestCase.send(:include, TestHelper)
