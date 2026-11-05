# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Defaults to a single process: jobs run inside each Puma process (see
# active_job.queue_adapter in production.rb), so every extra worker adds its
# own job threads and its own connection pool against Postgres max_connections.
worker_count = ENV["RAILS_ENV"] == "production" ? Integer(ENV.fetch("WEB_CONCURRENCY", 1)) : 1

# Feeds refresh on a timer rather than per request, so refreshes happen even
# with no traffic and don't multiply with it. enqueue_all only queues stale
# feeds; the refresh itself runs on the job queue.
start_feed_refresh = lambda do
  Concurrent::TimerTask.execute(execution_interval: 15 * 60, run_now: true) do
    Rails.application.reloader.wrap { RetrieveFeedsJob.enqueue_all }
  rescue => e
    # TimerTask swallows exceptions silently.
    Rails.logger.error("Scheduled feed refresh failed: #{e.full_message}")
  end
end

# Exactly one timer: in cluster mode the master serves no requests and runs no
# jobs, so it goes in worker 0 (re-created if that worker restarts).
if worker_count > 1
  workers worker_count
  before_worker_boot do |index|
    start_feed_refresh.call if index.zero?
  end
else
  after_booted { start_feed_refresh.call }
end

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart
