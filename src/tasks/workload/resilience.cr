# coding: utf-8
require "sam"
require "colorize"
require "crinja"
require "../utils/utils.cr"

desc "The CNF test suite checks to see if the CNFs are resilient to failures."
task "resilience", ["pod_network_latency", "chaos_cpu_hog", "chaos_container_kill", "disk_fill"] do |t, args|
  VERBOSE_LOGGING.info "resilience" if check_verbose(args)
  VERBOSE_LOGGING.debug "resilience args.raw: #{args.raw}" if check_verbose(args)
  VERBOSE_LOGGING.debug "resilience args.named: #{args.named}" if check_verbose(args)
  stdout_score("resilience")
end

desc "Does the CNF crash when network loss occurs"
task "chaos_network_loss", ["install_chaosmesh"] do |_, args|
  CNFManager::Task.task_runner(args) do |args, config|
    VERBOSE_LOGGING.info "chaos_network_loss" if check_verbose(args)
    LOGGING.debug "cnf_config: #{config}"
    emoji_chaos_network_loss = "📶☠️"
    destination_cnf_dir = config.cnf_config[:destination_cnf_dir]
    task_response = CNFManager.workload_resource_test(args, config) do |resource, container, initialized|
      if KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h? &&
         KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.size > 0
        test_passed = true
      else
        puts "No resource label found for container kill test for resource: #{resource}".colorize(:red)
        test_passed = false
      end

      if test_passed
        template = Crinja.render(network_chaos_template, {"labels" => KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h})
        chaos_config = `echo "#{template}" > "#{destination_cnf_dir}/chaos_network_loss.yml"`
        VERBOSE_LOGGING.debug "#{chaos_config}" if check_verbose(args)
        run_chaos = `kubectl create -f "#{destination_cnf_dir}/chaos_network_loss.yml"`
        VERBOSE_LOGGING.debug "#{run_chaos}" if check_verbose(args)
        if ChaosMeshSetup.wait_for_test("NetworkChaos", "network-loss")
          LOGGING.info("Wait Done")
          unless KubectlClient::Get.resource_desired_is_available?(resource["kind"].as_s, resource["name"].as_s)
            test_passed = false
            puts "Replicas did not return desired count after network chaos test for resource: #{resource["name"]}".colorize(:red)
          end
        else
          # TODO Change this to an exception (points = 0)
          # Add SKIPPED to points.yml and set to points = 0
          # e.g. upsert_exception_task
          test_passed = false
          puts "Chaosmesh failed to finish for resource: #{resource["name"]}".colorize(:red)
        end
      end
      test_passed
    end
    if task_response
      resp = upsert_passed_task("chaos_network_loss", "✔️  PASSED: Replicas available match desired count after network chaos test #{emoji_chaos_network_loss}")
    else
      resp = upsert_failed_task("chaos_network_loss", "✖️  FAILED: Replicas did not return desired count after network chaos test #{emoji_chaos_network_loss}")
    end
  ensure
    delete_chaos = `kubectl delete -f "#{destination_cnf_dir}/chaos_network_loss.yml"`
  end
end

desc "Does the CNF crash when CPU usage is high"
task "chaos_cpu_hog", ["install_chaosmesh"] do |_, args|
  CNFManager::Task.task_runner(args) do |args, config|
    VERBOSE_LOGGING.info "chaos_cpu_hog" if check_verbose(args)
    LOGGING.debug "cnf_config: #{config}"
    destination_cnf_dir = config.cnf_config[:destination_cnf_dir]
    emoji_chaos_cpu_hog = "📦💻🐷📈"
    task_response = CNFManager.workload_resource_test(args, config) do |resource, container, initialized|
      if KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h? && KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.size > 0
        test_passed = true
      else
        puts "No resource label found for container kill test for resource: #{resource["name"]}".colorize(:red)
        test_passed = false
      end
      if test_passed
        template = Crinja.render(cpu_chaos_template, {"labels" => KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h})
        chaos_config = `echo "#{template}" > "#{destination_cnf_dir}/chaos_cpu_hog.yml"`
        VERBOSE_LOGGING.debug "#{chaos_config}" if check_verbose(args)
        run_chaos = `kubectl create -f "#{destination_cnf_dir}/chaos_cpu_hog.yml"`
        VERBOSE_LOGGING.debug "#{run_chaos}" if check_verbose(args)
        # TODO fail if exceeds
        if ChaosMeshSetup.wait_for_test("StressChaos", "burn-cpu")
          unless KubectlClient::Get.resource_desired_is_available?(resource["kind"].as_s, resource["name"].as_s)
            test_passed = false
            puts "Chaosmesh Application pod is not healthy after high CPU consumption for resource: #{resource["name"]}".colorize(:red)
          end
        else
          # TODO Change this to an exception (points = 0)
          # TODO Add SKIPPED to points.yml and set to points = 0
          # e.g. upsert_exception_task
          test_passed = false
          puts "Chaosmesh failed to finish for resource: #{resource["name"]}".colorize(:red)
        end
      end
      test_passed
    end
    if task_response
      resp = upsert_passed_task("chaos_cpu_hog", "✔️  PASSED: Application pod is healthy after high CPU consumption #{emoji_chaos_cpu_hog}")
    else
      resp = upsert_failed_task("chaos_cpu_hog", "✖️  FAILED: Application pod is not healthy after high CPU consumption #{emoji_chaos_cpu_hog}")
    end
  ensure
    delete_chaos = `kubectl delete -f "#{destination_cnf_dir}/chaos_cpu_hog.yml"`
  end
end

desc "Does the CNF recover when its container is killed"
task "chaos_container_kill", ["install_chaosmesh"] do |_, args|
  CNFManager::Task.task_runner(args) do |args, config|
    VERBOSE_LOGGING.info "chaos_container_kill" if check_verbose(args)
    LOGGING.debug "cnf_config: #{config}"
    destination_cnf_dir = config.cnf_config[:destination_cnf_dir]
    emoji_chaos_container_kill = "🗡️💀♻️"
    resource_names = [] of Hash(String, String)
    task_response = CNFManager.workload_resource_test(args, config) do |resource, container, initialized|
      if KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h? &&
         KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.size > 0
        test_passed = true
      else
        puts "No resource label found for container kill test for resource: #{resource}".colorize(:red)
        test_passed = false
      end
      if test_passed
        # TODO change helm_chart_container_name to container_name
        template = Crinja.render(chaos_template_container_kill, {"labels" => KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h, "helm_chart_container_name" => "#{container.as_h["name"]}"})
        LOGGING.debug "chaos template: #{template}"
        chaos_config = `echo "#{template}" > "#{destination_cnf_dir}/chaos_container_kill.yml"`
        VERBOSE_LOGGING.debug "#{chaos_config}" if check_verbose(args)
        run_chaos = `kubectl create -f "#{destination_cnf_dir}/chaos_container_kill.yml"`
        VERBOSE_LOGGING.debug "#{run_chaos}" if check_verbose(args)
        if ChaosMeshSetup.wait_for_test("PodChaos", "container-kill")
          KubectlClient::Get.resource_wait_for_install(resource["kind"].as_s, resource["name"].as_s, wait_count = 60)
        else
          # TODO Change this to an exception (points = 0)
          # TODO Add SKIPPED to points.yml and set to points = 0
          # e.g. upsert_exception_task
          test_passed = false
          puts "Chaosmesh chaos_container_kill failed to finish for resource: #{resource} and container: #{container.as_h["name"].as_s}".colorize(:red)
        end
      end

      resource_names << {"kind" => resource["kind"].as_s,
                         "name" => resource["name"].as_s}
      test_passed
    end
    desired_passed = resource_names.map do |x|
      if KubectlClient::Get.resource_desired_is_available?(x["kind"], x["name"])
        true
      else
        puts "Replicas did not return desired count after container kill test for resource: #{x}".colorize(:red)
        false
      end
    end
    if task_response && desired_passed.all?
      resp = upsert_passed_task("chaos_container_kill", "✔️  PASSED: Replicas available match desired count after container kill test #{emoji_chaos_container_kill}")
    else
      resp = upsert_failed_task("chaos_container_kill", "✖️  FAILED: Replicas did not return desired count after container kill test #{emoji_chaos_container_kill}")
    end
  ensure
    delete_chaos = `kubectl delete -f "#{destination_cnf_dir}/chaos_container_kill.yml"`
  end
end

desc "Does the CNF crash when network latency occurs"
task "pod_network_latency", ["install_litmus"] do |_, args|
  CNFManager::Task.task_runner(args) do |args, config|
    VERBOSE_LOGGING.info "pod_network_latency" if check_verbose(args)
    LOGGING.debug "cnf_config: #{config}"
    # TODO tests should fail if cnf not installed
    destination_cnf_dir = config.cnf_config[:destination_cnf_dir]
    task_response = CNFManager.workload_resource_test(args, config) do |resource, container, initialized|
      if KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h? && KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.size > 0
        test_passed = true
      else
        puts "No resource label found for pod_network_latency test for resource: #{resource["name"]}".colorize(:red)
        test_passed = false
      end
      if test_passed
        if args.named["offline"]?
          LOGGING.info "install resilience offline mode"
          KubectlClient::Apply.file("#{OFFLINE_MANIFESTS_PATH}/experiment.yaml")
          KubectlClient::Apply.file("#{OFFLINE_MANIFESTS_PATH}/rbac.yaml")
        else
          KubectlClient::Apply.file("https://hub.litmuschaos.io/api/chaos/1.13.6?file=charts/generic/pod-network-latency/experiment.yaml")
          KubectlClient::Apply.file("https://hub.litmuschaos.io/api/chaos/1.13.6?file=charts/generic/pod-network-latency/rbac.yaml")
        end
        # annotate = `kubectl annotate --overwrite deploy/#{resource["name"]} litmuschaos.io/chaos="true"`
        KubectlClient::Annotate.run("--overwrite deploy/#{resource["name"]} litmuschaos.io/chaos=\"true\"")

        chaos_experiment_name = "pod-network-latency"
        total_chaos_duration = "60"
        test_name = "#{resource["name"]}-#{Random.rand(99)}"
        chaos_result_name = "#{test_name}-#{chaos_experiment_name}"

        template = Crinja.render(chaos_template_pod_network_latency, {"chaos_experiment_name" => "#{chaos_experiment_name}", "deployment_label" => "#{KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.first_key}", "deployment_label_value" => "#{KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.first_value}", "test_name" => test_name, "total_chaos_duration" => total_chaos_duration})
        chaos_config = `echo "#{template}" > "#{destination_cnf_dir}/#{chaos_experiment_name}-chaosengine.yml"`
        puts "#{chaos_config}" if check_verbose(args)
        # run_chaos = `kubectl apply -f "#{destination_cnf_dir}/#{chaos_experiment_name}-chaosengine.yml"`
        # puts "#{run_chaos}" if check_verbose(args)
        KubectlClient::Apply.file("#{destination_cnf_dir}/#{chaos_experiment_name}-chaosengine.yml")
        LitmusManager.wait_for_test(test_name, chaos_experiment_name, total_chaos_duration, args)
      end
      test_passed = LitmusManager.check_chaos_verdict(chaos_result_name, chaos_experiment_name, args)
    end
    if task_response
      resp = upsert_passed_task("pod_network_latency", "✔️  PASSED: pod_network_latency chaos test passed 🗡️💀♻️")
    else
      resp = upsert_failed_task("pod_network_latency", "✖️  FAILED: pod_network_latency chaos test failed 🗡️💀♻️")
    end
    resp
  end
end

desc "Does the CNF crash when disk fill occurs"
task "disk_fill", ["install_litmus"] do |_, args|
  CNFManager::Task.task_runner(args) do |args, config|
    VERBOSE_LOGGING.info "disk_fill" if check_verbose(args)
    LOGGING.debug "cnf_config: #{config}"
    destination_cnf_dir = config.cnf_config[:destination_cnf_dir]
    task_response = CNFManager.workload_resource_test(args, config) do |resource, container, initialized|
      if KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h? && KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.size > 0
        test_passed = true
      else
        puts "No resource label found for disk_fill test for resource: #{resource["name"]}".colorize(:red)
        test_passed = false
      end
      if test_passed
        if args.named["offline"]?
          LOGGING.info "install resilience offline mode"
          AirGapUtils.image_pull_policy("#{OFFLINE_MANIFESTS_PATH}/disk-fill-experiment.yaml")
          KubectlClient::Apply.file("#{OFFLINE_MANIFESTS_PATH}/disk-fill-experiment.yaml")
          KubectlClient::Apply.file("#{OFFLINE_MANIFESTS_PATH}/disk-fill-rbac.yaml")
        else
          KubectlClient::Apply.file("https://hub.litmuschaos.io/api/chaos/1.13.6?file=charts/generic/disk-fill/experiment.yaml")
          KubectlClient::Apply.file("https://hub.litmuschaos.io/api/chaos/1.13.6?file=charts/generic/disk-fill/rbac.yaml")
        end
        # annotate = `kubectl annotate --overwrite deploy/#{resource["name"]} litmuschaos.io/chaos="true"`
        KubectlClient::Annotate.run("--overwrite deploy/#{resource["name"]} litmuschaos.io/chaos=\"true\"")

        chaos_experiment_name = "disk-fill"
        disk_fill_time = "100"
        test_name = "#{resource["name"]}-#{Random.rand(99)}"
        chaos_result_name = "#{test_name}-#{chaos_experiment_name}"

        template = Crinja.render(chaos_template_disk_fill, {"chaos_experiment_name" => "#{chaos_experiment_name}", "deployment_label" => "#{KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.first_key}", "deployment_label_value" => "#{KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.first_value}", "test_name" => test_name})
        chaos_config = `echo "#{template}" > "#{destination_cnf_dir}/#{chaos_experiment_name}-chaosengine.yml"`
        puts "#{chaos_config}" if check_verbose(args)
        KubectlClient::Apply.file("#{destination_cnf_dir}/#{chaos_experiment_name}-chaosengine.yml")
        LitmusManager.wait_for_test(test_name, chaos_experiment_name, disk_fill_time, args)
      end
      test_passed = LitmusManager.check_chaos_verdict(chaos_result_name, chaos_experiment_name, args)
    end
    if task_response
      resp = upsert_passed_task("disk_fill", "✔️  PASSED: disk_fill chaos test passed 🗡️💀♻️")
    else
      resp = upsert_failed_task("disk_fill", "✖️  FAILED: disk_fill chaos test failed 🗡️💀♻️")
    end
    resp
  end
end

desc "Does the CNF crash when pod-delete occurs"
task "pod_delete", ["install_litmus"] do |_, args|
  CNFManager::Task.task_runner(args) do |args, config|
    VERBOSE_LOGGING.info "pod_delete" if check_verbose(args)
    LOGGING.debug "cnf_config: #{config}"
    destination_cnf_dir = config.cnf_config[:destination_cnf_dir]
    task_response = CNFManager.workload_resource_test(args, config) do |resource, container, initialized|
      if KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h? && KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.size > 0
        test_passed = true
      else
        puts "No resource label found for pod_delete test for resource: #{resource["name"]}".colorize(:red)
        test_passed = false
      end
      if test_passed
        if args.named["offline"]?
          LOGGING.info "install resilience offline mode"
          AirGapUtils.image_pull_policy("#{OFFLINE_MANIFESTS_PATH}/pod-delete-experiment.yaml")
          KubectlClient::Apply.file("#{OFFLINE_MANIFESTS_PATH}/pod-delete-experiment.yaml")
          KubectlClient::Apply.file("#{OFFLINE_MANIFESTS_PATH}/pod-delete-rbac.yaml")
        else
          KubectlClient::Apply.file("https://hub.litmuschaos.io/api/chaos/1.13.6?file=charts/generic/pod-delete/experiment.yaml")
          KubectlClient::Apply.file("https://hub.litmuschaos.io/api/chaos/1.13.6?file=charts/generic/pod-delete/rbac.yaml")
        end
        KubectlClient::Annotate.run("--overwrite deploy/#{resource["name"]} litmuschaos.io/chaos=\"true\"")

        chaos_experiment_name = "pod-delete"
        total_chaos_duration = "30"
        target_pod_name = ""
        test_name = "#{resource["name"]}-#{Random.rand(99)}"
        chaos_result_name = "#{test_name}-#{chaos_experiment_name}"

        template = Crinja.render(chaos_template_pod_delete, {"chaos_experiment_name" => "#{chaos_experiment_name}", "deployment_label" => "#{KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.first_key}", "deployment_label_value" => "#{KubectlClient::Get.resource_spec_labels(resource["kind"], resource["name"]).as_h.first_value}", "test_name" => test_name, "target_pod_name" => target_pod_name, "total_chaos_duration" => total_chaos_duration})
        chaos_config = `echo "#{template}" > "#{destination_cnf_dir}/#{chaos_experiment_name}-chaosengine.yml"`
        puts "#{chaos_config}" if check_verbose(args)
        KubectlClient::Apply.file("#{destination_cnf_dir}/#{chaos_experiment_name}-chaosengine.yml")
        LitmusManager.wait_for_test(test_name, chaos_experiment_name, total_chaos_duration, args)
      end
      test_passed = LitmusManager.check_chaos_verdict(chaos_result_name, chaos_experiment_name, args)
    end
    if task_response
      resp = upsert_passed_task("pod_delete", "✔️  PASSED: pod_delete chaos test passed 🗡️💀♻️")
    else
      resp = upsert_failed_task("pod_delete", "✖️  FAILED: pod_delete chaos test failed 🗡️💀♻️")
    end
    resp
  end
end

def network_chaos_template
  <<-TEMPLATE
  apiVersion: chaos-mesh.org/v1alpha1
  kind: NetworkChaos
  metadata:
    name: network-loss
    namespace: default
  spec:
    action: loss
    mode: one
    selector:
      labelSelectors:
        {% for label in labels %}
        '{{ label[0]}}': '{{ label[1] }}'
        {% endfor %}
    loss:
      loss: '100'
      correlation: '100'
    duration: '40s'
    scheduler:
      cron: '@every 600s'
  TEMPLATE
end

def cpu_chaos_template
  <<-TEMPLATE
  apiVersion: chaos-mesh.org/v1alpha1
  kind: StressChaos
  metadata:
    name: burn-cpu
    namespace: default
  spec:
    mode: one
    selector:
      labelSelectors:
        {% for label in labels %}
        '{{ label[0]}}': '{{ label[1] }}'
        {% endfor %}
    stressors:
      cpu:
        workers: 1
        load: 100
        options: ['-c 0']
    duration: '40s'
    scheduler:
      cron: '@every 600s'
  TEMPLATE
end

def chaos_template_container_kill
  <<-TEMPLATE
  apiVersion: chaos-mesh.org/v1alpha1
  kind: PodChaos
  metadata:
    name: container-kill
    namespace: default
  spec:
    action: container-kill
    mode: one
    containerName: '{{ helm_chart_container_name }}'
    selector:
      labelSelectors:
        {% for label in labels %}
        '{{ label[0]}}': '{{ label[1] }}'
        {% endfor %}
    scheduler:
      cron: '@every 600s'
  TEMPLATE
end

def chaos_template_pod_network_latency
  <<-TEMPLATE
  apiVersion: litmuschaos.io/v1alpha1
  kind: ChaosEngine
  metadata:
    name: {{ test_name }}
    namespace: default
  spec:
    jobCleanUpPolicy: 'delete'
    annotationCheck: 'true'
    engineState: 'active'
    appinfo:
      appns: 'default'
      applabel: '{{ deployment_label}}={{ deployment_label_value }}'
      appkind: 'deployment'
    chaosServiceAccount: {{ chaos_experiment_name }}-sa
    experiments:
      - name: {{ chaos_experiment_name }}
        spec:
          components:
            env:
              # If not provided it will take the first container of target pod
              - name: TARGET_CONTAINER
                value: ''

              - name: NETWORK_INTERFACE
                value: 'eth0'

              - name: NETWORK_LATENCY
                value: '60000'

              - name: TOTAL_CHAOS_DURATION
                value: '{{ total_chaos_duration }}'

              # provide the name of container runtime
              # it supports docker, containerd, crio
              # default to docker
              - name: CONTAINER_RUNTIME
                value: 'containerd'

              # provide the socket file path
              # applicable only for containerd and crio runtime
              - name: SOCKET_PATH
                value: '/run/containerd/containerd.sock'

  TEMPLATE
end

def chaos_template_disk_fill
  <<-TEMPLATE
  apiVersion: litmuschaos.io/v1alpha1
  kind: ChaosEngine
  metadata:
    name: {{ test_name }}
    namespace: default
  spec:
    annotationCheck: 'true'
    engineState: 'active'
    auxiliaryAppInfo: ''
    appinfo:
      appns: 'default'
      applabel: '{{ deployment_label}}={{ deployment_label_value }}'
      appkind: 'deployment'
    chaosServiceAccount: {{ chaos_experiment_name }}-sa
    jobCleanUpPolicy: 'delete'
    experiments:
      - name: {{ chaos_experiment_name }}
        spec:
          components:
            env:
              # specify the fill percentage according to the disk pressure required
              - name: EPHEMERAL_STORAGE_MEBIBYTES
                value: '500'
                
              - name: TARGET_CONTAINER
                value: '' 

              - name: FILL_PERCENTAGE
                value: ''

              - name: CONTAINER_PATH
                value: '/var/lib/containerd/io.containerd.grpc.v1.cri/containers/'
                            
  TEMPLATE
end

def chaos_template_pod_delete
  <<-TEMPLATE
  apiVersion: litmuschaos.io/v1alpha1
  kind: ChaosEngine
  metadata:
    name: {{ test_name }}
    namespace: default
  spec:
    engineState: 'active'
    appinfo:
      appns: 'default'
      applabel: '{{ deployment_label}}={{ deployment_label_value }}'
      appkind: 'deployment'
    chaosServiceAccount: {{ chaos_experiment_name }}-sa
    jobCleanUpPolicy: 'delete'
    experiments:
      - name: {{ chaos_experiment_name }}
        spec:
          components:
            env:
              # specify the fill percentage according to the disk pressure required
              - name: TOTAL_CHAOS_DURATION
                value: '{{ total_chaos_duration }}'
                
              - name: CHAOS_INTERVAL
                value: '10'
                
              - name: TARGET_PODS
                value: '{{ target_pod_name }}'

              - name: FORCE
                value: 'false'

  TEMPLATE
end
