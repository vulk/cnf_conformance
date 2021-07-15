require "sam"
require "file_utils"
require "colorize"
require "totem"
require "http/client"
require "halite"
require "./utils/utils.cr"

desc "Sets up Sonobuoy in the K8s Cluster"
task "install_sonobuoy" do |_, args|
  # TODO: Fetch version dynamically
  # k8s_version = HTTP::Client.get("https://storage.googleapis.com/kubernetes-release/release/stable.txt").body.chomp.split(".")[0..1].join(".").gsub("v", "")
  # TODO make k8s_version dynamic
  # TODO use kubectl version and grab the server version
  # k8s_version = "0.19.0"
  VERBOSE_LOGGING.debug SONOBUOY_K8S_VERSION if check_verbose(args)
  current_dir = FileUtils.pwd
  VERBOSE_LOGGING.debug current_dir if check_verbose(args)
  unless Dir.exists?("#{current_dir}/#{TOOLS_DIR}/sonobuoy")
    VERBOSE_LOGGING.debug "pwd? : #{current_dir}" if check_verbose(args)
    VERBOSE_LOGGING.debug "toolsdir : #{TOOLS_DIR}" if check_verbose(args)
    VERBOSE_LOGGING.debug "full path?: #{current_dir.to_s}/#{TOOLS_DIR}/sonobuoy" if check_verbose(args)
    FileUtils.mkdir_p("#{current_dir}/#{TOOLS_DIR}/sonobuoy")
    # curl = `VERSION="#{LITMUS_K8S_VERSION}" OS=linux ; curl -L "https://github.com/vmware-tanzu/sonobuoy/releases/download/v${VERSION}/sonobuoy_${VERSION}_${OS}_amd64.tar.gz" --output #{current_dir}/#{TOOLS_DIR}/sonobuoy/sonobuoy.tar.gz`
    # os="linux"
    if args.named["offline"]?
      LOGGING.info "install sonobuoy offline mode"
      `tar -xzf #{TarClient::TAR_DOWNLOAD_DIR}/sonobuoy.tar.gz -C #{current_dir}/#{TOOLS_DIR}/sonobuoy/ && \
       chmod +x #{current_dir}/#{TOOLS_DIR}/sonobuoy/sonobuoy`
      sonobuoy = "#{current_dir}/#{TOOLS_DIR}/sonobuoy/sonobuoy"
      VERBOSE_LOGGING.debug sonobuoy if check_verbose(args)
      VERBOSE_LOGGING.info `#{sonobuoy} version` if check_verbose(args)
    else
      url = "https://github.com/vmware-tanzu/sonobuoy/releases/download/v#{SONOBUOY_K8S_VERSION}/sonobuoy_#{SONOBUOY_K8S_VERSION}_#{SONOBUOY_OS}_amd64.tar.gz"
      write_file = "#{current_dir}/#{TOOLS_DIR}/sonobuoy/sonobuoy.tar.gz"
      LOGGING.info "url: #{url}"
      LOGGING.info "write_file: #{write_file}"
      resp = Halite.follow.get("#{url}") do |response|
        File.write("#{write_file}", response.body_io)
      end
      LOGGING.info "resp: #{resp}"
      # VERBOSE_LOGGING.debug curl if check_verbose(args)
      `tar -xzf #{current_dir}/#{TOOLS_DIR}/sonobuoy/sonobuoy.tar.gz -C #{current_dir}/#{TOOLS_DIR}/sonobuoy/ && \
       chmod +x #{current_dir}/#{TOOLS_DIR}/sonobuoy/sonobuoy && \
       rm #{current_dir}/#{TOOLS_DIR}/sonobuoy/sonobuoy.tar.gz`
      sonobuoy = "#{current_dir}/#{TOOLS_DIR}/sonobuoy/sonobuoy"
      VERBOSE_LOGGING.debug sonobuoy if check_verbose(args)
      VERBOSE_LOGGING.info `#{sonobuoy} version` if check_verbose(args)
    end
  end
end

desc "Cleans up Sonobuoy"
task "sonobuoy_cleanup" do |_, args|
  current_dir = FileUtils.pwd
  sonobuoy = "#{current_dir}/#{TOOLS_DIR}/sonobuoy/sonobuoy"
  delete = `#{sonobuoy} delete --wait`
  VERBOSE_LOGGING.info delete if check_verbose(args)
  rm = `rm -rf #{current_dir}/#{TOOLS_DIR}/sonobuoy`
  VERBOSE_LOGGING.info rm if check_verbose(args)
end
