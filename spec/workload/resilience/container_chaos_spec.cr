require "../../spec_helper"
require "colorize"
require "../../../src/tasks/utils/utils.cr"
require "../../../src/tasks/utils/system_information/helm.cr"
require "file_utils"
require "sam"

describe "Resilience Container Chaos" do
  before_all do
    `./cnf-testsuite setup`
    `./cnf-testsuite configuration_file_setup`
    $?.success?.should be_true
  end

  it "'chaos_container_kill' A 'Good' CNF should recover when its container is killed", tags: ["chaos_container_kill"] do
    begin
      `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml`
      $?.success?.should be_true
      response_s = `./cnf-testsuite chaos_container_kill verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: Replicas available match desired count after container kill test/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml`
      $?.success?.should be_true
    end
  end

  # TODO upgrade chaos mesh
  # it "'chaos_container_kill' A 'Bad' CNF should NOT recover when its container is killed", tags: ["chaos_container_kill"]  do
  #   begin
  #     `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample-fragile-state deploy_with_chart=false`
  #     $?.success?.should be_true
  #     response_s = `./cnf-testsuite chaos_container_kill verbose`
  #     LOGGING.info response_s
  #     $?.success?.should be_true
  #     (/FAILED: Replicas did not return desired count after container kill test/ =~ response_s).should_not be_nil
  #   ensure
  #     `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-fragile-state deploy_with_chart=false`
  #     $?.success?.should be_true
  #   end
  # end
end
