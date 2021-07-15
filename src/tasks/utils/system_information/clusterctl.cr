require "file_utils"
require "colorize"
require "totem"

def clusterctl_installation(verbose = false)
  gmsg = "No Global clusterctl version found"
  lmsg = "No Local clusterctl version found"
  gclusterctl = clusterctl_global_response(verbose)
  VERBOSE_LOGGING.info gclusterctl if verbose

  global_clusterctl_version = clusterctl_version(gclusterctl, verbose)

  if !global_clusterctl_version.empty?
    gmsg = "Global clusterctl found. Version: #{global_clusterctl_version}"
    stdout_success gmsg
  else
    stdout_warning gmsg
  end

  lclusterctl = clusterctl_local_response(verbose)
  VERBOSE_LOGGING.info lclusterctl if verbose

  local_clusterctl_version = clusterctl_version(lclusterctl, verbose)

  if !local_clusterctl_version.empty?
    lmsg = "Local clusterctl found. Version: #{local_clusterctl_version}"
    stdout_success lmsg
  else
    stdout_warning lmsg
  end

  # uncomment to fail the installation check
  # global_clusterctl_version = nil
  # local_clusterctl_version = nil
  # gmsg = "No Global clusterctl version found"
  # lmsg = "No Local clusterctl version found"
  if global_clusterctl_version.empty? && local_clusterctl_version.empty?
    stdout_failure "clusterctl not found"
    stdout_failure %Q(
    Linux installation instructions for clusterctl can be found here: https://cluster-api.sigs.k8s.io/user/quick-start.html#install-clusterctl

    Install clusterctl binary with curl on Linux
    Download the latest release with the command:

      curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.9/clusterctl-linux-amd64 -o clusterctl

    Make the clusterctl binary executable.

      chmod +x ./clusterctl
    Move the binary in to your PATH.

      sudo mv ./clusterctl /usr/local/bin/clusterctl
    Test to ensure the version you installed is up-to-date:

      clusterctl version
    )
  end
  "#{lmsg} #{gmsg}"
end

def clusterctl_global_response(verbose = false)
  # i think we can safely ignore  clusterctl version: unable to write version state file: https://github.com/kubernetes-sigs/cluster-api/pull/3575
  clusterctl_response = `clusterctl version`
  VERBOSE_LOGGING.info clusterctl_response if verbose
  clusterctl_response
end

def clusterctl_local_response(verbose = false)
  current_dir = FileUtils.pwd
  VERBOSE_LOGGING.info current_dir if verbose
  clusterctl = "#{current_dir}/#{TOOLS_DIR}/clusterctl/linux-amd64/clusterctl"
  # clusterctl_response = `#{clusterctl} version`
  status = Process.run("#{clusterctl} version", shell: true, output: clusterctl_response = IO::Memory.new, error: stderr = IO::Memory.new)

  VERBOSE_LOGGING.info clusterctl_response.to_s if verbose
  clusterctl_response.to_s
end

def clusterctl_version(clusterctl_response, verbose = false)
  # example
  # clusterctl version: &version.Info{Major:"0", Minor:"3", GitVersion:"v0.3.9", GitCommit:"e1f67d8ceb1d5b30ef967035f7a0d1b1ee088b37", GitTreeState:"clean", BuildDate:"2020-09-01T02:44:58Z", GoVersion:"go1.13.14", Compiler:"gc", Platform:"linux/amd64"}
  resp = clusterctl_response.match /clusterctl version: &version.Info{(Major:"(([0-9]{1,3})"\, )Minor:"([0-9]{1,3}[+]?)")/
  VERBOSE_LOGGING.info resp if verbose
  if resp
    "#{resp && resp.not_nil![3]}.#{resp && resp.not_nil![4]}"
  else
    ""
  end
end
