# coding: utf-8
require "sam"
require "colorize"
require "../utils/utils.cr"

namespace "platform" do
  desc "The CNF container should access all hardware and schedule to specific worker nodes by using a device plugin."
  task "hardware_and_scheduling", ["oci_compliant"] do |t, args|
    VERBOSE_LOGGING.info "hardware_and_scheduling" if check_verbose(args)
    VERBOSE_LOGGING.debug "hardware_and_scheduling args.raw: #{args.raw}" if check_verbose(args)
    VERBOSE_LOGGING.debug "hardware_and_scheduling args.named: #{args.named}" if check_verbose(args)
    stdout_score("platform:hardware_and_scheduling")
  end

  desc "Does the Platform use a runtime that is oci compliant"
  task "oci_compliant" do |_, args|
    task_response = CNFManager::Task.task_runner(args) do |args|
      resp = KubectlClient::Get.container_runtimes
      all_oci_runtimes = true
      resp.each do |x|
        if (x =~ KubectlClient::OCI_RUNTIME_REGEX).nil?
          all_oci_runtimes = false
        end
      end
      LOGGING.info "all_oci_runtimes: #{all_oci_runtimes}"
      if all_oci_runtimes
        emoji_chaos_oci_compliant = "📶☠️"
        upsert_passed_task("oci_compliant", "✔️  PASSED: Your platform is using the following runtimes: [#{KubectlClient::Get.container_runtimes.join(",")}] which are OCI compliant runtimes #{emoji_chaos_oci_compliant}")
      else
        emoji_chaos_oci_compliant = "📶☠️"
        upsert_failed_task("oci_compliant", "✖️  FAILED: Platform has at least one node that uses a non OCI compliant runtime #{emoji_chaos_oci_compliant}")
      end
    end
  end
end
