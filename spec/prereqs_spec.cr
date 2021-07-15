require "./spec_helper"
require "colorize"
require "../src/tasks/utils/utils.cr"
require "../src/tasks/utils/system_information/helm.cr"
require "file_utils"
require "sam"

describe "Prereq" do
  it "'prereq' should check the system for prerequisites", tags: ["points"] do
    response_s = `./cnf-testsuite prereqs verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/helm found/ =~ response_s).should_not be_nil
    # (/wget found/ =~ response_s).should_not be_nil
    # (/curl found/ =~ response_s).should_not be_nil
    (/kubectl found/ =~ response_s).should_not be_nil
    (/git found/ =~ response_s).should_not be_nil
  end

  it "'prereq' with offline option should check the system for prerequisites except git", tags: ["points"] do
    response_s = `./cnf-testsuite prereqs verbose offline=1`
    LOGGING.info response_s
    $?.success?.should be_true
    (/helm found/ =~ response_s).should_not be_nil
    # (/wget found/ =~ response_s).should_not be_nil
    # (/curl found/ =~ response_s).should_not be_nil
    (/kubectl found/ =~ response_s).should_not be_nil
    (/git found/ =~ response_s).should be_nil
  end
end
