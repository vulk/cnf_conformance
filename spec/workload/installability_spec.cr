require "../spec_helper"
require "colorize"

describe CnfTestSuite do
  before_all do
    `./cnf-testsuite samples_cleanup`
    $?.success?.should be_true
    LOGGING.info `./cnf-testsuite setup`
  end

  it "'install_script_helm' should fail if install script does not have helm", tags: ["helm"] do
    LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample-coredns-cnf-source/cnf-testsuite.yml verbose wait_count=0`
    $?.success?.should be_true
    response_s = `./cnf-testsuite install_script_helm`
    LOGGING.info response_s
    $?.success?.should be_true
    (/FAILED: Helm not found in supplied install script/ =~ response_s).should_not be_nil
    `./cnf-testsuite sample_coredns_source_cleanup`
  end

  it "'helm_deploy' should fail on a bad helm chart", tags: ["helm"] do
    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=./sample-cnfs/sample-bad-helm-deploy-repo verbose`
    response_s = `./cnf-testsuite helm_deploy destructive verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/FAILED: Helm deploy failed/ =~ response_s).should_not be_nil
  ensure
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=./sample-cnfs/sample-bad-helm-deploy-repo verbose`
  end

  it "'helm_deploy' should fail if command is not supplied cnf-config argument", tags: ["helm"] do
    response_s = `./cnf-testsuite helm_deploy destructive`
    LOGGING.info response_s
    $?.success?.should be_true
    (/No cnf_testsuite.yml found! Did you run the setup task/ =~ response_s).should_not be_nil
  end

  it "'helm_chart_valid' should pass on a good helm chart", tags: ["helm"] do
    LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml verbose wait_count=0`
    $?.success?.should be_true
    response_s = `./cnf-testsuite helm_chart_valid verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/Lint Passed/ =~ response_s).should_not be_nil
  end

  it "'helm_chart_valid' should fail on a bad helm chart", tags: ["helm"] do
    # LOGGING.debug `pwd`
    # LOGGING.debug `echo $KUBECONFIG`
    begin
      `./cnf-testsuite sample_coredns_cleanup force=true`
      $?.success?.should be_true
      LOGGING.info `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample-bad_helm_coredns-cnf/cnf-testsuite.yml verbose wait_count=0`
      $?.success?.should be_true
      response_s = `./cnf-testsuite helm_chart_valid`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Lint Failed/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite bad_helm_cnf_cleanup force=true`
      `./cnf-testsuite cnf_setup cnf-config=./sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml verbose wait_count=0`
    end
  end

  it "'helm_chart_published' should pass on a good helm chart repo", tags: ["helm_chart_published"] do
    begin
      `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample-coredns-cnf`
      $?.success?.should be_true
      response_s = `./cnf-testsuite helm_chart_published`
      LOGGING.info response_s
      $?.success?.should be_true
      (/PASSED: Published Helm Chart Found/ =~ response_s).should_not be_nil
    ensure
      `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-coredns-cnf`
    end
  end

  it "'helm_chart_published' should fail on a bad helm chart repo", tags: ["helm_chart_published"] do
    begin
      LOGGING.info "search command: #{`helm search repo stable/coredns`}"
      # LOGGING.info `#{CNFSingleton.helm} repo remove stable`
      # LOGGING.info "search command: #{`helm search repo stable/coredns`}"
      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample-bad-helm-repo wait_count=0`
      $?.success?.should be_false
      LOGGING.info "search command: #{`helm search repo stable/coredns`}"
      response_s = `./cnf-testsuite helm_chart_published verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/FAILED: Published Helm Chart Not Found/ =~ response_s).should_not be_nil
    ensure
      `#{CNFSingleton.helm} repo remove badrepo`
      `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample-bad-helm-repo`
    end
  end
end
