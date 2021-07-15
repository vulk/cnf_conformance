require "sam"
require "file_utils"
require "colorize"
require "totem"

desc "Cleans up the CNF test suite, the K8s cluster, and upstream projects"
# task "cleanup", ["samples_cleanup", "results_yml_cleanup"] do  |_, args|
task "cleanup", ["samples_cleanup"] do |_, args|
end

desc "Cleans up the CNF Test Suite sample projects"
task "samples_cleanup", ["sample_coredns_cleanup", "cleanup_sample_coredns", "bad_helm_cnf_cleanup", "sample_privileged_cnf_non_whitelisted_cleanup", "sample_privileged_cnf_whitelisted_cleanup", "sample_coredns_bad_liveness_cleanup", "sample_coredns_source_cleanup", "sample_generic_cnf_cleanup"] do |_, args|
  if args.named["force"]? && args.named["force"] == "true"
    force = true
  else
    force = false
  end
  # TODO use all_cnfs_task_runner to clean up all cnfs in the cnfs folder that have a cnf-testsuite yml
  `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-large-cnf`
  `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-bad-helm-deploy-repo`
  `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-bad-helm-repo`
  `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-bad_helm_coredns-cnf`
  `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-coredns-cnf-bad-chart`
  `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_coredns_chart_directory`
  # get rid of lingering coredns pods
  if force
    `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-coredns-cnf force=true`
  end
end

desc "Cleans up the CNF Test Suite helper tools and containers"
task "tools_cleanup", ["helm_local_cleanup", "sonobuoy_cleanup", "uninstall_chaosmesh", "uninstall_litmus", "uninstall_dockerd"] do |_, args|
end

desc "Cleans up the CNF Test Suite sample projects, helper tools, and containers"
task "cleanup_all", ["samples_cleanup", "tools_cleanup"] do |_, args|
end

task "results_yml_cleanup" do |_, args|
  if File.exists?("#{CNFManager::Points::Results.file}")
    rm = `rm #{CNFManager::Points::Results.file}`
    VERBOSE_LOGGING.info rm if check_verbose(args)
  end
end
