require "./spec_helper"
require "colorize"
require "../src/tasks/utils/utils.cr"
require "../src/tasks/utils/airgap.cr"
require "../src/tasks/utils/kubectl_client.cr"
require "../src/tasks/utils/system_information/helm.cr"
require "file_utils"
require "sam"

describe "Setup" do
  after_each do
    `./cnf-testsuite cleanup`
    $?.success?.should be_true
  end

  it "'setup' should completely setup the cnf testsuite environment before installing cnfs", tags: ["setup"] do
    response_s = `./cnf-testsuite setup`
    LOGGING.info response_s
    $?.success?.should be_true
    (/Setup complete/ =~ response_s).should_not be_nil
  end

  it "'generate_config' should generate a cnf-testsuite.yml for a helm chart", tags: ["setup-generate"] do
    LOGGING.info `./cnf-testsuite setup`
    response_s = `./cnf-testsuite generate_config config-src=stable/coredns output-file=./cnf-testsuite-test.yml`
    LOGGING.info response_s
    $?.success?.should be_true
    # (/Setup complete/ =~ response_s).should_not be_nil

    yaml = File.open("./cnf-testsuite-test.yml") do |file|
      YAML.parse(file)
    end
    LOGGING.debug "test yaml: #{yaml}"
    LOGGING.info `cat ./cnf-testsuite-test.yml`
    (yaml["container_names"][0]["name"] == "coredns").should be_true
    (yaml["container_names"][0]["rolling_update_test_tag"] == "1.7.1").should be_true
    (yaml["container_names"][0]["rolling_downgrade_test_tag"] == "1.7.1").should be_true
    (yaml["container_names"][0]["rolling_version_change_test_tag"] == "1.7.1").should be_true
    (yaml["container_names"][0]["rollback_from_tag"] == "1.7.1").should be_true
  ensure
    `rm ./cnf-testsuite-test.yml`
  end

  it "'generate_config' should generate a cnf-testsuite.yml for a helm directory", tags: ["setup-generate"] do
    LOGGING.info `./cnf-testsuite setup`
    response_s = `./cnf-testsuite generate_config config-src=sample-cnfs/k8s-sidecar-container-pattern/chart output-file=./cnf-testsuite-test.yml`
    LOGGING.info response_s
    $?.success?.should be_true
    # (/Setup complete/ =~ response_s).should_not be_nil

    yaml = File.open("./cnf-testsuite-test.yml") do |file|
      YAML.parse(file)
    end
    LOGGING.debug "test yaml: #{yaml}"
    LOGGING.info `cat ./cnf-testsuite-test.yml`
    (yaml["container_names"][0]["name"] == "sidecar-container1").should be_true
    (yaml["container_names"][1]["name"] == "sidecar-container2").should be_true
  ensure
    `rm ./cnf-testsuite-test.yml`
  end

  it "'generate_config' should generate a cnf-testsuite.yml for a manifest directory", tags: ["setup-generate"] do
    LOGGING.info `./cnf-testsuite setup`
    response_s = `./cnf-testsuite generate_config config-src=sample-cnfs/k8s-non-helm/manifests output-file=./cnf-testsuite-test.yml`
    LOGGING.info response_s
    $?.success?.should be_true
    # (/Setup complete/ =~ response_s).should_not be_nil

    yaml = File.open("./cnf-testsuite-test.yml") do |file|
      YAML.parse(file)
    end
    LOGGING.debug "test yaml: #{yaml}"
    LOGGING.info `cat ./cnf-testsuite-test.yml`
    (yaml["container_names"][0]["name"] == "sidecar-container1").should be_true
    (yaml["container_names"][1]["name"] == "sidecar-container2").should be_true
  ensure
    `rm ./cnf-testsuite-test.yml`
  end

  it "'cnf_setup/cnf_cleanup' should install/cleanup with cnf-path arg as alias for cnf-config", tags: ["setup"] do
    begin
      response_s = `./cnf-testsuite cnf_setup cnf-path=example-cnfs/coredns/cnf-testsuite.yml`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Successfully setup coredns/ =~ response_s).should_not be_nil
    ensure
      response_s = `./cnf-testsuite cnf_cleanup cnf-path=example-cnfs/coredns/cnf-testsuite.yml`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Successfully cleaned up/ =~ response_s).should_not be_nil
    end
  end

  it "'cnf_setup/cnf_cleanup' should install/cleanup a cnf with a cnf-testsuite.yml", tags: ["setup"] do
    begin
      response_s = `./cnf-testsuite cnf_setup cnf-config=example-cnfs/coredns/cnf-testsuite.yml`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Successfully setup coredns/ =~ response_s).should_not be_nil
    ensure
      response_s = `./cnf-testsuite cnf_cleanup cnf-config=example-cnfs/coredns/cnf-testsuite.yml`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Successfully cleaned up/ =~ response_s).should_not be_nil
    end
  end

  it "'cnf_setup/cnf_cleanup' should work with cnf-testsuite.yml that has no directory associated with it", tags: ["setup"] do
    begin
      # TODO force cnfs/<name> to be deployment name and not the directory name
      response_s = `./cnf-testsuite cnf_setup cnf-config=spec/fixtures/cnf-testsuite.yml verbose`
      LOGGING.info("response_s: #{response_s}")
      $?.success?.should be_true
      (/Successfully setup coredns/ =~ response_s).should_not be_nil
    ensure
      response_s = `./cnf-testsuite cnf_cleanup cnf-path=spec/fixtures/cnf-testsuite.yml verbose`
      LOGGING.info("response_s: #{response_s}")
      $?.success?.should be_true
      (/Successfully cleaned up/ =~ response_s).should_not be_nil
    end
  end
end
