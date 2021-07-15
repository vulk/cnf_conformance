require "totem"
require "colorize"
require "./cnf_manager.cr"
require "./release_manager.cr"
require "./embedded_file_manager.cr"
require "log"
require "file_utils"
require "option_parser"
require "../constants.cr"
require "semantic_version"

def log_formatter
  Log::Formatter.new do |entry, io|
    progname = "cnf-testsuite"
    label = entry.severity.none? ? "ANY" : entry.severity.to_s.upcase
    msg = entry.source.empty? ? "#{progname}: #{entry.message}" : "#{progname}-#{entry.source}: #{entry.message}"
    io << label[0] << ", [" << entry.timestamp << " #" << Process.pid << "] "
    io << label.rjust(5) << " -- " << msg
  end
end

class LogLevel
  class_property command_line_loglevel : String = ""
end

begin
  OptionParser.parse do |parser|
    parser.banner = "Usage: cnf-testsuite [arguments]"
    parser.on("-l LEVEL", "--loglevel=LEVEL", "Specifies the logging level for cnf-testsuite suite") do |level|
      LogLevel.command_line_loglevel = level
    end
    parser.on("-h", "--help", "Show this help") { puts parser }
  end
rescue ex : OptionParser::InvalidOption
  puts ex
end

# this first line necessary to make sure our custom formatter
# is used in the default error log line also
Log.setup(Log::Severity::Error, Log::IOBackend.new(formatter: log_formatter))
Log.setup(loglevel, Log::IOBackend.new(formatter: log_formatter))

def loglevel
  levelstr = "" # default to unset

  # of course last setting wins so make sure to keep the precendence order desired
  # currently
  #
  # 1. Cli flag is highest precedence
  # 2. Environment var is next level of precedence
  # 3. Config file is last level of precedence

  # lowest priority is first
  if File.exists?(BASE_CONFIG)
    config = Totem.from_file BASE_CONFIG
    if config["loglevel"].as_s?
      levelstr = config["loglevel"].as_s
    end
  end

  if ENV.has_key?("LOGLEVEL")
    levelstr = ENV["LOGLEVEL"]
  end

  if ENV.has_key?("LOG_LEVEL")
    levelstr = ENV["LOG_LEVEL"]
  end

  # highest priority is last
  if !LogLevel.command_line_loglevel.empty?
    levelstr = LogLevel.command_line_loglevel
  end

  if Log::Severity.parse?(levelstr)
    Log::Severity.parse(levelstr)
  else
    if !levelstr.empty?
      Log.error { "Invalid logging level set. defaulting to ERROR" }
    end
    # if nothing set but also nothing missplled then silently default to error
    Log::Severity::Error
  end
end

# TODO: get rid of LogginGenerator and VerboseLogginGenerator evil sourcery and refactor the rest of the code to use Log + procs directly
class LogginGenerator
  macro method_missing(call)
    if {{ call.name.stringify }} == "debug"
      Log.debug {{{call.args[0]}}}
    end
    if {{ call.name.stringify }} == "info"
      Log.info {{{call.args[0]}}}
    end
    if {{ call.name.stringify }} == "warn"
      Log.warn {{{call.args[0]}}}
    end
    if {{ call.name.stringify }} == "error"
      Log.error {{{call.args[0]}}}
    end
    if {{ call.name.stringify }} == "fatal"
      Log.fatal {{{call.args[0]}}}
    end
  end
end

class VerboseLogginGenerator
  macro method_missing(call)
    source = "verbose"
    if {{ call.name.stringify }} == "debug"
      Log.for(source).debug {{{call.args[0]}}}
    end
    if {{ call.name.stringify }} == "info"
      Log.for(source).info {{{call.args[0]}}}
    end
    if {{ call.name.stringify }} == "warn"
      Log.for(source).warn {{{call.args[0]}}}
    end
    if {{ call.name.stringify }} == "error"
      Log.for(source).error {{{call.args[0]}}}
    end
    if {{ call.name.stringify }} == "fatal"
      Log.for(source).fatal {{{call.args[0]}}}
    end
  end
end

LOGGING         = LogginGenerator.new
VERBOSE_LOGGING = VerboseLogginGenerator.new

def check_verbose(args)
  ((args.raw.includes? "verbose") || (args.raw.includes? "v"))
end

def check_cnf_config(args)
  VERBOSE_LOGGING.debug "args = #{args.inspect}" if check_verbose(args)
  LOGGING.info("check_cnf_config args: #{args.inspect}")
  if args.named.keys.includes? "cnf-config"
    yml_file = args.named["cnf-config"].as(String)
    cnf = File.dirname(yml_file)
    VERBOSE_LOGGING.info "all cnf: #{cnf}" if check_verbose(args)
  else
    cnf = nil
  end
  LOGGING.info("check_cnf_config cnf: #{cnf}")
  cnf
end

def toggle(toggle_name)
  toggle_on = false
  if File.exists?(BASE_CONFIG)
    config = Totem.from_file BASE_CONFIG
    if config["toggles"].as_a?
      feature_flag = config["toggles"].as_a.find do |x|
        x["name"] == toggle_name
      end
      toggle_on = feature_flag["toggle_on"].as_bool if feature_flag
    end
  else
    toggle_on = false
  end
  toggle_on
end

# # check feature level e.g. --beta
# # if no feature level then feature level = ga
def check_feature_level(args)
  LOGGING.info "args.raw #{args.raw}"
  case args.raw
  when .includes? "poc"
    "poc"
  when .includes? "wip"
    "wip"
  when .includes? "alpha"
    "alpha"
  when .includes? "beta"
    "beta"
  else
    "ga"
  end
end

# cncf/cnf-testsuite/issues/106
# Requesting beta tests to run will both beta and ga flagged tests
# Requesting alpha tests will run alpha, beta, and ga flagged tests
# Requesting wip tests will run wip, poc, alpha, beta, and ga flagged tests

# if the beta flag or alpha flag is true, then beta tests should be run
def check_beta
  toggle("beta") || check_alpha
end

# if the beta flag or alpha flag is true, then beta tests should be run
def check_beta(args)
  toggle("beta") || check_feature_level(args) == "beta" || check_alpha(args)
end

# if the alpha flag or wip flag is true, then alpha tests should be run
def check_alpha
  toggle("alpha") || check_wip
end

# if the alpha flag or wip flag is true, then alpha tests should be run
def check_alpha(args)
  toggle("alpha") || check_feature_level(args) == "alpha" || check_wip(args)
end

def check_wip
  toggle("wip") || toggle("poc")
end

def check_wip(args)
  toggle("wip") || check_feature_level(args) == "wip" ||
    toggle("poc") || check_feature_level(args) == "poc"
end

def check_poc
  check_wip
end

def check_poc(args)
  check_wip(args)
end

def check_destructive
  toggle("destructive")
end

def check_destructive(args)
  LOGGING.info "args.raw #{args.raw}"
  toggle("destructive") || args.raw.includes?("destructive")
end

def update_yml(yml_file, top_level_key, value)
  results = File.open("#{yml_file}") do |f|
    YAML.parse(f)
  end
  LOGGING.debug "update_yml results: #{results}"
  # The last key assigned wins
  new_yaml = YAML.dump(results) + "\n#{top_level_key}: #{value}"
  parsed_new_yml = YAML.parse(new_yaml)
  LOGGING.debug "update_yml parsed_new_yml: #{parsed_new_yml}"
  File.open("#{yml_file}", "w") do |f|
    YAML.dump(parsed_new_yml, f)
  end
end

def upsert_failed_task(task, message)
  CNFManager::Points.upsert_task(task, FAILED, CNFManager::Points.task_points(task, false))
  stdout_failure message
  message
end

def upsert_passed_task(task, message)
  CNFManager::Points.upsert_task(task, PASSED, CNFManager::Points.task_points(task))
  stdout_success message
  message
end

def upsert_skipped_task(task, message)
  CNFManager::Points.upsert_task(task, SKIPPED, CNFManager::Points.task_points(task, CNFManager::Points::Results::ResultStatus::Skipped))
  stdout_warning message
  message
end

def upsert_na_task(task, message)
  CNFManager::Points.upsert_task(task, NA, CNFManager::Points.task_points(task, CNFManager::Points::Results::ResultStatus::NA))
  stdout_warning message
  message
end

def stdout_info(msg)
  puts msg
end

def stdout_success(msg)
  puts msg.colorize(:green)
end

def stdout_warning(msg)
  puts msg.colorize(:yellow)
end

def stdout_failure(msg)
  puts msg.colorize(:red)
end

def stdout_score(test_name)
  total = CNFManager::Points.total_points(test_name)
  pretty_test_name = test_name.split(/:|_/).map(&.capitalize).join(" ")
  # test_log_msg = "#{pretty_test_name} final score: #{total} of #{CNFManager::Points.total_max_points(test_name)}"
  test_log_msg =
    <<-STRING
#{pretty_test_name} final score: #{total} of #{CNFManager::Points.total_max_points(test_name)}

STRING

  if total > 0
    stdout_success test_log_msg
  else
    stdout_failure test_log_msg
  end
end

# this method extracts a string value from a config section if it exists
# if the value is an integer it will be converted to a string before extraction
def optional_key_as_string(totem_config, key_name)
  "#{totem_config[key_name]? && (totem_config[key_name].as_s? || totem_config[key_name].as_i?)}"
end

# compare 2 SemVer strings and return true if v1 is less than v2
def version_less_than(v1str, v2str)
  # NOTES: This is why the below code attempts to strip the plus sign from the versions.
  # Versions for microk8s look like this: "1.20+". As a result, the input args to this function may be "1.20+.0"
  # This results in bad input to the semantic version parser.
  # To allow microk8s, we strip the plus sign from the versions.

  v1 = SemanticVersion.parse(v1str.gsub("+", ""))
  v2 = SemanticVersion.parse(v2str.gsub("+", ""))
  less_than = (v1 <=> v2) == -1
  LOGGING.debug "version_less_than: #{v1} < #{v2}: #{less_than}"
  less_than
end
