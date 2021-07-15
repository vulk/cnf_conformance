require "./../spec_helper"
require "colorize"
require "file_utils"
require "./../../src/tasks/utils/utils.cr"

describe "Cluster API" do
  before_all do
    `./cnf-testsuite setup`
    $?.success?.should be_true
  end

  after_all do
    # cleanup cluster api stuff
    # `./cnf-testsuite cluster_api_cleanup`
  end

  it "'clusterapi_enabled' should pass if cluster api is installed", tags: ["cluster-api"] do
    begin
      LOGGING.info `./cnf-testsuite cluster_api_setup`
      current_dir = FileUtils.pwd
      FileUtils.cd("#{current_dir}")
      response_s = `./cnf-testsuite clusterapi_enabled poc`
      LOGGING.info response_s
      (/Cluster API is enabled/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cluster_api_cleanup`
    end
  end

  it "'clusterapi_enabled' should fail if cluster api is not installed", tags: ["cluster-api"] do
    response_s = `./cnf-testsuite clusterapi_enabled poc`
    LOGGING.info response_s
    (/Cluster API NOT enabled/ =~ response_s).should_not be_nil
  end
end
