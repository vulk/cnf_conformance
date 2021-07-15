require "sam"
require "file_utils"
require "colorize"
require "totem"

desc "Static tests"
task "static", ["install_script_helm", "liveness", "ip_addresses"] do |_, args|
end
