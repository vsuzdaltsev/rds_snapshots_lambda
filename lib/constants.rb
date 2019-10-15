# frozen_string_literal: true

# Aws
module Aws
  #  Rds
  module Rds
    # Configuration
    module Config
      UTILIZED_REGIONS = %w[
        eu-west-1
        ap-southeast-2
      ].freeze
      ADDITIONAL_TAGS = [
        {
          key:   'created_by',
          value: 'lambda'
        }
      ].freeze
      KEEP_CURRENT_WEEK_SNAPSHOTS = %w[
        monday
        wednesday
        friday
        saturday
      ].freeze
      KEEP_PREVIOUS_WEEK_SNAPSHOTS = %w[
        monday
        friday
      ].freeze
      KEEP_TWO_WEEKS_AGO_SNAPSHOTS = %w[
        monday
      ].freeze
      DATE_SUFFIX = lambda do |time|
        t = ->(type) { time.send(type) }
        %W[#{t.call('year')} #{t.call('month')} #{t.call('day')} #{t.call('hour')} #{t.call('min')}].join('-')
      end
      DELETE_ALL_SNAPS_AFTER_WEEKS = 16
    end
  end
end
