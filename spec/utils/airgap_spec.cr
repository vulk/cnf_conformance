require "../spec_helper"
require "colorize"
require "../../src/tasks/utils/utils.cr"
require "../../src/tasks/utils/airgap.cr"
require "../../src/tasks/utils/kubectl_client.cr"
require "file_utils"
require "sam"

describe "AirGap" do
  it "'image_pull_policy' should change all imagepull policy references to never", tags: ["airgap"] do
    AirGapUtils.image_pull_policy("./spec/fixtures/litmus-operator-v1.13.2.yaml", "/tmp/imagetest.yml")
    (File.exists?("/tmp/imagetest.yml")).should be_true
    resp = File.read("/tmp/imagetest.yml")
    (resp).match(/imagePullPolicy: Always/).should be_nil
    (resp).match(/imagePullPolicy: Never/).should_not be_nil
  ensure
    `rm ./tmp/imagetest.yml`
  end

  it "'#AirGap.publish_tarball' should execute publish a tarball to a bootstrapped cluster", tags: ["airgap"] do
    AirGap.download_cri_tools
    AirGap.bootstrap_cluster
    tarball_name = "./spec/fixtures/testimage.tar.gz"
    resp = AirGap.publish_tarball(tarball_name)
    resp[0][:output].to_s.match(/unpacking docker.io\/testimage\/testimage:test/).should_not be_nil
  end

  it "'.tar_helm_repo' should create a tar file from a helm repository that has options", tags: ["airgap"] do
    Helm.helm_repo_add("chaos-mesh", "https://charts.chaos-mesh.org")
    AirGap.tar_helm_repo("chaos-mesh/chaos-mesh --version 0.5.1", "/tmp/airgapped.tar")
    (File.exists?("/tmp/airgapped.tar")).should be_true
    resp = `tar -tvf /tmp/airgapped.tar`
    LOGGING.info "Tar Filelist: #{resp}"
    (/repositories\/chaos-mesh_chaos-mesh/).should_not be_nil
  ensure
    `rm /tmp/airgapped.tar`
  end

  it "'.tar_helm_repo' should create a tar file from a helm repository", tags: ["airgap"] do
    AirGap.tar_helm_repo("stable/coredns", "/tmp/airgapped.tar")
    (File.exists?("/tmp/airgapped.tar")).should be_true
    resp = `tar -tvf /tmp/airgapped.tar`
    LOGGING.info "Tar Filelist: #{resp}"
    (/repositories\/stable_coredns/).should_not be_nil
  ensure
    `rm /tmp/airgapped.tar`
  end

  it "'.tar_manifest' should create a tar file from a manifest", tags: ["airgap"] do
    # KubectlClient::Apply.file("https://litmuschaos.github.io/litmus/litmus-operator-v1.13.2.yaml")
    AirGap.tar_manifest("https://litmuschaos.github.io/litmus/litmus-operator-v1.13.2.yaml", "/tmp/airgapped.tar")
    (File.exists?("/tmp/airgapped.tar")).should be_true
    resp = `tar -tvf /tmp/airgapped.tar`
    LOGGING.info "Tar Filelist: #{resp}"
    (/litmus-operator-v1.13.2.yaml/).should_not be_nil
  ensure
    `rm /tmp/airgapped.tar`
  end

  it "'#AirGap.check_tar' should determine if a pod has the tar binary on it", tags: ["airgap"] do
    pods = KubectlClient::Get.pods
    resp = AirGap.check_tar(pods.dig?("metadata", "name"))
    resp.should be_false
  end

  it "'#AirGap.check_tar' should determine if the host has the tar binary on it", tags: ["airgap"] do
    pods = KubectlClient::Get.pods_by_nodes(KubectlClient::Get.schedulable_nodes_list)
    pods = KubectlClient::Get.pods_by_label(pods, "name", "cri-tools")
    resp = AirGap.check_tar(pods[0].dig?("metadata", "name"), pod = false)
    LOGGING.debug "Path to tar on the host filesystem: #{resp}"
    resp.should_not be_nil
  end

  it "'#AirGap.check_sh' should determine if a pod has a shell on it", tags: ["airgap"] do
    pods = KubectlClient::Get.pods
    resp = AirGap.check_sh(pods.dig?("metadata", "name"))
    resp.should be_false
  end

  it "'#AirGap.pods_with_tar' should determine if there are any pods with a shell and tar on them", tags: ["airgap"] do
    # TODO Should install cri-tools or container with tar before running spec.
    resp = AirGap.pods_with_tar
    if resp[0].dig?("metadata", "name")
      LOGGING.debug "Pods With Tar Found #{resp[0].dig?("metadata", "name")}"
    end
    (resp[0].dig?("kind")).should eq "Pod"
  end

  it "'#AirGap.pods_with_sh' should determine if there are any pods with a shell on them", tags: ["airgap"] do
    resp = AirGap.pods_with_sh
    (resp[0].dig?("kind")).should eq "Pod"
  end

  it "'#AirGap.pod_images' should retrieve all of the images for the pods with tar", tags: ["airgap"] do
    pods = AirGap.pods_with_tar
    resp = AirGap.pod_images(pods)
    (resp[0]).should_not be_nil
  end

  it "'#AirGap.download_cri_tools' should download the cri tools", tags: ["airgap-tools"] do
    resp = AirGap.download_cri_tools
    (File.exists?("#{TarClient::TAR_BIN_DIR}/crictl-#{AirGap::CRI_VERSION}-linux-amd64.tar.gz")).should be_true
    (File.exists?("#{TarClient::TAR_BIN_DIR}/containerd-#{AirGap::CTR_VERSION}-linux-amd64.tar.gz")).should be_true
  end

  it "'#AirGap.untar_cri_tools' should untar the cri tools", tags: ["airgap-tools"] do
    AirGap.download_cri_tools
    resp = AirGap.untar_cri_tools
    (File.exists?("#{TarClient::TAR_BIN_DIR}/crictl")).should be_true
    (File.exists?("#{TarClient::TAR_BIN_DIR}/ctr")).should be_true
  end

  it "'#AirGap.create_pod_by_image' should install the cri pod in the cluster", tags: ["airgap-tools"] do
    pods = AirGap.pods_with_tar
    if pods.empty?
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./example-cnfs/envoy/cnf-testsuite.yml`
      $?.success?.should be_true
      pods = AirGap.pods_with_tar
    end
    images_with_tar = AirGap.pod_images(pods)
    image = images_with_tar[0]
    LOGGING.info "Image with TAR: #{image}"
    resp = AirGap.create_pod_by_image(image)
    (resp).should be_true
  ensure
    KubectlClient::Delete.command("daemonset cri-tools")
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./example-cnfs/envoy/cnf-testsuite.yml wait_count=0`
  end

  it "'#AirGap.bootstrap_cluster' should install the cri tools in the cluster that has an image with tar avaliable on the node.", tags: ["airgap-tools"] do
    pods = AirGap.pods_with_tar
    if pods.empty?
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./example-cnfs/envoy/cnf-testsuite.yml`
      $?.success?.should be_true
    end
    AirGap.bootstrap_cluster
    pods = KubectlClient::Get.pods_by_nodes(KubectlClient::Get.schedulable_nodes_list)
    pods = KubectlClient::Get.pods_by_label(pods, "name", "cri-tools")
    # Get the generated name of the cri-tools per node
    pods.map do |pod|
      pod_name = pod.dig?("metadata", "name")
      containers = pod.dig("spec", "containers").as_a
      image = containers[0]? && containers[0].dig("image")
      LOGGING.info "CRI Pod Image: #{image}"
      sh = KubectlClient.exec("-ti #{pod_name} -- cat /usr/local/bin/crictl > /dev/null")
      sh[:status].success?
      sh = KubectlClient.exec("-ti #{pod_name} -- cat /usr/local/bin/ctr > /dev/null")
      sh[:status].success?
    end
  ensure
    KubectlClient::Delete.command("daemonset cri-tools")
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./example-cnfs/envoy/cnf-testsuite.yml wait_count=0`
  end

  it "'#AirGap.bootstrap_cluster' should install the cri tools in the cluster that does not have tar in the images", tags: ["airgap-tools"] do
    KubectlClient::Delete.command("daemonset cri-tools")
    pods = AirGap.pods_with_tar
    # Skip the test if tar is available outside of the cri tools
    if pods.empty?
      AirGap.bootstrap_cluster
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
    end
  ensure
    KubectlClient::Delete.command("daemonset cri-tools")
  end
end
