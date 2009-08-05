# encoding: UTF-8

module BetterBJ
  class Runner
    def initialize(options = { }, &event_loop)
      @tethered          = options.fetch(:tethered, true)
      @sleep_seconds     = options.fetch(:sleep_seconds, 42)
      @running           = true
      @event_loop        = event_loop || lambda { run_jobs }
      @pid               = nil
      @event_loop_thread = nil
      @tether_thread     = nil
    end
    
    attr_reader :pid
    
    def run
      reader, writer = IO.pipe if @tethered
      @pid = fork do
        writer.close if @tethered
        @event_loop_thread = Thread.current
        @tether_thread     = Thread.new do
          Thread.current.abort_on_exception = true
          reader.read
          @running = false
          @event_loop_thread.run
        end
        while @running
          @event_loop[self]
          sleep @sleep_seconds
        end
      end
      reader.close if @tethered
    end
    
    private
    
    def run_jobs
      
    end
  end
end
