# coding: utf-8
require "sam"
require "file_utils"
require "colorize"
require "totem"
require "../utils/utils.cr"

desc "CNF containers should be isolated from one another and the host.  The CNF Test suite uses tools like Falco, Sysdig Inspect and gVisor"
task "security", ["privileged"] do |_, args|
  stdout_score("security")
end

desc "Check if any containers are running in privileged mode"
task "privileged" do |_, args|
  CNFManager::Task.task_runner(args) do |args, config|
    VERBOSE_LOGGING.info "privileged" if check_verbose(args)
    white_list_container_names = config.cnf_config[:white_list_container_names]
    VERBOSE_LOGGING.info "white_list_container_names #{white_list_container_names.inspect}" if check_verbose(args)
    violation_list = [] of String
    task_response = CNFManager.workload_resource_test(args, config) do |resource, container, initialized|
      privileged_list = KubectlClient::Get.privileged_containers
      white_list_containers = ((PRIVILEGED_WHITELIST_CONTAINERS + white_list_container_names) - [container])
      # Only check the containers that are in the deployed helm chart or manifest
      (privileged_list & ([container.as_h["name"].as_s] - white_list_containers)).each do |x|
        violation_list << x
      end
      if violation_list.size > 0
        false
      else
        true
      end
    end
    LOGGING.debug "violator list: #{violation_list.flatten}"
    emoji_security = "🔓🔑"
    if task_response
      upsert_passed_task("privileged", "✔️  PASSED: No privileged containers #{emoji_security}")
    else
      upsert_failed_task("privileged", "✖️  FAILED: Found #{violation_list.size} privileged containers: #{violation_list.inspect} #{emoji_security}")
    end
  end
end
