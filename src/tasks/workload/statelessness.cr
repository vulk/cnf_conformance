# coding: utf-8
require "sam"
require "file_utils"
require "colorize"
require "totem"
require "../utils/utils.cr"
require "../utils/kubectl_client.cr"

desc "The CNF test suite checks if state is stored in a custom resource definition or a separate database (e.g. etcd) rather than requiring local storage.  It also checks to see if state is resilient to node failure"
task "state", ["volume_hostpath_not_found"] do |_, args|
  stdout_score("state")
end

desc "Does the CNF use a non-cloud native data store: hostPath volume"
task "volume_hostpath_not_found" do |_, args|
  CNFManager::Task.task_runner(args) do |args, config|
    VERBOSE_LOGGING.info "volume_hostpath_not_found" if check_verbose(args)
    failed_emoji = "(ভ_ভ) ރ 💾"
    passed_emoji = "🖥️  💾"
    LOGGING.debug "cnf_config: #{config}"
    destination_cnf_dir = config.cnf_config[:destination_cnf_dir]
    task_response = CNFManager.cnf_workload_resources(args, config) do |resource|
      hostPath_found = nil
      begin
        # TODO check to see if volume is actually mounted.  Check to see if mount (without volume) has host path as well
        volumes = resource.dig?("spec", "template", "spec", "volumes")
        if volumes
          hostPath_not_found = volumes.as_a.none? do |volume|
            if volume.as_h["hostPath"]?
              true
            end
          end
        else
          hostPath_not_found = true
        end
      rescue ex
        VERBOSE_LOGGING.error ex.message if check_verbose(args)
        puts "Rescued: On resource #{resource["metadata"]["name"]?} of kind #{resource["kind"]}, volumes not found. #{passed_emoji}".colorize(:yellow)
        hostPath_not_found = true
      end
      hostPath_not_found
    end

    if task_response.any?(false)
      upsert_failed_task("volume_hostpath_not_found", "✖️  FAILED: hostPath volumes found #{failed_emoji}")
    else
      upsert_passed_task("volume_hostpath_not_found", "✔️  PASSED: hostPath volumes not found #{passed_emoji}")
    end
  end
end

desc "Does the CNF use a non-cloud native data store: local volumes on the node?"
task "no_local_volume_configuration" do |_, args|
  failed_emoji = "(ভ_ভ) ރ 💾"
  passed_emoji = "🖥️  💾"
  CNFManager::Task.task_runner(args) do |args, config|
    VERBOSE_LOGGING.info "no_local_volume_configuration" if check_verbose(args)

    destination_cnf_dir = config.cnf_config[:destination_cnf_dir]
    task_response = CNFManager.cnf_workload_resources(args, config) do |resource|
      hostPath_found = nil
      begin
        # Note: A storageClassName value of "local-storage" is insufficient to determine if the
        # persistent volume is indeed local storage.  This is because the storageClass can be redefined
        # to be anything (e.g. the name local-storage can be redefined to be block storage behind the scenes)

        volumes = [] of YAML::Any
        if resource["spec"].as_h["template"].as_h["spec"].as_h["volumes"]?
          volumes = resource["spec"].as_h["template"].as_h["spec"].as_h["volumes"].as_a
        end
        LOGGING.debug "volumes: #{volumes}"
        persistent_volume_claim_names = volumes.map do |volume|
          # get persistent volume claim that matches persistent volume claim name
          if volume.as_h["persistentVolumeClaim"]? && volume.as_h["persistentVolumeClaim"].as_h["claimName"]?
            volume.as_h["persistentVolumeClaim"].as_h["claimName"]
          else
            nil
          end
        end.compact
        LOGGING.debug "persistent volume claim names: #{persistent_volume_claim_names}"

        # TODO (optional) check storage class of persistent volume claim
        # loop through all pvc names
        # get persistent volume that matches pvc name
        # get all items, get spec, get claimRef, get pvc name that matches pvc name
        local_storage_not_found = true
        persistent_volume_claim_names.map do |claim_name|
          items = KubectlClient::Get.pv_items_by_claim_name(claim_name)
          items.map do |item|
            begin
              if item["spec"]["local"]? && item["spec"]["local"]["path"]?
                local_storage_not_found = false
              end
            rescue ex
              LOGGING.info ex.message
              local_storage_not_found = true
            end
          end
        end
      rescue ex
        VERBOSE_LOGGING.error ex.message if check_verbose(args)
        puts "Rescued: On resource #{resource["metadata"]["name"]?} of kind #{resource["kind"]}, local storage configuration volumes not found #{passed_emoji}".colorize(:yellow)
        local_storage_not_found = true
      end
      local_storage_not_found
    end

    if task_response.any?(false)
      upsert_failed_task("no_local_volume_configuration", "✖️  FAILED: local storage configuration volumes found #{failed_emoji}")
    else
      upsert_passed_task("no_local_volume_configuration", "✔️  PASSED: local storage configuration volumes not found #{passed_emoji}")
    end
  end
end
