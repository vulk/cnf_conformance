require "../spec_helper"
require "../../src/tasks/utils/utils.cr"
require "colorize"

describe "CNF Test Suite all Network Chaos" do
  # before_all do
  #   `./cnf-testsuite setup`
  #   $?.success?.should be_true
  # end

  # after_all do
  #   `./cnf-testsuite samples_cleanup`
  #   $?.success?.should be_true
  # end

  # it "'all' should run the whole test suite" do
  # `./cnf-testsuite samples_cleanup`

  # response_s = `./cnf-testsuite all ~platform ~compatibilty ~state ~security ~scalability ~configuration_lifecycle ~observability ~installability ~hardware_and_scheduling ~microservice ~chaos_cpu_hog ~chaos_container_kill cnf-config=./sample-cnfs/k8s-multiple-deployments/cnf-testsuite.yml deploy_with_chart=false verbose`
  #   response_s = `./cnf-testsuite all ~platform ~compatibilty ~state ~security ~scalability ~configuration_lifecycle ~observability ~installability ~hardware_and_scheduling ~microservice ~chaos_network_loss ~chaos_cpu_hog ~chaos_container_kill cnf-config=./sample-cnfs/k8s-multiple-deployments/cnf-testsuite.yml deploy_with_chart=false verbose`
  #   LOGGING.info response_s
  #   (/Final workload score:/ =~ response_s).should_not be_nil
  #   (/Final score:/ =~ response_s).should_not be_nil
  #   (CNFManager::Points.all_result_test_names(CNFManager.final_cnf_results_yml)).should eq([ "chaos_network_loss"])
  #   $?.success?.should be_true
  # ensure
  #   LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/k8s-multiple-deployments/cnf-testsuite.yml deploy_with_chart=false `

  # end
end
