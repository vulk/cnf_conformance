require "option_parser"
require "path"
require "file_utils"

# There are two environments, inside of docker and outside of docker
# Outside of docker
#  -- You don't need crystal installed
#  -- You do need the cnf-testsuite source (git clone)?
#    -- The container mounts the cnf-testsuite directory
#  -- You do need the ephemeral_env binary
#    -- pull down from a release
#    -- binary could be checked in??
# Inside of docker
#   -- crystal needs to be installed
#   -- There are two binaries, ephemeral_env and cnf-testsuite
# Are we in a ephemeral_env binary?  Can we tell this from the arguments?
#  -- if we are in a ephemeral_env binary, use the binary version of the alias command
#  -- otherwise use the crystal version
# Is there a cnf-testsuite binary? We dont call cnf-testsuite binary directly
if ARGV[0]? && ARGV[0] == "setup"
  bin_path = ""
  crystal_path = ""
  source_path = ""
  OptionParser.parse do |parser|
    parser.banner = "Usage: setup [--binary] | [--crystal --source]"
    parser.on("-b PATH", "--binary=PATH", "Full path to ephemeral dev tool binary. Set this if you want the alias                                                        command to execute using a compiled version of the dev tool, this is required
                                     if you don't have 'crystal' installed.") { |path| bin_path = path }
    parser.on("-c PATH", "--crystal=PATH", "Full path to the Crystal Lang executable. Set this if you want the alias                                                      command to execute using the source version of the dev tool.") { |path| crystal_path = path }
    parser.on("-s PATH", "--source=PATH", "Full path to the source ephemeral_env.cr file. Set this if you want the alias \n                                     command to execute using the source version of the dev tool.") { |path| source_path = path }
    parser.on("-h", "--help", "Show this help") { puts parser }
    parser.invalid_option do |flag|
      STDERR.puts "ERROR #{flag} is not valid"
      STDERR.puts parser
      exit 1
    end
  end
  if (!bin_path.empty?) || (!crystal_path.empty? && !source_path.empty?)
    system "docker build -t cnf-test:latest $(pwd)/tools/ephemeral_env/"
    home = Path.home
    unless Dir.exists?("#{home}/.bash.d")
      FileUtils.mkdir("#{home}/.bash.d")
    end
    crystal_alias = "#{home}/.bash.d/crystal.alias"
    cnf_testsuite_alias = "#{home}/.bash.d/cnf_testsuite.alias"
  end
  if !bin_path.empty?
    File.write("#{crystal_alias}", "alias crystal='#{bin_path} command alias $@'")
    File.write("#{cnf_testsuite_alias}", "alias cnf-testsuite='#{bin_path} command alias binary $@'")
    puts "A Crystal alias has been created under #{crystal_alias} & #{cnf_testsuite_alias} \n But you will need to restart your terminal session for it to apply, or in your current session you can manually run: \n alias crystal='crystal #{bin_path} command alias $@' \n alias cnf-testsuite='crystal #{bin_path} command alias binary $@'"
  elsif !crystal_path.empty? && !source_path.empty?
    File.write("#{crystal_alias}", "alias crystal='#{crystal_path} #{source_path} command alias -- $@'")
    File.write("#{cnf_testsuite_alias}", "alias cnf-testsuite='#{crystal_path} #{source_path} command alias binary -- $@'")
    puts "Crystal aliases has been created under #{crystal_alias} & #{cnf_testsuite_alias} \n But you will need to restart your terminal session for it to apply, or in your current session you can manually run: \n alias crystal='#{crystal_path} #{source_path} command alias -- $@' \n alias cnf-testsuite='#{crystal_path} #{source_path} command alias binary -- $@'"
  else
    puts "Missing Arguments: [--binary] or [--crystal --source]"
  end
elsif ARGV[0]? && ARGV[0] == "cleanup"
  bash_alias = ""
  force = ""
  prune = ""
  all = ""
  OptionParser.parse do |parser|
    parser.banner = "Usage: cleanup [arguments]"
    parser.on("-a", "--alias", "Cleanup the bash alias") { bash_alias = true }
    parser.on("-p", "--prune", "Cleanup inactive environments") { prune = true }
    parser.on("-A", "--all", "Cleanup images, alias and environments") { all = true }
    parser.on("-f", "--force", "Force removal of all active environments in additon to inactive") { force = "-f" }
    parser.on("-h", "--help", "Show this help") { puts parser }
    parser.invalid_option do |flag|
      STDERR.puts "ERROR #{flag} is not valid"
      STDERR.puts parser
    end
    if ARGV.size == 1
      puts parser
    end
  end

  if bash_alias == true || all == true
    if File.exists?("#{Path.home}/.bash.d/crystal.alias")
      FileUtils.rm("#{Path.home}/.bash.d/crystal.alias")
    end
    if File.exists?("#{Path.home}/.bash.d/cnf_testsuite.alias")
      FileUtils.rm("#{Path.home}/.bash.d/cnf_testsuite.alias")
    end
  end

  if prune == true || all == true
    if force.empty?
      envs = `docker ps -f ancestor=cnf-test -f status=exited -f status=created --format '{{.Names}}'`
    else
      envs = `docker ps -f ancestor=cnf-test --format '{{.Names}}'`
    end
    envs_list = envs.split("\n")
    envs_list.pop
    envs_list.each do |env|
      `docker rm #{force} #{env}`
    end
  end
elsif ARGV[0]? && ARGV[0] == "create_env"
  env_name = ""
  kubeconfig = ""
  OptionParser.parse do |parser|
    parser.banner = "Usage: create_env [arguments]"
    parser.on("-n NAME", "--name=NAME", "[Required] Specifies the name of the env to create") { |name| env_name = name }
    parser.on("-k FILE", "--kubeconfig=FILE", "[Required] Specifies the path to a kubeconfig") { |file| kubeconfig = file }
    parser.on("-h", "--help", "Show this help") { puts parser }
    parser.invalid_option do |flag|
      STDERR.puts "ERROR #{flag} is not valid"
      STDERR.puts parser
      exit 1
    end
  end
  if env_name.empty? && kubeconfig.empty?
    puts "Required arguments missing [-n, --name] [-k, --kubeconfig]"
  elsif kubeconfig.empty?
    puts "Required argument missing [-k, --kubeconfig]"
  elsif env_name.empty?
    puts "Required argument missing [-n, --name]"
  else
    puts "Creating ENV For: \n Name: #{env_name} \n Kubeconfig: #{kubeconfig}"
    `docker run --name #{env_name} --network host -d -e GITHUB_USER=$GITHUB_USER -e GITHUB_TOKEN=$GITHUB_TOKEN -e DOCKERHUB_USERNAME=$DOCKERHUB_USERNAME -e DOCKERHUB_PASSWORD=$DOCKERHUB_PASSWORD -v $(pwd):/cnf-testsuite -v #{kubeconfig}:/root/.kube/config -ti cnf-test /bin/sleep infinity`
    puts `docker ps -f name=#{env_name}`
  end
elsif ARGV[0]? && ARGV[0] == "delete_env"
  env_name = ""
  OptionParser.parse do |parser|
    parser.banner = "Usage: delete_env [arguments]"
    parser.on("-n NAME", "--name=NAME", "[Required] Specifies the name of the env to delete") { |name| env_name = name }
    parser.on("-h", "--help", "Show this help") { puts parser }
    parser.invalid_option do |flag|
      STDERR.puts "ERROR #{flag} is not valid"
      STDERR.puts parser
      exit 1
    end
  end

  if env_name.empty?
    puts "Required argument missing [-n, --name]"
  else
    puts "Deleteing ENV For: #{env_name}"
    `docker rm -f #{env_name}`
  end
elsif ARGV[0] && ARGV[0] == "list_envs"
  OptionParser.parse do |parser|
    parser.banner = "Usage: list_envs"
    parser.on("-h", "--help", "Show this help") { puts parser }
    parser.invalid_option do |flag|
      STDERR.puts "ERROR #{flag} is not valid"
      STDERR.puts parser
      exit 1
    end
  end

  envs = `docker ps -f ancestor=cnf-test --format '{{.Names}}'`
  envs_list = envs.split("\n")
  envs_list.pop
  if envs_list.empty?
    puts "You currently don't have any active envs, to create one run 'create_env'"
  else
    envs_list.each do |env|
      puts "export CRYSTAL_DEV_ENV=#{env}"
    end
    puts "To Set an ENV run one of the export commands in your session e.g. 'export CRYSTAL_DEV_ENV=test44'"
  end
elsif ARGV[0]? && ARGV[0] == "command"
  usage = "Usage: command [execute_command]"
  if ARGV[1]? == "--help" || ARGV[1] == "-h"
    puts "#{usage}"
    exit 0
  end

  if ARGV.find { |x| x == "alias" }
    puts "WARNING: Crystal Alias in use. All crystal commands are being piped to the env container"
    ARGV.delete("alias")
  end

  if ARGV.find { |x| x == "binary" }
    binary = true
    ARGV.delete("binary")
  end

  execute_command = ARGV[1..-1].join(" ")
  if ENV["CRYSTAL_DEV_ENV"]?
    puts "Using Environment: #{ENV["CRYSTAL_DEV_ENV"]}"
    # ./ephemeral_env crystal spec
    # ./ephemeral_env ./cnf-testsuite all
    # ./ephemeral_env crystal src/cnf-testsuite.cr all
    # crystal ephemeral.cr crystal spec
    # crystal ephemeral.cr ./cnf-testsuite all
    # crystal ephemeral.cr crystal src/cnf-testsuite.cr all
    # cyrstal spec
    # cyrstal src/cnf-testsuite.cr all
    # cyrstal ./cnf-testsuite all
    if binary == true
      system "docker exec -ti #{ENV["CRYSTAL_DEV_ENV"]} ./cnf-testsuite #{execute_command}"
      exit $?.exit_code
    else
      system "docker exec -ti #{ENV["CRYSTAL_DEV_ENV"]} crystal #{execute_command}"
      exit $?.exit_code
    end
  else
    puts "CRYSTAL_DEV_ENV Not Set. Run list_envs and select one"
  end
else
  puts "Usage: [setup | cleanup | create_env | delete_env | list_envs | command]"
  OptionParser.parse do |parser|
    parser.on("-h", "--help", "Show this help") { puts parser }
    parser.invalid_option do |flag|
      STDERR.puts "ERROR #{flag} is not valid"
      STDERR.puts parser
    end
  end
end
