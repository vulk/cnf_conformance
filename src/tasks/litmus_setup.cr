require "sam"
require "file_utils"
require "colorize"
require "totem"
require "./utils/utils.cr"

desc "Install LitmusChaos"
task "install_litmus" do |_, args|
  if args.named["offline"]?
    LOGGING.info "install litmus offline mode"
    AirGapUtils.image_pull_policy("#{OFFLINE_MANIFESTS_PATH}/litmus-operator-v1.13.6.yaml")
    KubectlClient::Apply.file("#{OFFLINE_MANIFESTS_PATH}/litmus-operator-v1.13.6.yaml")
    KubectlClient::Apply.file("#{OFFLINE_MANIFESTS_PATH}/chaos_crds.yaml")
  else
    KubectlClient::Apply.file("https://litmuschaos.github.io/litmus/litmus-operator-v1.13.6.yaml")
  end
end

module LitmusManager
  # # wait_for_test will wait for the completion of litmus test
  def self.wait_for_test(test_name, chaos_experiment_name, total_chaos_duration, args)
    # # Maximum wait time is TCD (total chaos duration) + 60s (additional wait time)
    delay = 2
    timeout = "#{total_chaos_duration}".to_i + 60
    retry = timeout/delay
    chaos_result_name = "#{test_name}-#{chaos_experiment_name}"
    wait_count = 0
    status_code = -1
    experimentStatus = ""

    experimentStatus_cmd = "kubectl get chaosengine.litmuschaos.io #{test_name} -o jsonpath='{.status.engineStatus}'"
    puts "Checking experiment status  #{experimentStatus_cmd}" if check_verbose(args)

    # # Wait for completion of chaosengine which indicates the completion of chaos
    until (status_code == 0 && experimentStatus == "Completed") || wait_count >= retry
      sleep delay
      experimentStatus_cmd = "kubectl get chaosengine.litmuschaos.io #{test_name} -o jsonpath='{.status.experiments[0].status}'"
      puts "Checking experiment status  #{experimentStatus_cmd}" if check_verbose(args)
      status_code = Process.run("#{experimentStatus_cmd}", shell: true, output: experimentStatus_response = IO::Memory.new, error: stderr = IO::Memory.new).exit_status
      puts "status_code: #{status_code}" if check_verbose(args)
      puts "Checking experiment status  #{experimentStatus_cmd}" if check_verbose(args)
      experimentStatus = experimentStatus_response.to_s
      LOGGING.info "#{chaos_experiment_name} experiment status: " + experimentStatus

      emoji_test_failed = "🗡️💀♻️"
      LOGGING.info "experimentStatus #{experimentStatus}"
      if (experimentStatus != "Waiting for Job Creation" && experimentStatus != "Running" && experimentStatus != "Completed")
        resp = upsert_failed_task("pod-network-latency", "✖️  FAILED: #{chaos_experiment_name} chaos test failed #{emoji_test_failed}")
        resp
      end
      wait_count = wait_count + 1
    end

    verdict = ""
    wait_count = 0
    verdict_cmd = "kubectl get chaosresults.litmuschaos.io #{chaos_result_name} -o jsonpath='{.status.experimentStatus.verdict}'"
    puts "Checking experiment verdict  #{verdict_cmd}" if check_verbose(args)
    # # Check the chaosresult verdict
    until (status_code == 0 && verdict != "Awaited") || wait_count >= 20
      sleep delay
      status_code = Process.run("#{verdict_cmd}", shell: true, output: verdict_response = IO::Memory.new, error: stderr = IO::Memory.new).exit_status
      puts "status_code: #{status_code}" if check_verbose(args)
      puts "verdict: #{verdict_response.to_s}" if check_verbose(args)
      verdict = verdict_response.to_s
      wait_count = wait_count + 1
    end
  end

  # # check_chaos_verdict will check the verdict of chaosexperiment
  def self.check_chaos_verdict(chaos_result_name, chaos_experiment_name, args) : Bool
    verdict_cmd = "kubectl get chaosresults.litmuschaos.io #{chaos_result_name} -o jsonpath='{.status.experimentStatus.verdict}'"
    puts "Checking experiment verdict  #{verdict_cmd}" if check_verbose(args)
    status_code = Process.run("#{verdict_cmd}", shell: true, output: verdict_response = IO::Memory.new, error: stderr = IO::Memory.new).exit_status
    puts "status_code: #{status_code}" if check_verbose(args)
    puts "verdict: #{verdict_response.to_s}" if check_verbose(args)
    verdict = verdict_response.to_s

    emoji_test_failed = "🗡️💀♻️"
    if verdict == "Pass"
      return true
    else
      LOGGING.info "#{chaos_experiment_name} chaos test failed: #{chaos_result_name}, verdict: #{verdict}"
      puts "#{chaos_experiment_name} chaos test failed #{emoji_test_failed}"
      return false
    end
  end
end
