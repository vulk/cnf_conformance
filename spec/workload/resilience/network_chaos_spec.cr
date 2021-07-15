require "../../spec_helper"
require "colorize"
require "../../../src/tasks/utils/utils.cr"
require "../../../src/tasks/utils/system_information/helm.cr"
require "file_utils"
require "sam"

describe "Resilience Network Chaos" do
  before_all do
    `./cnf-testsuite setup`
    `./cnf-testsuite configuration_file_setup`
    $?.success?.should be_true
  end

  # TODO Fix Chaos Network Loss Test
  # it "'chaos_network_loss' A 'Good' CNF should not crash when network loss occurs", tags: ["chaos_network_loss"]  do
  #   begin
  #     `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml`
  #     $?.success?.should be_true
  #     response_s = `./cnf-testsuite chaos_network_loss verbose`
  #     LOGGING.info response_s
  #     $?.success?.should be_true
  #     (/PASSED: Replicas available match desired count after network chaos test/ =~ response_s).should_not be_nil
  #   ensure
  #     `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml`
  #     $?.success?.should be_true
  #   end
  # end

  # TODO upgrade chaos mesh
  # it "'chaos_network_loss' A 'Bad' CNF should crash when network loss occurs", tags: ["chaos_network_loss"]  do
  #   begin
  #     `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_network_loss deploy_with_chart=false wait_count=60`
  #     $?.success?.should be_true
  #     response_s = `./cnf-testsuite chaos_network_loss verbose`
  #     LOGGING.info response_s
  #     $?.success?.should be_true
  #     (/FAILED: Replicas did not return desired count after network chaos test/ =~ response_s).should_not be_nil
  #   ensure
  #     `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_network_loss deploy_with_chart=false`
  #     $?.success?.should be_true
  #   end
  # end
end
