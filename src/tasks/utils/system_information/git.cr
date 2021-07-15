require "file_utils"
require "colorize"
require "totem"

def git_installation(verbose = false)
  gmsg = "No Global git version found"
  lmsg = "No Local git version found"
  ggit = git_global_response
  VERBOSE_LOGGING.info ggit if verbose

  global_git_version = git_version(ggit, verbose)

  if !global_git_version.empty?
    gmsg = "Global git found. Version: #{global_git_version}"
    stdout_success gmsg
  else
    stdout_warning gmsg
  end

  lgit = git_local_response
  VERBOSE_LOGGING.info lgit if verbose

  local_git_version = git_version(lgit, verbose)

  if !local_git_version.empty?
    lmsg = "Local git found. Version: #{local_git_version}"
    stdout_success lmsg
  else
    stdout_warning lmsg
  end

  # uncomment to fail the installation check
  # global_git_version = nil
  # local_git_version = nil
  # gmsg = "No Global git version found"
  # lmsg = "No Local git version found"
  if !(global_git_version && local_git_version)
    stdout_failure "Git not found"
    stdout_failure %Q(
    Linux installation instructions for Git can be found here: https://github.com/git-guides/install-git

    Install git binary with curl on Linux

    On Debian/Ubuntu:

    sudo apt-get install git-all

    On Fedora

    sudo dnf install git-all
    )
  end
  "#{lmsg} #{gmsg}"
end

def git_global_response(verbose = false)
  git_response = `git version`
  VERBOSE_LOGGING.info git_response if verbose
  git_response
end

def git_local_response(verbose = false)
  current_dir = FileUtils.pwd
  VERBOSE_LOGGING.info current_dir if verbose
  git = "#{current_dir}/#{TOOLS_DIR}/git/linux-amd64/git"
  # git_response = `#{git} version`
  status = Process.run("#{git} version", shell: true, output: git_response = IO::Memory.new, error: stderr = IO::Memory.new)
  VERBOSE_LOGGING.info git_response.to_s if verbose
  git_response.to_s
end

def git_version(git_response, verbose = false)
  # example
  # git version 1.9.1
  resp = git_response.match /git version (([0-9]{1,3}[\.]){1,2}[0-9]{1,3})/
  VERBOSE_LOGGING.info resp if verbose
  if resp
    "#{resp && resp.not_nil![1]}"
  else
    ""
  end
end
