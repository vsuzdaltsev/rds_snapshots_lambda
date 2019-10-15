# frozen_string_literal: true

# Aws
module Aws
  # Rds
  module Rds
    # Delete outdated snapshots
    class Delete
      class << self
        attr_accessor :all_deleted_snapshots
      end

      attr_reader :time,
                  :db_name,
                  :db_snapshots,
                  :snapshots_by_weeks,
                  :snapshots_to_delete

      KEEP_CURRENT_WEEK_SNAPSHOTS  = Config::KEEP_CURRENT_WEEK_SNAPSHOTS
      KEEP_PREVIOUS_WEEK_SNAPSHOTS = Config::KEEP_PREVIOUS_WEEK_SNAPSHOTS
      KEEP_TWO_WEEKS_AGO_SNAPSHOTS = Config::KEEP_TWO_WEEKS_AGO_SNAPSHOTS
      DELETE_ALL_SNAPS_AFTER_WEEKS = Config::DELETE_ALL_SNAPS_AFTER_WEEKS

      DELETED_SNAPSHOTS = lambda do |obj, to_delete|
        obj.class.all_deleted_snapshots ||= []
        obj.class.all_deleted_snapshots += to_delete
      end

      BEGINNING_OF_THE_WEEK = lambda do |count|
        define_method("beginning_of_#{count}_week") do
          (@time.to_date - (@time.wday + 7 * count)).to_time
        end
      end

      SNAPSHOTS_OF_THE_WEEK = lambda do |count|
        define_method("snapshot_of_#{count}_week") do
          start  = send("beginning_of_#{count}_week")
          finish = send("beginning_of_#{count - 1}_week")
          @db_snapshots.each_pair.each_with_object({}) do |(snap, attrs), memo|
            memo.merge!(snap => created_at(attrs)) if created_at(attrs).between?(start, finish)
          end.compact
        end
      end

      # @param region [String] - aws region
      # @param db_name [String] - rds db name
      # @param all_snapshots [Object] - all snapshots available for the given aws region
      # @param time [Time] - time
      # @return [Object]
      def initialize(
        region:        nil,
        db_name:       nil,
        all_snapshots: Rds::Snapshots.new(region: region).snapshots_by_hostname,
        time:          Time.now.utc
      )
        @time         = time
        @db_name      = db_name
        @db_snapshots = all_snapshots[@db_name]

        create_methods

        @snapshots_by_weeks = {
          this_week_snapshots:          snapshot_of_0_week,
          previous_week_snapshots:      snapshot_of_1_week,
          two_weeks_ago_snapshots:      snapshot_of_2_week,
          tree_weeks_ago_snapshots:     snapshot_of_3_week,
          four_weeks_ago_snapshots:     snapshot_of_4_week,
          five_weeks_ago_snapshots:     snapshot_of_5_week,
          six_weeks_ago_snapshots:      snapshot_of_6_week,
          seven_weeks_ago_snapshots:    snapshot_of_7_week,
          eight_weeks_ago_snapshots:    snapshot_of_8_week,
          nine_weeks_ago_snapshots:     snapshot_of_9_week,
          ten_weeks_ago_snapshots:      snapshot_of_10_week,
          eleven_weeks_ago_snapshots:   snapshot_of_11_week,
          twelve_weeks_ago_snapshots:   snapshot_of_12_week,
          thirteen_weeks_ago_snapshots: snapshot_of_13_week,
          fourteen_weeks_ago_snapshots: snapshot_of_14_week,
          fifteen_weeks_ago_snapshots:  snapshot_of_15_week,
          sixteen_weeks_ago_snapshots:  snapshot_of_16_week
        }

        @snapshots_to_delete = {
          this_week_snapshots:         delete_0_week,
          previous_week_snapshots:     delete_1_week,
          two_weeks_ago_snapshots:     delete_2_week,
          sixteen_weeks_ago_snapshots: delete_16_week
        }

        DELETED_SNAPSHOTS.call(self, to_delete)
      end

      # Delete snapshots that were outdated according to configuration
      # @return [Boolean]
      def delete_outdated_snapshots!
        return true if to_delete.empty?

        to_delete.each do |snapshot_id|
          puts ">> Calling deletion of outdated snapshot #{snapshot_id}..".green
          Aws::RDS::DBSnapshot.new(instance_id: @db_name, snapshot_id: snapshot_id).delete
        end
        true
      rescue StandardError => e
        puts ">> Can't delete outdated snapshot for #{@db_name}. Error is: #{e}".red
        false
      end

      private

      def snapshot_of_0_week
        @db_snapshots.each_pair.each_with_object({}) do |(snap, attrs), memo|
          memo.merge!(snap => created_at(attrs)) if created_at(attrs).between?(beginning_of_0_week, @time)
        end.compact
      end

      def created_at(attrs)
        attrs[:snapshot_create_time]
      end

      def create_methods
        (0..DELETE_ALL_SNAPS_AFTER_WEEKS).each do |count|
          BEGINNING_OF_THE_WEEK.call(count)
        end

        (1..DELETE_ALL_SNAPS_AFTER_WEEKS).each do |count|
          SNAPSHOTS_OF_THE_WEEK.call(count)
        end
      end

      def delete_0_week
        snaps = @snapshots_by_weeks[:this_week_snapshots].map do |snap, creation_time|
          snap unless filter_keep_snapshots(KEEP_CURRENT_WEEK_SNAPSHOTS, creation_time)
        end.compact
        return [] if snaps.size < 4

        snaps
      end

      def delete_x_week(week, keep)
        @snapshots_by_weeks[week].map do |snap, creation_time|
          snap unless filter_keep_snapshots(keep, creation_time)
        end.compact
      end

      def delete_1_week
        delete_x_week(:previous_week_snapshots, KEEP_PREVIOUS_WEEK_SNAPSHOTS)
      end

      def delete_2_week
        delete_x_week(:two_weeks_ago_snapshots, KEEP_TWO_WEEKS_AGO_SNAPSHOTS)
      end

      def delete_16_week
        @snapshots_by_weeks[:sixteen_weeks_ago_snapshots].keys
      end

      def filter_keep_snapshots(days, creation_time)
        days.any? do |day|
          creation_time.send(day + '?')
        end
      end

      def to_delete
        @snapshots_to_delete.values.compact.flatten
      end
    end
  end
end
