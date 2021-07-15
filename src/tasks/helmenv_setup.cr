require "sam"
require "file_utils"
require "colorize"
require "totem"
require "./utils/utils.cr"
require "http/client"

desc "Sets up helm 3.1.1"
task "helm_local_install", ["cnf_directory_setup"] do |_, args|
  VERBOSE_LOGGING.info "helm_local_install" if check_verbose(args)
  # check if helm is installed
  # if proper version of helm installed, don't install
  unless global_helm_installed?
    current_dir = FileUtils.pwd
    VERBOSE_LOGGING.debug current_dir if check_verbose(args)
    unless Dir.exists?("#{current_dir}/#{TOOLS_DIR}/helm")
      begin
        VERBOSE_LOGGING.debug "pwd? : #{current_dir}" if check_verbose(args)
        VERBOSE_LOGGING.debug "toolsdir : #{TOOLS_DIR}" if check_verbose(args)
        VERBOSE_LOGGING.debug "full path?: #{current_dir.to_s}/#{TOOLS_DIR}/helm" if check_verbose(args)
        FileUtils.mkdir_p("#{current_dir}/#{TOOLS_DIR}/helm")
        HTTP::Client.get("https://get.helm.sh/helm-v3.1.1-linux-amd64.tar.gz") do |response|
          File.write("#{current_dir}/#{TOOLS_DIR}/helm/helm-v3.1.1-linux-amd64.tar.gz", response.body_io)
        end
        tar = `cd #{current_dir}/#{TOOLS_DIR}/helm; tar -xvf #{current_dir}/#{TOOLS_DIR}/helm/helm-v3.1.1-linux-amd64.tar.gz`
        VERBOSE_LOGGING.debug tar if check_verbose(args)
        helm = CNFSingleton.helm
        VERBOSE_LOGGING.debug helm if check_verbose(args)
        VERBOSE_LOGGING.debug `#{helm} version` if check_verbose(args)
        # TODO what is this for?
        stable_repo = `#{helm} repo add stable https://cncf.gitlab.io/stable`
        VERBOSE_LOGGING.debug stable_repo if check_verbose(args)

        # TODO grep for specific version e.g. version.BuildInfo{Version:"v3.1.1", GitCommit:"afe70585407b420d0097d07b21c47dc511525ac8", GitTreeState:"clean", GoVersion:"go1.13.8"}
      ensure
        cd = `cd #{current_dir}`
        VERBOSE_LOGGING.debug cd if check_verbose(args)
      end
    end
  end
  # `#{CNFSingleton.helm} repo add stable https://cncf.gitlab.io/stable`
end

desc "Cleans up helm 3.1.1"
task "helm_local_cleanup" do |_, args|
  VERBOSE_LOGGING.info "helm_local_cleanup" if check_verbose(args)
  current_dir = FileUtils.pwd
  rm = `rm -rf #{current_dir}/#{TOOLS_DIR}/helm`
  VERBOSE_LOGGING.debug rm if check_verbose(args)
end
