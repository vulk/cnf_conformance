require "sam"
require "file_utils"
require "colorize"
require "totem"
require "./utils/utils.cr"

desc "Sets up api snoop"
task "install_api_snoop" do |_, args|
  response = String::Builder.new
  Process.run("echo installing api snoop", shell: true) do |proc|
    while line = proc.output.gets
      response << line
      VERBOSE_LOGGING.info "#{line}" if check_verbose(args)
    end
  end
end
