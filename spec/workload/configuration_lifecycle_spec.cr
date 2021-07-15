require "../spec_helper"
require "../../src/tasks/utils/kubectl_client.cr"
require "colorize"

describe CnfTestSuite do
  before_all do
    LOGGING.debug `pwd`
    LOGGING.debug `echo $KUBECONFIG`

    `./cnf-testsuite setup`
    `./cnf-testsuite samples_cleanup`
    $?.success?.should be_true
    `./cnf-testsuite configuration_file_setup`

    # `./cnf-testsuite setup`
    # $?.success?.should be_true
  end

  it "'liveness' should pass when livenessProbe is set", tags: ["liveness"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/k8s-multiple-deployments/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `LOG_LEVEL=debug ./cnf-testsuite liveness verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: Helm liveness probe/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/k8s-multiple-deployments/cnf-testsuite.yml deploy_with_chart=false `
    end
  end

  it "'liveness' should fail when livenessProbe is not set", tags: ["liveness"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns_bad_liveness/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite liveness verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: No livenessProbe found/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite sample_coredns_bad_liveness_cleanup`
    end
  end

  it "'readiness' should pass when readinessProbe is set", tags: ["readiness"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/k8s-multiple-deployments/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `LOG_LEVEL=debug ./cnf-testsuite readiness verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: Helm readiness probe/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/k8s-multiple-deployments/cnf-testsuite.yml deploy_with_chart=false `
    end
  end

  it "'readiness' should fail when readinessProbe is not set", tags: ["readiness"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns_bad_liveness/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite readiness verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: No readinessProbe found/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite sample_coredns_bad_liveness_cleanup`
    end
  end

  it "'rolling_update' should pass when valid version is given", tags: ["rolling_update"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite rolling_update verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Passed/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cleanup_sample_coredns`
    end
  end

  it "'rolling_update' should fail when invalid version is given", tags: ["rolling_update"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns_invalid_version/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite rolling_update verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Failed/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample_coredns_invalid_version/cnf-testsuite.yml deploy_with_chart=false`
    end
  end

  it "'rolling_downgrade' should pass when valid version is given", tags: ["rolling_downgrade"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      retry_limit = 5
      retries = 1
      response_s = ""
      until (/Passed/ =~ response_s) || retries > retry_limit
        LOGGING.info "rolling_downgrade retry: #{retries}"
        sleep 1.0
        response_s = `./cnf-testsuite rolling_downgrade verbose`
        retries = retries + 1
      end
      LOGGING.info response_s
      $?.success?.should be_true
      (/Passed/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cleanup_sample_coredns`
    end
  end

  it "'rolling_downgrade' should fail when invalid version is given", tags: ["rolling_downgrade"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns_invalid_version/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite rolling_downgrade verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Failed/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample_coredns_invalid_version/cnf-testsuite.yml deploy_with_chart=false`
    end
  end

  it "'rolling_version_change' should pass when valid version is given", tags: ["rolling_version_change"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite rolling_version_change verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Passed/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cleanup_sample_coredns`
    end
  end

  it "'rolling_version_change' should fail when invalid version is given", tags: ["rolling_version_change"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns_invalid_version/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite rolling_version_change verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Failed/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample_coredns_invalid_version/cnf-testsuite.yml deploy_with_chart=false`
    end
  end

  it "'rollback' should pass ", tags: ["rollback"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite rollback verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Passed/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cleanup_sample_coredns`
    end
  end

  # TODO: figure out failing test for rollback

  it "'nodeport_not_used' should fail when a node port is being used", tags: ["nodeport_not_used"] do
    begin
      `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_nodeport deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite nodeport_not_used verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: NodePort is being used/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_nodeport deploy_with_chart=false`
    end
  end

  it "'nodeport_not_used' should pass when a node port is not being used", tags: ["nodeport_not_used"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite nodeport_not_used verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: NodePort is not used/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cleanup_sample_coredns`
    end
  end

  it "'ip_addresses' should pass when no uncommented ip addresses are found in helm chart source", tags: ["ip_addresses"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample-coredns-cnf-source/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite ip_addresses verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: No IP addresses found/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite sample_coredns_source_cleanup verbose`
    end
  end

  it "'hardcoded_ip_addresses_in_k8s_runtime_configuration' should fail when a hardcoded ip is found in the K8s configuration", tags: ["ip_addresses"] do
    begin
      `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_coredns_hardcoded_ips deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `LOG_LEVEL=info ./cnf-testsuite hardcoded_ip_addresses_in_k8s_runtime_configuration verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: Hard-coded IP addresses found in the runtime K8s configuration/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_coredns_hardcoded_ips deploy_with_chart=false`
    end
  end

  it "'hardcoded_ip_addresses_in_k8s_runtime_configuration' should pass when no ip addresses are found in the K8s configuration", tags: ["ip_addresses"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite hardcoded_ip_addresses_in_k8s_runtime_configuration verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: No hard-coded IP addresses found in the runtime K8s configuration/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cleanup_sample_coredns`
    end
  end

  it "'secrets_used' should pass when secrets are provided as volumes and used by a container", tags: ["secrets"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_secret_volume/cnf-testsuite.yml verbose `
      $?.success?.should be_true
      response_s = `./cnf-testsuite secrets_used verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: Secrets defined and used/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_secret_volume verbose`
    end
  end

  it "'secrets_used' should fail when secrets are provided as volumes and not mounted by a container", tags: ["secrets"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_unmounted_secret_volume/cnf-testsuite.yml verbose wait_count=0 `
      $?.success?.should be_true
      response_s = `./cnf-testsuite secrets_used verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/SKIPPED: Secrets not used/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_unmounted_secret_volume verbose`
    end
  end

  it "'secrets_used' should pass when secrets are provided as environment variables and used by a container", tags: ["secrets"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_secret_env/cnf-testsuite.yml verbose `
      $?.success?.should be_true
      response_s = `./cnf-testsuite secrets_used verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: Secrets defined and used/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_secret_env verbose`
    end
  end

  it "'secrets_used' should skip when secrets are not referenced as environment variables by a container", tags: ["secrets"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_secret_env_no_ref/cnf-testsuite.yml wait_count=2 verbose`
      $?.success?.should be_true
      response_s = `./cnf-testsuite secrets_used verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/SKIPPED: Secrets not used/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_secret_env verbose`
    end
  end

  it "'secrets_used' should pass when no secret volumes are mounted or no container secrets are provided (secrets ignored)`", tags: ["secrets"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml verbose wait_count=0 `
      $?.success?.should be_true
      response_s = `./cnf-testsuite secrets_used verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/SKIPPED: Secrets not used/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_coredns verbose`
    end
  end

  # # 1. test 1 fails because the sample_coredns helm chart configmap is not immutable
  # # 2. copay that sample_coredns cnf  and and make the config map immutable rename it and make sure test passes

  it "'immutable_configmap' fail without immutable configmaps", tags: ["immutable_configmap"] do
    begin
      `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite immutable_configmap verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: Found mutable configmap/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml deploy_with_chart=false`
    end
  end

  it "'immutable_configmap' fail with only some immutable configmaps", tags: ["immutable_configmap"] do
    begin
      `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_coredns/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite immutable_configmap verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: Found mutable configmap/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample_immutable_configmap_some/cnf-testsuite.yml deploy_with_chart=false`
    end
  end

  it "'immutable_configmap' should pass with all immutable configmaps", tags: ["immutable_configmap"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_immutable_configmap_all/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite immutable_configmap verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: All volume or container mounted configmaps immutable/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample_immutable_configmap_all/cnf-testsuite.yml deploy_with_chart=false`
    end
  end

  it "'immutable_configmap' should pass with all immutable configmaps with env mounted", tags: ["immutable_configmap_env"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_immutable_configmap_all_plus_env/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite immutable_configmap verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: All volume or container mounted configmaps immutable/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample_immutable_configmap_all/cnf-testsuite.yml deploy_with_chart=false`
    end
  end

  it "'immutable_configmap' should fail with a mutable env mounted configmap", tags: ["immutable_configmap_fail"] do
    begin
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample_immutable_configmap_all_plus_env_but_fail/cnf-testsuite.yml deploy_with_chart=false`
      $?.success?.should be_true
      response_s = `./cnf-testsuite immutable_configmap verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: Found mutable configmap/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-config=./sample-cnfs/sample_immutable_configmap_all/cnf-testsuite.yml deploy_with_chart=false`
    end
  end
end
