require "../spec_helper"
require "colorize"
require "../../src/tasks/utils/utils.cr"
require "../../src/tasks/utils/kubectl_client.cr"
require "../../src/tasks/utils/system_information/helm.cr"
require "file_utils"
require "sam"

describe "State" do
  before_all do
    `./cnf-testsuite configuration_file_setup`
  end

  it "'volume_hostpath_not_found' should pass if the cnf doesn't have a hostPath volume", tags: ["volume_hostpath_not_found"] do
    begin
      `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml`
      $?.success?.should be_true
      response_s = `./cnf-testsuite volume_hostpath_not_found verbose`
      LOGGING.info "Status:  #{response_s}"
      (/PASSED: hostPath volumes not found/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml`
      $?.success?.should be_true
    end
  end

  it "'volume_hostpath_not_found' should fail if the cnf has a hostPath volume", tags: ["volume_hostpath_not_found"] do
    begin
      `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample-fragile-state/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite volume_hostpath_not_found verbose`
      LOGGING.info "Status:  #{response_s}"
      (/FAILED: hostPath volumes found/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample-fragile-state/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
    end
  end

  it "'no_local_volume_configuration' should fail if local storage configuration found", tags: ["no_local_volume_configuration"] do
    begin
      # update the helm parameter with a schedulable node for the pv chart
      schedulable_nodes = KubectlClient::Get.schedulable_nodes
      update_yml("sample-cnfs/sample-local-storage/cnf-testsuite.yml", "release_name", "coredns --set worker_node='#{schedulable_nodes[0]}'")
      `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample-local-storage/cnf-testsuite.yml verbose`
      $?.success?.should be_true
      response_s = `./cnf-testsuite no_local_volume_configuration verbose`
      LOGGING.info "Status:  #{response_s}"
      (/FAILED: local storage configuration volumes found/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample-local-storage/cnf-testsuite.yml deploy_with_chart=false`
      update_yml("sample-cnfs/sample-local-storage/cnf-testsuite.yml", "release_name", "coredns")
      $?.success?.should be_true
    end
  end

  it "'no_local_volume_configuration' should pass if local storage configuration is not found", tags: ["no_local_volume_configuration"] do
    begin
      `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml verbose`
      $?.success?.should be_true
      response_s = `./cnf-testsuite no_local_volume_configuration verbose`
      LOGGING.info "Status:  #{response_s}"
      (/PASSED: local storage configuration volumes not found/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
    end
  end
end
