require "sam"
require "file_utils"
require "colorize"
require "totem"
require "./utils/utils.cr"

#  LOGGING.info `./cnf-testsuite cnf_setup cnf-config=example-cnfs/coredns/cnf-testsuite.yml airgapped output-file=./tmp/airgapped.tar.gz`
task "cnf_setup", ["helm_local_install"] do |_, args|
  VERBOSE_LOGGING.info "cnf_setup" if check_verbose(args)
  VERBOSE_LOGGING.debug "args = #{args.inspect}" if check_verbose(args)
  cli_hash = CNFManager.sample_setup_cli_args(args)
  output_file = cli_hash[:output_file]
  input_file = cli_hash[:input_file]
  if output_file && !output_file.empty?
    puts "cnf tarball generation mode".colorize(:green)
    tar_info = AirGap.generate_cnf_setup(cli_hash[:config_file], output_file, cli_hash)
    puts "cnf tarball generation mode complete".colorize(:green)
  elsif input_file && !input_file.empty?
    puts "cnf setup airgapped mode".colorize(:green)
    AirGap.extract(input_file)
    puts "cnf setup caching images on nodes (airgapped mode)".colorize(:green)
    AirGap.cache_images(input_file, cnf_setup: true)
    puts "cnf setup finished caching images on nodes (airgapped mode)".colorize(:green)
    CNFManager.sample_setup(cli_hash)
    puts "cnf setup airgapped mode complete".colorize(:green)
  else
    puts "cnf setup online mode".colorize(:green)
    CNFManager.sample_setup(cli_hash)
    puts "cnf setup online mode complete".colorize(:green)
  end
end

task "cnf_cleanup" do |_, args|
  VERBOSE_LOGGING.info "cnf_cleanup" if check_verbose(args)
  VERBOSE_LOGGING.debug "args = #{args.inspect}" if check_verbose(args)
  LOGGING.debug "args = #{args.inspect}"
  if args.named.keys.includes? "cnf-config"
    cnf = args.named["cnf-config"].as(String)
  elsif args.named.keys.includes? "cnf-path"
    cnf = args.named["cnf-path"].as(String)
  else
    stdout_failure "Error: You must supply either cnf-config or cnf-path"
    exit 1
  end
  VERBOSE_LOGGING.debug "cnf_cleanup cnf: #{cnf}" if check_verbose(args)
  if args.named["force"]? && args.named["force"] == "true"
    force = true
  else
    force = false
  end
  # todo make cnf_cleanup deduce if the installation was a manifest installation
  if args.named["installed-from-manifest"]? && args.named["installed-from-manifest"] == "true"
    installed_from_manifest = true
  else
    installed_from_manifest = false
  end
  CNFManager.sample_cleanup(config_file: cnf, force: force, installed_from_manifest: installed_from_manifest, verbose: check_verbose(args))
end

task "CNFManager.helm_repo_add" do |_, args|
  VERBOSE_LOGGING.info "CNFManager.helm_repo_add" if check_verbose(args)
  VERBOSE_LOGGING.debug "args = #{args.inspect}" if check_verbose(args)
  if args.named["cnf-config"]? || args.named["yml-file"]?
    CNFManager.helm_repo_add(args: args)
  else
    CNFManager.helm_repo_add
  end
end

task "generate_config" do |_, args|
  VERBOSE_LOGGING.info "CNFManager.generate_config" if check_verbose(args)
  VERBOSE_LOGGING.debug "args = #{args.inspect}" if check_verbose(args)
  if args.named["config-src"]?
    config_src = args.named["config-src"].as(String)
    output_file = args.named["output-file"].as(String) if args.named["output-file"]?
    output_file = args.named["of"].as(String) if args.named["of"]?
    # TODO make this work in airgapped mode
    if output_file && !output_file.empty?
      LOGGING.info "generating config with an output file"
      CNFManager::GenerateConfig.generate_config(config_src, output_file)
    else
      LOGGING.info "generating config without an output file"
      CNFManager::GenerateConfig.generate_config(config_src)
    end
  end
end

# TODO force all cleanups to use generic cleanup
task "sample_coredns_cleanup" do |_, args|
  CNFManager.sample_cleanup(config_file: "sample-cnfs/sample-coredns-cnf", verbose: true)
end

task "cleanup_sample_coredns" do |_, args|
  CNFManager.sample_cleanup(config_file: "sample-cnfs/sample_coredns", verbose: true)
end

task "bad_helm_cnf_cleanup" do |_, args|
  CNFManager.sample_cleanup(config_file: "sample-cnfs/sample-bad_helm_coredns-cnf", verbose: true)
end

task "sample_privileged_cnf_whitelisted_cleanup" do |_, args|
  CNFManager.sample_cleanup(config_file: "sample-cnfs/sample_whitelisted_privileged_cnf", verbose: true)
end

task "sample_privileged_cnf_non_whitelisted_cleanup" do |_, args|
  CNFManager.sample_cleanup(config_file: "sample-cnfs/sample_privileged_cnf", verbose: true)
end

task "sample_coredns_bad_liveness_cleanup" do |_, args|
  CNFManager.sample_cleanup(config_file: "sample-cnfs/sample_coredns_bad_liveness", verbose: true)
end
task "sample_coredns_source_cleanup" do |_, args|
  CNFManager.sample_cleanup(config_file: "sample-cnfs/sample-coredns-cnf-source", verbose: true)
end

task "sample_generic_cnf_cleanup" do |_, args|
  CNFManager.sample_cleanup(config_file: "sample-cnfs/sample-generic-cnf", verbose: true)
end
