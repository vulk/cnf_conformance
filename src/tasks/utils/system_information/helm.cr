require "file_utils"
require "colorize"
require "totem"

# TODO put this in a module
def helm_installation(verbose = false)
  gmsg = "No Global helm version found"
  lmsg = "No Local helm version found"
  ghelm = helm_global_response
  VERBOSE_LOGGING.info ghelm if verbose

  global_helm_version = helm_version(ghelm, verbose)

  if global_helm_version && !global_helm_version.empty?
    gmsg = "Global helm found. Version: #{global_helm_version}"
    stdout_success gmsg
  else
    stdout_warning gmsg
  end

  lhelm = helm_local_response
  VERBOSE_LOGGING.info lhelm if verbose

  local_helm_version = helm_version(lhelm, verbose)

  if local_helm_version && !local_helm_version.empty?
    lmsg = "Local helm found. Version: #{local_helm_version}"
    stdout_success lmsg
  else
    stdout_warning lmsg
  end

  if global_helm_version.empty? && local_helm_version.empty?
    stdout_failure "Helm not found"
    stdout_failure %Q(
    Installation instructions for Helm can be found here: https://helm.sh/docs/intro/install

    To install helm on Linux use:
    sudo snap install helm --classic
    )
  end
  "#{lmsg} #{gmsg}"
end

def helm_global_response(verbose = false)
  helm_response = `helm version 2>/dev/null`
  VERBOSE_LOGGING.info helm_response if verbose
  helm_response
end

def helm_local_response(verbose = false)
  current_dir = FileUtils.pwd
  VERBOSE_LOGGING.info current_dir if verbose
  # helm = "#{current_dir}/#{TOOLS_DIR}/helm/linux-amd64/helm"
  helm = CNFSingleton.helm
  # helm_response = `#{helm} version`
  status = Process.run("#{helm} version", shell: true, output: helm_response = IO::Memory.new, error: stderr = IO::Memory.new)
  VERBOSE_LOGGING.info helm_response.to_s if verbose
  helm_response.to_s
end

def helm_version(helm_response, verbose = false)
  resp = "#{helm_v2_version(helm_response) || helm_v3_version(helm_response)}"
  VERBOSE_LOGGING.info resp if verbose
  resp
end

def helm_v2_version(helm_response)
  # example
  # Client: &version.Version{SemVer:\"v2.14.3\", GitCommit:\"0e7f3b6637f7af8fcfddb3d2941fcc7cbebb0085\", GitTreeState:\"clean\"}\nServer: &version.Version{SemVer:\"v2.16.1\", GitCommit:\"bbdfe5e7803a12bbdf97e94cd847859890cf4050\", GitTreeState:\"clean\"}
  helm_v2 = helm_response.match /Client: &version.Version{SemVer:\"(v([0-9]{1,3}[\.]){1,2}[0-9]{1,3}).+"/
  LOGGING.debug "helm_v2?: #{helm_v2}"
  helm_v2 && helm_v2.not_nil![1]
end

def helm_v3_version(helm_response)
  # example
  # version.BuildInfo{Version:"v3.1.1", GitCommit:"afe70585407b420d0097d07b21c47dc511525ac8", GitTreeState:"clean", GoVersion:"go1.13.8"}
  helm_v3 = helm_response.match /BuildInfo{Version:\"(v([0-9]{1,3}[\.]){1,2}[0-9]{1,3}).+"/
  LOGGING.debug "helm_v3?: #{helm_v3}"
  helm_v3 && helm_v3.not_nil![1]
end

# TODO Get global response for helm
# TODO Get version number of global response for helm
# TODO If version of helm not 3 or greater, act as if helm is not installed
# TODO If version of helm is 3, return helm installed

def global_helm_installed?
  ghelm = helm_global_response
  global_helm_version = helm_v3_version(ghelm)
  if (global_helm_version)
    true
  else
    false
  end
end

def local_helm_installed?
  lhelm = helm_local_response
  local_helm_version = helm_version(lhelm)
  if (local_helm_version)
    true
  else
    false
  end
end
