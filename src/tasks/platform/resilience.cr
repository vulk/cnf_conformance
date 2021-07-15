# coding: utf-8
require "sam"
require "colorize"
require "../utils/utils.cr"

namespace "platform" do
  desc "The CNF test suite checks to see if the CNFs are resilient to failures."
  task "resilience", ["worker_reboot_recovery"] do |t, args|
    VERBOSE_LOGGING.info "resilience" if check_verbose(args)
    VERBOSE_LOGGING.debug "resilience args.raw: #{args.raw}" if check_verbose(args)
    VERBOSE_LOGGING.debug "resilience args.named: #{args.named}" if check_verbose(args)
    stdout_score("platform:resilience")
  end

  desc "Does the Platform recover the node and reschedule pods when a worker node fails"
  task "worker_reboot_recovery" do |_, args|
    unless check_destructive(args)
      LOGGING.info "skipping node_failure: not in destructive mode"
      puts "SKIPPED: Node Failure".colorize(:yellow)
      next
    end
    LOGGING.info "Running POC in destructive mode!"
    task_response = CNFManager::Task.task_runner(args) do |args|
      current_dir = FileUtils.pwd
      helm = CNFSingleton.helm

      # Select the first node that isn't a master and is also schedulable
      worker_nodes = `kubectl get nodes --selector='!node-role.kubernetes.io/master' -o 'go-template={{range .items}}{{$taints:=""}}{{range .spec.taints}}{{if eq .effect "NoSchedule"}}{{$taints = print $taints .key ","}}{{end}}{{end}}{{if not $taints}}{{.metadata.name}}{{ "\\n"}}{{end}}{{end}}'`
      worker_node = worker_nodes.split("\n")[0]

      File.write("node_failure_values.yml", NODE_FAILED_VALUES)
      install_coredns = `#{helm} install node-failure -f ./node_failure_values.yml --set nodeSelector."kubernetes\\.io/hostname"=#{worker_node} stable/coredns`
      KubectlClient::Get.wait_for_install("node-failure-coredns")

      File.write("reboot_daemon_pod.yml", REBOOT_DAEMON)
      install_reboot_daemon = `kubectl create -f reboot_daemon_pod.yml`
      KubectlClient::Get.wait_for_install("node-failure-coredns")

      pod_ready = ""
      pod_ready_timeout = 45
      begin
        until (pod_ready == "true" || pod_ready_timeout == 0)
          pod_ready = KubectlClient::Get.pod_status("reboot", "--field-selector spec.nodeName=#{worker_node}").split(",")[2]
          pod_ready_timeout = pod_ready_timeout - 1
          if pod_ready_timeout == 0
            upsert_failed_task("worker_reboot_recovery", "✖️  FAILED: Failed to install reboot daemon")
            exit 1
          end
          sleep 1
          puts "Waiting for reboot daemon to be ready"
          puts "Reboot Daemon Ready Status: #{pod_ready}"
        end

        # Find Reboot Daemon name
        reboot_daemon_pod = KubectlClient::Get.pod_status("reboot", "--field-selector spec.nodeName=#{worker_node}").split(",")[0]
        start_reboot = `kubectl exec -ti #{reboot_daemon_pod} touch /tmp/reboot`

        # Watch for Node Failure.
        pod_ready = ""
        node_ready = ""
        node_failure_timeout = 30
        until (pod_ready == "false" || node_ready == "False" || node_ready == "Unknown" || node_failure_timeout == 0)
          pod_ready = KubectlClient::Get.pod_status("node-failure").split(",")[2]
          node_ready = KubectlClient::Get.node_status("#{worker_node}")
          puts "Waiting for Node to go offline"
          puts "Pod Ready Status: #{pod_ready}"
          puts "Node Ready Status: #{node_ready}"
          node_failure_timeout = node_failure_timeout - 1
          if node_failure_timeout == 0
            upsert_failed_task("worker_reboot_recovery", "✖️  FAILED: Node failed to go offline")
            exit 1
          end
          sleep 1
        end

        # Watch for Node to come back online
        pod_ready = ""
        node_ready = ""
        node_online_timeout = 300
        until (pod_ready == "true" && node_ready == "True" || node_online_timeout == 0)
          pod_ready = KubectlClient::Get.pod_status("node-failure", "").split(",")[2]
          node_ready = KubectlClient::Get.node_status("#{worker_node}")
          puts "Waiting for Node to come back online"
          puts "Pod Ready Status: #{pod_ready}"
          puts "Node Ready Status: #{node_ready}"
          node_online_timeout = node_online_timeout - 1
          if node_online_timeout == 0
            upsert_failed_task("worker_reboot_recovery", "✖️  FAILED: Node failed to come back online")
            exit 1
          end
          sleep 1
        end

        emoji_worker_reboot_recovery = ""
        resp = upsert_passed_task("worker_reboot_recovery", "✔️  PASSED: Node came back online #{emoji_worker_reboot_recovery}")
      ensure
        LOGGING.info "node_failure cleanup"
        delete_reboot_daemon = `kubectl delete -f reboot_daemon_pod.yml`
        delete_coredns = `#{helm} delete node-failure`
        File.delete("reboot_daemon_pod.yml")
        File.delete("node_failure_values.yml")
      end
    end
  end
end
