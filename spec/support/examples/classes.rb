class ExamplePoolError < Celluloid::Error; end

class MyPoolWorker
  include Celluloid

  def process(queue = nil)
    if queue
      queue << :done
    else
      :done
    end
  end

  def sleepy_work
    t = Time.now.to_f
    sleep 0.25
    t
  end

  def sleepier_work
    sleep 1.0
    :worky
  end

  def crash
    fail ExamplePoolError, "zomgcrash"
  end

  protected

  def a_protected_method
  end

  private

  def a_private_method
  end
end

class SupervisionContainerHelper
  QUEUE = Queue.new

  # Keep it at 3 to better detect argument-passing issues
  SIZE = 3
end

class MyPoolActor
  include Celluloid

  attr_reader :args
  def initialize(*args)
    @args = *args
    ready
  end

  def running?
    :yep
  end

  def ready
    SupervisionContainerHelper::QUEUE << :done
  end
end
