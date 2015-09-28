unless $CELLULOID_BACKPORTED == false
  RSpec.describe "BACKPORTED Celluloid.pool", actor_system: :global do
    subject { MyPoolWorker.pool }
    let(:logger) { Specs::FakeLogger.current }

    it "processes work units synchronously" do
      expect(subject.process).to be :done
    end

    it "processes work units asynchronously" do
      queue = Queue.new
      subject.async.process(queue)
      expect(queue.pop).to be :done
    end

    it "handles crashes" do
      allow(logger).to receive(:crash) # de .with("Actor crashed!", ExamplePoolError)
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

    context "#size=" do
      let(:initial_size) { 3 } # anything other than 2 or 4 or too big on Travis

      subject { MyPoolWorker.pool size: initial_size }

      it "should adjust the pool size up", flaky: true do
        expect(test_concurrency_of(subject)).to eq(initial_size)

        subject.size = 6
        expect(subject.size).to eq(6)

        expect(test_concurrency_of(subject)).to eq(6)
      end

      it "should adjust the pool size down", flaky: true do
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
        before do
          allow(logger).to receive(:crash)
          allow(logger).to receive(:warn)
          allow(logger).to receive(:with_backtrace) do |*args, &block|
            block.call logger
          end
        end

        it "logs ArgumentError exception", retry: Specs::ALLOW_RETRIES, flaky: true do
          expect(logger).to receive(:crash).with(
            anything,
            instance_of(ArgumentError))

          subject.process(:something, :one_argument_too_many)
          sleep 0.1 # async hax
        end
      end

      context "when unintialized" do
        it "should provide reasonable dump" do
          expect(subject.inspect).to eq("#<Celluloid::Proxy::Async(Celluloid::Supervision::Container::Pool)>")
        end
      end
    end
  end
end
