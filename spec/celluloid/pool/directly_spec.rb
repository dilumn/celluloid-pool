RSpec.describe Celluloid::Supervision::Container::Pool, actor_system: :global do

  let(:logger) { Specs::FakeLogger.current }

  context "when auditing actors directly, whether they are idle or not" do

    let(:size) { SupervisionContainerHelper::SIZE }
    before(:each) { subject { MyPoolActor.pool } }

    it "has idle and busy arrays totalling the same as one actor set" do
      expect(subject.actors.length).to eq(subject.busy_size + subject.idle_size)
    end

    it "can be determined whether an actor is idle or busy" do
      busy = 0
      worky = subject.future.sleepier_work
      subject.actors.each { |actor| busy += 1 if subject.__busy?(actor) }
      expect(worky.value).to eq(:worky)
      expect(busy).to eq(1)
    end

    it "can have the actor state revealed by keyword" do
      worky = subject.future.sleepier_work
      states = subject.actors.map { |actor| subject.__state(actor) }
      expect(worky.value).to eq(:worky)
      expect(states.include?(:busy)).to be_truthy
    end
  end

  subject { MyPoolWorker.pool }

  it "processes work units synchronously" do
    expect(subject.process).to be :done
  end

  it "processes work units asynchronously" do
    queue = Queue.new
    subject.async.process(queue)
    expect(queue.pop).to be :done
  end

  it "handles crashes" do
    allow(logger).to receive(:crash) #de .with("Actor crashed!", ExamplePoolError)
    expect { subject.crash }.to raise_error(ExamplePoolError)
    expect(subject.process).to be :done
  end

  it "uses a fixed-sized number of threads" do
    subject # eagerly evaluate the pool to spawn it

    actors = Celluloid::Actor.all
    100.times.map { subject.future(:process) }.map(&:value)

    new_actors = Celluloid::Actor.all - actors
    expect(new_actors).to eq []
  end

  it "terminates" do
    expect { subject.terminate }.to_not raise_exception
  end

  it "handles many requests" do
    futures = 10.times.map do
      subject.future.process
    end
    futures.map(&:value)
  end

  context "allows single worker pools" do
    let(:initial_size) { 1 }

    subject { MyPoolWorker.pool size: initial_size }

    it "properly" do
      expect(test_concurrency_of(subject)).to eq(initial_size)
    end

    context "and resizes properly" do
      let(:initial_size) { 1 } # anything other than 2 or 4 too big on Travis

      subject { MyPoolWorker.pool size: initial_size }

      it "should adjust the pool size up" do
        expect(test_concurrency_of(subject)).to eq(initial_size)

        subject.size = 6
        expect(subject.size).to eq(6)

        expect(test_concurrency_of(subject)).to eq(6)
      end

      it "should adjust the pool size down" do
        expect(test_concurrency_of(subject)).to eq(initial_size)

        subject.size = 2
        expect(subject.size).to eq(2)
        expect(test_concurrency_of(subject)).to eq(2)
      end
    end
  end

  context "#size=" do
    let(:initial_size) { 3 } # anything other than 2 or 4 too big on Travis

    subject { MyPoolWorker.pool size: initial_size }

    it "should adjust the pool size up" do
      expect(test_concurrency_of(subject)).to eq(initial_size)

      subject.size = 6
      expect(subject.size).to eq(6)

      expect(test_concurrency_of(subject)).to eq(6)
    end

    it "should adjust the pool size down" do
      expect(test_concurrency_of(subject)).to eq(initial_size)

      subject.size = 2
      expect(subject.size).to eq(2)
      expect(test_concurrency_of(subject)).to eq(2)
    end
  end

  context "when called synchronously" do
    subject { MyPoolWorker.pool }

    it { is_expected.to respond_to(:process) }
    it { is_expected.to respond_to(:inspect) }
    it { is_expected.not_to respond_to(:foo) }

    it { is_expected.to respond_to(:a_protected_method) }
    it { is_expected.not_to respond_to(:a_private_method) }

    context "when include_private is true" do
      it "should respond_to :a_private_method" do
        expect(subject.respond_to?(:a_private_method, true)).to eq(true)
      end
    end
  end

  context "when called asynchronously" do
    subject { MyPoolWorker.pool.async }

    context "with incorrect invocation" do

      it "logs ArgumentError exception" do
        expect(logger).to receive(:crash).with(
          anything,
          instance_of(ArgumentError))

        subject.process(:something, :one_argument_too_many)
        sleep 0.001 # Let Celluloid do it's async magic
        sleep 0.1 if RUBY_PLATFORM == "java"
      end
    end

    context "when unintialized" do
      it "should provide reasonable dump" do
        expect(subject.inspect).to eq("#<Celluloid::Proxy::Async(Celluloid::Supervision::Container::Pool)>")
      end
    end
  end
end
