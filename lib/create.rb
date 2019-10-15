# frozen_string_literal: true

require 'aws-sdk-rds'

# Aws
module Aws
  # Rds
  module Rds
    # Create snapshots
    # @param db_name [String] - rds db name
    # @param db_arn [String] - arn of given db
    # @param region [String] - aws region
    # @param all_snapshots [Object] - all snapshots available for the given aws region
    # @param time [Time] - time
    # @return [Object]
    class Create
      class << self
        attr_accessor :all_created_snapshots
      end

      CREATED_SNAPSHOTS = lambda do |obj, snapshot_id|
        obj.class.all_created_snapshots ||= []
        obj.class.all_created_snapshots << snapshot_id
      end

      def initialize(
        db_name:       nil,
        db_arn:        nil,
        region:        nil,
        all_snapshots: Rds::Snapshots.new(region: region).snapshots_by_hostname,
        time:          Time.now.utc
      )
        @db_name           = db_name
        @db_arn            = db_arn
        @region            = region
        @time              = time
        @snapshot_id       = snapshot_id
        @db_snapshot       = Aws::RDS::DBSnapshot.new(instance_id: db_name, snapshot_id: snapshot_id)
        @db_name           = db_name
        @snapshots_by_name = all_snapshots
      end

      # Create snapshot if it wasn't done yet today
      # @return [Boolean]
      def try_snapshot!
        if already_done_today?
          puts ">> No need to make a snapshot for #{@db_name}"
          return false
        end

        snapshot!
      end

      private

      def snapshot!
        puts ">> Calling snapshot #{@snapshot_id} creation..".green
        @db_snapshot.create(tags: existing_tags + additional_tags)
        CREATED_SNAPSHOTS.call(self, @snapshot_id)
        true
      rescue StandardError => e
        puts ">> Can't create snapshot #{@snapshot_id}. Error is: #{e}".red
        false
      end

      def additional_tags
        Config::ADDITIONAL_TAGS
      end

      def existing_tags
        Aws::RDS::Client.new(region: @region).list_tags_for_resource(
          resource_name: @db_arn
        ).to_h[:tag_list]
      end

      def existing_snapshots
        puts ">> Existing snapshots for #{@db_name}: #{JSON.pretty_generate(@snapshots_by_name[@db_name].keys)}"
        @snapshots_by_name[@db_name]
      end

      def already_done_today?
        existing_snapshots.each_pair do |snap, attrs|
          if creating_or_available?(attrs[:status]) && done_today?(attrs[:snapshot_create_time])
            puts ">> There is #{snap} in #{attrs[:status]} status and was done today"
            return true
          end
        end
        false
      end

      def creating_or_available?(status)
        %w[creating available].any?(status)
      end

      def done_today?(creation_time)
        @time - creation_time < @time - beginning_of_day
      end

      def beginning_of_day
        Date.parse(@time.to_s).to_time
      end

      def snapshot_id
        "#{@db_name}-#{date_suffix}"
      end

      def date_suffix
        Rds::Config::DATE_SUFFIX.call(@time)
      end
    end
  end
end
