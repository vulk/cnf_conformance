# coding: utf-8
require "../spec_helper"
require "colorize"
require "../../src/tasks/utils/utils.cr"
require "../../src/tasks/utils/kubectl_client.cr"
require "file_utils"
require "sam"

describe "Utils" do
  before_each do
    `./cnf-testsuite results_yml_cleanup`
  end
  after_each do
    `./cnf-testsuite results_yml_cleanup`
  end

  it "'toggle' should return a boolean for a toggle in the config.yml", tags: ["args"] do
    (toggle("wip")).should eq(false)
  end

  it "'check_feature_level' should return the feature level for an argument variable", tags: ["args"] do
    args = Sam::Args.new(["name", "arg1=1", "beta"])
    (check_feature_level(args)).should eq("beta")
    args = Sam::Args.new(["name", "arg1=1", "alpha"])
    (check_feature_level(args)).should eq("alpha")
    args = Sam::Args.new(["name", "arg1=1", "wip"])
    (check_feature_level(args)).should eq("wip")
    args = Sam::Args.new(["name", "arg1=1", "hi"])
    (check_feature_level(args)).should eq("ga")
  end

  it "'check_<x>' should return the feature level for an argument variable", tags: ["args"] do
    # (check_ga).should be_false
    (check_alpha).should be_false
    (check_beta).should be_false
    (check_wip).should be_false
  end

  it "'check_<x>(args)' should return the feature level for an argument variable", tags: ["args"] do
    args = Sam::Args.new(["name", "arg1=1", "alpha"])
    (check_alpha(args)).should be_true
    (check_beta(args)).should be_true
    (check_wip(args)).should be_false
  end

  it "'check_cnf_config' should return the value for a cnf-config argument", tags: ["args"] do
    args = Sam::Args.new(["cnf-config=./sample-cnfs/sample-generic-cnf/cnf-testsuite.yml"])
    # TODO make CNFManager.sample_setup_args accept the full path to the config yml instead of the directory
    (check_cnf_config(args)).should eq("./sample-cnfs/sample-generic-cnf")
  end

  it "'upsert_skipped_task' should put a 0 in the results file", tags: ["task_runner"] do
    CNFManager::Points.clean_results_yml
    resp = upsert_skipped_task("ip_addresses", "✖️  FAILED: IP addresses found")
    yaml = File.open("#{CNFManager::Points::Results.file}") do |file|
      YAML.parse(file)
    end
    (yaml["items"].as_a.find { |x|
      x["name"] == "ip_addresses" &&
        x["points"] == CNFManager::Points.task_points("ip_addresses", CNFManager::Points::Results::ResultStatus::Skipped)
    }).should be_truthy

    (yaml["items"].as_a.find { |x| x["name"] == "ip_addresses" && x["points"] == 0 }).should be_truthy
  end

  it "'single_task_runner' should accept a cnf-config argument and apply a test to that cnf", tags: ["task_runner"] do
    args = Sam::Args.new(["cnf-config=./sample-cnfs/sample-generic-cnf/cnf-testsuite.yml"])
    # check_cnf_config_then_deploy(args)
    cli_hash = CNFManager.sample_setup_cli_args(args, false)
    CNFManager.sample_setup(cli_hash) if cli_hash["config_file"]
    task_response = CNFManager::Task.single_task_runner(args) do
      config = CNFManager.parsed_config_file(CNFManager.ensure_cnf_testsuite_yml_path(args.named["cnf-config"].as(String)))
      helm_chart_container_name = config.get("helm_chart_container_name").as_s
      privileged_response = `kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[?(@.securityContext.privileged==true)].name}'`
      privileged_list = privileged_response.to_s.split(" ").uniq
      LOGGING.info "privileged_list #{privileged_list}"
      if privileged_list.select { |x| x == helm_chart_container_name }.size > 0
        resp = "✖️  FAILED: Found privileged containers: #{privileged_list.inspect}".colorize(:red)
      else
        resp = "✔️  PASSED: No privileged containers".colorize(:green)
      end
      LOGGING.info resp
      resp
    end
    (task_response).should eq("✔️  PASSED: No privileged containers".colorize(:green))
    CNFManager.sample_cleanup(config_file: "sample-cnfs/sample-generic-cnf", verbose: true)
  end

  it "'single_task_runner' should put a 1 in the results file if it has an exception", tags: ["task_runner"] do
    CNFManager::Points.clean_results_yml
    args = Sam::Args.new(["cnf-config=./cnf-testsuite.yml"])
    task_response = CNFManager::Task.single_task_runner(args) do
      cdir = FileUtils.pwd
      response = String::Builder.new
      config = CNFManager.parsed_config_file(CNFManager.ensure_cnf_testsuite_yml_path(args.named["cnf-config"].as(String)))
      helm_directory = "#{config.get("helm_directory").as_s?}"
      if File.directory?(CNFManager.ensure_cnf_testsuite_dir(args.named["cnf-config"].as(String)) + helm_directory)
        Dir.cd(CNFManager.ensure_cnf_testsuite_dir(args.named["cnf-config"].as(String)) + helm_directory)
        Process.run("grep -r -P '^(?!.+0.0.0.0)(?![[:space:]]*0.0.0.0)(?!#)(?![[:space:]]*#)(?!//)(?![[:space:]]*//)(?!/\\*)(?![[:space:]]*/\\*)(.+([0-9]{1,3}[.]){3}[0-9]{1,3})'", shell: true) do |proc|
          while line = proc.output.gets
            response << line
          end
        end
        Dir.cd(cdir)
        if response.to_s.size > 0
          resp = upsert_failed_task("ip_addresses", "✖️  FAILED: IP addresses found")
        else
          resp = upsert_passed_task("ip_addresses", "✔️  PASSED: No IP addresses found")
        end
        resp
      else
        Dir.cd(cdir)
        resp = upsert_passed_task("ip_addresses", "✔️  PASSED: No IP addresses found")
      end
    end
    yaml = File.open("#{CNFManager::Points::Results.file}") do |file|
      YAML.parse(file)
    end
    (yaml["exit_code"]).should eq(1)
  end

  it "'all_cnfs_task_runner' should run a test against all cnfs in the cnfs directory if there is not cnf-config argument passed to it", tags: ["task_runner"] do
    my_args = Sam::Args.new
    # CNFManager.sample_setup_args(sample_dir: "sample-cnfs/sample-generic-cnf", args: my_args)
    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample-generic-cnf`
    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_privileged_cnf`
    # CNFManager.sample_setup_args(sample_dir: "sample-cnfs/sample_privileged_cnf", args: my_args )
    task_response = CNFManager::Task.all_cnfs_task_runner(my_args) do |args, config|
      LOGGING.info("all_cnfs_task_runner spec args #{args.inspect}")
      VERBOSE_LOGGING.info "privileged" if check_verbose(args)
      white_list_container_names = config.cnf_config[:white_list_container_names]
      VERBOSE_LOGGING.info "white_list_container_names #{white_list_container_names.inspect}" if check_verbose(args)
      violation_list = [] of String
      resource_response = CNFManager.workload_resource_test(args, config) do |resource, container, initialized|
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
      emoji_security = ""
      if resource_response
        resp = upsert_passed_task("privileged", "✔️  PASSED: No privileged containers")
      else
        resp = upsert_failed_task("privileged", "✖️  FAILED: Found #{violation_list.size} privileged containers: #{violation_list.inspect}")
      end
      resp
    end
    (task_response).should eq(["✔️  PASSED: No privileged containers",
                               "✖️  FAILED: Found 1 privileged containers: [\"coredns\"]"])
  ensure
    CNFManager.sample_cleanup(config_file: "sample-cnfs/sample-generic-cnf", verbose: true)
    CNFManager.sample_cleanup(config_file: "sample-cnfs/sample_privileged_cnf", verbose: true)
  end

  it "'task_runner' should run a test against a single cnf if passed a cnf-config argument even if there are multiple cnfs installed", tags: ["task_runner"] do
    config_file = "sample-cnfs/sample-generic-cnf"
    args = Sam::Args.new(["cnf-config=./#{config_file}/cnf-testsuite.yml", "verbose", "wait_count=0"])
    cli_hash = CNFManager.sample_setup_cli_args(args)
    CNFManager.sample_setup(cli_hash)
    args = Sam::Args.new(["cnf-config=./sample-cnfs/sample_privileged_cnf/cnf-testsuite.yml", "verbose", "wait_count=0"])
    cli_hash = CNFManager.sample_setup_cli_args(args)
    CNFManager.sample_setup(cli_hash)
    # my_args = Sam::Args.new
    # config_file = "sample-cnfs/sample-generic-cnf"
    # CNFManager.sample_setup_args(sample_dir: config_file, args: my_args)
    # CNFManager.sample_setup_args(sample_dir: "sample-cnfs/sample_privileged_cnf", args: my_args )
    cnfmng_config = CNFManager::Config.parse_config_yml(CNFManager.ensure_cnf_testsuite_yml_path(config_file))
    release_name = cnfmng_config.cnf_config[:release_name]
    installed_args = Sam::Args.new(["cnf-config=./cnfs/#{release_name}/cnf-testsuite.yml"])
    task_response = CNFManager::Task.task_runner(installed_args) do |args|
      LOGGING.info("task_runner spec args #{args.inspect}")
      # config = cnf_testsuite_yml(CNFManager.ensure_cnf_testsuite_dir(args.named["cnf-config"].as(String)))
      config = CNFManager.parsed_config_file(CNFManager.ensure_cnf_testsuite_yml_path(args.named["cnf-config"].as(String)))
      helm_chart_container_name = config.get("helm_chart_container_name").as_s
      privileged_response = `kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[?(@.securityContext.privileged==true)].name}'`
      privileged_list = privileged_response.to_s.split(" ").uniq
      LOGGING.info "privileged_list #{privileged_list}"
      if privileged_list.select { |x| x == helm_chart_container_name }.size > 0
        resp = "✖️  FAILED: Found privileged containers: #{privileged_list.inspect}".colorize(:red)
      else
        resp = "✔️  PASSED: No privileged containers".colorize(:green)
      end
      LOGGING.info resp
      resp
    end
    (task_response).should eq("✖️  FAILED: Found privileged containers: [\"coredns\", \"kube-proxy\"]".colorize(:red))
    CNFManager.sample_cleanup(config_file: "sample-cnfs/sample-generic-cnf", verbose: true)
    CNFManager.sample_cleanup(config_file: "sample-cnfs/sample_privileged_cnf", verbose: true)
  end

  it "'logger' command line logger level setting via config.yml", tags: ["logger"] do
    # NOTE: the config.yml file is in the root of the repo directory.
    # as written this test depends on they key loglevel being set to 'info' in that config.yml
    response_s = `./cnf-testsuite test`
    $?.success?.should be_true
    (/DEBUG -- cnf-testsuite: debug test/ =~ response_s).should be_nil
    (/INFO -- cnf-testsuite: info test/ =~ response_s).should_not be_nil
    (/WARN -- cnf-testsuite: warn test/ =~ response_s).should_not be_nil
    (/ERROR -- cnf-testsuite: error test/ =~ response_s).should_not be_nil
  end

  it "'logger' command line logger level setting works", tags: ["logger"] do
    # Note: implicitly tests the override of config.yml if it exist in repo root
    response_s = `./cnf-testsuite -l debug test`
    LOGGING.info response_s
    $?.success?.should be_true
    (/DEBUG -- cnf-testsuite: debug test/ =~ response_s).should_not be_nil
  end

  it "'logger' LOGLEVEL NO underscore environment variable level setting works", tags: ["logger"] do
    # Note: implicitly tests the override of config.yml if it exist in repo root
    response_s = `unset LOG_LEVEL; LOGLEVEL=DEBUG ./cnf-testsuite test`
    $?.success?.should be_true
    (/DEBUG -- cnf-testsuite: debug test/ =~ response_s).should_not be_nil
  end

  it "'logger' LOG_LEVEL WITH underscore environment variable level setting works", tags: ["logger"] do
    # Note: implicitly tests the override of config.yml if it exist in repo root
    response_s = `LOG_LEVEL=DEBUG ./cnf-testsuite test`
    $?.success?.should be_true
    (/DEBUG -- cnf-testsuite: debug test/ =~ response_s).should_not be_nil
  end

  it "'logger' command line level setting overrides environment variable", tags: ["logger"] do
    response_s = `LOGLEVEL=DEBUG ./cnf-testsuite -l error test`
    $?.success?.should be_true
    (/DEBUG -- cnf-testsuite: debug test/ =~ response_s).should be_nil
    (/INFO -- cnf-testsuite: info test/ =~ response_s).should be_nil
    (/WARN -- cnf-testsuite: warn test/ =~ response_s).should be_nil
    (/ERROR -- cnf-testsuite: error test/ =~ response_s).should_not be_nil
  end

  it "'logger' defaults to error when level set is missplled", tags: ["logger"] do
    # Note: implicitly tests the override of config.yml if it exist in repo root
    response_s = `unset LOG_LEVEL; LOGLEVEL=DEGUB ./cnf-testsuite test`
    $?.success?.should be_true
    (/ERROR -- cnf-testsuite: Invalid logging level set. defaulting to ERROR/ =~ response_s).should_not be_nil
  end

  it "'logger' or verbose output should be shown when verbose flag is set", tags: ["logger"] do
    response_s = `./cnf-testsuite helm_deploy destructive verbose`
    LOGGING.info response_s
    puts response_s
    $?.success?.should be_true
    (/INFO -- cnf-testsuite-verbose: helm_deploy/ =~ response_s).should_not be_nil
  end

  it "'#update_yml' should update the value for a key in a yml file", tags: ["logger"] do
    begin
      update_yml("spec/fixtures/cnf-testsuite.yml", "release_name", "coredns --set worker-node='kind-control-plane'")
      yaml = File.open("spec/fixtures/cnf-testsuite.yml") do |file|
        YAML.parse(file)
      end
      (yaml["release_name"]).should eq("coredns --set worker-node='kind-control-plane'")
    ensure
      update_yml("spec/fixtures/cnf-testsuite.yml", "release_name", "coredns")
    end
  end

  it "spec directory should have tags for all of the specs", tags: ["spec-tags"] do
    response = String::Builder.new
    Process.run("grep -r -I -P '^ *it \"(?!.*tags(.*\"))' ./spec", shell: true) do |proc|
      while line = proc.output.gets
        response << line
        LOGGING.info "#{line}"
      end
    end
    (response.to_s.size > 0).should be_false
  end
end
