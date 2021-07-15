require "sam"
require "file_utils"
require "colorize"
require "totem"
require "./utils/utils.cr"

desc "Sets up initial directories for the cnf-testsuite suite"
task "cnf_testsuite_setup", ["cnf_directory_setup"] do |_, args|
end

desc "Sets up initial directories for the cnf-testsuite suite"
task "cnf_directory_setup" do |_, args|
  FileUtils.mkdir_p("cnfs")
  FileUtils.mkdir_p("tools")
  stdout_success "Successfully created directories for cnf-testsuite"
end
