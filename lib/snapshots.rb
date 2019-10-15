# frozen_string_literal: true

require_relative File.expand_path('constants.rb', __dir__)
require 'aws-sdk'

# Aws
module Aws
  # Rds
  module Rds
    # Aws rds snapshots api call
    class ApiCall
      # @param region [String] - aws region
      # @return [Object]
      def self.rds_snapshots(region: nil)
        raise ArgumentError, ">> #{self}.#{__method__}: mandatory <region> kwarg missing" unless region

        Aws::RDS::Client.new(region: region).describe_db_snapshots.each_with_object([]) do |response, memo|
          memo << response[:db_snapshots]
        end.flatten
      rescue StandardError => e
        puts "Can't get info about existing RDS snapshots. Error is: #{e}"
      end
    end

    # Aws rds instances available within given region
    class Instances
      # @param region [String] - aws region
      # @return [Object]
      def self.available(region: nil)
        raise ArgumentError, ">> #{self}.#{__method__}: mandatory <region> kwarg missing" unless region

        # collect only <available> for backing-up, not those that are already in <backing-up> status
        Aws::RDS::Resource.new(region: region).db_instances.each_with_object({}) do |instance, memo|
          memo.merge!(instance.id => instance.db_instance_arn) if instance.db_instance_status.eql?(__method__.to_s)
        end
      end

      def self.available_names(region: nil)
        available(region: region).keys
      end
    end

    # Report existing snapshots in given region
    class Snapshots
      attr_reader :describe_rds_snapshots,
                  :snapshots_by_hostname

      # @param region [String] - aws region
      # @return [Object]
      def initialize(region: nil)
        raise ArgumentError, ">> #{self}.#{__method__}: mandatory <region> kwarg missing" unless region

        @region                  = region
        @describe_rds_snapshots  = ApiCall.rds_snapshots(region: region)
        @current_snapshots_count = snaps_by_hostname.values.flatten.size
        @snapshots_by_hostname   = snaps_by_hostname
      end

      private

      def instance_ids
        @describe_rds_snapshots.map do |snap|
          db_instance(snap)
        end.uniq
      end

      def snaps_by_hostname
        @describe_rds_snapshots.each_with_object(Hash.new({})) do |snap, memo|
          memo[db_instance(snap)] = memo[db_instance(snap)].merge(snapshot_by_instance(snap))
        end
      end

      def db_instance(snap)
        snap[:db_instance_identifier]
      end

      def snapshot_by_instance(snap)
        {
          snap[:db_snapshot_identifier] => {
            snapshot_create_time: snap[:snapshot_create_time],
            snapshot_type:        snap[:snapshot_type],
            status:               snap[:status],
            db_snapshot_arn:      snap[:db_snapshot_arn]
          }
        }
      end
    end
  end
end
