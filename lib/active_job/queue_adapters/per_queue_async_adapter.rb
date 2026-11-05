require "securerandom"
require "concurrent/map"
require "concurrent/scheduled_task"
require "concurrent/executor/thread_pool_executor"

module ActiveJob
  module QueueAdapters
    # In-process adapter like AsyncAdapter, except each queue gets its own
    # executor. AsyncAdapter ignores queue names and runs every job on one
    # shared pool, so a stuck job on one queue would delay all the others.
    #
    # Required explicitly from config/environments/production.rb, which runs
    # before autoloading is set up; lib/active_job is excluded from autoload_lib.
    class PerQueueAsyncAdapter < AbstractAdapter
      def initialize(**executor_options)
        @executor_options = { min_threads: 0, max_threads: 1, idletime: 60, max_queue: 0 }
                            .merge(executor_options)
        @executors = Concurrent::Map.new
      end

      def enqueue(job)
        data = serialize(job)
        executor_for(job.queue_name).post { Base.execute(data) }
      end

      def enqueue_at(job, timestamp)
        data = serialize(job)
        delay = [timestamp - Time.current.to_f, 0].max
        Concurrent::ScheduledTask.execute(delay, executor: executor_for(job.queue_name)) do
          Base.execute(data)
        end
      end

      private

      # Serializing in-process jobs is unnecessary, but matches what AsyncAdapter
      # and out-of-process adapters do so serialization bugs still surface.
      def serialize(job)
        job.provider_job_id = SecureRandom.uuid
        job.serialize
      end

      def executor_for(queue_name)
        @executors.compute_if_absent(queue_name) do
          Concurrent::ThreadPoolExecutor.new(name: "ActiveJob-#{queue_name}", **@executor_options)
        end
      end
    end
  end
end
