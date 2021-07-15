require "totem"
require "colorize"

module Find
  def self.find(directory, wildcard = "*.tar*", maxdepth = "1", silent = true)
    LOGGING.info "find command: find #{directory} -maxdepth #{maxdepth} -name #{wildcard}"
    status = Process.run("find #{directory} -maxdepth #{maxdepth} -name \"#{wildcard}\"",
      shell: true,
      output: output = IO::Memory.new,
      error: stderr = IO::Memory.new)
    LOGGING.info "find output: #{output.to_s}"
    LOGGING.info "find stderr: #{stderr.to_s}"
    found_files = output.to_s.split("\n").select { |x| x.empty? == false }
    if found_files.size == 0 && !silent
      raise "No files found!"
    end
    found_files
  end
end
