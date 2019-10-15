# frozen_string_literal: true

require 'json'

require_relative File.expand_path('lib/string', __dir__)
require_relative File.expand_path('lib/constants', __dir__)
require_relative File.expand_path('lib/delete', __dir__)
require_relative File.expand_path('lib/create', __dir__)
require_relative File.expand_path('lib/snapshots', __dir__)

def lambda_handler(*)
  rds_snapshots
  {
    statusCode: 200,
    body:       JSON.generate(
      to_create: Aws::Rds::Create.all_created_snapshots,
      to_delete: Aws::Rds::Delete.all_deleted_snapshots
    )
  }
end

def rds_snapshots
  Aws::Rds::Config::UTILIZED_REGIONS.each do |region|
    available_instances = Aws::Rds::Instances.available(region: region)
    existing_snapshots  = Aws::Rds::Snapshots.new(region: region).snapshots_by_hostname

    available_instances.each_pair do |db, db_arn|
      Aws::Rds::Create.new(
        db_name:       db,
        db_arn:        db_arn,
        region:        region,
        all_snapshots: existing_snapshots
      ).try_snapshot!

      Aws::Rds::Delete.new(
        db_name:       db,
        region:        region,
        all_snapshots: existing_snapshots
      ).delete_outdated_snapshots!
    end
  end
end
