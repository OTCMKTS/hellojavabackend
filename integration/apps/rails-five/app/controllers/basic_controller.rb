require "#{Rails.root}/app/jobs/test_job"

class BasicController < ApplicationController
  # Reads & writes from cache, reads from DB, and queues a Resque job.
  #
  # Example trace:
  #
  # ----------------------- Rack -----------------------------
  #    -------------- ActionController --------------------
  #      --- ActiveSupport -- ActiveRecord -- Resque ---
  #        ----- Redis ----                 -- Redis --
  #
  def default
  