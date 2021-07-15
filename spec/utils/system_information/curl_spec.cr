require "../../spec_helper"
require "colorize"
require "../../../src/tasks/utils/utils.cr"
require "../../../src/tasks/prereqs.cr"
require "../../../src/tasks/utils/system_information/curl.cr"
require "file_utils"
require "sam"

describe "Curl" do
  it "'curl_global_response()' should return the information about the curl installation", tags: ["curl"] do
    (curl_global_response(true)).should contain("curl")
  end

  it "'curl_local_response()' should return the information about the curl installation", tags: ["curl"] do
    (curl_local_response(true)).should eq("")
  end

  it "'curl_version()' should return the information about the curl version", tags: ["curl"] do
    (curl_version(curl_global_response)).should match(/(([0-9]{1,3}[\.]){1,2}[0-9]{1,3})/)
    (curl_version(curl_local_response)).should contain("")
  end

  it "'curl_installations()' should return the information about the curl installation", tags: ["curl"] do
    (curl_installation(true)).should contain("curl found")
  end
end
