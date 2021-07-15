require "sam"
require "file_utils"
require "colorize"
require "totem"
require "./utils/utils.cr"
require "./utils/tar.cr"

CHAOS_MESH_VERSION     = "v0.8.0"
CHAOS_MESH_OFFLINE_DIR = "#{TarClient::TAR_REPOSITORY_DIR}/chaos-mesh_chaos-mesh"

desc "Install Chaos Mesh"
task "install_chaosmesh" do |_, args|
  VERBOSE_LOGGING.info "install_chaosmesh" if check_verbose(args)
  current_dir = FileUtils.pwd
  helm = CNFSingleton.helm
  # KubectlClient::Apply.file("https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/#{CHAOS_MESH_VERSION}/manifests/crd.yaml")

  if args.named["offline"]?
    LOGGING.info "install chaos mesh offline mode"
    helm_chart = Dir.entries(CHAOS_MESH_OFFLINE_DIR).first
    Helm.install("my-chaos-mesh #{CHAOS_MESH_OFFLINE_DIR}/#{helm_chart} --version 0.5.1")
  else
    # `helm repo add chaos-mesh https://charts.chaos-mesh.org`
    # `helm install my-chaos-mesh chaos-mesh/chaos-mesh --version 0.5.1`
    Helm.helm_repo_add("chaos-mesh", "https://charts.chaos-mesh.org")
    Helm.install("my-chaos-mesh chaos-mesh/chaos-mesh --version 0.5.1")
  end
  # unless Dir.exists?("#{current_dir}/#{TOOLS_DIR}/chaos_mesh")
  #   status = Process.run("git clone https://github.com/chaos-mesh/chaos-mesh.git #{current_dir}/#{TOOLS_DIR}/chaos_mesh  > /dev/null 2>&1",
  #                        shell: true,
  #                        input: input = Process::Redirect::Close,
  #                        output: output = Process::Redirect::Close,
  #                        error: stderr = Process::Redirect::Close)
  #   LOGGING.info "KubectlClient.apply output: #{output.to_s}"
  #   LOGGING.info "KubectlClient.apply stderr: #{stderr.to_s}"
  #   checkout_tag = `cd #{current_dir}/#{TOOLS_DIR}/chaos_mesh && git checkout tags/#{CHAOS_MESH_VERSION} > /dev/null 2>&1 && cd -`
  # end
  # #TODO use helm wrapper
  # install_chaos_mesh = `#{helm} install chaos-mesh #{current_dir}/#{TOOLS_DIR}/chaos_mesh/helm/chaos-mesh --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock > /dev/null 2>&1`
  File.write("chaos_network_loss.yml", CHAOS_NETWORK_LOSS)
  File.write("chaos_cpu_hog.yml", CHAOS_CPU_HOG)
  File.write("chaos_container_kill.yml", CHAOS_CONTAINER_KILL)
  ChaosMeshSetup.wait_for_resource("chaos_network_loss.yml")
  ChaosMeshSetup.wait_for_resource("chaos_cpu_hog.yml")
  ChaosMeshSetup.wait_for_resource("chaos_container_kill.yml")
end

desc "Uninstall Chaos Mesh"
task "uninstall_chaosmesh" do |_, args|
  VERBOSE_LOGGING.info "uninstall_chaosmesh" if check_verbose(args)
  current_dir = FileUtils.pwd
  helm = CNFSingleton.helm
  # crd_delete = `kubectl delete -f https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/#{CHAOS_MESH_VERSION}/manifests/crd.yaml`
  #   KubectlClient::Delete.file("https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/#{CHAOS_MESH_VERSION}/manifests/crd.yaml")
  # FileUtils.rm_rf("#{current_dir}/#{TOOLS_DIR}/chaos_mesh")
  delete_chaos_mesh = `#{helm} delete my-chaos-mesh > /dev/null 2>&1`
end

module ChaosMeshSetup
  def self.wait_for_test(test_type, test_name)
    second_count = 0
    wait_count = 60
    status = ""
    until (status.empty? != true && status == "Finished") || second_count > wait_count.to_i
      LOGGING.debug "second_count = #{second_count}"
      sleep 1
      LOGGING.info "kubectl get #{test_type} #{test_name} -o json"
      status = Process.run("kubectl get #{test_type} #{test_name} -o json ",
        shell: true,
        output: output = IO::Memory.new,
        error: stderr = IO::Memory.new)
      LOGGING.info "KubectlClient.exec output: #{output.to_s}"
      LOGGING.info "KubectlClient.exec stderr: #{stderr.to_s}"
      get_status = output.to_s
      if get_status && !get_status.empty?
        status_data = JSON.parse(get_status)
      else
        status_data = JSON.parse(%({}))
      end
      LOGGING.info "Status: #{get_status}"
      status = status_data.dig?("status", "experiment", "phase").to_s
      second_count = second_count + 1
      LOGGING.info "#{get_status}"
      LOGGING.info "#{second_count}"
    end
    # Did chaos mesh finish the test successfully
    # (status.empty? !=true && status == "Finished")
    true
  end

  # TODO make generate without delete?
  def self.wait_for_resource(resource_file)
    second_count = 0
    wait_count = 60
    is_resource_created = nil
    until (is_resource_created.nil? != true && is_resource_created == true) || second_count > wait_count.to_i
      LOGGING.info "second_count = #{second_count}"
      sleep 3
      `kubectl create -f #{resource_file} 2>&1 >/dev/null`
      is_resource_created = $?.success?
      LOGGING.info "Waiting for CRD"
      LOGGING.info "Status: #{is_resource_created}"
      LOGGING.debug "resource file: #{resource_file}"
      second_count = second_count + 1
    end
    `kubectl delete -f #{resource_file}`
  end
end
