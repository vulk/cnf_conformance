require "../../spec_helper"
require "colorize"
require "../../../src/tasks/utils/utils.cr"
require "../../../src/tasks/utils/system_information/helm.cr"
require "file_utils"
require "sam"

describe "Resilience pod delete Chaos" do
  before_all do
    `./cnf-testsuite setup`
    `./cnf-testsuite configuration_file_setup`
    $?.success?.should be_true
  end

  it "'pod_delete' A 'Good' CNF should not crash when pod delete occurs", tags: ["pod_delete"] do
    begin
      `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml`
      $?.success?.should be_true
      response_s = `./cnf-testsuite pod_delete verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: pod_delete chaos test passed/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml`
      $?.success?.should be_true
      `./cnf-testsuite uninstall_litmus`
      $?.success?.should be_true
    end
  end
end
