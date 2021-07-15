require "../spec_helper"
require "colorize"
require "../../src/tasks/utils/utils.cr"

describe CnfTestSuite do
  before_all do
    # LOGGING.debug `pwd`
    # LOGGING.debug `echo $KUBECONFIG`
    `./cnf-testsuite samples_cleanup`
    $?.success?.should be_true
    `./cnf-testsuite configuration_file_setup`
    # `./cnf-testsuite setup`
    # $?.success?.should be_true
  end
  it "'privileged' should pass with a non-privileged cnf", tags: ["privileged"] do
    begin
      LOGGING.debug `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample-statefulset-cnf/cnf-testsuite.yml`
      response_s = `./cnf-testsuite privileged verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Found.*privileged containers.*coredns/ =~ response_s).should be_nil
    ensure
      LOGGING.debug `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample-statefulset-cnf/cnf-testsuite.yml`
    end
  end
  it "'privileged' should fail on a non-whitelisted, privileged cnf", tags: ["privileged"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_privileged_cnf/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite privileged cnf-config=sample-cnfs/sample_privileged_cnf verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Found.*privileged containers.*coredns/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite sample_privileged_cnf_non_whitelisted_cleanup`
    end
  end
  it "'privileged' should pass on a whitelisted, privileged cnf", tags: ["privileged"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_whitelisted_privileged_cnf/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite privileged cnf-config=sample-cnfs/sample_whitelisted_privileged_cnf verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Found.*privileged containers.*coredns/ =~ response_s).should be_nil
    ensure
      `./cnf-testsuite sample_privileged_cnf_whitelisted_cleanup`
    end
  end
end
