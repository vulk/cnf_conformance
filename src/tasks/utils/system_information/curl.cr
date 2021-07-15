require "file_utils"
require "colorize"
require "totem"

def curl_installation(verbose = false)
  gmsg = "No Global curl version found"
  lmsg = "No Local curl version found"
  gcurl = curl_global_response
  VERBOSE_LOGGING.info gcurl if verbose

  global_curl_version = curl_version(gcurl, verbose)

  if !global_curl_version.empty?
    gmsg = "Global curl found. Version: #{global_curl_version}"
    stdout_success gmsg
  else
    stdout_warning gmsg
  end

  lcurl = curl_local_response
  VERBOSE_LOGGING.info lcurl if verbose

  local_curl_version = curl_version(lcurl, verbose)

  if !local_curl_version.empty?
    lmsg = "Local curl found. Version: #{local_curl_version}"
    stdout_success lmsg
  else
    stdout_warning lmsg
  end

  if global_curl_version.empty? && local_curl_version.empty?
    stdout_failure "Curl not found"
    stdout_failure %Q(
    Linux installation instructions for Curl can be found here: https://www.tecmint.com/install-curl-in-linux/
    )
  end
  "#{lmsg} #{gmsg}"
end

def curl_global_response(verbose = false)
  curl_response = `curl --version`
  VERBOSE_LOGGING.info curl_response if verbose
  curl_response
end

def curl_local_response(verbose = false)
  current_dir = FileUtils.pwd
  VERBOSE_LOGGING.info current_dir if verbose
  curl = "#{current_dir}/#{TOOLS_DIR}/curl/linux-amd64/curl"
  # curl_response = `#{curl} --version`
  status = Process.run("#{curl} --version", shell: true, output: curl_response = IO::Memory.new, error: stderr = IO::Memory.new)
  VERBOSE_LOGGING.info curl_response.to_s if verbose
  curl_response.to_s
end

def curl_version(curl_response, verbose = false)
  # example
  # GNU Curl 1.15 built on linux-gnu.
  resp = curl_response.match /curl (([0-9]{1,3}[\.]){1,2}[0-9]{1,3})/
  VERBOSE_LOGGING.info resp if verbose
  "#{resp && resp.not_nil![1]}"
end
