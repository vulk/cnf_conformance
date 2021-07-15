# coding: utf-8
require "./spec_helper"
require "colorize"
require "../src/tasks/utils/utils.cr"
require "file_utils"
require "sam"

describe "CurlInstall" do
  after_all do
    LOGGING.info "Curl install tests finished.  Building ./cnf-testsuite again".colorize(:green)
    `crystal build src/cnf-testsuite.cr`
    if $?.success?
      LOGGING.info "Build Success!".colorize(:green)
    else
      LOGGING.info "crystal build failed!".colorize(:red)
      raise "crystal build failed! curl_install_spec.cr"
    end
  end
  it "'source curl_install.sh' should download a cnf-testsuite binary", tags: ["curl"] do
    response_s = `/bin/bash -c "source ./curl_install.sh"`
    LOGGING.info response_s
    $?.success?.should be_true
    (/cnf-testsuite/ =~ response_s).should_not be_nil
  end
  it "'curl_install.sh' should download a cnf-testsuite binary", tags: ["curl"] do
    response_s = `./curl_install.sh`
    LOGGING.info response_s
    $?.success?.should be_true
    (/To use the cnf-testsuite please restart you terminal session to load the new PATH/ =~ response_s).should_not be_nil
  end
end
