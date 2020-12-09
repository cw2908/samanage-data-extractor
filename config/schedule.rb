# frozen_string_literal: true

job_type :rake, "cd :path && :bundle_command rake :task :output"
set :output, File.join("/swsd-data-extractor", "exports", "log", "cron_log.log")

# This job should run daily as early as possible
every 1.day, at: ["12:01 am"] do
  rake "extract_data"
end
