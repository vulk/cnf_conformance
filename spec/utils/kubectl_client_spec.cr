require "../spec_helper"
require "../../src/tasks/utils/utils.cr"
require "../../src/tasks/dockerd_setup.cr"
require "../../src/tasks/utils/kubectl_client.cr"
require "file_utils"
require "sam"

describe "KubectlClient" do
  # after_all do
  # end

  it "'#KubectlClient.pods_by_node' should return all pods on a specific node", tags: ["kubectl-nodes"] do
    pods = KubectlClient::Get.pods_by_nodes(KubectlClient::Get.schedulable_nodes_list)
    (pods).should_not be_nil
    if pods && pods[0] != Nil
      (pods.size).should be > 0
      first_node = pods[0]
      if first_node
        (first_node.dig("kind")).should eq "Pod"
      else
        true.should be_false
      end
    else
      true.should be_false
    end
  end

  it "'#KubectlClient.pods_by_label' should return all pods on a specific node", tags: ["kubectl-nodes"] do
    AirGap.bootstrap_cluster
    pods = KubectlClient::Get.pods_by_nodes(KubectlClient::Get.schedulable_nodes_list)
    (pods).should_not be_nil
    pods = KubectlClient::Get.pods_by_label(pods, "name", "cri-tools")
    (pods).should_not be_nil
    if pods && pods[0]? != Nil
      (pods.size).should be > 0
      first_node = pods[0]
      if first_node
        (first_node.dig("kind")).should eq "Pod"
      else
        true.should be_false
      end
    else
      true.should be_false
    end
  end

  it "'#KubectlClient.schedulable_nodes_list' should return all schedulable worker nodes", tags: ["kubectl-nodes"] do
    retry_limit = 50
    retries = 1
    empty_json_any = JSON.parse(%({}))
    nodes = [empty_json_any]
    until (nodes != [empty_json_any]) || retries > retry_limit
      LOGGING.info "schedulable_node retry: #{retries}"
      sleep 1.0
      nodes = KubectlClient::Get.schedulable_nodes_list
      retries = retries + 1
    end
    LOGGING.info "schedulable_node node: #{nodes}"
    (nodes).should_not be_nil
    if nodes && nodes[0] != Nil
      (nodes.size).should be > 0
      first_node = nodes[0]
      if first_node
        (first_node.dig("kind")).should eq "Node"
      else
        true.should be_false
      end
    else
      true.should be_false
    end
  end

  it "'#KubectlClient.resource_map' should a subset of manifest resource json", tags: ["kubectl-nodes"] do
    retry_limit = 50
    retries = 1
    empty_json_any = JSON.parse(%({}))
    filtered_nodes = [empty_json_any]
    until (filtered_nodes != [empty_json_any]) || retries > retry_limit
      LOGGING.info "resource_map retry: #{retries}"
      sleep 1.0
      filtered_nodes = KubectlClient::Get.resource_map(KubectlClient::Get.nodes) do |item, metadata|
        taints = item.dig?("spec", "taints")
        LOGGING.debug "taints: #{taints}"
        if (taints && taints.dig?("effect") == "NoSchedule")
          nil
        else
          {:node => item, :name => item.dig?("metadata", "name")}
        end
      end
      retries = retries + 1
    end
    LOGGING.info "spec: resource_map node: #{filtered_nodes}"
    (filtered_nodes).should_not be_nil
    if filtered_nodes
      (filtered_nodes.size).should be > 0
    else
      true.should be_false
    end
  end

  it "'Kubectl::Get.wait_for_install' should wait for a cnf to be installed", tags: ["kubectl-install"] do
    LOGGING.debug `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml verbose wait_count=0`

    $?.success?.should be_true

    current_dir = FileUtils.pwd
    LOGGING.info current_dir
    # helm = "#{current_dir}/#{TOOLS_DIR}/helm/linux-amd64/helm"
    helm = CNFSingleton.helm
    LOGGING.info helm
    # TODO only need previous install now this helm install
    helm_install = `#{helm} install coredns stable/coredns`
    LOGGING.info helm_install
    KubectlClient::Get.wait_for_install("coredns-coredns")
    current_replicas = `kubectl get deployments coredns-coredns -o=jsonpath='{.status.readyReplicas}'`
    (current_replicas.to_i > 0).should be_true
  end

  it "'Kubectl::Get.resource_wait_for_uninstall' should wait for a cnf to be installed", tags: ["kubectl-install"] do
    LOGGING.debug `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample-statefulset-cnf/cnf-testsuite.yml verbose wait_count=0`

    $?.success?.should be_true

    LOGGING.debug `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample-statefulset-cnf/cnf-testsuite.yml`
    resp = KubectlClient::Get.resource_wait_for_uninstall("deployment", "my-release-wordpress")
    (resp).should be_true
  end

  it "'#KubectlClient.pods_for_resource' should return the pods for a resource", tags: ["kubectl-nodes"] do
    LOGGING.debug `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample-statefulset-cnf/cnf-testsuite.yml verbose wait_count=0`
    json = KubectlClient::Get.pods_for_resource("deployment", "my-release-wordpress")
    # (json["items"].size).should be > 0
  end

  it "'#KubectlClient.get_nodes' should return the information about a node in json", tags: ["kubectl-nodes"] do
    json = KubectlClient::Get.nodes
    (json["items"].size).should be > 0
  end
  it "'#KubectlClient.container_runtime' should return the information about the container runtime", tags: ["kubectl-runtime"] do
    resp = KubectlClient::Get.container_runtime
    (resp.match(KubectlClient::OCI_RUNTIME_REGEX)).should_not be_nil
  end
  it "'#KubectlClient.container_runtimes' should return all container runtimes", tags: ["kubectl-runtime"] do
    resp = KubectlClient::Get.container_runtimes
    (resp[0].match(KubectlClient::OCI_RUNTIME_REGEX)).should_not be_nil
  end

  it "'#KubectlClient.schedulable_nodes' should return all schedulable worker nodes", tags: ["kubectl-nodes"] do
    retry_limit = 50
    retries = 1
    nodes = nil
    until (nodes && nodes.size > 0 && !nodes[0].empty?) || retries > retry_limit
      LOGGING.info "schedulable_node retry: #{retries}"
      sleep 1.0
      nodes = KubectlClient::Get.schedulable_nodes
      retries = retries + 1
    end
    LOGGING.info "schedulable_node node: #{nodes}"
    # resp = KubectlClient::Get.schedulable_nodes
    (nodes).should_not be_nil
    if nodes
      (nodes.size).should be > 0
      (nodes[0]).should_not be_nil
      (nodes[0]).should_not be_empty
    end
  end

  it "'#KubectlClient.containers' should return all containers defined in a deployment", tags: ["kubectl-deployment"] do
    LOGGING.debug `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/k8s-sidecar-container-pattern/cnf-testsuite.yml wait_count=0`
    resp = KubectlClient::Get.deployment_containers("nginx-webapp")
    (resp.size).should be > 0
  ensure
    LOGGING.debug `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/k8s-sidecar-container-pattern/cnf-testsuite.yml deploy_with_chart=false`
  end

  it "'#KubectlClient.pod_exists?' should true if a pod exists", tags: ["kubectl-status"] do
    LOGGING.debug `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample-generic-cnf/cnf-testsuite.yml`
    resp = KubectlClient::Get.pod_exists?("coredns")
    (resp).should be_true
  ensure
    LOGGING.debug `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample-generic-cnf/cnf-testsuite.yml`
  end

  it "'#KubectlClient.pod_status' should return a status of false if the pod is not installed (failed to install) and other pods exist", tags: ["kubectl-status"] do
    cnf = "./sample-cnfs/sample-coredns-cnf"
    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
    LOGGING.info `./cnf-testsuite uninstall_dockerd`

    resp = KubectlClient::Get.pod_status(pod_name_prefix: "dockerd").split(",")[2] # true/false
    LOGGING.info resp
    (resp && !resp.empty? && resp == "true").should be_false
  ensure
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf}`
  end

  it "'#KubectlClient.pod_status' should return a status of true if the pod is installed and other pods exist", tags: ["kubectl-status"] do
    cnf = "./sample-cnfs/sample-coredns-cnf"
    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
    LOGGING.info `./cnf-testsuite install_dockerd`

    resp = KubectlClient::Get.pod_status(pod_name_prefix: "dockerd").split(",")[2] # true/false
    LOGGING.info resp
    (resp && !resp.empty? && resp == "true").should be_true
  ensure
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf}`
  end
end
