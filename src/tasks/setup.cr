require "sam"
require "file_utils"
require "colorize"
require "totem"

desc "Sets up the CNF test suite, the K8s cluster, and upstream projects"

task "setup", ["offline", "helm_local_install", "prereqs", "configuration_file_setup", "install_opa", "install_api_snoop", "install_sonobuoy", "install_chart_testing", "cnf_testsuite_setup"] do |_, args|
  stdout_success "Setup complete"
end

task "offline" do |_, args|
  # ./cnf-testsuite setup --offline=./airgapped.tar.gz
  # ./cnf-testsuite setup --input-file=./airgapped.tar.gz
  # ./cnf-testsuite setup --if=./airgapped.tar.gz
  input_file = args.named["offline"].as(String) if args.named["offline"]?
  input_file = args.named["input-file"].as(String) if args.named["input-file"]?
  input_file = args.named["if"].as(String) if args.named["if"]?
  if input_file && !input_file.empty?
    AirGap.extract(input_file)
    AirGap.cache_images(input_file)
  end
end

task "configuration_file_setup" do |_, args|
  VERBOSE_LOGGING.info "configuration_file_setup" if check_verbose(args)
  CNFManager::Points.create_points_yml
end
