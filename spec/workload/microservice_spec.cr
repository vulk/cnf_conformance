require "../spec_helper"
require "colorize"
require "../../src/tasks/utils/utils.cr"
require "../../src/tasks/utils/kubectl_client.cr"
require "../../src/tasks/utils/system_information/helm.cr"
require "../../src/tasks/dockerd_setup.cr"
require "file_utils"
require "sam"

describe "Microservice" do
  it "'reasonable_startup_time' should pass if the cnf has a reasonable startup time(helm_directory)", tags: ["reasonable_startup_time"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_coredns`
      response_s = `./cnf-testsuite reasonable_startup_time verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: CNF had a reasonable startup time/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_coredns`
      $?.success?.should be_true
    end
  end

  it "'reasonable_startup_time' should fail if the cnf doesn't has a reasonable startup time(helm_directory)", tags: ["reasonable_startup_time"] do
    `./cnf-testsuite cnf_setup cnf-config=sample-cnfs/sample_envoy_slow_startup/cnf-testsuite.yml force=true`
    begin
      response_s = `./cnf-testsuite reasonable_startup_time verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: CNF had a startup time of/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=sample-cnfs/sample_envoy_slow_startup/cnf-testsuite.yml force=true`
      $?.success?.should be_true
    end
  end

  it "'reasonable_image_size' should pass if image is smaller than 5gb", tags: ["reasonable_image_size"] do
    if ENV["PROTECTED_DOCKERHUB_USERNAME"]? && ENV["PROTECTED_DOCKERHUB_PASSWORD"]? && ENV["PROTECTED_DOCKERHUB_EMAIL"]?
      cnf = "./sample-cnfs/sample_coredns_protected"
    else
      cnf = "./sample-cnfs/sample-coredns-cnf"
    end
    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
    response_s = `./cnf-testsuite reasonable_image_size verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/Image size is good/ =~ response_s).should_not be_nil
  ensure
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf}`
  end

  it "'reasonable_image_size' should fail if image is larger than 5gb", tags: ["reasonable_image_size"] do
    `./cnf-testsuite cnf_setup cnf-path=./sample-cnfs/sample_envoy_slow_startup wait_count=0`
    response_s = `./cnf-testsuite reasonable_image_size verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/Image size too large/ =~ response_s).should_not be_nil
  ensure
    `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_envoy_slow_startup force=true`
  end

  it "'reasonable_image_size' should skip if dockerd does not install", tags: ["reasonable_image_size"] do
    cnf = "./sample-cnfs/sample-coredns-cnf"
    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
    LOGGING.info `./cnf-testsuite uninstall_dockerd`
    dockerd_tempname_helper

    response_s = `./cnf-testsuite reasonable_image_size verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/SKIPPED: Skipping reasonable_image_size: Dockerd tool failed to install/ =~ response_s).should_not be_nil
  ensure
    LOGGING.info "reasonable_image_size skipped ensure"
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf}`
    dockerd_name_helper
  end
end
