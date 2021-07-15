require "totem"
require "colorize"
require "./cnf_manager.cr"
require "halite"

module GitClient
  def self.clone(command)
    LOGGING.info "GitClient.clone command: #{command}"
    status = Process.run("git clone #{command}",
      shell: true,
      output: output = IO::Memory.new,
      error: stderr = IO::Memory.new)
    LOGGING.info "GitClient.clone output: #{output.to_s}"
    LOGGING.info "GitClient.clone stderr: #{stderr.to_s}"
    {status: status, output: output, error: stderr}
  end
end
