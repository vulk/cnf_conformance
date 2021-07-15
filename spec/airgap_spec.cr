require "./spec_helper"
require "colorize"
require "../src/tasks/utils/utils.cr"
require "../src/tasks/utils/airgap.cr"
require "file_utils"
require "sam"

describe "AirGap" do
  before_all do
    Helm.helm_repo_add("chaos-mesh", "https://charts.chaos-mesh.org")
    LOGGING.info `./cnf-testsuite airgapped output-file=/tmp/airgapped.tar.gz` unless File.exists?("/tmp/airgapped.tar.gz")
    (File.exists?("/tmp/airgapped.tar.gz")).should be_true
  end

  it "'setup' task should create an airgapped tarball with the necessary files", tags: ["airgap-setup"] do
    file_list = `tar -tvf /tmp/airgapped.tar.gz`
    LOGGING.info "file_list: #{file_list}"
    (file_list).match(/kubectl.tar/).should_not be_nil
    (file_list).match(/chaos-mesh.tar/).should_not be_nil
    (file_list).match(/chaos-daemon.tar/).should_not be_nil
    (file_list).match(/chaos-dashboard.tar/).should_not be_nil
    (file_list).match(/chaos-kernel.tar/).should_not be_nil
    (file_list).match(/prometheus.tar/).should_not be_nil
    (file_list).match(/rbac.yaml/).should_not be_nil
    (file_list).match(/disk-fill-rbac.yaml/).should_not be_nil
    (file_list).match(/litmus-operator/).should_not be_nil
    (file_list).match(/download\/sonobuoy.tar.gz/).should_not be_nil
  end

  it "'setup' task should install the necessary cri tools in the cluster", tags: ["airgap-setup"] do
    response_s = `./cnf-testsuite -l info setup offline=/tmp/airgapped.tar.gz`
    $?.success?.should be_true
    LOGGING.info response_s
    pods = KubectlClient::Get.pods_by_nodes(KubectlClient::Get.schedulable_nodes_list)
    pods = KubectlClient::Get.pods_by_label(pods, "name", "cri-tools")
    # Get the generated name of the cri-tools per node
    pods.map do |pod|
      pod_name = pod.dig?("metadata", "name")
      sh = KubectlClient.exec("-ti #{pod_name} -- cat /usr/local/bin/crictl > /dev/null")
      sh[:status].success?
      sh = KubectlClient.exec("-ti #{pod_name} -- cat /usr/local/bin/ctr > /dev/null")
      sh[:status].success?
    end
    (/All prerequisites found./ =~ response_s).should_not be_nil
    (/Setup complete/ =~ response_s).should_not be_nil
  end

  it "'cnf_setup/cnf_cleanup' should install/cleanup a cnf helm chart in airgapped mode", tags: ["airgap-repo"] do
    begin
      response_s = `./cnf-testsuite cnf_setup cnf-config=example-cnfs/coredns/cnf-testsuite.yml airgapped=/tmp/airgapped.tar.gz`
      LOGGING.info response_s
      file_list = `tar -tvf /tmp/airgapped.tar.gz`
      LOGGING.info "file_list: #{file_list}"
      (file_list).match(/coredns_1.8.0.tar/).should_not be_nil
      (file_list).match(/coredns_1.6.7.tar/).should_not be_nil
      response_s = `./cnf-testsuite cnf_setup cnf-config=example-cnfs/coredns/cnf-testsuite.yml input-file=/tmp/airgapped.tar.gz`
      $?.success?.should be_true
      LOGGING.info response_s
      (/Successfully setup coredns/ =~ response_s).should_not be_nil
    ensure
      response_s = `./cnf-testsuite cnf_cleanup cnf-config=example-cnfs/coredns/cnf-testsuite.yml wait_count=0`
      $?.success?.should be_true
      LOGGING.info response_s
      (/Successfully cleaned up/ =~ response_s).should_not be_nil
    end
  end

  it "'cnf_setup/cnf_cleanup' should install/cleanup a cnf helm directory in airgapped mode", tags: ["airgap-directory"] do
    begin
      response_s = `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample_coredns/cnf-testsuite.yml airgapped=/tmp/airgapped.tar.gz`
      LOGGING.info response_s
      response_s = `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample_coredns/cnf-testsuite.yml input-file=/tmp/airgapped.tar.gz`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Successfully setup coredns/ =~ response_s).should_not be_nil
    ensure
      response_s = `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample_coredns/cnf-testsuite.yml wait_count=0`
      $?.success?.should be_true
      LOGGING.info response_s
      (/Successfully cleaned up/ =~ response_s).should_not be_nil
    end
  end

  it "'cnf_setup/cnf_cleanup' should install/cleanup a cnf manifest directory in airgapped mode", tags: ["airgap-manifest"] do
    begin
      response_s = `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/k8s-non-helm/cnf-testsuite.yml airgapped=/tmp/airgapped.tar.gz`
      LOGGING.info response_s
      response_s = `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/k8s-non-helm/cnf-testsuite.yml input-file=/tmp/airgapped.tar.gz`
      $?.success?.should be_true
      LOGGING.info response_s
      (/Successfully setup nginx-webapp/ =~ response_s).should_not be_nil
      (/exported_chart\" not found/ =~ response_s).should be_nil
    ensure
      response_s = `LOG_LEVEL=debug ./cnf-testsuite cnf_cleanup installed-from-manifest=true cnf-config=sample-cnfs/k8s-non-helm/cnf-testsuite.yml wait_count=0`
      $?.success?.should be_true
      LOGGING.info response_s
      (/Successfully cleaned up/ =~ response_s).should_not be_nil
    end
  end

  after_all do
    AirGap.tmp_cleanup
    (File.exists?("/tmp/airgapped.tar.gz")).should_not be_true
  end
end
