require "./../spec_helper"
require "colorize"
require "./../../src/tasks/utils/utils.cr"

describe "Platform" do
  before_all do
    `./cnf-testsuite setup`
    $?.success?.should be_true
  end
  it "'worker_reboot_recovery' should pass if platform successfully recovers after reboot", tags: ["platform:worker_reboot_recovery"] do
    if check_destructive
      puts "Tests running in destructive mode".colorize(:red)
      response_s = `./cnf-testsuite platform:worker_reboot_recovery destructive`
      LOGGING.info response_s
      (/(PASSED: Node came back online)/ =~ response_s).should_not be_nil
    else
      response_s = `./cnf-testsuite platform:worker_reboot_recovery`
      LOGGING.info response_s
      (/SKIPPED/ =~ response_s).should_not be_nil
    end
  end
end
