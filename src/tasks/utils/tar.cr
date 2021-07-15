require "totem"
require "colorize"
require "halite"

# todo put in a separate library. it shold go under ./tools for now
module TarClient
  TAR_REPOSITORY_DIR = "/tmp/repositories"
  TAR_MANIFEST_DIR   = "/tmp/manifests"
  TAR_DOWNLOAD_DIR   = "/tmp/download"
  TAR_IMAGES_DIR     = "/tmp/images"
  TAR_BIN_DIR        = "/tmp/bin"
  TAR_TMP_BASE       = "/tmp"
  TAR_MODIFY_DIR     = "/tmp/modify_tar"

  def self.tar(tarball_name, working_directory, source_file_or_directory, options = "")
    LOGGING.info "TarClient.tar command: tar #{options} -czvf #{tarball_name} -C #{working_directory} #{source_file_or_directory}"
    LOGGING.info "cding into #{working_directory} and tarring #{source_file_or_directory} into #{tarball_name}"
    LOGGING.info "#{tarball_name} exists?: #{File.exists?(tarball_name)}"
    if File.exists?(tarball_name)
      LOGGING.info "#{tarball_name} contents (before tar): #{`tar -tvf #{tarball_name}`}"
    end
    # tar -czvf #{cnf_tarball_name} ./#{cnf_bin_asset_name}
    status = Process.run("tar #{options} -czvf #{tarball_name} -C #{working_directory} #{source_file_or_directory}",
      shell: true,
      output: output = IO::Memory.new,
      error: stderr = IO::Memory.new)
    LOGGING.info "TarClient.tar output: #{output.to_s}"
    LOGGING.info "TarClient.tar stderr: #{stderr.to_s}"
    LOGGING.info "#{tarball_name} contents (after tar): #{`tar -tvf #{tarball_name}`}"
    {status: status, output: output, error: stderr}
  end

  def self.append(tarball_name, working_directory, source_file_or_directory, options = "")
    # working_directory: directory to cd into before running the tar command
    LOGGING.info "TarClient.tar (append) command: tar #{options} -rf #{tarball_name} -C #{working_directory} #{source_file_or_directory}"
    LOGGING.info "cding into #{working_directory} and tarring #{source_file_or_directory} into #{tarball_name}"
    LOGGING.info "#{tarball_name} exists?: #{File.exists?(tarball_name)}"
    if File.exists?(tarball_name)
      LOGGING.info "#{tarball_name} contents (before tar): #{`tar -tvf #{tarball_name}`}"
    end

    status = Process.run("tar #{options} -rf #{tarball_name} -C #{working_directory} #{source_file_or_directory}",
      shell: true,
      output: output = IO::Memory.new,
      error: stderr = IO::Memory.new)
    LOGGING.info "TarClient.tar output: #{output.to_s}"
    LOGGING.info "TarClient.tar stderr: #{stderr.to_s}"
    LOGGING.info "#{tarball_name} contents (after tar): #{`tar -tvf #{tarball_name}`}"
    {status: status, output: output, error: stderr}
  end

  def self.untar(tarball_name, destination_directory, options = "")
    LOGGING.info "TarClient.untar command: tar #{options} -xvf #{tarball_name} -C #{destination_directory}"
    status = Process.run("tar #{options} -xvf #{tarball_name} -C #{destination_directory}",
      shell: true,
      output: output = IO::Memory.new,
      error: stderr = IO::Memory.new)
    LOGGING.info "TarClient.untar output: #{output.to_s}"
    LOGGING.info "TarClient.untar stderr: #{stderr.to_s}"
    {status: status, output: output, error: stderr}
  end

  #
  # modify_tar! << untars file, yields to block, retars, keep in tar module
  #
  def self.modify_tar!(tar_file)
    raise "Critical Error" if tar_file.empty? || tar_file == '/'
    tar_name = tar_file.split("/")[-1]
    FileUtils.mkdir_p(TAR_MODIFY_DIR)
    TarClient.untar(tar_file, TAR_MODIFY_DIR)
    yield TAR_MODIFY_DIR
    `rm #{tar_file}`
    file_list = `ls #{TAR_MODIFY_DIR}`.gsub("\n", " ")
    TarClient.tar(tar_file, TAR_MODIFY_DIR, file_list)
    `rm -rf #{TAR_MODIFY_DIR}`
  end

  def self.tar_file_by_url(url, append_file : String = "./downloaded.tar.gz", output_file = "")
    download_path = "download/"
    `rm -rf /tmp/#{download_path} > /dev/null 2>&1`
    FileUtils.mkdir_p("/tmp/" + download_path)
    if output_file.empty?
      download_name = url.split("/").last
    else
      download_name = output_file
    end
    download_full_path = download_path + download_name
    LOGGING.info "download_name: #{download_name}"
    LOGGING.info "download_full_path: #{download_full_path}"
    Halite.get("#{url}") do |response|
      File.open("/tmp/" + download_full_path, "w") do |file|
        IO.copy(response.body_io, file)
      end
    end
    TarClient.append(append_file, "/tmp", download_full_path)
  ensure
    `rm -rf /tmp/#{download_path} > /dev/null 2>&1`
  end
end
